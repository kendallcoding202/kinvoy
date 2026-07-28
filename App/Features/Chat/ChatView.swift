import SwiftUI
import Supabase

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draft = ""
    @Published var isLoading = false

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var pollTask: Task<Void, Never>?

    func start(trip: Trip, isDemo: Bool) {
        guard pollTask == nil else { return }
        if isDemo {
            messages = DemoData.messages
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
        } catch {
            print("Chat refresh failed: \(error)")
        }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
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
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            senderName: store.member(for: message.memberId)?.displayName ?? "Someone",
                            isMine: message.memberId == store.currentMember?.id
                        )
                        .id(message.id)
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
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
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
