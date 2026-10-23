import SwiftUI
import AVFoundation
import CoreImage
import PhotosUI
import UniformTypeIdentifiers

enum VideoFilter: String, CaseIterable, Identifiable {
    case none, mono, noir, sepia, vivid, chrome, fade

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Original"
        case .mono: return "Mono"
        case .noir: return "Noir"
        case .sepia: return "Sepia"
        case .vivid: return "Vivid"
        case .chrome: return "Chrome"
        case .fade: return "Fade"
        }
    }

    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .none: return image
        case .mono: return image.applyingFilter("CIPhotoEffectMono")
        case .noir: return image.applyingFilter("CIPhotoEffectNoir")
        case .sepia: return image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.9])
        case .vivid: return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.5, kCIInputContrastKey: 1.1])
        case .chrome: return image.applyingFilter("CIPhotoEffectChrome")
        case .fade: return image.applyingFilter("CIPhotoEffectFade")
        }
    }
}

enum ExportQuality: String, CaseIterable, Identifiable {
    case hd720, fullHD, best

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hd720: return "720p"
        case .fullHD: return "1080p"
        case .best: return "Best"
        }
    }

    var preset: String {
        switch self {
        case .hd720: return AVAssetExportPreset1280x720
        case .fullHD: return AVAssetExportPreset1920x1080
        case .best: return AVAssetExportPresetHighestQuality
        }
    }
}

/// Lets the Photos picker hand us a video as a file we own.
struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let destination = DocumentsStore.uniqueURL(in: DocumentsStore.root, name: received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return MovieFile(url: destination)
        }
    }
}

final class VideoModel: ObservableObject, KeyInputTarget {
    let windowID: UUID
    let player = AVPlayer()

    @Published private(set) var asset: AVAsset?
    @Published private(set) var sourceURL: URL?
    @Published private(set) var duration: Double = 0
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 0
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var thumbnails: [UIImage?] = []
    @Published private(set) var exportProgress: Double?
    @Published var message: String?
    @Published private(set) var lastExport: URL?

    @Published var speed: Double = 1 {
        didSet { if isPlaying { player.rate = Float(speed) } }
    }
    @Published var isMuted = false {
        didSet { player.isMuted = isMuted }
    }
    @Published var filter: VideoFilter = .none {
        didSet { refreshPreviewComposition() }
    }
    @Published var quality: ExportQuality = .fullHD

    private var timeObserver: Any?
    private var thumbnailGenerator: AVAssetImageGenerator?

    init(windowID: UUID) {
        self.windowID = windowID
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.tick(time.seconds)
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    var clipDuration: Double { max(0, trimEnd - trimStart) / max(speed, 0.01) }

    // MARK: Loading

    func load(url: URL) {
        Task { @MainActor in
            await self.loadAsync(url)
        }
    }

    func pickFromFiles() {
        DeskSession.shared.presenter.importFiles(types: [.movie]) { [weak self] urls in
            guard let url = urls.first, let local = try? DocumentsStore.importCopy(of: url) else { return }
            self?.load(url: local)
        }
    }

    func pickFromPhotos() {
        DeskSession.shared.presenter.pickPhoto(filter: .videos) { [weak self] item in
            Task { @MainActor in
                if let movie = try? await item.loadTransferable(type: MovieFile.self) {
                    self?.load(url: movie.url)
                } else {
                    self?.message = "Couldn't load that video."
                }
            }
        }
    }

    @MainActor
    private func loadAsync(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            let length = try await asset.load(.duration).seconds
            guard length.isFinite, length > 0 else {
                message = "This video has no duration."
                return
            }
            pause()
            self.asset = asset
            sourceURL = url
            duration = length
            trimStart = 0
            trimEnd = length
            currentTime = 0
            lastExport = nil
            message = nil
            player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            player.isMuted = isMuted
            refreshPreviewComposition()
            generateThumbnails(for: asset, duration: length)
            DeskSession.shared.windows.setTitle(windowID, url.lastPathComponent)
        } catch {
            message = "Couldn't open this video: \(error.localizedDescription)"
        }
    }

