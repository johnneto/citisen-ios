import MapKit
import SwiftData
import SwiftUI

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
    @Environment(AppRouter.self)
    private var router

    @State private var viewModel: POISheetViewModel?
    @State private var showMoreReviewsAlert = false
    @State private var showVoiceAlert = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = POISheetViewModel(place: place, context: modelContext)
            }
        }
    }

    private func content(_ vm: POISheetViewModel) -> some View {
        @Bindable var vm = vm
        let shouldExpand = router.poiDetent != .height(340)

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    header
                    titleAndMeta

                    if shouldExpand {
                        Divider().background(AppColor.dividerSoft).padding(.vertical, 2)
                        tagsRow
                        heroCarousel
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
                SaveRatingMenu(current: vm.currentRating) { rating in
                    vm.pick(rating)
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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            ModeChip(mode: place.mode, style: .tint)
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

    private var titleAndMeta: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(place.name)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
                .kerning(-0.5)
                .lineLimit(2)

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

    // MARK: - Expanded sections

    private var tagsRow: some View {
        HStack(spacing: 6) {
            ForEach(place.tags, id: \.self) { tag in
                TagChip(label: tag)
            }
            Spacer(minLength: 0)
        }
    }

    private var heroCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let photoNames = place.photoNames, !photoNames.isEmpty {
                    ForEach(Array(photoNames.enumerated()), id: \.offset) { index, name in
                        PlacePhotoView(
                            photoName: name,
                            mode: place.mode,
                            seed: "\(place.id.uuidString)-\(index)",
                            height: 160,
                            cornerRadius: Radius.md
                        )
                        .frame(width: 240)
                    }
                } else {
                    ForEach(0..<3, id: \.self) { index in
                        PlaceholderPhoto(
                            seed: "\(place.id.uuidString)-\(index)",
                            mode: place.mode,
                            height: 160,
                            cornerRadius: Radius.md
                        )
                        .frame(width: 200)
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
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { vm.isHoursExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(AppColor.textSecondary)
                    Group {
                        Text(place.isOpenNow ? "Open now" : "Closed")
                            .foregroundStyle(place.isOpenNow ? AppColor.success : AppColor.danger)
                            .fontWeight(.semibold)
                        if let closes = place.closesAt {
                            Text(" · Closes \(closes)").foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .font(.subheadline15)
                    Spacer()
                    Image(systemName: vm.isHoursExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption12)
                        .foregroundStyle(AppColor.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if vm.isHoursExpanded {
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
            Label(place.address, systemImage: "mappin.circle")
                .font(.caption12)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var reviewsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reviews")
                    .font(.headline17)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Button {
                    showMoreReviewsAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add review")
                    }
                    .font(.caption11Bold)
                    .foregroundStyle(place.mode.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(place.mode.tintColor)
                    .clipShape(Capsule())
                }
            }

            ForEach(place.reviews) { review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Avatar(initials: String(review.authorName.prefix(1)), size: 28)
                        Text(review.authorName)
                            .font(.footnote13.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("· \(review.daysAgo)d ago")
                            .font(.caption12)
                            .foregroundStyle(AppColor.textTertiary)
                        Spacer()
                        HStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { idx in
                                Image(systemName: idx < review.rating ? "star.fill" : "star")
                                    .font(.system(size: 11))
                                    .foregroundStyle(idx < review.rating ? AppColor.warning : AppColor.textTertiary)
                            }
                        }
                    }
                    Text(review.text)
                        .font(.subheadline15)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineSpacing(2)
                }
                .padding(.vertical, 6)
                Divider().background(AppColor.dividerSoft)
            }

            Button {
                showMoreReviewsAlert = true
            } label: {
                Text("See all reviews")
                    .font(.subheadline15.weight(.medium))
                    .foregroundStyle(BrandColor.sand)
            }
        }
    }

    // MARK: - Action bar

    private func actionBar(vm: POISheetViewModel) -> some View {
        let rating = vm.currentRating
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
