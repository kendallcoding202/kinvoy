import SwiftUI

@main
struct GetawayApp: App {
    @StateObject private var store = TripStore()
    @StateObject private var familyStore = FamilyStore()
    @StateObject private var locationService = LocationService()
    @StateObject private var moderation = ModerationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(familyStore)
                .environmentObject(locationService)
                .environmentObject(moderation)
                .tint(Color(red: 0.98, green: 0.45, blue: 0.25))
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var familyStore: FamilyStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var moderation: ModerationService

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading…")
            } else if familyStore.family != nil || (store.trip != nil && store.currentMember != nil) {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .task {
            await store.bootstrap()
            await familyStore.bootstrap()
            await moderation.refreshBlocks()
            if store.isDemo { familyStore.enterDemo() }
            if let family = familyStore.family, let member = familyStore.currentMember, !familyStore.isDemo {
                locationService.configureFamily(familyId: family.id, familyMemberId: member.id)
            }
        }
        .onChange(of: store.isDemo) {
            if store.isDemo { familyStore.enterDemo() }
        }
        .onChange(of: store.currentMember?.id, initial: true) {
            // currentMember is the last thing set when a trip loads or changes,
            // so this fires once trip + member are both known. Stops sharing
            // first so a trip switch never leaks the old trip's pin.
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
