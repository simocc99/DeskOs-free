import SwiftUI
import Combine
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Input protocols

/// Tools that can react to the software pointer (clicks and scrolling).
protocol PointerInteractive: AnyObject {
    /// `point` is relative to the top-left corner of the window content area.
    func pointerClick(at point: CGPoint)
    func pointerScroll(by delta: CGPoint)
    /// Pinch on the trackpad; `scale` is the incremental factor (1.05 = 5 % bigger).
    func pointerZoom(by scale: CGFloat)
}

extension PointerInteractive {
    func pointerZoom(by scale: CGFloat) {}
}

/// Tools that add entries to the File and Edit menus of the menu bar.
protocol MenuContributing: AnyObject {
    func fileMenuEntries() -> [MenuEntry]
    func editMenuEntries() -> [MenuEntry]
}

extension MenuContributing {
    func fileMenuEntries() -> [MenuEntry] { [] }
    func editMenuEntries() -> [MenuEntry] { [] }
}

enum KeyInput {
    case text(String)
    case backspace
    case enter
}

/// Tools that accept typing from the phone keyboard while the desktop is on a big screen.
protocol KeyInputTarget: AnyObject {
    func handle(_ key: KeyInput)
}

// MARK: - Per-window model storage

/// Keeps tool state (open tabs, edited video...) alive across scene changes, e.g. when the
/// desktop moves from the phone to an external display.
final class ToolModelStore {
    private var models: [UUID: AnyObject] = [:]

    func model<T: AnyObject>(for id: UUID, make: () -> T) -> T {
        if let existing = models[id] as? T { return existing }
        let created = make()
        models[id] = created
        return created
    }

    func existing(for id: UUID) -> AnyObject? {
        models[id]
    }

    func retain(_ ids: Set<UUID>) {
        for key in models.keys where !ids.contains(key) {
            models[key] = nil
        }
    }
}

// MARK: - System UI requests (always presented by the phone)

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

/// System pickers and sheets can only be shown by the phone's own screen, so tools ask
/// this object and the root view presents them.
final class SystemPresenter: ObservableObject {
    @Published var isImporting = false
    @Published private(set) var importTypes: [UTType] = [.item]
    @Published private(set) var importMultiple = false
    private var importHandler: (([URL]) -> Void)?

    @Published var isPickingPhoto = false
    @Published private(set) var photoFilter: PHPickerFilter = .images
    @Published var photoSelection: PhotosPickerItem?
    private var photoHandler: ((PhotosPickerItem) -> Void)?

    @Published var quickLookURL: URL?
    @Published var shareItem: ShareItem?

    func importFiles(types: [UTType], multiple: Bool = false, completion: @escaping ([URL]) -> Void) {
        importTypes = types
        importMultiple = multiple
        importHandler = completion
        isImporting = true
    }

    func finishImport(_ urls: [URL]) {
        let handler = importHandler
        importHandler = nil
        if !urls.isEmpty { handler?(urls) }
    }

    func pickPhoto(filter: PHPickerFilter, completion: @escaping (PhotosPickerItem) -> Void) {
        photoFilter = filter
        photoHandler = completion
        photoSelection = nil
        isPickingPhoto = true
    }

    func finishPhoto(_ item: PhotosPickerItem?) {
        let handler = photoHandler
        photoHandler = nil
        if let item { handler?(item) }
    }

    func share(_ url: URL) {
        shareItem = ShareItem(url: url)
    }
}

// MARK: - Pointer

final class PointerModel: ObservableObject {
    @Published var position = CGPoint(x: 240, y: 200)
    @Published var isVisible = false
    @Published var isPressed = false
}

private enum PointerDrag {
    case none
    case pendingMove(id: UUID, origin: CGPoint)
    case move(id: UUID, start: CGRect, origin: CGPoint)
    case resize(id: UUID, anchor: ResizeAnchor, start: CGRect, origin: CGPoint)
}

// MARK: - Session

enum LiveHost {
    case phone, external
}

enum PhoneLayout {
    case touchDesktop, controller
}

