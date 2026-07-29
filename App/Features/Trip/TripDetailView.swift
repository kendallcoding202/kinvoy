import Supabase
import SwiftUI

@MainActor
final class LogisticsViewModel: ObservableObject {
    @Published var items: [LogisticsItem] = []

    private var client: SupabaseClient { SupabaseService.shared.client }

    func load(tripId: UUID, isDemo: Bool) async {
        if isDemo {
            if items.isEmpty { items = DemoData.logistics }
            return
        }
        do {
            items = try await client
                .from("logistics").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at")
                .execute().value
        } catch {
            print("Logistics load failed: \(error)")
        }
    }

    func add(_ item: LogisticsItem, isDemo: Bool) async throws {
        if isDemo {
            items.append(item)
            return
        }
        struct LogisticsInsert: Encodable {
            let trip_id: String
            let member_id: String
            let kind: String
            let title: String
            let details: String?
            let happens_on: String?
        }
        _ = try await client.from("logistics").insert(LogisticsInsert(
            trip_id: item.tripId.uuidString,
            member_id: item.memberId.uuidString,
            kind: item.kind.rawValue,
            title: item.title,
            details: item.details,
            happens_on: item.happensOn
        )).execute()
        await load(tripId: item.tripId, isDemo: false)
    }

    func delete(_ item: LogisticsItem, isDemo: Bool) async {
        if isDemo {
            items.removeAll { $0.id == item.id }
            return
        }
        _ = try? await client.from("logistics").delete()
            .eq("id", value: item.id.uuidString)
            .execute()
        await load(tripId: item.tripId, isDemo: false)
    }
}

struct TripDetailView: View {
    @EnvironmentObject private var store: TripStore
    @StateObject private var logistics = LogisticsViewModel()
    @State private var forecast: [DayForecast] = []
    @State private var showAddLogistics = false
    @State private var showCreateTrip = false
    @State private var showJoinTrip = false

    var body: some View {
        NavigationStack {
            Group {
                if let trip = store.trip {
                    List {
                        inviteSection(trip: trip)
                        sharedSection
                        weatherSection(trip: trip)
                        logisticsSection
                        membersSection
                        myTripsSection
                        aboutSection(trip: trip)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(store.trip?.name ?? "Trip")
            .task(id: store.trip?.id) {
                if let trip = store.trip {
                    await logistics.load(tripId: trip.id, isDemo: store.isDemo)
                    await store.refreshMembers()
                    await store.refreshMyTrips()
                    forecast = (try? await WeatherService.forecast(for: trip)) ?? []
                }
            }
            .sheet(isPresented: $showAddLogistics) {
                if let trip = store.trip, let member = store.currentMember {
                    AddLogisticsView(trip: trip, memberId: member.id) { item in
                        try await logistics.add(item, isDemo: store.isDemo)
                    }
                }
            }
            .sheet(isPresented: $showCreateTrip) { CreateTripView() }
            .sheet(isPresented: $showJoinTrip) { JoinTripView() }
        }
    }

    private func inviteSection(trip: Trip) -> some View {
        Section("Invite family") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.inviteCode)
                        .font(.system(.title, design: .monospaced).weight(.bold))
                        .kerning(3)
                    Text("Family members enter this code to join.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ShareLink(item: inviteMessage(trip: trip)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func inviteMessage(trip: Trip) -> String {
        "Join our trip \"\(trip.name)\" on Kinvoy! Download the app, tap \"Join with invite code,\" and enter: \(trip.inviteCode)"
    }

    private var sharedSection: some View {
        Section("Shared") {
            NavigationLink {
                ChecklistsView()
            } label: {
                Label("Packing & checklists", systemImage: "checklist")
            }
            NavigationLink {
                PhotoAlbumView()
            } label: {
                Label("Photo album", systemImage: "photo.on.rectangle.angled")
            }
            NavigationLink {
                ExpensesView()
            } label: {
                Label("Expenses", systemImage: "dollarsign.circle")
            }
            NavigationLink {
                IdeasView()
            } label: {
                Label("Ideas", systemImage: "sparkles")
            }
        }
    }

    private func weatherSection(trip: Trip) -> some View {
        Section("Weather in \(trip.destination)") {
            if forecast.isEmpty {
                Text("Forecast appears here as your trip dates get closer (about two weeks out).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(forecast) { day in
                            VStack(spacing: 5) {
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption.weight(.semibold))
                                Image(systemName: day.symbolName)
                                    .font(.title3)
                                    .symbolRenderingMode(.multicolor)
                                Text("\(Int(day.highF))°")
                                    .font(.subheadline.weight(.bold))
                                Text("\(Int(day.lowF))°")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if day.precipChance >= 30 {
                                    Text("\(day.precipChance)%")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var logisticsSection: some View {
        Section {
            if logistics.items.isEmpty {
                Text("Keep flight confirmations, lodging details, rental car info, and tickets where everyone can find them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(logistics.items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.kind.systemImage)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.body.weight(.medium))
                        if let details = item.details, !details.isEmpty {
                            Text(details).font(.caption).foregroundStyle(.secondary)
                        }
                        if let day = item.happensOn, let date = Trip.dayFormatter.date(from: day) {
                            Text(date.formatted(.dateTime.weekday().month().day()))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await logistics.delete(item, isDemo: store.isDemo) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button {
                showAddLogistics = true
            } label: {
                Label("Add travel info", systemImage: "plus")
            }
        } header: {
            Text("Travel info")
        }
    }

    private var membersSection: some View {
        Section("Who's on this trip") {
            ForEach(store.members) { member in
                HStack {
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor, in: Circle())
                    Text(member.displayName)
                    if member.id == store.currentMember?.id {
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var myTripsSection: some View {
        Section {
            ForEach(store.myTrips) { candidate in
                Button {
                    Task { await store.switchTrip(to: candidate) }
                } label: {
                    HStack {
                        Text(candidate.kindOrDefault.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(candidate.startDate.formatted(.dateTime.month().day())) – \(candidate.endDate.formatted(.dateTime.month().day())) · \(candidate.destination)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if candidate.id == store.trip?.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            Button {
                showCreateTrip = true
            } label: {
                Label("Start another trip", systemImage: "plus")
            }
            Button {
                showJoinTrip = true
            } label: {
                Label("Join with invite code", systemImage: "person.badge.key")
            }
        } header: {
            Text("My trips")
        } footer: {
            Text("Tap a trip to switch. Every trip keeps its own plans, chat, map, photos, and expenses.")
        }
    }

    private func aboutSection(trip: Trip) -> some View {
        Section {
            LabeledContent("Destination", value: trip.destination)
            LabeledContent("Dates", value: "\(trip.startDate.formatted(.dateTime.month().day())) – \(trip.endDate.formatted(.dateTime.month().day()))")
            if store.isDemo {
                LabeledContent("Mode", value: "Demo — sample data only")
            }
            Button("Leave trip", role: .destructive) {
                Task { await store.leaveTrip() }
            }
        }
    }
}
