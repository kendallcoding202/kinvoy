import SwiftUI

struct TripTabView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label("Plans", systemImage: "calendar") }
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            FamilyMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
            IdeasView()
                .tabItem { Label("Ideas", systemImage: "sparkles") }
            TripDetailView()
                .tabItem { Label("Trip", systemImage: "suitcase.fill") }
        }
    }
}