/// Everything that is shared between the phone scene and the external-display scene.
final class DeskSession: ObservableObject {
    static let shared = DeskSession()

    let settings: DeskSettings
    let windows: WindowManager
    let pointer = PointerModel()
    let models = ToolModelStore()
    let presenter = SystemPresenter()

    @Published var spotlightVisible = false {
        didSet {
            if spotlightVisible {
                keyboardWanted = true
            } else if oldValue {
                keyboardWanted = false
            }
        }
    }
    @Published var spotlightQuery = ""
    @Published var spotlightSelection = 0
    @Published private(set) var spotlightFiles: [URL] = []
    @Published private(set) var externalConnected = false
    /// User chose to drive the desktop by touch on the phone even with a screen connected.
    @Published var forceTouchDesktop = false
    @Published var launchpadVisible = false
    @Published var switcherVisible = false
    /// Index of the menu-bar menu that is open.
    @Published var openMenu: Int?
    /// A tool clicked a text field: the controller should bring up the phone keyboard.
    @Published var keyboardWanted = false
    /// The controller shows the preview full height instead of the trackpad.
    @Published var previewExpanded = false

    private var cancellables = Set<AnyCancellable>()
    private var drag: PointerDrag = .none
    private var downTarget: HitTarget?
    private var dragTravel: CGFloat = 0

    init() {
        let settings = DeskSettings()
        self.settings = settings
        self.windows = WindowManager()
        windows.dockIconPreference = CGFloat(settings.dockIconSize)

        settings.$dockIconSize
            .dropFirst()
            .sink { [weak self] size in
                guard let self else { return }
                self.windows.dockIconPreference = CGFloat(size)
                self.windows.refit()
            }
            .store(in: &cancellables)

        windows.$windows
            .sink { [weak self] list in
                self?.models.retain(Set(list.map(\.id)))
            }
            .store(in: &cancellables)
    }

    // MARK: Layout

    var liveHost: LiveHost {
        externalConnected && !forceTouchDesktop ? .external : .phone
    }

    func phoneLayout(isLandscape: Bool) -> PhoneLayout {
        if liveHost == .external { return .controller }
        if forceTouchDesktop { return .touchDesktop }
        if isLandscape || !settings.trackpadInPortrait { return .touchDesktop }
        return .controller
    }

    func updateDesktopSize(container: CGSize, isLandscape: Bool) {
        switch phoneLayout(isLandscape: isLandscape) {
        case .touchDesktop:
            guard container.width > 100, container.height > 100 else { return }
            windows.setDesktopSize(CGSize(width: container.width.rounded(), height: container.height.rounded()))
        case .controller:
            windows.setDesktopSize(settings.resolution.size)
        }
    }

    func externalDisplayChanged(connected: Bool) {
        externalConnected = connected
        if !connected { forceTouchDesktop = false }
    }

    // MARK: Hit testing helpers

    func dockLayout() -> DockLayout {
        DockLayout(
            desktop: windows.desktopSize,
            preferredIconSize: CGFloat(settings.dockIconSize),
            minimized: windows.minimizedWindows.map(\.id)
        )
    }

    func hitTester() -> HitTester {
        HitTester(
            desktop: windows.desktopSize,
            windows: windows.windows,
            dock: dockLayout(),
            overlay: currentOverlay(),
            menu: menuLayout()
        )
    }

    func currentOverlay() -> DesktopOverlay {
        if launchpadVisible { return .launchpad }
        if switcherVisible { return .switcher(windows.windows.map(\.id)) }
        return .none
    }

    // MARK: Pointer

    func pointerMove(by delta: CGPoint) {
        let size = windows.desktopSize
        let speed = CGFloat(settings.pointerSpeed)
        let old = pointer.position
        let p = CGPoint(
            x: min(max(old.x + delta.x * speed, 0), size.width),
            y: min(max(old.y + delta.y * speed, 0), size.height)
        )
        pointer.position = p
        if pointer.isPressed {
            dragTravel += hypot(p.x - old.x, p.y - old.y)
            applyDrag()
        }
    }

