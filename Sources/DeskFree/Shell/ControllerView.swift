import SwiftUI

/// Phone UI used when the desktop is on a big screen (or in portrait): a live preview of
/// the desktop, a trackpad, and quick actions.
struct ControllerView: View {
    @ObservedObject var session: DeskSession
    @ObservedObject var windows: WindowManager
    let size: CGSize
    let previewLive: Bool

    @State private var typed = KeyboardField.sentinel
    @State private var showTips = false
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        let landscape = size.width > size.height
        VStack(spacing: 10) {
            header
            if landscape {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        titleBlock
                        preview
                    }
                    .frame(width: size.width * 0.48)
                    VStack(spacing: 10) {
                        if !session.previewExpanded { trackpad }
                        keyboardArea
                        buttons
                    }
                }
            } else {
                titleBlock
                preview
                    .aspectRatio(session.previewExpanded ? nil : windows.desktopSize.width / windows.desktopSize.height, contentMode: .fit)
                if !session.previewExpanded {
                    trackpad
                }
                keyboardArea
                buttons
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onChange(of: session.keyboardWanted) { _, wanted in
            keyboardFocused = wanted
        }
        .sheet(isPresented: $showTips) { tips }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 2) {
                Menu {
                    Picker("Resolution", selection: Binding(get: { session.settings.resolution }, set: { session.settings.resolution = $0 })) {
                        ForEach(DisplayResolution.allCases) { resolution in
                            Text(resolution.title).tag(resolution)
                        }
                    }
                    Button("Settings…") { session.openOrFocus(.settings) }
                } label: {
                    Image(systemName: "display")
                        .frame(width: 40, height: 34)
                }
                Button {
                    session.forceTouchDesktop.toggle()
                } label: {
                    Image(systemName: "hand.tap")
                        .frame(width: 40, height: 34)
                        .background(session.forceTouchDesktop ? Color.accentColor.opacity(0.25) : Color.clear, in: Capsule())
                }
            }
            .pill()

            Spacer()
            Text("DeskFree").font(.headline)
            Spacer()

            HStack(spacing: 2) {
                Button { showTips = true } label: {
                    Image(systemName: "questionmark.circle").frame(width: 40, height: 34)
                }
                Menu {
                    Button { session.toggleLaunchpad() } label: { Label("Launchpad", systemImage: "square.grid.3x3") }
                    Button { windows.toggleShowDesktop() } label: { Label("Show Desktop", systemImage: "rectangle.on.rectangle") }
                    Button { session.requestKeyboard() } label: { Label("Keyboard", systemImage: "keyboard") }
                    Button(role: .destructive) { windows.closeAll() } label: { Label("Close All Windows", systemImage: "xmark.circle") }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 40, height: 34)
                }
            }
            .pill()
        }
        .foregroundStyle(Color.primary)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(session.liveHost == .external ? "EXTERNAL DISPLAY" : "LIVE PREVIEW")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(windows.frontmost?.title ?? "Desktop")
                .font(.system(size: 21, weight: .bold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var preview: some View {
        ScaledDesktop(session: session, windows: windows, live: previewLive)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.black.opacity(0.4), lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    // MARK: Trackpad

    private var trackpad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.17))
            VStack {
                Text("TRACKPAD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 10)
                Spacer()
                Text("Tap to click · hold, then move to drag\nTwo fingers scroll · pinch zooms · three fingers up: windows")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 10)
            }
            .allowsHitTesting(false)

            TrackpadSurface(
                onMove: { session.pointerMove(by: $0) },
                onScroll: { session.pointerScroll(by: $0) },
                onTap: { session.pointerClick() },
                onDragBegan: { session.pointerDown() },
                onDragEnded: { session.pointerUp() },
                onPinch: { session.pointerZoom(by: $0) },
                onThreeFingerSwipe: { session.toggleSwitcher() }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Keyboard

    @ViewBuilder
    private var keyboardArea: some View {
        if session.keyboardWanted {
            HStack(spacing: 8) {
                Image(systemName: "keyboard").foregroundStyle(.secondary)
                TextField("Type — text goes to the desktop", text: $typed)
                    .focused($keyboardFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.return)
                    .onSubmit {
                        session.sendKey(.enter)
                        keyboardFocused = true
                    }
                    .onChange(of: typed) { old, new in
                        forward(from: old, to: new)
                    }
                Button {
                    session.dismissKeyboard()
                    keyboardFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .onAppear { keyboardFocused = true }
        } else {
            Text("Select a text field to show the keyboard")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            actionButton("Spotlight", symbol: "magnifyingglass") { session.toggleSpotlight() }
            actionButton("Address", symbol: "globe") { session.focusBrowserAddress() }
            actionButton("Windows", symbol: "rectangle.on.rectangle", highlighted: session.switcherVisible) { session.toggleSwitcher() }
            actionButton("Preview", symbol: "eye", highlighted: session.previewExpanded) { session.previewExpanded.toggle() }
        }
    }

    private func actionButton(_ title: String, symbol: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 22)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(highlighted ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(highlighted ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var tips: some View {
        NavigationStack {
            List {
                Section("Trackpad") {
                    Label("Move one finger to move the pointer", systemImage: "hand.point.up.left")
                    Label("Tap to click", systemImage: "hand.tap")
                    Label("Hold, then move to drag windows and files", systemImage: "hand.draw")
                    Label("Two fingers scroll, pinch zooms", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    Label("Three fingers up shows all windows", systemImage: "rectangle.on.rectangle")
                }
                Section("Desktop") {
                    Label("Spotlight searches apps, files and the web", systemImage: "magnifyingglass")
                    Label("Address focuses the browser address bar", systemImage: "globe")
                    Label("Touch drives the desktop with your fingers", systemImage: "hand.tap")
                    Label("Preview enlarges the live preview", systemImage: "eye")
                }
            }
            .navigationTitle("Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { showTips = false } }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Keyboard forwarding

    private func forward(from old: String, to new: String) {
        if new.isEmpty {
            session.sendKey(.backspace)
            typed = KeyboardField.sentinel
            return
        }
        if new.count > old.count, new.hasPrefix(old) {
            session.sendKey(.text(String(new.dropFirst(old.count))))
        } else if new.count < old.count, old.hasPrefix(new) {
            for _ in 0..<(old.count - new.count) {
                session.sendKey(.backspace)
            }
        } else if new != old {
            for _ in 0..<old.count { session.sendKey(.backspace) }
            session.sendKey(.text(new))
        }
    }
}

private enum KeyboardField {
    /// Zero-width space: lets us notice a backspace even when nothing visible was typed.
    static let sentinel = "\u{200B}"
}

private extension View {
    func pill() -> some View {
        self
            .font(.system(size: 17))
            .padding(.horizontal, 4)
            .background(Capsule().fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }
}
