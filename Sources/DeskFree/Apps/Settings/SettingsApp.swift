import SwiftUI

struct SettingsWindowView: View {
    let window: DeskWindow
    @ObservedObject private var settings = DeskSession.shared.settings
    @ObservedObject private var windows = DeskSession.shared.windows

    var body: some View {
        Form {
            Section("Wallpaper") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                    ForEach(Wallpaper.allCases.filter { $0 != .custom }) { wallpaper in
                        wallpaperTile(wallpaper)
                    }
                    if DocumentsStore.customWallpaper() != nil {
                        wallpaperTile(.custom)
                    }
                }
                .padding(.vertical, 4)
                Button {
                    DeskSession.shared.presenter.pickPhoto(filter: .images) { item in
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                DocumentsStore.saveWallpaper(data)
                                await MainActor.run {
                                    settings.customWallpaperRevision += 1
                                    settings.wallpaper = .custom
                                }
                            }
                        }
                    }
                } label: {
                    Label("Choose Photo…", systemImage: "photo")
                }
            }

            Section("Dock") {
                HStack {
                    Image(systemName: "dock.rectangle").foregroundStyle(.secondary)
                    Slider(value: $settings.dockIconSize, in: 36...76, step: 2)
                    Text("\(Int(settings.dockIconSize)) pt")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }

            Section("Big screen") {
                Picker("Resolution", selection: $settings.resolution) {
                    ForEach(DisplayResolution.allCases) { resolution in
                        Text(resolution.title).tag(resolution)
                    }
                }
                HStack {
                    Image(systemName: "cursorarrow.motionlines").foregroundStyle(.secondary)
                    Slider(value: $settings.pointerSpeed, in: 1...4, step: 0.25)
                    Text(String(format: "%.1f×", settings.pointerSpeed))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                Toggle("Trackpad layout in portrait", isOn: $settings.trackpadInPortrait)
            }

            Section("Desktop") {
                Button("Close all windows", role: .destructive) {
                    windows.closeAll()
                }
            }

            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                Text("DeskFree is free and open source (MIT). It is an independent project, not affiliated with any commercial app.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func wallpaperTile(_ wallpaper: Wallpaper) -> some View {
        Button {
            settings.wallpaper = wallpaper
        } label: {
            VStack(spacing: 4) {
                WallpaperView(wallpaper: wallpaper, revision: settings.customWallpaperRevision)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(settings.wallpaper == wallpaper ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                Text(wallpaper.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