    func pointerDown() {
        let p = pointer.position
        let target = hitTester().hit(p)
        downTarget = target
        dragTravel = 0
        pointer.isPressed = true
        drag = .none
        switch target {
        case .windowTitle(let id):
            windows.focus(id)
            drag = .pendingMove(id: id, origin: p)
        case .windowResize(let id, let anchor):
            windows.focus(id)
            if let window = windows.window(id) {
                drag = .resize(id: id, anchor: anchor, start: window.frame, origin: p)
            }
        case .windowContent(let id, _):
            windows.focus(id)
        default:
            break
        }
    }

    func pointerUp() {
        guard pointer.isPressed else { return }
        pointer.isPressed = false
        let target = downTarget
        let travelled = dragTravel
        drag = .none
        downTarget = nil
        dragTravel = 0
        if travelled <= 3, let target {
            performClick(target)
        }
    }

    func pointerClick() {
        pointerDown()
        pointerUp()
    }

    func pointerScroll(by delta: CGPoint) {
        if case .windowContent(let id, _) = hitTester().hit(pointer.position),
           let tool = models.existing(for: id) as? PointerInteractive {
            tool.pointerScroll(by: delta)
        }
    }

    func pointerZoom(by scale: CGFloat) {
        var targetID = windows.frontmostID
        if case .windowContent(let id, _) = hitTester().hit(pointer.position) { targetID = id }
        if let id = targetID, let tool = models.existing(for: id) as? PointerInteractive {
            tool.pointerZoom(by: scale)
        }
    }

    private func applyDrag() {
        let p = pointer.position
        guard dragTravel > 3 else { return }
        switch drag {
        case .pendingMove(let id, let origin):
            let start = windows.beginMove(id, grab: origin)
            drag = .move(id: id, start: start, origin: origin)
            windows.move(id, from: start, by: CGSize(width: p.x - origin.x, height: p.y - origin.y))
        case .move(let id, let start, let origin):
            windows.move(id, from: start, by: CGSize(width: p.x - origin.x, height: p.y - origin.y))
        case .resize(let id, let anchor, let start, let origin):
            windows.resize(id, anchor: anchor, from: start, by: CGSize(width: p.x - origin.x, height: p.y - origin.y))
        case .none:
            break
        }
    }

    private func performClick(_ target: HitTarget) {
        if spotlightVisible {
            switch target {
            case .menuSearch: break
            default: spotlightVisible = false
            }
        }
        switch target {
        case .windowClose(let id): windows.close(id)
        case .windowMinimize(let id): windows.minimize(id)
        case .windowMaximize(let id): windows.toggleMaximize(id)
        case .dock(.tool(let tool)): windows.activate(tool)
        case .dock(.minimized(let id)): windows.focus(id)
        case .dock(.launchpad): toggleLaunchpad()
        case .menuLogo: windows.activate(.settings)
        case .menuSearch: toggleSpotlight()
        case .menuTitle(let index): toggleMenu(index)
        case .menuRow(let menu, let row): runMenuEntry(menu: menu, row: row)
        case .menuDismiss: openMenu = nil
        case .launchpadApp(let tool): openApplication(tool)
        case .launchpadBackground: launchpadVisible = false
        case .switcherCard(let id):
            switcherVisible = false
            windows.focus(id)
        case .switcherBackground: switcherVisible = false
        case .desktopIcon(let icon): openDesktopIcon(icon)
        case .windowContent(let id, let point):
            if let tool = models.existing(for: id) as? PointerInteractive {
                tool.pointerClick(at: point)
            }
        default: break
        }
    }

    // MARK: Overlays, menus, shortcuts

    func toggleLaunchpad() {
        launchpadVisible.toggle()
        if launchpadVisible { closeTransientUI(except: .launchpad) }
    }

    func toggleSwitcher() {
        switcherVisible.toggle()
        if switcherVisible { closeTransientUI(except: .switcher) }
    }

    private enum Transient { case launchpad, switcher }

