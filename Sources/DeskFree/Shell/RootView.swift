import SwiftUI
import PhotosUI
import QuickLook

/// The phone scene. Shows the touch desktop in landscape, or the preview + trackpad
/// controller in portrait / when a big screen is connected.
struct RootView: View {
    @ObservedObject private var session = DeskSession.shared
    @ObservedObject private var windows = DeskSession.shared.windows
    @ObservedObject private var settings = DeskSession.shared.settings
    @ObservedObject private var presenter = DeskSession.shared.presenter

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let layout = session.phoneLayout(isLandscape: landscape)
            ZStack {
                switch layout {
                case .touchDesktop:
                    ScaledDesktop(session: session, windows: windows, live: session.liveHost == .phone, drawsWallpaper: false)
                case .controller:
                    ControllerView(
                        session: session,
                        windows: windows,
                        size: geo.size,
                        previewLive: session.liveHost == .phone
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                sync(geo.size)
                DemoMode.runIfRequested(session: session)
            }
            .onChange(of: geo.size) { sync(geo.size) }
            .onChange(of: layout) { sync(geo.size) }
            .onChange(of: settings.resolution) { sync(geo.size) }
        }
        .background(
            WallpaperView(wallpaper: settings.wallpaper, revision: settings.customWallpaperRevision)
                .ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard)
        .fileImporter(
            isPresented: $presenter.isImporting,
            allowedContentTypes: presenter.importTypes,
            allowsMultipleSelection: presenter.importMultiple
        ) { result in
            if case .success(let urls) = result {
                presenter.finishImport(urls)
            }
        }
        .photosPicker(
            isPresented: $presenter.isPickingPhoto,
            selection: $presenter.photoSelection,
            matching: presenter.photoFilter
        )
        .onChange(of: presenter.photoSelection) { _, item in
            if let item {
                presenter.finishPhoto(item)
                presenter.photoSelection = nil
            }
        }
        .quickLookPreview($presenter.quickLookURL)
        .sheet(item: $presenter.shareItem) { item in
            ShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
    }

    private func sync(_ size: CGSize) {
        let landscape = size.width > size.height
        session.updateDesktopSize(container: size, isLandscape: landscape)
        session.pointer.isVisible = session.phoneLayout(isLandscape: landscape) == .controller
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
