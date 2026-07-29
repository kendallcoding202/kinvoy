import Supabase
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var upcomingEvents: [TripEvent] = []
    @Published var latestMessages: [Message] = []
    @Published var forecast: [DayForecast] = []

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var pollTask: Task<Void, Never>?

    private var activeTripId: UUID?

    func start(trip: Trip, isDemo: Bool) {
        if activeTripId != trip.id {
            stop()
            upcomingEvents = []
            latestMessages = []
            forecast = []
        }
        activeTripId = trip.id
        guard pollTask == nil else { return }
        if isDemo {
            upcomingEvents = Array(DemoData.events.filter { $0.startsAt > .now.addingTimeInterval(-3600) }.prefix(3))
            latestMessages = Array(DemoData.messages.suffix(2))
            Task { await loadForecast(trip: trip) }
            return
        }
        pollTask = Task {
            await loadForecast(trip: trip)
            while !Task.isCancelled {
                await refresh(tripId: trip.id)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func refresh(tripId: UUID) async {
        do {
            let events: [TripEvent] = try await client
                .from("events").select()
                .eq("trip_id", value: tripId.uuidString)
                .gte("starts_at", value: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-3600)))
                .order("starts_at")
                .limit(3)
                .execute().value
            upcomingEvents = events

            let messages: [Message] = try await client
                .from("messages").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at", ascending: false)
                .limit(2)
                .execute().value
            latestMessages = messages.reversed()
        } catch {
            print("Home refresh failed: \(error)")
        }
    }

    private func loadForecast(trip: Trip) async {
        forecast = (try? await WeatherService.forecast(for: trip)) ?? []
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var familyStore: FamilyStore
    @StateObject private var viewModel = HomeViewModel()
    @State private var showCreateFamily = false
    @State private var showJoinFamily = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let trip = store.trip {
                    VStack(alignment: .leading, spacing: 18) {
                        familyCard
                        header(trip: trip)
                        if !viewModel.forecast.isEmpty {
                            weatherCard
                        }
                        plansCard
                        chatCard
                        quickLinks
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .sheet(isPresented: $showCreateFamily) { FamilySetupView(mode: .create) }
            .sheet(isPresented: $showJoinFamily) { FamilySetupView(mode: .join) }
            .onAppear {
                if let trip = store.trip {
                    viewModel.start(trip: trip, isDemo: store.isDemo)
                }
            }
            .onDisappear { viewModel.stop() }
        }
    }

    @ViewBuilder
    private var familyCard: some View {
        if let family = familyStore.family {
            NavigationLink {
                FamilyDetailView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(family.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(memberSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("Set up your family", systemImage: "house.badge.plus")
                    .font(.headline)
                Text("One standing chat, a shared calendar, and always-on location — here every day, not just on trips.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Create family") { showCreateFamily = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Join with code") { showJoinFamily = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var memberSummary: String {
        let names = familyStore.members.map(\.displayName)
        if names.isEmpty { return "Just you so far — invite everyone" }
        return names.count <= 4 ? names.joined(separator: ", ") : "\(names.count) members"
    }

    private func header(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(trip.kindOrDefault.emoji) \(trip.name)")
                .font(.title2.bold())
            Text(countdownText(trip: trip))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func countdownText(trip: Trip) -> String {
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.startOfDay(for: trip.startDate)
        let end = Calendar.current.startOfDay(for: trip.endDate)
        if today < start {
            let days = Calendar.current.dateComponents([.day], from: today, to: start).day ?? 0
            return days == 1 ? "1 day to go — \(trip.destination)" : "\(days) days to go — \(trip.destination)"
        } else if today <= end {
            let day = (Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            return "Day \(day) of \(trip.days.count) in \(trip.destination)"
        } else {
            return "Trip complete — \(trip.destination)"
        }
    }

    private var weatherCard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.forecast.prefix(7)) { day in
                    VStack(spacing: 4) {
                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2.weight(.semibold))
                        Image(systemName: day.symbolName)
                            .symbolRenderingMode(.multicolor)
                        Text("\(Int(day.highF))°")
                            .font(.subheadline.weight(.bold))
                    }
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var plansCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Coming up", systemImage: "calendar")
                .font(.headline)
            if viewModel.upcomingEvents.isEmpty {
                Text("Nothing on the calendar yet. Add plans in the Plans tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.upcomingEvents) { event in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.startsAt.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                            Text(event.startsAt.formatted(.dateTime.hour().minute()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 58, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title).font(.subheadline.weight(.medium))
                            if let location = event.locationName, !location.isEmpty {
                                Text(location).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var chatCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Latest in chat", systemImage: "bubble.left.and.bubble.right")
                .font(.headline)
            if viewModel.latestMessages.isEmpty {
                Text("No messages yet — say hi in the Chat tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.latestMessages) { message in
                    HStack(alignment: .top, spacing: 6) {
                        Text(store.member(for: message.memberId)?.displayName ?? "Someone")
                            .font(.caption.weight(.bold))
                        Text(message.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var quickLinks: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            quickLink("Ideas", icon: "sparkles") { IdeasView() }
            quickLink("Lists", icon: "checklist") { ChecklistsView() }
            quickLink("Photos", icon: "photo.on.rectangle.angled") { PhotoAlbumView() }
            quickLink("Expenses", icon: "dollarsign.circle") { ExpensesView() }
        }
    }

    private func quickLink(_ title: String, icon: String, @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
