import Supabase
import SwiftUI

@MainActor
final class ExpensesViewModel: ObservableObject {
    @Published var expenses: [Expense] = []

    private var client: SupabaseClient { SupabaseService.shared.client }

    func load(tripId: UUID, isDemo: Bool) async {
        if isDemo {
            if expenses.isEmpty { expenses = DemoData.expenses }
            return
        }
        do {
            expenses = try await client
                .from("expenses").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at", ascending: false)
                .execute().value
        } catch {
            print("Expenses load failed: \(error)")
        }
    }

    func add(title: String, amountCents: Int, tripId: UUID, memberId: UUID, isDemo: Bool) async throws {
        if isDemo {
            expenses.insert(Expense(id: UUID(), tripId: tripId, memberId: memberId, title: title, amountCents: amountCents, createdAt: .now), at: 0)
            return
        }
        struct ExpenseInsert: Encodable {
            let trip_id: String
            let member_id: String
            let title: String
            let amount_cents: Int
        }
        _ = try await client.from("expenses")
            .insert(ExpenseInsert(trip_id: tripId.uuidString, member_id: memberId.uuidString, title: title, amount_cents: amountCents))
            .execute()
        await load(tripId: tripId, isDemo: false)
    }

    func delete(_ expense: Expense, isDemo: Bool) async {
        expenses.removeAll { $0.id == expense.id }
        guard !isDemo else { return }
        _ = try? await client.from("expenses").delete()
            .eq("id", value: expense.id.uuidString)
            .execute()
    }

    var totalCents: Int { expenses.reduce(0) { $0 + $1.amountCents } }

    /// Even split across all members: positive = is owed money, negative = owes.
    func netCents(for memberId: UUID, memberCount: Int) -> Int {
        guard memberCount > 0 else { return 0 }
        let paid = expenses.filter { $0.memberId == memberId }.reduce(0) { $0 + $1.amountCents }
        let share = totalCents / memberCount
        return paid - share
    }
}

struct ExpensesView: View {
    @EnvironmentObject private var store: TripStore
    @StateObject private var viewModel = ExpensesViewModel()
    @State private var showAdd = false

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    private func dollars(_ cents: Int) -> String {
        Self.currency.string(from: NSNumber(value: Double(cents) / 100)) ?? "$0.00"
    }

    var body: some View {
        List {
            if !viewModel.expenses.isEmpty {
                summarySection
            }
            expensesSection
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddExpenseView { title, cents in
                guard let trip = store.trip, let member = store.currentMember else { return }
                try await viewModel.add(title: title, amountCents: cents, tripId: trip.id, memberId: member.id, isDemo: store.isDemo)
            }
        }
        .task {
            if let trip = store.trip {
                await viewModel.load(tripId: trip.id, isDemo: store.isDemo)
                await store.refreshMembers()
            }
        }
    }

    private var summarySection: some View {
        Section {
            LabeledContent("Trip total") {
                Text(dollars(viewModel.totalCents)).font(.headline)
            }
            ForEach(store.members) { member in
                let net = viewModel.netCents(for: member.id, memberCount: store.members.count)
                LabeledContent(member.displayName) {
                    if net > 0 {
                        Text("is owed \(dollars(net))").foregroundStyle(.green)
                    } else if net < 0 {
                        Text("owes \(dollars(-net))").foregroundStyle(.orange)
                    } else {
                        Text("settled").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
        } header: {
            Text(store.members.count <= 1
                ? "Just you so far — invite others to split costs"
                : "Split evenly \(store.members.count) ways")
        }
    }

    private var expensesSection: some View {
        Section("Purchases") {
            if viewModel.expenses.isEmpty {
                Text("Track shared costs — condo, groceries, dinners out — and see who owes who at the end.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.expenses) { expense in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.title)
                        Text("Paid by \(store.member(for: expense.memberId)?.displayName ?? "someone") · \(expense.createdAt.formatted(.dateTime.month().day()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(dollars(expense.amountCents))
                        .font(.body.weight(.semibold))
                }
                .swipeActions {
                    if expense.memberId == store.currentMember?.id {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(expense, isDemo: store.isDemo) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

struct AddExpenseView: View {
    let onSave: (String, Int) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amountText = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var amountCents: Int? {
        let cleaned = amountText.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value > 0, value < 1_000_000 else { return nil }
        return Int((value * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("What was it? (e.g. Groceries)", text: $title)
                TextField("Amount (e.g. 84.50)", text: $amountText)
                    .keyboardType(.decimalPad)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.callout)
                }
            }
            .navigationTitle("Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Add") { submit() }
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amountCents == nil)
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    private func submit() {
        guard let cents = amountCents else { return }
        isWorking = true
        Task {
            do {
                try await onSave(title.trimmingCharacters(in: .whitespaces), cents)
                dismiss()
            } catch {
                errorMessage = "Couldn't save. Try again."
                isWorking = false
            }
        }
    }
}
