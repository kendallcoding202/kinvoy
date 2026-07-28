import Supabase
import SwiftUI

@MainActor
final class ChecklistsViewModel: ObservableObject {
    @Published var lists: [Checklist] = []
    @Published var items: [ChecklistItem] = []

    private var client: SupabaseClient { SupabaseService.shared.client }

    func load(tripId: UUID, isDemo: Bool) async {
        if isDemo {
            if lists.isEmpty {
                lists = DemoData.checklists
                items = DemoData.checklistItems
            }
            return
        }
        do {
            lists = try await client
                .from("checklists").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at")
                .execute().value
            items = try await client
                .from("checklist_items").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at")
                .execute().value
        } catch {
            print("Checklists load failed: \(error)")
        }
    }

    func items(in list: Checklist) -> [ChecklistItem] {
        items.filter { $0.checklistId == list.id }
    }

    func progress(of list: Checklist) -> (done: Int, total: Int) {
        let listItems = items(in: list)
        return (listItems.filter(\.isDone).count, listItems.count)
    }

    func createList(title: String, tripId: UUID, memberId: UUID, isDemo: Bool) async throws {
        if isDemo {
            lists.append(Checklist(id: UUID(), tripId: tripId, memberId: memberId, title: title))
            return
        }
        struct ListInsert: Encodable {
            let trip_id: String
            let member_id: String
            let title: String
        }
        _ = try await client.from("checklists")
            .insert(ListInsert(trip_id: tripId.uuidString, member_id: memberId.uuidString, title: title))
            .execute()
        await load(tripId: tripId, isDemo: false)
    }

    func deleteList(_ list: Checklist, isDemo: Bool) async {
        if isDemo {
            lists.removeAll { $0.id == list.id }
            items.removeAll { $0.checklistId == list.id }
            return
        }
        _ = try? await client.from("checklists").delete()
            .eq("id", value: list.id.uuidString)
            .execute()
        await load(tripId: list.tripId, isDemo: false)
    }

    func addItem(title: String, to list: Checklist, isDemo: Bool) async throws {
        if isDemo {
            items.append(ChecklistItem(id: UUID(), checklistId: list.id, tripId: list.tripId, title: title, assignedMemberId: nil, isDone: false))
            return
        }
        struct ItemInsert: Encodable {
            let checklist_id: String
            let trip_id: String
            let title: String
        }
        _ = try await client.from("checklist_items")
            .insert(ItemInsert(checklist_id: list.id.uuidString, trip_id: list.tripId.uuidString, title: title))
            .execute()
        await load(tripId: list.tripId, isDemo: false)
    }

    func toggle(_ item: ChecklistItem, isDemo: Bool) async {
        // Optimistic flip; server sync follows.
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isDone.toggle()
        }
        guard !isDemo else { return }
        _ = try? await client.from("checklist_items")
            .update(["is_done": !item.isDone])
            .eq("id", value: item.id.uuidString)
            .execute()
    }

    func assign(_ item: ChecklistItem, to memberId: UUID?, isDemo: Bool) async {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].assignedMemberId = memberId
        }
        guard !isDemo else { return }
        _ = try? await client.from("checklist_items")
            .update(["assigned_member_id": memberId?.uuidString])
            .eq("id", value: item.id.uuidString)
            .execute()
    }

    func deleteItem(_ item: ChecklistItem, isDemo: Bool) async {
        items.removeAll { $0.id == item.id }
        guard !isDemo else { return }
        _ = try? await client.from("checklist_items").delete()
            .eq("id", value: item.id.uuidString)
            .execute()
    }
}

struct ChecklistsView: View {
    @EnvironmentObject private var store: TripStore
    @StateObject private var viewModel = ChecklistsViewModel()
    @State private var showNewList = false
    @State private var newListTitle = ""

    var body: some View {
        Group {
            if viewModel.lists.isEmpty {
                ContentUnavailableView(
                    "No lists yet",
                    systemImage: "checklist",
                    description: Text("Packing lists, grocery runs, to-dos — everyone sees and checks off together.")
                )
            } else {
                List {
                    ForEach(viewModel.lists) { list in
                        NavigationLink {
                            ChecklistDetailView(list: list, viewModel: viewModel)
                        } label: {
                            listRow(list)
                        }
                        .swipeActions {
                            if list.memberId == store.currentMember?.id {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteList(list, isDemo: store.isDemo) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewList = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New list", isPresented: $showNewList) {
            TextField("Name (e.g. Packing — kids)", text: $newListTitle)
            Button("Create") {
                let title = newListTitle.trimmingCharacters(in: .whitespaces)
                newListTitle = ""
                guard !title.isEmpty, let trip = store.trip, let member = store.currentMember else { return }
                Task { try? await viewModel.createList(title: title, tripId: trip.id, memberId: member.id, isDemo: store.isDemo) }
            }
            Button("Cancel", role: .cancel) { newListTitle = "" }
        }
        .task {
            if let trip = store.trip {
                await viewModel.load(tripId: trip.id, isDemo: store.isDemo)
            }
        }
    }

    private func listRow(_ list: Checklist) -> some View {
        let progress = viewModel.progress(of: list)
        return HStack {
            Image(systemName: "checklist")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.title).font(.body.weight(.medium))
                Text(progress.total == 0 ? "Empty" : "\(progress.done) of \(progress.total) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if progress.total > 0 && progress.done == progress.total {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

struct ChecklistDetailView: View {
    let list: Checklist
    @ObservedObject var viewModel: ChecklistsViewModel
    @EnvironmentObject private var store: TripStore
    @State private var newItemTitle = ""
    @FocusState private var addFocused: Bool

    var body: some View {
        List {
            ForEach(viewModel.items(in: list)) { item in
                itemRow(item)
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteItem(item, isDemo: store.isDemo) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            Section {
                HStack {
                    TextField("Add an item…", text: $newItemTitle)
                        .focused($addFocused)
                        .onSubmit(addItem)
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func itemRow(_ item: ChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggle(item, isDemo: store.isDemo) }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                if let assignedId = item.assignedMemberId,
                   let member = store.member(for: assignedId) {
                    Text(member.displayName)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }
            }
            Spacer()
            Menu {
                Button("Unassigned") {
                    Task { await viewModel.assign(item, to: nil, isDemo: store.isDemo) }
                }
                ForEach(store.members) { member in
                    Button(member.displayName) {
                        Task { await viewModel.assign(item, to: member.id, isDemo: store.isDemo) }
                    }
                }
            } label: {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newItemTitle = ""
        addFocused = true
        Task { try? await viewModel.addItem(title: title, to: list, isDemo: store.isDemo) }
    }
}