    private func closeTransientUI(except kept: Transient) {
        openMenu = nil
        spotlightVisible = false
        if kept != .launchpad { launchpadVisible = false }
        if kept != .switcher { switcherVisible = false }
    }

    func toggleMenu(_ index: Int) {
        openMenu = openMenu == index ? nil : index
    }

    /// Opens a new window for the tool, or brings its topmost window to the front.
    func openOrFocus(_ tool: ToolKind) {
        let existing = windows.windows(of: tool)
        if let top = existing.max(by: { $0.z < $1.z }) {
            windows.focus(top.id)
        } else {
            windows.open(tool)
        }
    }

    func openApplication(_ tool: ToolKind) {
        launchpadVisible = false
        openOrFocus(tool)
    }

    func openDesktopIcon(_ icon: DesktopIcon) {
        switch icon {
        case .documents: openOrFocus(.files)
        case .applications: toggleLaunchpad()
        }
    }

    func requestKeyboard() {
        keyboardWanted = true
    }

    func dismissKeyboard() {
        keyboardWanted = false
    }

    /// Focuses the browser address bar (opening a browser if needed).
    func focusBrowserAddress() {
        openOrFocus(.browser)
        if let id = windows.frontmostID, let browser = models.existing(for: id) as? BrowserModel {
            browser.addressDraft = ""
        }
        requestKeyboard()
    }

    func menuLayout() -> MenuLayout {
        MenuLayout(
            appName: windows.frontmost?.tool.title ?? "Desktop",
            menus: menus(),
            openIndex: openMenu,
            desktop: windows.desktopSize
        )
    }

    func runMenuEntry(menu: Int, row: Int) {
        let all = menus()
        guard all.indices.contains(menu), all[menu].entries.indices.contains(row) else { return }
        let entry = all[menu].entries[row]
        guard entry.enabled, !entry.isSeparator else { return }
        openMenu = nil
        entry.action()
    }

    func menus() -> [DesktopMenu] {
        let front = windows.frontmost
        let contributor = front.flatMap { models.existing(for: $0.id) } as? MenuContributing

        var file: [MenuEntry] = []
        let newTool = front?.tool ?? .files
        file.append(MenuEntry(title: "New \(newTool.title) Window", shortcut: "⌘N") { [weak self] in
            self?.windows.open(newTool)
        })
        let toolFile = contributor?.fileMenuEntries() ?? []
        if !toolFile.isEmpty {
            file.append(.separator)
            file += toolFile
        }
        file.append(.separator)
        file.append(MenuEntry(title: "Close Window", shortcut: "⌘W", enabled: front != nil) { [weak self] in
            if let id = self?.windows.frontmostID { self?.windows.close(id) }
        })
        file.append(MenuEntry(title: "Close All Windows", enabled: !windows.windows.isEmpty) { [weak self] in
            self?.windows.closeAll()
        })

        var edit = contributor?.editMenuEntries() ?? []
        if edit.isEmpty {
            edit = [MenuEntry(title: "Undo", shortcut: "⌘Z", enabled: false), MenuEntry(title: "Redo", shortcut: "⇧⌘Z", enabled: false)]
        }
        edit.append(.separator)
        edit.append(MenuEntry(title: "Spotlight Search…", shortcut: "⌘Space") { [weak self] in
            self?.spotlightVisible = true
        })

        var window: [MenuEntry] = []
        window.append(MenuEntry(title: "Minimize", shortcut: "⌘M", enabled: front != nil) { [weak self] in
            if let id = self?.windows.frontmostID { self?.windows.minimize(id) }
        })
        window.append(MenuEntry(title: "Zoom", enabled: front != nil) { [weak self] in
            if let id = self?.windows.frontmostID { self?.windows.toggleMaximize(id) }
        })
        window.append(MenuEntry(title: "Tile Window to Left", enabled: front != nil) { [weak self] in
            if let id = self?.windows.frontmostID { self?.windows.snap(id, to: .left) }
        })
        window.append(MenuEntry(title: "Tile Window to Right", enabled: front != nil) { [weak self] in
            if let id = self?.windows.frontmostID { self?.windows.snap(id, to: .right) }
        })
        window.append(.separator)
        window.append(MenuEntry(title: "Show Desktop", enabled: !windows.windows.isEmpty) { [weak self] in
            self?.windows.toggleShowDesktop()
        })
        window.append(MenuEntry(title: "All Windows") { [weak self] in
            self?.toggleSwitcher()
        })
        window.append(MenuEntry(title: "Launchpad") { [weak self] in
            self?.toggleLaunchpad()
        })
        if !windows.windows.isEmpty {
            window.append(.separator)
            for item in windows.windows {
                let mark = item.id == front?.id ? "✓ " : "   "
                let id = item.id
                window.append(MenuEntry(title: mark + item.title) { [weak self] in
                    self?.windows.focus(id)
                })
            }
        }

        let help: [MenuEntry] = [
            MenuEntry(title: "Welcome to DeskFree") { [weak self] in
                self?.openFile(DocumentsStore.ensureWelcomeFile())
            },
            MenuEntry(title: "DeskFree on GitHub") { [weak self] in
                if let url = URL(string: "https://github.com/simocc99/DeskOs-free") { self?.openURL(url) }
            }
        ]

        return [
            DesktopMenu(title: "File", entries: file),
            DesktopMenu(title: "Edit", entries: edit),
            DesktopMenu(title: "Window", entries: window),
            DesktopMenu(title: "Help", entries: help)
        ]
    }

