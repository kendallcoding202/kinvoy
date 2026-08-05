import MapKit
import Supabase
import SwiftUI

// MARK: - Family chat

@MainActor
final class FamilyChatViewModel: ObservableObject {
    @Published var messages: [FamilyMessage] = []
    @Published var draft = ""

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var pollTask: Task<Void, Never>?

    private var activeFamilyId: UUID?

    func start(family: Family, isDemo: Bool) {
        if activeFamilyId != family.id {
            stop()
            messages = []
        }
        activeFamilyId = family.id
        guard pollTask == nil else { return }
        if isDemo {
            messages = DemoData.familyMessages
            return
        }
        pollTask = Task {
            while !Task.isCancelled {
                await refresh(familyId: family.id)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(familyId: UUID) async {
        do {
            messages = try await client
                .from("family_messages").select()
                .eq("family_id", value: familyId.uuidString)
                .order("created_at")
                .limit(500)
                .execute().value
        } catch {
            print("Family chat refresh failed: \(error)")
        }
    }

    func send(familyId: UUID, memberId: UUID, isDemo: Bool) async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        draft = ""
        if isDemo {
            messages.append(FamilyMessage(id: UUID(), familyId: familyId, memberId: memberId, content: content, createdAt: .now))
            return
        }
        struct MessageInsert: Encodable {
            let family_id: String
            let member_id: String
            let content: String
        }
        do {
            _ = try await client.from("family_messages")
                .insert(MessageInsert(family_id: familyId.uuidString, member_id: memberId.uuidString, content: content))
                .execute()
            await refresh(familyId: familyId)
        } catch {
            draft = content
        }
    }
}

struct FamilyChatView: View {
    @EnvironmentObject private var familyStore: FamilyStore
    @EnvironmentObject private var moderation: ModerationService
    @StateObject private var viewModel = FamilyChatViewModel()
    @FocusState private var inputFocused: Bool
    @State private var reportTarget: ReportTarget?

    private var visibleMessages: [FamilyMessage] {
        viewModel.messages.filter {
            !moderation.isBlocked(userId: familyStore.member(for: $0.memberId)?.userId)
        }
    }

    /// The group's own name, so friend groups don't get called "the family".
    private var groupName: String {
        familyStore.family?.name ?? "your group"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if viewModel.messages.isEmpty {
                            ContentUnavailableView(
                                familyStore.family.map { "\($0.name) chat" } ?? "Group chat",
                                systemImage: "bubble.left.and.bubble.right",
                                description: Text("One standing thread for everyone in \(groupName) — always here, trip or no trip.")
                            )
                            .padding(.top, 60)
                        }
                        ForEach(visibleMessages) { message in
                            MessageBubble(
                                message: Message(id: message.id, tripId: message.familyId, memberId: message.memberId, content: message.content, createdAt: message.createdAt),
                                senderName: familyStore.member(for: message.memberId)?.displayName ?? "Someone",
                                isMine: message.memberId == familyStore.currentMember?.id
                            )
                            .id(message.id)
                            .contextMenu {
                                if message.memberId != familyStore.currentMember?.id {
                                    Button(role: .destructive) {
                                        reportTarget = ReportTarget(kind: .familyMessage, contentId: message.id, authorMemberId: message.memberId)
                                    } label: {
                                        Label("Report or block", systemImage: "exclamationmark.bubble")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onTapGesture { inputFocused = false }
            }

            HStack(spacing: 10) {
                TextField("Message \(groupName)…", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                    .focused($inputFocused)
                Button {
                    if let family = familyStore.family, let member = familyStore.currentMember {
                        Task { await viewModel.send(familyId: family.id, memberId: member.id, isDemo: familyStore.isDemo) }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(kind: target.kind, contentId: target.contentId, authorMemberId: target.authorMemberId, scope: .family)
        }
        .onAppear {
            if let family = familyStore.family {
                viewModel.start(family: family, isDemo: familyStore.isDemo)
            }
        }
        .onChange(of: familyStore.family?.id) {
            if let family = familyStore.family {
                viewModel.start(family: family, isDemo: familyStore.isDemo)
            }
        }
        .onDisappear { viewModel.stop() }
    }
}

// MARK: - Family map scope

@MainActor
final class FamilyLocationsViewModel: ObservableObject {
    @Published var locations: [FamilyLocation] = []

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var pollTask: Task<Void, Never>?

    func start(family: Family, isDemo: Bool) {
        guard pollTask == nil else { return }
        if isDemo {
            locations = DemoData.familyLocations
            return
        }
        pollTask = Task {
            while !Task.isCancelled {
                do {
                    locations = try await client
                        .from("family_locations").select()
                        .eq("family_id", value: family.id.uuidString)
                        .execute().value
                } catch {
                    print("Family locations refresh failed: \(error)")
                }
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }
}

// MARK: - Family calendar

@MainActor
final class FamilyEventsViewModel: ObservableObject {
    @Published var events: [FamilyEvent] = []

    private var client: SupabaseClient { SupabaseService.shared.client }

    func load(familyId: UUID, isDemo: Bool) async {
        if isDemo {
            if events.isEmpty { events = DemoData.familyEvents }
            return
        }
        do {
            events = try await client
                .from("family_events").select()
                .eq("family_id", value: familyId.uuidString)
                .gte("starts_at", value: ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: .now)))
                .order("starts_at")
                .execute().value
        } catch {
            print("Family events load failed: \(error)")
        }
    }

    func add(_ event: FamilyEvent, isDemo: Bool) async throws {
        if isDemo {
            events.append(event)
            events.sort { $0.startsAt < $1.startsAt }
            return
        }
        struct EventInsert: Encodable {
            let family_id: String
            let member_id: String
            let title: String
            let notes: String?
            let location_name: String?
            let starts_at: Date
            let ends_at: Date?
        }
        _ = try await client.from("family_events").insert(EventInsert(
            family_id: event.familyId.uuidString,
            member_id: event.memberId.uuidString,
            title: event.title,
            notes: event.notes,
            location_name: event.locationName,
            starts_at: event.startsAt,
            ends_at: event.endsAt
        )).execute()
        await load(familyId: event.familyId, isDemo: false)
    }

    func delete(_ event: FamilyEvent, isDemo: Bool) async {
        events.removeAll { $0.id == event.id }
        guard !isDemo else { return }
        _ = try? await client.from("family_events").delete()
            .eq("id", value: event.id.uuidString)
            .execute()
    }
}

struct FamilyCalendarView: View {
    @EnvironmentObject private var familyStore: FamilyStore
    @StateObject private var viewModel = FamilyEventsViewModel()
    @State private var showAdd = false

    var body: some View {
        Group {
            if viewModel.events.isEmpty {
                ContentUnavailableView {
                    Label("Nothing scheduled yet", systemImage: "calendar.badge.clock")
                } description: {
                    Text("Soccer games, birthdays, dinners out — anything the group should know about. Always on, trip or no trip.")
                } actions: {
                    Button("Add the first event") { showAdd = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(viewModel.events) { event in
                        EventRow(
                            event: TripEvent(id: event.id, tripId: event.familyId, memberId: event.memberId, title: event.title, notes: event.notes, locationName: event.locationName, startsAt: event.startsAt, endsAt: event.endsAt),
                            authorName: familyStore.member(for: event.memberId)?.displayName
                        )
                        .swipeActions {
                            if event.memberId == familyStore.currentMember?.id {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(event, isDemo: familyStore.isDemo) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
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
            if let family = familyStore.family, let member = familyStore.currentMember {
                AddFamilyEventView(familyId: family.id, memberId: member.id) { event in
                    try await viewModel.add(event, isDemo: familyStore.isDemo)
                }
            }
        }
        .task(id: familyStore.family?.id) {
            viewModel.events = []
            if let family = familyStore.family {
                await viewModel.load(familyId: family.id, isDemo: familyStore.isDemo)
            }
        }
    }
}

struct AddFamilyEventView: View {
    let familyId: UUID
    let memberId: UUID
    let onSave: (FamilyEvent) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var locationName = ""
    @State private var notes = ""
    @State private var startsAt: Date = .now.addingTimeInterval(3600)
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("Title (e.g. Riley's soccer game)", text: $title)
                    TextField("Location (optional)", text: $locationName)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("When") {
                    DatePicker("Starts", selection: $startsAt)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("Family event")
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
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func submit() {
        isWorking = true
        let event = FamilyEvent(
            id: UUID(),
            familyId: familyId,
            memberId: memberId,
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes.isEmpty ? nil : notes,
            locationName: locationName.isEmpty ? nil : locationName,
            startsAt: startsAt,
            endsAt: nil
        )
        Task {
            do {
                try await onSave(event)
                dismiss()
            } catch {
                errorMessage = "Couldn't save. Try again."
                isWorking = false
            }
        }
    }
}

// MARK: - Family management

struct FamilyDetailView: View {
    @EnvironmentObject private var familyStore: FamilyStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var store: TripStore
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        List {
            if let family = familyStore.family {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.inviteCode)
                                .font(.system(.title, design: .monospaced).weight(.bold))
                                .kerning(3)
                            Text("This code adds someone to \(family.name) — the everyday chat, calendar, and map.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ShareLink(item: "Join our family \"\(family.name)\" on Kinvoy! Download the app, tap \"Join a family with a code,\" and enter: \(family.inviteCode)") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Family invite code")
                } footer: {
                    Text("Trips have their own separate invite codes — share a trip's code from inside that trip to add people to it.")
                }

                Section("Members") {
                    ForEach(familyStore.members) { member in
                        HStack {
                            Text(String(member.displayName.prefix(1)).uppercased())
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.accentColor, in: Circle())
                            Text(member.displayName)
                            if member.id == familyStore.currentMember?.id {
                                Text("You")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { locationService.isFamilySharing },
                        set: { locationService.setFamilySharing($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Always share my location")
                            Text("Only \(family.name) sees it. Off anytime.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Your family's chat, calendar, and map are the Chat, Calendar, and Map tabs — they're here every day. Trips live in the Trips tab and open in their own workspace.")
                }

                Section {
                    Button("Leave \(family.name)", role: .destructive) {
                        Task { await familyStore.leaveFamily() }
                    }
                }

                Section {
                    Link("Privacy Policy", destination: URL(string: "https://kendallcoding202.github.io/kinvoy/privacy.html")!)
                    Link("Terms of Use", destination: URL(string: "https://kendallcoding202.github.io/kinvoy/terms.html")!)
                    Link("Contact support", destination: URL(string: "mailto:kendall12236@gmail.com")!)
                    Button("Delete my account", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deleting your account permanently removes you from every group and trip, along with everything you've posted. This can't be undone.")
                }
            }
        }
        .navigationTitle(familyStore.family?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await familyStore.refreshMembers()
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete permanently", role: .destructive) {
                isDeleting = true
                Task {
                    try? await moderation.deleteAccount()
                    await familyStore.leaveFamily()
                    await store.leaveTrip()
                    isDeleting = false
                }
            }
        } message: {
            Text("This removes you from every group and trip and deletes everything you've posted. It can't be undone.")
        }
        .overlay {
            if isDeleting {
                ProgressView("Deleting…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Family setup (create / join)

struct FamilySetupView: View {
    enum Mode {
        case create, join
    }

    let mode: Mode
    @EnvironmentObject private var familyStore: FamilyStore
    @EnvironmentObject private var locationService: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var code = ""
    @State private var displayName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        let hasTarget = mode == .create
            ? !name.trimmingCharacters(in: .whitespaces).isEmpty
            : code.trimmingCharacters(in: .whitespaces).count >= 6
        return hasTarget && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if mode == .create {
                    Section("Family name") {
                        TextField("e.g. The Sorensons", text: $name)
                    }
                } else {
                    Section("Family invite code") {
                        TextField("6-character code", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title2, design: .monospaced))
                    }
                }
                Section("You") {
                    TextField("Your name (what the group sees)", text: $displayName)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle(mode == .create ? "Create your family" : "Join a family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button(mode == .create ? "Create" : "Join") { submit() }
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private func submit() {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                if mode == .create {
                    try await familyStore.createFamily(
                        name: name.trimmingCharacters(in: .whitespaces),
                        displayName: displayName.trimmingCharacters(in: .whitespaces)
                    )
                } else {
                    try await familyStore.joinFamily(
                        code: code,
                        displayName: displayName.trimmingCharacters(in: .whitespaces)
                    )
                }
                if let family = familyStore.family, let member = familyStore.currentMember {
                    locationService.configureFamily(familyId: family.id, familyMemberId: member.id)
                }
                dismiss()
            } catch {
                errorMessage = mode == .create
                    ? "Couldn't create the family. Try again."
                    : "Couldn't join — double-check the code."
                isWorking = false
            }
        }
    }
}
