import MapKit
import SwiftUI

/// The main app: family-first. Trips are workspaces you enter from the
/// Trips tab (or Home) and leave with Done — no mode toggles anywhere.
struct MainTabView: View {
    @EnvironmentObject private var store: TripStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            FamilyChatTab()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            FamilyCalendarTab()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            FamilyMapTab()
                .tabItem { Label("Map", systemImage: "map.fill") }
            TripsListView()
                .tabItem { Label("Trips", systemImage: "suitcase.fill") }
        }
        .fullScreenCover(isPresented: $store.showTripWorkspace) {
            TripWorkspaceView()
        }
    }
}

/// A trip's own world: full-screen workspace with its own tabs.
struct TripWorkspaceView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(store.trip?.kindOrDefault.emoji ?? "🧳") \(store.trip?.name ?? "Trip")")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)

            TabView {
                CalendarView()
                    .tabItem { Label("Plans", systemImage: "calendar") }
                ChatView()
                    .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                TripMapView()
                    .tabItem { Label("Map", systemImage: "map.fill") }
                IdeasView()
                    .tabItem { Label("Ideas", systemImage: "sparkles") }
                TripDetailView()
                    .tabItem { Label("Info", systemImage: "info.circle.fill") }
            }
        }
    }
}

/// The Trips tab: all your trips, enter one, start or join another.
struct TripsListView: View {
    @EnvironmentObject private var store: TripStore
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.myTrips.isEmpty {
                        Text("No trips yet — start one and share the invite code with your family.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.myTrips) { trip in
                        Button {
                            Task {
                                await store.switchTrip(to: trip)
                                store.showTripWorkspace = true
                            }
                        } label: {
                            tripRow(trip)
                        }
                    }
                } footer: {
                    if !store.myTrips.isEmpty {
                        Text("Tap a trip to step into its workspace — plans, chat, map, photos, and expenses all live inside. Trips you share with the family include everyone automatically.")
                    }
                }
                Section {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Start a trip", systemImage: "plus")
                    }
                    Button {
                        showJoin = true
                    } label: {
                        Label("Join with invite code", systemImage: "person.badge.key")
                    }
                }
            }
            .navigationTitle("Trips")
            .sheet(isPresented: $showCreate) { CreateTripView() }
            .sheet(isPresented: $showJoin) { JoinTripView() }
            .task {
                await store.refreshMyTrips()
            }
        }
    }

    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            Text(trip.kindOrDefault.emoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text("\(trip.startDate.formatted(.dateTime.month().day())) – \(trip.endDate.formatted(.dateTime.month().day())) · \(trip.destination)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if trip.isFamilyTrip {
                    Label("Whole family", systemImage: "house.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                } else if trip.isPrivate == true {
                    Label("Private — invite by code", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if trip.isActiveToday {
                Text("Now")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Family-first tab wrappers

struct FamilyChatTab: View {
    @EnvironmentObject private var familyStore: FamilyStore

    var body: some View {
        NavigationStack {
            Group {
                if familyStore.family != nil {
                    FamilyChatView()
                } else {
                    FamilySetupPrompt(feature: "chat")
                }
            }
            .navigationTitle(familyStore.family?.name ?? "Family chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FamilyCalendarTab: View {
    @EnvironmentObject private var familyStore: FamilyStore

    var body: some View {
        NavigationStack {
            Group {
                if familyStore.family != nil {
                    FamilyCalendarView()
                } else {
                    FamilySetupPrompt(feature: "calendar")
                }
            }
            .navigationTitle("Calendar")
        }
    }
}

struct FamilyMapTab: View {
    @EnvironmentObject private var familyStore: FamilyStore
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var viewModel = FamilyLocationsViewModel()
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Group {
                if familyStore.family != nil {
                    ZStack(alignment: .bottom) {
                        map
                        sharePanel
                            .padding()
                    }
                } else {
                    FamilySetupPrompt(feature: "map")
                }
            }
            .navigationTitle("Family Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let family = familyStore.family {
                    viewModel.start(family: family, isDemo: familyStore.isDemo)
                }
            }
            .onDisappear { viewModel.stop() }
        }
    }

    private var map: some View {
        Map(position: $cameraPosition) {
            ForEach(viewModel.locations) { location in
                Annotation(
                    familyStore.member(for: location.memberId)?.displayName ?? "Family",
                    coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                ) {
                    MemberPin(
                        name: familyStore.member(for: location.memberId)?.displayName ?? "?",
                        isStale: Date.now.timeIntervalSince(location.updatedAt) > 900
                    )
                }
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var sharePanel: some View {
        VStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { locationService.isFamilySharing },
                set: { locationService.setFamilySharing($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Always share with my family")
                        .font(.subheadline.weight(.semibold))
                    Text("Stays on until you turn it off. Only your family can see you.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = locationService.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Shown in family tabs before a family group exists.
struct FamilySetupPrompt: View {
    let feature: String
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Set up your family first",
                systemImage: "house.badge.plus",
                description: Text("The family \(feature) unlocks once your family group exists — takes about ten seconds.")
            )
            HStack {
                Button("Create family") { showCreate = true }
                    .buttonStyle(.borderedProminent)
                Button("Join with code") { showJoin = true }
                    .buttonStyle(.bordered)
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showCreate) { FamilySetupView(mode: .create) }
        .sheet(isPresented: $showJoin) { FamilySetupView(mode: .join) }
    }
}