    // MARK: Spotlight

    func toggleSpotlight() {
        spotlightVisible.toggle()
        if spotlightVisible {
            spotlightQuery = ""
            spotlightSelection = 0
            spotlightFiles = DocumentsStore.allFiles()
        }
    }

    func spotlightResults() -> [SpotlightResult] {
        SpotlightEngine.search(spotlightQuery, windows: windows.windows, files: spotlightFiles)
    }

    func launchSelectedSpotlightResult() {
        let results = spotlightResults()
        guard !results.isEmpty else { return }
        launch(results[min(spotlightSelection, results.count - 1)])
    }

    func launch(_ result: SpotlightResult) {
        spotlightVisible = false
        switch result.kind {
        case .tool(let tool): openOrFocus(tool)
        case .window(let id): windows.focus(id)
        case .file(let url): openFile(url)
        case .web(let query):
            if let url = BrowserAddress.searchURL(query) { openURL(url) }
        case .url(let url): openURL(url)
        case .math(let value): UIPasteboard.general.string = value
        }
    }

    // MARK: Opening things

    func openFile(_ url: URL) {
        switch url.pathExtension.lowercased() {
        case "pdf":
            windows.open(.preview, payload: url, title: url.lastPathComponent)
        case "png", "jpg", "jpeg", "heic", "gif", "tiff", "webp":
            windows.open(.preview, payload: url, title: url.lastPathComponent)
        case "mp4", "mov", "m4v":
            windows.open(.video, payload: url, title: url.lastPathComponent)
        case "txt", "md":
            NotesStore.shared.importTextFile(url)
            if windows.windows(of: .notes).isEmpty { windows.open(.notes) } else { windows.activate(.notes) }
        default:
            presenter.quickLookURL = url
        }
    }

    func openURL(_ url: URL) {
        let candidates = windows.windows(of: .browser).sorted { $0.z > $1.z }
        for window in candidates {
            if let browser = models.existing(for: window.id) as? BrowserModel {
                browser.openTab(url)
                windows.focus(window.id)
                return
            }
        }
        windows.open(.browser, payload: url)
    }

    // MARK: Keyboard

    func sendKey(_ key: KeyInput) {
        if spotlightVisible {
            switch key {
            case .text(let s):
                spotlightQuery += s
                spotlightSelection = 0
            case .backspace:
                if !spotlightQuery.isEmpty { spotlightQuery.removeLast() }
                spotlightSelection = 0
            case .enter:
                launchSelectedSpotlightResult()
            }
            return
        }
        guard let id = windows.frontmostID, let target = models.existing(for: id) as? KeyInputTarget else { return }
        target.handle(key)
    }
}
