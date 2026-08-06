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
    @EnvironmentObject private var familyStore: FamilyStore
    @State private var showCreate = false
    @State private var showJoin = false
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showPaywall = false

    private var isWide: Bool { sizeClass == .regular }

    /// Free tier: one trip that hasn't ended yet. Joining a trip someone else
    /// created is always free — only creating more is Premium.
    private var canStartAnotherTrip: Bool {
        if subscriptions.hasPremium(familyId: familyStore.family?.id) { return true }
        let live = store.myTrips.filter { $0.endDate >= Calendar.current.startOfDay(for: .now) }
        return live.count < 1
    }

    /// Names the group a shared trip belongs to, so someone in several
    /// groups can tell "the Sorensons" from "Disneyland Crew" at a glance.
    private func groupName(for trip: Trip) -> String {
        guard let id = trip.familyId,
              let group = familyStore.myFamilies.first(where: { $0.id == id })
        else { return "Shared with group" }
        return "Everyone in \(group.name)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.myTrips.isEmpty {
                        Text("No trips yet — start one and share the invite code with everyone coming.")
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
                        Text("Tap a trip to step into its workspace — plans, chat, map, photos, and expenses all live inside. Trips shared with a group include everyone in it automatically.")
                    }
                }
                Section {
                    Button {
                        // Free covers one active trip; more needs Premium.
                        if canStartAnotherTrip {
                            showCreate = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Start a trip", systemImage: "plus")
                            if !canStartAnotherTrip {
                                Spacer()
                                Label("Premium", systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button {
                        showJoin = true
                    } label: {
                        Label("Join with invite code", systemImage: "person.badge.key")
                    }
                }
            }
            .readableColumn(maxWidth: 820)
            .navigationTitle("Trips")
            // Inline keeps the title centered over the readable column
            // instead of stranding it at the far edge on iPad.
            .navigationBarTitleDisplayMode(isWide ? .inline : .large)
            .sheet(isPresented: $showCreate) { CreateTripView() }
            .sheet(isPresented: $showJoin) { JoinTripView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
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
                    Label(groupName(for: trip), systemImage: "house.fill")
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
            .navigationBarTitleDisplayMode(.inline)
            .groupSwitcherToolbar()
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
            .navigationBarTitleDisplayMode(.inline)
            .groupSwitcherToolbar()
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
                        VStack(spacing: 10) {
                            if viewModel.locations.isEmpty {
                                emptyHint
                            }
                            sharePanel
                        }
                        .padding()
                    }
                } else {
                    FamilySetupPrompt(feature: "map")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .groupSwitcherToolbar()
            .onAppear {
                if let family = familyStore.family {
                    viewModel.start(family: family, isDemo: familyStore.isDemo)
                }
            }
            .onChange(of: familyStore.family?.id) {
                viewModel.stop()
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

    private var emptyHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .foregroundStyle(.secondary)
            Text(locationService.isFamilySharing
                ? "You're sharing. Pins appear as others turn sharing on."
                : "Nobody's sharing yet — flip the switch below to start.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var sharePanel: some View {
        VStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { locationService.isFamilySharing },
                set: { locationService.setFamilySharing($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(familyStore.family.map { "Always share with \($0.name)" } ?? "Always share my location")
                        .font(.subheadline.weight(.semibold))
                    Text("Stays on until you turn it off. Only this group can see you.")
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
    @EnvironmentObject private var store: TripStore
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        VStack(spacing: 16) {
            // Someone who joined a trip already has a chat, map, and plans —
            // they live inside the trip. Point there before selling them a
            // family group, or the app reads as mostly locked.
            if let trip = store.myTrips.first {
                ContentUnavailableView(
                    "Your trip has its own \(feature)",
                    systemImage: "suitcase.fill",
                    description: Text("\(trip.name) has its own plans, chat, map, and ideas inside it. This tab is the everyday \(feature) for a group — separate from any one trip.")
                )
                Button("Open \(trip.name)") {
                    Task {
                        await store.switchTrip(to: trip)
                        store.showTripWorkspace = true
                    }
                }
                .buttonStyle(.borderedProminent)
                HStack {
                    Button("Create a group") { showCreate = true }
                    Button("Join with code") { showJoin = true }
                }
                .font(.subheadline)
                .padding(.bottom, 40)
            } else {
                ContentUnavailableView(
                    "Set up your group first",
                    systemImage: "house.badge.plus",
                    description: Text("The everyday \(feature) unlocks once your group exists — takes about ten seconds.")
                )
                HStack {
                    Button("Create a group") { showCreate = true }
                        .buttonStyle(.borderedProminent)
                    Button("Join with code") { showJoin = true }
                        .buttonStyle(.bordered)
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showCreate) { FamilySetupView(mode: .create) }
        .sheet(isPresented: $showJoin) { FamilySetupView(mode: .join) }
    }
}
