import PhotosUI
import Supabase
import SwiftUI

@MainActor
final class PhotoAlbumViewModel: ObservableObject {
    @Published var photos: [TripPhoto] = []
    @Published var signedURLs: [UUID: URL] = [:]
    @Published var isUploading = false
    @Published var errorMessage: String?

    private var client: SupabaseClient { SupabaseService.shared.client }
    private let bucket = "trip-photos"

    func load(tripId: UUID, isDemo: Bool) async {
        guard !isDemo else { return }   // demo shows the empty state
        do {
            let rows: [TripPhoto] = try await client
                .from("photos").select()
                .eq("trip_id", value: tripId.uuidString)
                .order("created_at", ascending: false)
                .execute().value
            photos = rows
            await refreshURLs()
        } catch {
            print("Photos load failed: \(error)")
        }
    }

    private func refreshURLs() async {
        for photo in photos where signedURLs[photo.id] == nil {
            signedURLs[photo.id] = try? await client.storage
                .from(bucket)
                .createSignedURL(path: photo.storagePath, expiresIn: 3600)
        }
    }

    func upload(_ pickerItems: [PhotosPickerItem], tripId: UUID, memberId: UUID, isDemo: Bool) async {
        guard !isDemo else {
            errorMessage = "Photo upload is disabled in demo mode."
            return
        }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        for pickerItem in pickerItems {
            guard let data = try? await pickerItem.loadTransferable(type: Data.self),
                  let jpeg = Self.downscaledJPEG(from: data) else { continue }
            let path = "\(tripId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            do {
                _ = try await client.storage.from(bucket).upload(
                    path,
                    data: jpeg,
                    options: FileOptions(contentType: "image/jpeg")
                )
                struct PhotoInsert: Encodable {
                    let trip_id: String
                    let member_id: String
                    let storage_path: String
                }
                _ = try await client.from("photos")
                    .insert(PhotoInsert(trip_id: tripId.uuidString, member_id: memberId.uuidString, storage_path: path))
                    .execute()
            } catch {
                errorMessage = "Some photos didn't upload. Try again."
                print("Upload failed: \(error)")
            }
        }
        await load(tripId: tripId, isDemo: false)
    }

    func delete(_ photo: TripPhoto) async {
        photos.removeAll { $0.id == photo.id }
        _ = try? await client.from("photos").delete()
            .eq("id", value: photo.id.uuidString)
            .execute()
        _ = try? await client.storage.from(bucket).remove(paths: [photo.storagePath])
    }

    /// Keeps uploads fast and storage small: long edge capped at 1600px.
    static func downscaledJPEG(from data: Data, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image.jpegData(compressionQuality: 0.75) }
        let scale = maxDimension / largest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }
}

struct PhotoAlbumView: View {
    @EnvironmentObject private var store: TripStore
    @StateObject private var viewModel = PhotoAlbumViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 3)]

    var body: some View {
        Group {
            if viewModel.photos.isEmpty {
                ContentUnavailableView(
                    "No photos yet",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(store.isDemo
                        ? "In a real trip, everyone's photos land here in one shared album."
                        : "Tap + to add the first photos. Everyone on the trip can see and add.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(viewModel.photos) { photo in
                            photoCell(photo)
                        }
                    }
                    .padding(3)
                    if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("Photos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isUploading {
                    ProgressView()
                } else {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onChange(of: pickerItems) {
            guard !pickerItems.isEmpty, let trip = store.trip, let member = store.currentMember else { return }
            let items = pickerItems
            pickerItems = []
            Task { await viewModel.upload(items, tripId: trip.id, memberId: member.id, isDemo: store.isDemo) }
        }
        .task {
            if let trip = store.trip {
                await viewModel.load(tripId: trip.id, isDemo: store.isDemo)
            }
        }
    }

    private func photoCell(_ photo: TripPhoto) -> some View {
        GeometryReader { geo in
            AsyncImage(url: viewModel.signedURLs[photo.id]) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color(.systemGray5).overlay(Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary))
                default:
                    Color(.systemGray6)
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .contextMenu {
            if photo.memberId == store.currentMember?.id {
                Button(role: .destructive) {
                    Task { await viewModel.delete(photo) }
                } label: {
                    Label("Delete photo", systemImage: "trash")
                }
            }
            if let member = store.member(for: photo.memberId) {
                Text("Added by \(member.displayName)")
            }
        }
    }
}
