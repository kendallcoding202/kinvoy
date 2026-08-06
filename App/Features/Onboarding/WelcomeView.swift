import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: TripStore
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showCreateFamily = false
    @State private var showJoinFamily = false

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
                    Text("Your family, every day — chat, calendar, and map.\nPlus a workspace for every trip you take.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showCreateFamily = true
                    } label: {
                        Label("Set up your family", systemImage: "house.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showJoinFamily = true
                    } label: {
                        Label("Join a family with a code", systemImage: "person.badge.key.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)

                    // Most people arriving here were handed a trip code by a
                    // friend, not a family code. Buried as small text, they
                    // read the whole app as a family product they can't use.
                    Button {
                        showJoin = true
                    } label: {
                        Label("Join a trip with a code", systemImage: "suitcase.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)

                    Button("Start a trip instead") { showCreate = true }
                        .font(.subheadline)
                        .padding(.top, 4)

                    if !AppConfig.isConfigured {
                        Button("Explore a demo") {
                            store.enterDemo()
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 480)

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
            .sheet(isPresented: $showCreateFamily) { FamilySetupView(mode: .create) }
            .sheet(isPresented: $showJoinFamily) { FamilySetupView(mode: .join) }
        }
    }
}
