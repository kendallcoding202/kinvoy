import Foundation

struct Trip: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var destination: String
    var startsOn: String   // "yyyy-MM-dd"
    var endsOn: String     // "yyyy-MM-dd"
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id, name, destination
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case inviteCode = "invite_code"
    }

    var startDate: Date { Self.dayFormatter.date(from: startsOn) ?? .now }
    var endDate: Date { Self.dayFormatter.date(from: endsOn) ?? .now }

    /// Whole days of the trip, inclusive of both ends.
    var days: [Date] {
        var result: [Date] = []
        var day = Calendar.current.startOfDay(for: startDate)
        let last = Calendar.current.startOfDay(for: endDate)
        while day <= last {
            result.append(day)
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    var isActiveToday: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return today >= Calendar.current.startOfDay(for: startDate)
            && today <= Calendar.current.startOfDay(for: endDate)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
}

struct Member: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let tripId: UUID
    let userId: UUID
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case userId = "user_id"
        case displayName = "display_name"
    }
}

struct TripEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let tripId: UUID
    let memberId: UUID
    var title: String
    var notes: String?
    var locationName: String?
    var startsAt: Date
    var endsAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, notes
        case tripId = "trip_id"
        case memberId = "member_id"
        case locationName = "location_name"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }
}

struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let tripId: UUID
    let memberId: UUID
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content
        case tripId = "trip_id"
        case memberId = "member_id"
        case createdAt = "created_at"
    }
}

struct MemberLocation: Codable, Identifiable, Equatable {
    let memberId: UUID
    let tripId: UUID
    let latitude: Double
    let longitude: Double
    let updatedAt: Date

    var id: UUID { memberId }

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case tripId = "trip_id"
        case latitude, longitude
        case updatedAt = "updated_at"
    }
}

enum LogisticsKind: String, Codable, CaseIterable, Identifiable {
    case flight, hotel, car, ticket, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .flight: "Flight"
        case .hotel: "Lodging"
        case .car: "Rental car"
        case .ticket: "Tickets"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .flight: "airplane"
        case .hotel: "bed.double.fill"
        case .car: "car.fill"
        case .ticket: "ticket.fill"
        case .other: "doc.text.fill"
        }
    }
}

struct LogisticsItem: Codable, Identifiable, Equatable {
    let id: UUID
    let tripId: UUID
    let memberId: UUID
    var kind: LogisticsKind
    var title: String
    var details: String?
    var happensOn: String?   // "yyyy-MM-dd", optional

    enum CodingKeys: String, CodingKey {
        case id, kind, title, details
        case tripId = "trip_id"
        case memberId = "member_id"
        case happensOn = "happens_on"
    }
}

struct ActivitySuggestion: Codable, Identifiable, Equatable {
    var id: String { title }
    let title: String
    let description: String
    let category: String   // e.g. "Outdoors", "Food", "Rainy day"
    let emoji: String
    let costLevel: String  // "Free", "$", "$$", "$$$"

    enum CodingKeys: String, CodingKey {
        case title, description, category, emoji
        case costLevel = "cost_level"
    }
}
