import SwiftData
import SwiftUI

struct SavedPlacesView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(LocationService.self)
    private var locationService

    @Query(sort: \SavedPlace.timestamp, order: .reverse)
    private var allSavedPlaces: [SavedPlace]

    @State private var viewModel: SavedPlacesViewModel?
    @State private var showingAddPlaceSheet = false

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SavedPlacesViewModel(modelContext: modelContext)
                locationService.requestWhenInUse()
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: SavedPlacesViewModel) -> some View {
        @Bindable var vm = vm
        NavigationStack {
            VStack(spacing: 0) {
                FilterBarView(viewModel: vm)
                    .padding(.vertical, Spacing.xs)
                Divider()
                SavedPlacesList(
                    viewModel: vm,
                    sections: vm.groupedSections(from: allSavedPlaces)
                )
            }
            .background(AppColor.surfacePrimary.ignoresSafeArea())
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Place", systemImage: "plus") {
                        showingAddPlaceSheet = true
                    }
                    .tint(BrandColor.sand)
                }
            }
            .sheet(isPresented: $showingAddPlaceSheet) {
                AddPlaceSheet(
                    viewModel: vm,
                    locationService: locationService,
                    isPresented: $showingAddPlaceSheet
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct SavedPlacesList: View {
    @Bindable var viewModel: SavedPlacesViewModel
    let sections: [GroupedSection]

    var body: some View {
        List {
            if sections.isEmpty {
                emptyState
            } else {
                ForEach(sections) { section in
                    Section {
                        placeRows(in: section)
                    } header: {
                        sectionHeader(for: section)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(AppColor.surfacePrimary)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always)
        )
    }

    @ViewBuilder private var emptyState: some View {
        if viewModel.searchText.isEmpty {
            ContentUnavailableView(
                "No Saved Places",
                systemImage: "bookmark",
                description: Text("Tap + to save your first place.")
            )
            .listRowBackground(Color.clear)
        } else {
            ContentUnavailableView.search(text: viewModel.searchText)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func placeRows(in section: GroupedSection) -> some View {
        ForEach(section.items) { place in
            SavedPlaceRowView(place: place)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.delete(place)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    ForEach(SavedPlaceStatus.allCases) { status in
                        Button {
                            viewModel.updateStatus(of: place, to: status)
                        } label: {
                            Label(
                                status.rawValue,
                                systemImage: place.status == status
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                        }
                    }
                }
        }
    }

    private func sectionHeader(for section: GroupedSection) -> some View {
        HStack(spacing: 4) {
            if viewModel.selectedGroupingCriterion == .country,
               let code = section.items.first?.countryCode {
                Text(code.flagEmoji())
            }
            Text(section.header)
        }
        .font(.footnote13.weight(.semibold))
        .foregroundStyle(AppColor.textSecondary)
        .textCase(nil)
    }
}

struct AddPlaceSheet: View {
    @Bindable var viewModel: SavedPlacesViewModel
    let locationService: LocationService
    @Binding var isPresented: Bool

    @State private var placeName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var selectedPlaceType: PlaceType = .other
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Place Name", text: $placeName)
                TextField("Latitude", text: $latitude)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $longitude)
                    .keyboardType(.decimalPad)
                Picker("Place Type", selection: $selectedPlaceType) {
                    ForEach(PlaceType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            .navigationTitle("New Saved Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .tint(BrandColor.sand)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let lat = Double(latitude), let lon = Double(longitude) else { return }
                        isSaving = true
                        Task {
                            await viewModel.savePlace(
                                name: placeName,
                                latitude: lat,
                                longitude: lon,
                                placeType: selectedPlaceType,
                                locationService: locationService
                            )
                            isPresented = false
                        }
                    }
                    .disabled(placeName.isEmpty || latitude.isEmpty || longitude.isEmpty || isSaving)
                    .tint(BrandColor.sand)
                }
            }
        }
    }
}
