import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: TripStore
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "sun.horizon.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.orange)
                    Text("Kinvoy")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("Your family's trips, all in one place.\nPlans, chat, locations, photos, and ideas.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Start a trip", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showJoin = true
                    } label: {
                        Label("Join with invite code", systemImage: "person.badge.key.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)

                    if !AppConfig.isConfigured {
                        Button("Explore a demo trip") {
                            store.enterDemo()
                        }
                        .font(.subheadline)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                if !AppConfig.isConfigured {
                    Text("Backend not configured yet — see SETUP.md.\nCreate/join will work once Supabase keys are added.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 20)
            }
            .sheet(isPresented: $showCreate) { CreateTripView() }
            .sheet(isPresented: $showJoin) { JoinTripView() }
        }
    }
}
