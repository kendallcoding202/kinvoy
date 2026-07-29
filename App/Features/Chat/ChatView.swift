import SwiftUI
import Supabase

enum ChatEntry: Identifiable, Equatable {
    case message(Message)
    case poll(Poll)

    var id: UUID {
        switch self {
        case .message(let message): message.id
        case .poll(let poll): poll.id
        }
    }

    var createdAt: Date {
        switch self {
        case .message(let message): message.createdAt
        case .poll(let poll): poll.createdAt
        }
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var polls: [Poll] = []
    @Published var votes: [PollVote] = []
    @Published var draft = ""
    @Published var isLoading = false

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var pollTask: Task<Void, Never>?

    var timeline: [ChatEntry] {
        (messages.map(ChatEntry.message) + polls.map(ChatEntry.poll))
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var activeTripId: UUID?

    func start(trip: Trip, isDemo: Bool) {
        if activeTripId != trip.id {
            stop()
            messages = []
            polls = []
            votes = []
        }
        activeTripId = trip.id
        guard pollTask == nil else { return }
        if isDemo {
            messages = DemoData.messages
            polls = DemoData.polls
            votes = DemoData.pollVotes
            return
        }
        pollTask = Task {
            await refresh(tripId: trip.id, showSpinner: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await refresh(tripId: trip.id, showSpinner: false)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh(tripId: UUID, showSpinner: Bool) async {
        if showSpinner { isLoading = true }
        defer { isLoading = false }
        do {
            messages = try await client
                .from("messages").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at")
                .limit(500)
                .execute().value
            polls = try await client
                .from("polls").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at")
                .execute().value
            votes = try await client
                .from("poll_votes").select()
                .eq("trip_id", value: tripId.uuidString)
                .execute().value
        } catch {
            print("Chat refresh failed: \(error)")
        }
    }

    func createPoll(question: String, options: [String], tripId: UUID, memberId: UUID, isDemo: Bool) async throws {
        if isDemo {
            polls.append(Poll(id: UUID(), tripId: tripId, memberId: memberId, question: question, options: options, createdAt: .now))
            return
        }
        struct PollInsert: Encodable {
            let trip_id: String
            let member_id: String
            let question: String
            let options: [String]
        }
        _ = try await client.from("polls")
            .insert(PollInsert(trip_id: tripId.uuidString, member_id: memberId.uuidString, question: question, options: options))
            .execute()
        await refresh(tripId: tripId, showSpinner: false)
    }

    func vote(poll: Poll, optionIndex: Int, memberId: UUID, isDemo: Bool) async {
        // Optimistic local update.
        votes.removeAll { $0.pollId == poll.id && $0.memberId == memberId }
        votes.append(PollVote(pollId: poll.id, tripId: poll.tripId, memberId: memberId, optionIndex: optionIndex))
        guard !isDemo else { return }
        struct VoteUpsert: Encodable {
            let poll_id: String
            let trip_id: String
            let member_id: String
            let option_index: Int
        }
        _ = try? await client.from("poll_votes")
            .upsert(VoteUpsert(poll_id: poll.id.uuidString, trip_id: poll.tripId.uuidString, member_id: memberId.uuidString, option_index: optionIndex), onConflict: "poll_id,member_id")
            .execute()
    }

    func voteCount(poll: Poll, optionIndex: Int) -> Int {
        votes.filter { $0.pollId == poll.id && $0.optionIndex == optionIndex }.count
    }

    func myVote(poll: Poll, memberId: UUID?) -> Int? {
        guard let memberId else { return nil }
        return votes.first { $0.pollId == poll.id && $0.memberId == memberId }?.optionIndex
    }

    func send(tripId: UUID, memberId: UUID, isDemo: Bool) async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        draft = ""
        if isDemo {
            messages.append(Message(id: UUID(), tripId: tripId, memberId: memberId, content: content, createdAt: .now))
            return
        }
        struct MessageInsert: Encodable {
            let trip_id: String
            let member_id: String
            let content: String
        }
        do {
            _ = try await client.from("messages")
                .insert(MessageInsert(trip_id: tripId.uuidString, member_id: memberId.uuidString, content: content))
                .execute()
            await refresh(tripId: tripId, showSpinner: false)
        } catch {
            draft = content   // give the text back so it isn't lost
        }
    }
}

struct ChatView: View {
    @EnvironmentObject private var store: TripStore
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var inputFocused: Bool
    @State private var showCreatePoll = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle("Trip chat")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreatePoll) {
                CreatePollView { question, options in
                    guard let trip = store.trip, let member = store.currentMember else { return }
                    try await viewModel.createPoll(question: question, options: options, tripId: trip.id, memberId: member.id, isDemo: store.isDemo)
                }
            }
            .onAppear {
                if let trip = store.trip {
                    viewModel.start(trip: trip, isDemo: store.isDemo)
                }
            }
            .onDisappear { viewModel.stop() }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.timeline) { entry in
                        entryView(entry)
                            .id(entry.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.timeline.count) {
                if let last = viewModel.timeline.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onTapGesture { inputFocused = false }
        }
    }

    @ViewBuilder
    private func entryView(_ entry: ChatEntry) -> some View {
        switch entry {
        case .message(let message):
            MessageBubble(
                message: message,
                senderName: store.member(for: message.memberId)?.displayName ?? "Someone",
                isMine: message.memberId == store.currentMember?.id
            )
        case .poll(let poll):
            PollBubble(
                poll: poll,
                authorName: store.member(for: poll.memberId)?.displayName ?? "Someone",
                viewModel: viewModel
            )
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                showCreatePoll = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            TextField("Message the family…", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)

            Button {
                if let trip = store.trip, let member = store.currentMember {
                    Task { await viewModel.send(tripId: trip.id, memberId: member.id, isDemo: store.isDemo) }
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
}

struct PollBubble: View {
    let poll: Poll
    let authorName: String
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject private var store: TripStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.accentColor)
                Text("\(authorName) asked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(poll.question)
                .font(.body.weight(.semibold))

            ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                optionRow(index: index, option: option)
            }

            Text(poll.createdAt.formatted(.dateTime.hour().minute()))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.accentColor.opacity(0.25)))
    }

    private func optionRow(index: Int, option: String) -> some View {
        let count = viewModel.voteCount(poll: poll, optionIndex: index)
        let total = max(1, poll.options.indices.reduce(0) { $0 + viewModel.voteCount(poll: poll, optionIndex: $1) })
        let isMyVote = viewModel.myVote(poll: poll, memberId: store.currentMember?.id) == index

        return Button {
            guard let member = store.currentMember else { return }
            Task { await viewModel.vote(poll: poll, optionIndex: index, memberId: member.id, isDemo: store.isDemo) }
        } label: {
            HStack {
                Image(systemName: isMyVote ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isMyVote ? Color.accentColor : .secondary)
                Text(option)
                Spacer()
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(isMyVote ? 0.18 : 0.08))
                        .frame(width: geo.size.width * CGFloat(count) / CGFloat(total), alignment: .leading)
                }
            )
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct CreatePollView: View {
    let onSave: (String, [String]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var options = ["", ""]
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var cleanOptions: [String] {
        options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("e.g. Beach or pool tomorrow?", text: $question)
                }
                Section("Options") {
                    ForEach(options.indices, id: \.self) { index in
                        TextField("Option \(index + 1)", text: $options[index])
                    }
                    if options.count < 4 {
                        Button {
                            options.append("")
                        } label: {
                            Label("Add option", systemImage: "plus")
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.callout)
                }
            }
            .navigationTitle("New poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Post") { submit() }
                            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || cleanOptions.count < 2)
                    }
                }
            }
        }
    }

    private func submit() {
        isWorking = true
        Task {
            do {
                try await onSave(question.trimmingCharacters(in: .whitespaces), cleanOptions)
                dismiss()
            } catch {
                errorMessage = "Couldn't post the poll. Try again."
                isWorking = false
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let senderName: String
    let isMine: Bool

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
            if !isMine {
                Text(senderName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }
            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isMine ? Color.accentColor : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(isMine ? .white : .primary)
            Text(message.createdAt.formatted(.dateTime.hour().minute()))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .padding(isMine ? .leading : .trailing, 48)
    }
}
