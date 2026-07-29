import SwiftUI
import Supabase

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [TripEvent] = []
    @Published var isLoading = false

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var pollTask: Task<Void, Never>?

    private var activeTripId: UUID?

    func start(trip: Trip, isDemo: Bool) {
        if activeTripId != trip.id {
            stop()
            events = []
        }
        activeTripId = trip.id
        guard pollTask == nil else { return }
        if isDemo {
            events = DemoData.events
            return
        }
        pollTask = Task {
            await refresh(tripId: trip.id, showSpinner: true)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
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
            events = try await client
                .from("events").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("starts_at")
                .execute().value
        } catch {
            print("Events refresh failed: \(error)")
        }
    }

    func add(_ event: TripEvent, isDemo: Bool) async throws {
        if isDemo {
            events.append(event)
            events.sort { $0.startsAt < $1.startsAt }
            return
        }
        struct EventInsert: Encodable {
            let trip_id: String
            let member_id: String
            let title: String
            let notes: String?
            let location_name: String?
            let starts_at: Date
            let ends_at: Date?
        }
        let row = EventInsert(
            trip_id: event.tripId.uuidString,
            member_id: event.memberId.uuidString,
            title: event.title,
            notes: event.notes,
            location_name: event.locationName,
            starts_at: event.startsAt,
            ends_at: event.endsAt
        )
        _ = try await client.from("events").insert(row).execute()
        await refresh(tripId: event.tripId, showSpinner: false)
    }

    func delete(_ event: TripEvent, isDemo: Bool) async {
        if isDemo {
            events.removeAll { $0.id == event.id }
            return
        }
        _ = try? await client.from("events").delete()
            .eq("id", value: event.id.uuidString)
            .execute()
        await refresh(tripId: event.tripId, showSpinner: false)
    }
}

struct CalendarView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var familyStore: FamilyStore
    @StateObject private var viewModel = EventsViewModel()
    @State private var selectedDay: Date?
    @State private var showAdd = false
    @State private var scope: PlansScope = .trip

    enum PlansScope {
        case trip, family
    }

    private var trip: Trip? { store.trip }

    var body: some View {
        NavigationStack {
            Group {
                if scope == .family, familyStore.family != nil {
                    VStack(spacing: 0) {
                        scopePicker
                        FamilyCalendarView()
                    }
                } else if let trip {
                    VStack(spacing: 0) {
                        if familyStore.family != nil {
                            scopePicker
                        }
                        dayPicker(trip: trip)
                        Divider()
                        eventList(trip: trip)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(scope == .family ? "Family calendar" : "Plans")
            .toolbar {
                if scope == .trip {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                if let trip, let member = store.currentMember {
                    AddEventView(trip: trip, memberId: member.id, defaultDay: selectedDay) { event in
                        try await viewModel.add(event, isDemo: store.isDemo)
                    }
                }
            }
            .onAppear {
                if let trip {
                    viewModel.start(trip: trip, isDemo: store.isDemo)
                }
            }
            .onDisappear { viewModel.stop() }
        }
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            Text("\(store.trip?.kindOrDefault.emoji ?? "🧳") Trip").tag(PlansScope.trip)
            Text("🏠 Family").tag(PlansScope.family)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func dayPicker(trip: Trip) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                dayChip(label: "All", isSelected: selectedDay == nil) { selectedDay = nil }
                ForEach(trip.days, id: \.self) { day in
                    dayChip(
                        label: day.formatted(.dateTime.weekday(.abbreviated).day()),
                        isSelected: selectedDay == day,
                        isToday: Calendar.current.isDateInToday(day)
                    ) { selectedDay = day }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func dayChip(label: String, isSelected: Bool, isToday: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
                .overlay {
                    if isToday && !isSelected {
                        Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var filteredEvents: [TripEvent] {
        guard let selectedDay else { return viewModel.events }
        return viewModel.events.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: selectedDay) }
    }

    private func eventList(trip: Trip) -> some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "Nothing planned yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Tap + to add the first plan. Everyone on the trip sees it instantly.")
                )
            } else {
                List {
                    ForEach(groupedDays, id: \.self) { day in
                        Section(day.formatted(.dateTime.weekday(.wide).month().day())) {
                            ForEach(eventsOn(day)) { event in
                                EventRow(event: event, authorName: store.member(for: event.memberId)?.displayName)
                                    .swipeActions {
                                        if event.memberId == store.currentMember?.id {
                                            Button(role: .destructive) {
                                                Task { await viewModel.delete(event, isDemo: store.isDemo) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var groupedDays: [Date] {
        let days = filteredEvents.map { Calendar.current.startOfDay(for: $0.startsAt) }
        return Array(Set(days)).sorted()
    }

    private func eventsOn(_ day: Date) -> [TripEvent] {
        filteredEvents.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: day) }
    }
}

struct EventRow: View {
    let event: TripEvent
    let authorName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.startsAt.formatted(.dateTime.hour().minute()))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let end = event.endsAt {
                    Text(end.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.body.weight(.medium))
                if let location = event.locationName, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let authorName {
                    Text("Added by \(authorName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
