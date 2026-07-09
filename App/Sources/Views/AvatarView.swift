import SwiftUI
import PhotosUI

/// Circular profile picture, falling back to an initials monogram.
/// Purely aesthetic — photos are never used by transcription or sync.
struct AvatarView: View {
    let fileName: String?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .overlay {
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tint)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var loadedImage: UIImage? {
        guard let fileName else { return nil }
        return UIImage(contentsOfFile: Store.photoURL(fileName: fileName).path)
    }

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

/// Avatar wrapped in a photo picker: tap to choose a picture, long-press to
/// remove it. Hands back downscaled JPEG data ready for `Store`.
struct AvatarPicker: View {
    let fileName: String?
    let name: String
    var size: CGFloat = 56
    let onChange: (Data?) -> Void

    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            AvatarView(fileName: fileName, name: name, size: size)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.2))
                        .foregroundStyle(.white)
                        .padding(size * 0.08)
                        .background(.tint, in: Circle())
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if fileName != nil {
                Button(role: .destructive) {
                    onChange(nil)
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        }
        .onChange(of: selection) {
            guard let item = selection else { return }
            selection = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let jpeg = Self.downscaledJPEG(from: data) else { return }
                onChange(jpeg)
            }
        }
    }

    /// Avatars render at ≤88 pt, so cap photos at 512 px and re-encode as
    /// JPEG rather than storing multi-megabyte originals.
    private static func downscaledJPEG(from data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