    private func generateThumbnails(for asset: AVAsset, duration: Double) {
        let count = 12
        thumbnails = Array(repeating: nil, count: count)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 135)
        let times = (0..<count).map {
            NSValue(time: CMTime(seconds: duration * (Double($0) + 0.5) / Double(count), preferredTimescale: 600))
        }
        generator.generateCGImagesAsynchronously(forTimes: times) { [weak self] requested, image, _, _, _ in
            guard let image else { return }
            let index = min(count - 1, max(0, Int(requested.seconds / duration * Double(count))))
            DispatchQueue.main.async {
                guard let self, index < self.thumbnails.count else { return }
                self.thumbnails[index] = UIImage(cgImage: image)
            }
        }
        thumbnailGenerator = generator
    }

    // MARK: Playback

    private func tick(_ seconds: Double) {
        guard seconds.isFinite else { return }
        currentTime = seconds
        if isPlaying, seconds >= trimEnd - 0.03 {
            pause()
            currentTime = trimEnd
        }
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard asset != nil else { return }
        if currentTime >= trimEnd - 0.05 || currentTime < trimStart - 0.01 {
            seek(to: trimStart)
        }
        isPlaying = true
        player.playImmediately(atRate: Float(speed))
    }

    func pause() {
        isPlaying = false
        player.pause()
    }

    func seek(to seconds: Double) {
        let clamped = min(max(seconds, 0), duration)
        currentTime = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func setTrimStart(_ value: Double) {
        trimStart = min(max(0, value), trimEnd - 0.2)
        seek(to: trimStart)
    }

    func setTrimEnd(_ value: Double) {
        trimEnd = max(min(duration, value), trimStart + 0.2)
        seek(to: trimEnd)
    }

    // MARK: Filters

    private func refreshPreviewComposition() {
        guard let item = player.currentItem else { return }
        item.videoComposition = Self.makeVideoComposition(for: item.asset, filter: filter)
    }

    static func makeVideoComposition(for asset: AVAsset, filter: VideoFilter) -> AVVideoComposition? {
        guard filter != .none else { return nil }
        return AVMutableVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            let source = request.sourceImage.clampedToExtent()
            let output = filter.apply(to: source).cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: nil)
        })
    }

    // MARK: Export

    func export() {
        Task { @MainActor in
            await self.exportAsync()
        }
    }

    @MainActor
    private func exportAsync() async {
        guard let asset, exportProgress == nil else { return }
        pause()
        exportProgress = 0
        message = nil
        defer { exportProgress = nil }

        do {
            let timescale: CMTimeScale = 600
            let range = CMTimeRange(
                start: CMTime(seconds: trimStart, preferredTimescale: timescale),
                end: CMTime(seconds: trimEnd, preferredTimescale: timescale)
            )

            let composition = AVMutableComposition()
            guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first,
                  let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                message = "This file has no video track."
                return
            }
            try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
            videoTrack.preferredTransform = try await sourceVideo.load(.preferredTransform)

            if !isMuted,
               let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first,
               let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
            }

            if abs(speed - 1) > 0.001 {
                let scaled = CMTimeMultiplyByFloat64(range.duration, multiplier: 1 / speed)
                composition.scaleTimeRange(CMTimeRange(start: .zero, duration: range.duration), toDuration: scaled)
            }

            guard let session = AVAssetExportSession(asset: composition, presetName: quality.preset) else {
                message = "Export isn't available for this video."
                return
            }
            let baseName = (sourceURL?.deletingPathExtension().lastPathComponent ?? "Video") + " edited"
            let output = DocumentsStore.uniqueURL(in: DocumentsStore.exportsDirectory, name: baseName + ".mp4")
            session.outputURL = output
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true
            if filter != .none {
                session.videoComposition = Self.makeVideoComposition(for: composition, filter: filter)
            }

            let progressTask = Task { @MainActor in
                while !Task.isCancelled {
                    self.exportProgress = Double(session.progress)
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                session.exportAsynchronously {
                    continuation.resume()
                }
            }
            progressTask.cancel()

            if session.status == .completed {
                lastExport = output
                message = "Saved to Documents/Exports as \(output.lastPathComponent)"
            } else {
                message = "Export failed: \(session.error?.localizedDescription ?? "unknown error")"
            }
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    func shareExport() {
        guard let lastExport else { return }
        DeskSession.shared.presenter.share(lastExport)
    }

    // MARK: KeyInputTarget

    func handle(_ key: KeyInput) {
        if case .text(let s) = key, s == " " { togglePlay() }
        if case .enter = key { togglePlay() }
    }
}
