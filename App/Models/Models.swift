import Foundation

enum TripKind: String, Codable, CaseIterable, Identifiable {
    case vacation, camping, birthday, holiday, reunion, sports, getaway, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .vacation: "Vacation"
        case .camping: "Camping trip"
        case .birthday: "Birthday"
        case .holiday: "Holiday"
        case .reunion: "Reunion"
        case .sports: "Sports"
        case .getaway: "Weekend getaway"
        case .other: "Something else"
        }
    }

    var emoji: String {
        switch self {
        case .vacation: "🏖️"
        case .camping: "🏕️"
        case .birthday: "🎂"
        case .holiday: "🎄"
        case .reunion: "👨‍👩‍👧‍👦"
        case .sports: "🏆"
        case .getaway: "🚗"
        case .other: "📌"
        }
    }
}

struct Trip: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var destination: String
    var startsOn: String   // "yyyy-MM-dd"
    var endsOn: String     // "yyyy-MM-dd"
    let inviteCode: String
    var kind: TripKind?    // optional: rows created before migration 003 decode fine
    var familyId: UUID?    // set when the trip belongs to a family
    var isPrivate: Bool?

    var kindOrDefault: TripKind { kind ?? .vacation }
    var isFamilyTrip: Bool { familyId != nil && !(isPrivate ?? false) }

    enum CodingKeys: String, CodingKey {
        case id, name, destination, kind
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case inviteCode = "invite_code"
        case familyId = "family_id"
        case isPrivate = "is_private"
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

struct Checklist: Codable, Identifiable, Equatable {
    let id: UUID
    let tripId: UUID
    let memberId: UUID
    var title: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case tripId = "trip_id"
        case memberId = "member_id"
    }
}

struct ChecklistItem: Codable, Identifiable, Equatable {
    let id: UUID
    let checklistId: UUID
    let tripId: UUID
    var title: String
    var assignedMemberId: UUID?
    var isDone: Bool

    enum CodingKeys: String, CodingKey {
        case id, title
        case checklistId = "checklist_id"
        case tripId = "trip_id"
        case assignedMemberId = "assigned_member_id"
        case isDone = "is_done"
    }
}

struct TripPhoto: Codable, Identifiable, Equatable {
    let id: UUID
    let tripId: UUID
    let memberId: UUID
    let storagePath: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case memberId = "member_id"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }
}

struct Expense: Codable, Identifiable, Equatable {
    let id: UUID
    let tripId: UUID
    let memberId: UUID   // who paid
    var title: String
    var amountCents: Int
    let createdAt: Date

    var amount: Double { Double(amountCents) / 100 }

    enum CodingKeys: String, CodingKey {
        case id, title
        case tripId = "trip_id"
        case memberId = "member_id"
        case amountCents = "amount_cents"
        case createdAt = "created_at"
    }
}

struct Poll: Codable, Identifiable, Equatable {
    let id: UUID
    let tripId: UUID
    let memberId: UUID
    let question: String
    let options: [String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, question, options
        case tripId = "trip_id"
        case memberId = "member_id"
        case createdAt = "created_at"
    }
}

struct PollVote: Codable, Equatable {
    let pollId: UUID
    let tripId: UUID
    let memberId: UUID
    var optionIndex: Int

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case tripId = "trip_id"
        case memberId = "member_id"
        case optionIndex = "option_index"
    }
}

struct Family: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
    }
}

struct FamilyMember: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let familyId: UUID
    let userId: UUID
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case userId = "user_id"
        case displayName = "display_name"
    }
}

struct FamilyMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let familyId: UUID
    let memberId: UUID
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content
        case familyId = "family_id"
        case memberId = "member_id"
        case createdAt = "created_at"
    }
}

struct FamilyEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let familyId: UUID
    let memberId: UUID
    var title: String
    var notes: String?
    var locationName: String?
    var startsAt: Date
    var endsAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, notes
        case familyId = "family_id"
        case memberId = "member_id"
        case locationName = "location_name"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }
}

struct FamilyLocation: Codable, Identifiable, Equatable {
    let memberId: UUID
    let familyId: UUID
    let latitude: Double
    let longitude: Double
    let updatedAt: Date

    var id: UUID { memberId }

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case familyId = "family_id"
        case latitude, longitude
        case updatedAt = "updated_at"
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
