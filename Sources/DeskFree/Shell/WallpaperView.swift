import SwiftUI

struct WallpaperView: View {
    let wallpaper: Wallpaper
    let revision: Int

    @State private var custom: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if wallpaper == .custom, let custom {
                    Image(uiImage: custom)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    BlobWallpaper(palette: wallpaper.palette)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: revision) {
            custom = DocumentsStore.customWallpaper()
        }
    }
}

/// A soft "mesh" look made of blurred colour blobs over a dark base.
private struct BlobWallpaper: View {
    let palette: [Color]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let d = max(w, h)
            ZStack {
                palette[0]
                Circle()
                    .fill(palette[1])
                    .frame(width: d * 0.65, height: d * 0.65)
                    .offset(x: -w * 0.28, y: -h * 0.22)
                Circle()
                    .fill(palette[2])
                    .frame(width: d * 0.55, height: d * 0.55)
                    .offset(x: w * 0.3, y: -h * 0.05)
                Circle()
                    .fill(palette[3])
                    .frame(width: d * 0.6, height: d * 0.6)
                    .offset(x: w * 0.05, y: h * 0.38)
            }
            .blur(radius: d * 0.09)
            .frame(width: w, height: h)
            .clipped()
            .drawingGroup()
        }
    }
}
