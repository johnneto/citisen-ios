import MapKit
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// swiftlint:disable:next type_body_length
struct POISheetView: View {
    let place: Place

    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.openURL)
    private var openURL
    @Environment(\.dismiss)
    private var dismiss
    @Environment(CityService.self)
    private var cityService
    @Environment(UserPreferencesService.self)
    private var prefs
    @Environment(AppRouter.self)
    private var router

    @Query private var savedQueryResults: [SavedSpotEntity]

    @State private var viewModel: POISheetViewModel?
    @State private var showMoreReviewsAlert = false
    @State private var showVoiceAlert = false
    @State private var didCopyAddress = false
    @State private var viewerPhotoIndex: Int?

    init(place: Place) {
        self.place = place
        let pid = place.id
        _savedQueryResults = Query(filter: #Predicate<SavedSpotEntity> { $0.placeId == pid })
    }

    /// Reactively reflects the SwiftData state so the saved indicator stays in
    /// sync across travel-mode switches and external mutations (e.g. removing
    /// the entity from the saved tab while the sheet is open).
    private var currentRating: SavedSpotRating? {
        savedQueryResults.first?.rating
    }

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .task(id: place.id) {
            if viewModel == nil {
                viewModel = POISheetViewModel(
                    place: place,
                    context: modelContext,
                    cityInfoProvider: { [cityService, prefs, place] in
                        Self.resolveCityInfo(
                            for: place.cityId,
                            cityService: cityService,
                            prefs: prefs
                        )
                    }
                )
            }
        }
    }

    private static func resolveCityInfo(
        for cityId: String,
        cityService: CityService,
        prefs: UserPreferencesService
    ) -> CityInfo? {
        if cityService.activeCity.id == cityId {
            let city = cityService.activeCity
            return CityInfo(name: city.name, country: city.country, flag: city.flagEmoji)
        }
        if let recent = prefs.recentCities.first(where: { $0.id == cityId }) {
            return CityInfo(name: recent.name, country: recent.country, flag: recent.flagEmoji)
        }
        if let dynamic = cityService.dynamicCity, dynamic.id == cityId {
            return CityInfo(name: dynamic.name, country: dynamic.country, flag: dynamic.flagEmoji)
        }
        if let preset = City.all.first(where: { $0.id == cityId }) {
            return CityInfo(name: preset.name, country: preset.country, flag: preset.flagEmoji)
        }
        return nil
    }

    private func content(_ vm: POISheetViewModel) -> some View {
        @Bindable var vm = vm
        let shouldExpand = router.poiDetent != .height(340)

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    header
                    titleAndMeta
                    if !shouldExpand {
                        whyVisitRow
                    }
                    heroCarousel(compact: !shouldExpand)

                    if shouldExpand {
                        Divider().background(AppColor.dividerSoft).padding(.vertical, 2)
                        tagsRow
                        descriptionBlock
                        hoursBlock(vm: vm)
                        contactBlock
                        Divider().background(AppColor.dividerSoft).padding(.vertical, 2)
                        reviewsBlock
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }

            actionBar(vm: vm)
        }
        .overlay(alignment: .bottomTrailing) {
            if vm.isSaveMenuOpen {
                SaveRatingMenu(current: currentRating) { rating in
                    vm.pick(rating, currentRating: currentRating)
                }
                .padding(.trailing, Spacing.md)
                .padding(.bottom, 92)
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: vm.isSaveMenuOpen)
            }
        }
        .alert("More reviews coming soon", isPresented: $showMoreReviewsAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("Voice search coming soon", isPresented: $showVoiceAlert) {
            Button("OK", role: .cancel) {}
        }
        .fullScreenCover(item: Binding(
            get: { viewerPhotoIndex.map(PhotoViewerPresentation.init) },
            set: { viewerPhotoIndex = $0?.index }
        )) { presentation in
            PhotoViewerView(
                photoNames: place.photoNames ?? [],
                initialIndex: presentation.index,
                mode: place.mode
            )
        }
    }

    private struct PhotoViewerPresentation: Identifiable {
        let index: Int
        var id: Int { index }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ModeChip(mode: place.mode, style: .tint)
            closedBadge
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(AppColor.surfaceGrouped)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
        }
    }

    @ViewBuilder private var closedBadge: some View {
        switch place.businessStatus {
        case .closedTemporarily:
            ClosedStatusBadge(text: "Temporarily closed")
        case .closedPermanently:
            ClosedStatusBadge(text: "Permanently closed")
        default:
            EmptyView()
        }
    }

    private var titleAndMeta: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(place.name)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
                .kerning(-0.5)
                .lineLimit(2)
                .contentShape(Rectangle())
                .onTapGesture { focusMapOnPlace() }
                .contextMenu {
                    Button {
                        copyName()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .accessibilityHint("Double tap to focus map on this place. Long press to copy name.")

            HStack(spacing: 8) {
                Text(place.formattedDistance(from: cityService.activeCity.center.clLocation) + " away")
                Text("·").foregroundStyle(AppColor.textTertiary)
                Text(place.budgetLabel)
                Text("·").foregroundStyle(AppColor.textTertiary)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.warning)
                    Text(String(format: "%.1f", place.rating))
                }
                Text("(\(place.reviewCount))")
                    .foregroundStyle(AppColor.textTertiary)
            }
            .font(.footnote13)
            .foregroundStyle(AppColor.textSecondary)
        }
    }

    @ViewBuilder private var whyVisitRow: some View {
        let trimmed = place.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(place.mode.color)
                Text(trimmed)
                    .font(.footnote13.italic())
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Expanded sections

    private var tagsRow: some View {
        HStack(spacing: 6) {
            ForEach(place.tags, id: \.self) { tag in
                TagChip(label: tag)
            }
            Spacer(minLength: 0)
        }
    }

    private func heroCarousel(compact: Bool) -> some View {
        let photoHeight: CGFloat = compact ? 96 : 160
        let photoWidth: CGFloat = compact ? 140 : 240
        let placeholderWidth: CGFloat = compact ? 120 : 200

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let photoNames = place.photoNames, !photoNames.isEmpty {
                    ForEach(Array(photoNames.enumerated()), id: \.offset) { index, name in
                        Button {
                            viewerPhotoIndex = index
                        } label: {
                            PlacePhotoView(
                                photoName: name,
                                mode: place.mode,
                                seed: "\(place.id.uuidString)-\(index)",
                                height: photoHeight,
                                cornerRadius: Radius.md
                            )
                            .frame(width: photoWidth)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open photo \(index + 1) of \(photoNames.count)")
                    }
                } else {
                    ForEach(0..<3, id: \.self) { index in
                        PlaceholderPhoto(
                            seed: "\(place.id.uuidString)-\(index)",
                            mode: place.mode,
                            height: photoHeight,
                            cornerRadius: Radius.md
                        )
                        .frame(width: placeholderWidth)
                    }
                }
            }
        }
    }

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.description)
                .font(.subheadline15)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
        }
    }

    private func hoursBlock(vm: POISheetViewModel) -> some View {
        @Bindable var vm = vm
        let isBusinessClosed = place.businessStatus == .closedTemporarily
            || place.businessStatus == .closedPermanently
        let hasHours = place.openingHours.hasAny
        let isCollapsible = !isBusinessClosed && hasHours
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                guard isCollapsible else { return }
                withAnimation(.easeInOut(duration: 0.2)) { vm.isHoursExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(AppColor.textSecondary)
                    Group {
                        switch place.businessStatus {
                        case .closedTemporarily:
                            Text("Temporarily closed")
                                .foregroundStyle(AppColor.danger)
                                .fontWeight(.semibold)
                        case .closedPermanently:
                            Text("Permanently closed")
                                .foregroundStyle(AppColor.danger)
                                .fontWeight(.semibold)
                        default:
                            if hasHours {
                                Text(place.isOpenNow ? "Open now" : "Closed")
                                    .foregroundStyle(place.isOpenNow ? AppColor.success : AppColor.danger)
                                    .fontWeight(.semibold)
                                if place.isOpenNow, let closes = place.closesAt {
                                    Text(" · Closes \(closes)").foregroundStyle(AppColor.textSecondary)
                                }
                            } else {
                                Text("No opening information available")
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                        }
                    }
                    .font(.subheadline15)
                    Spacer()
                    if isCollapsible {
                        Image(systemName: vm.isHoursExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption12)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!isCollapsible)

            if vm.isHoursExpanded && isCollapsible {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(place.openingHours.weekList.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(entry.day).frame(width: 36, alignment: .leading)
                                .foregroundStyle(AppColor.textSecondary)
                            Text(entry.hours)
                                .foregroundStyle(AppColor.textPrimary)
                        }
                        .font(.caption12)
                    }
                }
                .padding(.leading, 22)
            }
        }
    }

    private var contactBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let website = place.website {
                Button {
                    openURL(website)
                } label: {
                    Label(website.host ?? website.absoluteString, systemImage: "globe")
                        .font(.subheadline15)
                        .foregroundStyle(BrandColor.sand)
                }
            }
            if let phone = place.phone,
               let url = URL(string: "tel://\(phone.filter(\.isNumber))") {
                Button {
                    openURL(url)
                } label: {
                    Label(phone, systemImage: "phone.fill")
                        .font(.subheadline15)
                        .foregroundStyle(BrandColor.sand)
                }
            }
            Button(action: copyAddress) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle")
                    Text(place.address)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 6)
                    Image(systemName: didCopyAddress ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(didCopyAddress ? AppColor.success : AppColor.textTertiary)
                }
                .font(.caption12)
                .foregroundStyle(AppColor.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(didCopyAddress ? "Address copied" : "Copy address")
            .accessibilityValue(place.address)
        }
    }

    private func focusMapOnPlace() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            router.poiDetent = .height(340)
        }
        router.requestPOIRecenter()
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func copyName() {
        #if canImport(UIKit)
        UIPasteboard.general.string = place.name
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func copyAddress() {
        #if canImport(UIKit)
        UIPasteboard.general.string = place.address
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            didCopyAddress = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeInOut(duration: 0.2)) { didCopyAddress = false }
        }
    }

    private var reviewsBlock: some View {
        POIReviewsBlock(
            place: place,
            onAddReview: { showMoreReviewsAlert = true },
            onSeeAll: { showMoreReviewsAlert = true }
        )
    }

    // MARK: - Action bar

    private func actionBar(vm: POISheetViewModel) -> some View {
        let rating = currentRating
        let background: Color = rating?.color ?? place.mode.color

        return HStack(spacing: 10) {
            ShareLink(
                item: appleMapsURL(for: place),
                subject: Text(place.name),
                message: Text("Check out \(place.name) on Citisen.")
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.subheadline15.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppColor.surfaceElevated)
                .overlay(Capsule().strokeBorder(AppColor.divider, lineWidth: 0.5))
                .clipShape(Capsule())
            }

            Button(action: openDirections) {
                HStack(spacing: 6) {
                    Image(systemName: "location.north.line.fill")
                    Text("Directions")
                }
                .font(.subheadline15.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppColor.surfaceElevated)
                .overlay(Capsule().strokeBorder(AppColor.divider, lineWidth: 0.5))
                .clipShape(Capsule())
            }
            .buttonStyle(.pressableScale)

            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    vm.toggleSaveMenu()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: rating?.iconSymbol ?? "bookmark.fill")
                    Text(rating?.label ?? "Save")
                        .lineLimit(1)
                }
                .font(.subheadline15.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(background)
                .clipShape(Capsule())
                .shadow(color: background.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.pressableScale)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surfaceElevated.opacity(0.92))
    }

    private func appleMapsURL(for place: Place) -> URL {
        let latitude = place.coordinate.latitude
        let longitude = place.coordinate.longitude
        let encodedName = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name
        // swiftlint:disable:next force_unwrapping
        return URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(encodedName)")!
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: place.coordinate.clLocation)
        let item = MKMapItem(placemark: placemark)
        item.name = place.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
