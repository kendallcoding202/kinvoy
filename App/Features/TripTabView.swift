import SwiftUI

struct TripTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            CalendarView()
                .tabItem { Label("Plans", systemImage: "calendar") }
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            FamilyMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
            TripDetailView()
                .tabItem { Label("Trip", systemImage: "suitcase.fill") }
        }
    }
}
