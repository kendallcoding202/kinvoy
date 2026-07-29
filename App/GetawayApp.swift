import SwiftUI

@main
struct GetawayApp: App {
    @StateObject private var store = TripStore()
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(locationService)
                .tint(Color(red: 0.98, green: 0.45, blue: 0.25))
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading your trip…")
            } else if store.trip != nil, store.currentMember != nil {
                TripTabView()
            } else {
                WelcomeView()
            }
        }
        .task {
            await store.bootstrap()
        }
        .onChange(of: store.trip?.id) {
            // Reconfigure (and stop) location sharing whenever the active trip changes.
            locationService.setSharing(false)
            if let trip = store.trip, let member = store.currentMember {
                locationService.configure(trip: trip, memberId: member.id, isDemo: store.isDemo)
            }
        }
        .onOpenURL { url in
            store.handleDeepLink(url)
        }
        .sheet(item: $store.pendingJoinCode) { pending in
            JoinTripView(initialCode: pending.code)
        }
    }
}
