import SwiftUI

@main
struct GetawayApp: App {
    @StateObject private var store = TripStore()
    @StateObject private var familyStore = FamilyStore()
    @StateObject private var locationService = LocationService()
    @StateObject private var moderation = ModerationService()
    @StateObject private var subscriptions = SubscriptionService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(familyStore)
                .environmentObject(locationService)
                .environmentObject(moderation)
                .environmentObject(subscriptions)
                .tint(Color(red: 0.98, green: 0.45, blue: 0.25))
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var familyStore: FamilyStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var splashFinished = false
    @AppStorage("acceptedTermsVersion") private var acceptedTermsVersion = 0

    var body: some View {
        Group {
            if store.isLoading || !splashFinished {
                LaunchView()
                    .transition(.opacity)
            } else if acceptedTermsVersion < TermsGate.currentVersion {
                TermsGate()
            } else if familyStore.family != nil || (store.trip != nil && store.currentMember != nil) {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: splashFinished)
        .task {
            // App Store screenshots run on demo data so marketing shots never
            // depend on (or pollute) real accounts: launch with -screenshotMode.
            if ProcessInfo.processInfo.arguments.contains("-screenshotMode") {
                acceptedTermsVersion = TermsGate.currentVersion
                store.enterDemo()
                familyStore.enterDemo()
                splashFinished = true
                return
            }
            // Hold the splash briefly so a fast launch reads as intentional
            // rather than a flash of orange.
            async let minimumSplash: Void? = try? await Task.sleep(for: .milliseconds(1300))
            await store.bootstrap()
            await familyStore.bootstrap()
            await moderation.refreshBlocks()
            await subscriptions.refreshEntitlements()
            _ = await minimumSplash
            splashFinished = true
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
