import SwiftUI

/// The persistent "which group am I in?" control. Sits in the nav bar of
/// every family screen so the answer is always on screen — and lets people
/// with more than one group (in-laws, a friend group) switch in one tap.
struct GroupSwitcher: View {
    @EnvironmentObject private var familyStore: FamilyStore
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Binding var showCreate: Bool
    @Binding var showJoin: Bool
    @Binding var showPaywall: Bool

    /// Free covers one group; more is Premium. Premium held by ANY of your
    /// groups unlocks it, so a paying family can add the in-laws.
    private var canAddGroup: Bool {
        if familyStore.myFamilies.count < 1 { return true }
        return familyStore.myFamilies.contains { subscriptions.hasPremium(familyId: $0.id) }
    }

    var body: some View {
        Menu {
            if familyStore.myFamilies.count > 1 {
                Section("Your groups") {
                    ForEach(familyStore.myFamilies) { group in
                        Button {
                            Task { await familyStore.switchFamily(to: group) }
                        } label: {
                            if group.id == familyStore.family?.id {
                                Label(group.name, systemImage: "checkmark")
                            } else {
                                Text(group.name)
                            }
                        }
                    }
                }
            }
            Section {
                Button {
                    if canAddGroup { showCreate = true } else { showPaywall = true }
                } label: {
                    Label(canAddGroup ? "Create a group" : "Create a group (Premium)",
                          systemImage: canAddGroup ? "plus" : "sparkles")
                }
                Button {
                    if canAddGroup { showJoin = true } else { showPaywall = true }
                } label: {
                    Label(canAddGroup ? "Join with a code" : "Join a group (Premium)",
                          systemImage: canAddGroup ? "person.badge.key" : "sparkles")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "house.fill")
                    .font(.caption)
                Text(familyStore.family?.name ?? "Set up a group")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
    }
}

/// Attaches the group switcher as a principal nav-bar item plus the two
/// setup sheets it can open.
struct GroupSwitcherToolbar: ViewModifier {
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    GroupSwitcher(showCreate: $showCreate, showJoin: $showJoin, showPaywall: $showPaywall)
                }
            }
            .sheet(isPresented: $showCreate) { FamilySetupView(mode: .create) }
            .sheet(isPresented: $showJoin) { FamilySetupView(mode: .join) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

extension View {
    func groupSwitcherToolbar() -> some View {
        modifier(GroupSwitcherToolbar())
    }
}
