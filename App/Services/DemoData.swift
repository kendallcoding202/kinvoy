import Foundation

/// Sample data so the app is fully explorable in the simulator before
/// Supabase is configured. Nothing here touches the network.
enum DemoData {
    static let tripId = UUID(uuidString: "00000000-0000-0000-0000-00000000AAAA")!

    static let members: [Member] = [
        Member(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, tripId: tripId, userId: UUID(), displayName: "You"),
        Member(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, tripId: tripId, userId: UUID(), displayName: "Mom"),
        Member(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, tripId: tripId, userId: UUID(), displayName: "Dad"),
        Member(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, tripId: tripId, userId: UUID(), displayName: "Riley"),
    ]

    static var trip: Trip {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start)!
        return Trip(
            id: tripId,
            name: "Summer Beach Week",
            destination: "Gulf Shores, Alabama",
            startsOn: Trip.dayFormatter.string(from: start),
            endsOn: Trip.dayFormatter.string(from: end),
            inviteCode: "DEMO42"
        )
    }

    static var events: [TripEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func at(day: Int, hour: Int) -> Date {
            cal.date(byAdding: DateComponents(day: day, hour: hour), to: today)!
        }
        return [
            TripEvent(id: UUID(), tripId: tripId, memberId: members[1].id, title: "Beach morning", notes: "Bring sunscreen and the umbrella", locationName: "West Beach", startsAt: at(day: 0, hour: 9), endsAt: at(day: 0, hour: 12)),
            TripEvent(id: UUID(), tripId: tripId, memberId: members[2].id, title: "Dinner at The Hangout", notes: nil, locationName: "The Hangout", startsAt: at(day: 0, hour: 18), endsAt: nil),
            TripEvent(id: UUID(), tripId: tripId, memberId: members[0].id, title: "Dolphin cruise", notes: "Booked for 6 people", locationName: "Orange Beach Marina", startsAt: at(day: 1, hour: 10), endsAt: at(day: 1, hour: 12)),
            TripEvent(id: UUID(), tripId: tripId, memberId: members[3].id, title: "Mini golf", notes: nil, locationName: "The Track", startsAt: at(day: 2, hour: 15), endsAt: nil),
        ]
    }

    static var messages: [Message] {
        let now = Date.now
        return [
            Message(id: UUID(), tripId: tripId, memberId: members[1].id, content: "We landed! Heading to the condo now 🏖️", createdAt: now.addingTimeInterval(-7200)),
            Message(id: UUID(), tripId: tripId, memberId: members[2].id, content: "Grabbing groceries on the way. Need anything?", createdAt: now.addingTimeInterval(-6800)),
            Message(id: UUID(), tripId: tripId, memberId: members[0].id, content: "Coffee!! And breakfast stuff", createdAt: now.addingTimeInterval(-6500)),
            Message(id: UUID(), tripId: tripId, memberId: members[3].id, content: "Pool is open until 10 btw", createdAt: now.addingTimeInterval(-3600)),
        ]
    }

    static var locations: [MemberLocation] {
        [
            MemberLocation(memberId: members[1].id, tripId: tripId, latitude: 30.2460, longitude: -87.7008, updatedAt: .now.addingTimeInterval(-120)),
            MemberLocation(memberId: members[2].id, tripId: tripId, latitude: 30.2530, longitude: -87.6820, updatedAt: .now.addingTimeInterval(-300)),
            MemberLocation(memberId: members[3].id, tripId: tripId, latitude: 30.2410, longitude: -87.7090, updatedAt: .now.addingTimeInterval(-60)),
        ]
    }

    static var logistics: [LogisticsItem] {
        [
            LogisticsItem(id: UUID(), tripId: tripId, memberId: members[2].id, kind: .flight, title: "Delta 1432 → PNS", details: "Departs 8:15 AM, Confirmation #ABC123", happensOn: trip.startsOn),
            LogisticsItem(id: UUID(), tripId: tripId, memberId: members[1].id, kind: .hotel, title: "Beachfront Condo", details: "Check-in 4 PM, gate code 4488", happensOn: trip.startsOn),
            LogisticsItem(id: UUID(), tripId: tripId, memberId: members[2].id, kind: .car, title: "Enterprise minivan", details: "Pickup at PNS airport, Confirmation #R55921", happensOn: trip.startsOn),
        ]
    }

    static let checklists: [Checklist] = [
        Checklist(id: UUID(uuidString: "00000000-0000-0000-0000-00000000CC01")!, tripId: tripId, memberId: members[1].id, title: "Packing — beach gear"),
        Checklist(id: UUID(uuidString: "00000000-0000-0000-0000-00000000CC02")!, tripId: tripId, memberId: members[2].id, title: "Grocery run"),
    ]

    static var checklistItems: [ChecklistItem] {
        let packing = checklists[0].id
        let grocery = checklists[1].id
        return [
            ChecklistItem(id: UUID(), checklistId: packing, tripId: tripId, title: "Beach umbrella", assignedMemberId: members[2].id, isDone: true),
            ChecklistItem(id: UUID(), checklistId: packing, tripId: tripId, title: "Sunscreen (SPF 50)", assignedMemberId: members[1].id, isDone: true),
            ChecklistItem(id: UUID(), checklistId: packing, tripId: tripId, title: "Boogie boards", assignedMemberId: members[3].id, isDone: false),
            ChecklistItem(id: UUID(), checklistId: packing, tripId: tripId, title: "Cooler", assignedMemberId: nil, isDone: false),
            ChecklistItem(id: UUID(), checklistId: grocery, tripId: tripId, title: "Coffee", assignedMemberId: members[0].id, isDone: false),
            ChecklistItem(id: UUID(), checklistId: grocery, tripId: tripId, title: "Breakfast stuff", assignedMemberId: nil, isDone: false),
        ]
    }

    static var expenses: [Expense] {
        [
            Expense(id: UUID(), tripId: tripId, memberId: members[1].id, title: "Beach condo (3 nights)", amountCents: 68400, createdAt: .now.addingTimeInterval(-90000)),
            Expense(id: UUID(), tripId: tripId, memberId: members[2].id, title: "Groceries", amountCents: 14275, createdAt: .now.addingTimeInterval(-80000)),
            Expense(id: UUID(), tripId: tripId, memberId: members[0].id, title: "Dolphin cruise tickets", amountCents: 18000, createdAt: .now.addingTimeInterval(-3600)),
        ]
    }

    static var polls: [Poll] {
        [Poll(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000DD01")!,
            tripId: tripId,
            memberId: members[1].id,
            question: "Beach or pool tomorrow morning?",
            options: ["Beach 🏖️", "Pool 🏊", "Sleep in 😴"],
            createdAt: .now.addingTimeInterval(-3000)
        )]
    }

    static var pollVotes: [PollVote] {
        let poll = polls[0].id
        return [
            PollVote(pollId: poll, tripId: tripId, memberId: members[1].id, optionIndex: 0),
            PollVote(pollId: poll, tripId: tripId, memberId: members[2].id, optionIndex: 0),
            PollVote(pollId: poll, tripId: tripId, memberId: members[3].id, optionIndex: 2),
        ]
    }

    static let suggestions: [ActivitySuggestion] = [
        ActivitySuggestion(title: "Sunset dolphin cruise", description: "Two-hour boat tour where dolphins swim alongside the wake. Kids love the upper deck.", category: "Outdoors", emoji: "🐬", costLevel: "$$"),
        ActivitySuggestion(title: "Gulf State Park bike trail", description: "Flat, shaded 28-mile trail network. Rent bikes near the pier and look for alligators at the lake.", category: "Outdoors", emoji: "🚴", costLevel: "$"),
        ActivitySuggestion(title: "The Hangout", description: "Loud, fun burger spot right on the beach with a sand pit and live music for the kids to burn energy.", category: "Food", emoji: "🍔", costLevel: "$$"),
        ActivitySuggestion(title: "Rainy-day escape room", description: "Family-friendly puzzle rooms rated easy enough for kids 8 and up.", category: "Rainy day", emoji: "🧩", costLevel: "$$"),
    ]
}
