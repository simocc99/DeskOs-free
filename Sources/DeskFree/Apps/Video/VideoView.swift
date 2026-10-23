import SwiftUI
import AVFoundation

struct VideoWindowView: View {
    let window: DeskWindow
    @ObservedObject private var model: VideoModel

    init(window: DeskWindow) {
        self.window = window
        let id = window.id
        let payload = window.payload
        _model = ObservedObject(wrappedValue: DeskSession.shared.models.model(for: id) {
            let created = VideoModel(windowID: id)
            if let payload { created.load(url: payload) }
            return created
        })
    }

    var body: some View {
        if model.asset == nil {
            emptyState
        } else {
            editor
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Open a video to trim, speed up, filter and export it")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("From Files…") { model.pickFromFiles() }
                    .buttonStyle(.borderedProminent)
                Button("From Photos…") { model.pickFromPhotos() }
                    .buttonStyle(.bordered)
            }
            if let message = model.message {
                Text(message).font(.system(size: 12)).foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editor: some View {
        VStack(spacing: 0) {
            PlayerSurface(player: model.player)
                .background(Color.black)
                .frame(maxHeight: .infinity)

            VStack(spacing: 8) {
                VideoTimeline(model: model)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                controls
                    .padding(.horizontal, 10)

                statusLine
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }

    private var controls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    model.togglePlay()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .frame(width: 36, height: 32)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Text("\(Self.format(model.currentTime)) / \(Self.format(model.duration))")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)

                Picker("Speed", selection: $model.speed) {
                    Text("0.5×").tag(0.5)
                    Text("1×").tag(1.0)
                    Text("1.5×").tag(1.5)
                    Text("2×").tag(2.0)
                }
                .pickerStyle(.menu)

                Picker("Filter", selection: $model.filter) {
                    ForEach(VideoFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    model.isMuted.toggle()
                } label: {
                    Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                Picker("Quality", selection: $model.quality) {
                    ForEach(ExportQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                .pickerStyle(.menu)

                if let progress = model.exportProgress {
                    ProgressView(value: progress)
                        .frame(width: 90)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12).monospacedDigit())
                } else {
                    Button {
                        model.export()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Menu {
                    Button("Open from Files…") { model.pickFromFiles() }
                    Button("Open from Photos…") { model.pickFromPhotos() }
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 8) {
            Text("Clip \(Self.format(model.clipDuration))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let message = model.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(message.hasPrefix("Saved") ? Color.green : Color.red)
                    .lineLimit(1)
            }
            Spacer()
            if model.lastExport != nil {
                Button("Share") { model.shareExport() }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
            }
        }
    }

    static func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00.0" }
        let total = max(0, seconds)
        let minutes = Int(total) / 60
        let rest = total - Double(minutes * 60)
        return String(format: "%ld:%04.1f", minutes, rest)
    }
}

// MARK: - Timeline with trim handles

private struct VideoTimeline: View {
    @ObservedObject var model: VideoModel

    private let height: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let duration = max(model.duration, 0.01)
            let startX = CGFloat(model.trimStart / duration) * width
            let endX = CGFloat(model.trimEnd / duration) * width
            let playX = CGFloat(model.currentTime / duration) * width

            ZStack(alignment: .topLeading) {
                thumbnailStrip(width: width)

                Color.black.opacity(0.6)
                    .frame(width: max(startX, 0), height: height)
                Color.black.opacity(0.6)
                    .frame(width: max(width - endX, 0), height: height)
                    .offset(x: endX)

                Rectangle()
                    .strokeBorder(Color.yellow, lineWidth: 2)
                    .frame(width: max(endX - startX, 0), height: height)
                    .offset(x: startX)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: height + 8)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .offset(x: playX - 1, y: -4)
                    .allowsHitTesting(false)

                handle(isStart: true)
                    .offset(x: startX - 14)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                            .onChanged { value in
                                model.setTrimStart(Double(value.location.x / width) * duration)
                            }
                    )
                handle(isStart: false)
                    .offset(x: endX)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                            .onChanged { value in
                                model.setTrimEnd(Double(value.location.x / width) * duration)
                            }
                    )
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .coordinateSpace(name: "timeline")
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                    .onChanged { value in
                        model.seek(to: Double(value.location.x / width) * duration)
                    }
            )
        }
        .frame(height: height + 8)
    }

    private func thumbnailStrip(width: CGFloat) -> some View {
        let count = max(model.thumbnails.count, 1)
        return HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                Group {
                    if index < model.thumbnails.count, let image = model.thumbnails[index] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.35)
                    }
                }
                .frame(width: width / CGFloat(count), height: height)
                .clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .allowsHitTesting(false)
    }

    private func handle(isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.yellow)
            .frame(width: 14, height: height)
            .overlay(
                Image(systemName: isStart ? "chevron.compact.left" : "chevron.compact.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.7))
            )
    }
}

// MARK: - Player

private final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // layerClass guarantees the type.
        layer as! AVPlayerLayer
    }
}

private struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
