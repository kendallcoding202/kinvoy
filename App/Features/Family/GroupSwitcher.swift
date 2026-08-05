import SwiftUI

/// The persistent "which group am I in?" control. Sits in the nav bar of
/// every family screen so the answer is always on screen — and lets people
/// with more than one group (in-laws, a friend group) switch in one tap.
struct GroupSwitcher: View {
    @EnvironmentObject private var familyStore: FamilyStore
    @Binding var showCreate: Bool
    @Binding var showJoin: Bool

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
                    showCreate = true
                } label: {
                    Label("Create a group", systemImage: "plus")
                }
                Button {
                    showJoin = true
                } label: {
                    Label("Join with a code", systemImage: "person.badge.key")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "house.fill")
                    .font(.caption)
                Text(familyStore.family?.name ?? "Group")
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

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    GroupSwitcher(showCreate: $showCreate, showJoin: $showJoin)
                }
            }
            .sheet(isPresented: $showCreate) { FamilySetupView(mode: .create) }
            .sheet(isPresented: $showJoin) { FamilySetupView(mode: .join) }
    }
}

extension View {
    func groupSwitcherToolbar() -> some View {
        modifier(GroupSwitcherToolbar())
    }
}
