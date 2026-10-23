import SwiftUI

/// Phone UI used when the desktop is on a big screen (or in portrait): a small preview of
/// the desktop on top, a trackpad and quick actions below.
struct ControllerView: View {
    let session: DeskSession
    @ObservedObject var windows: WindowManager
    let size: CGSize
    let previewLive: Bool

    @State private var keyboardOn = false
    @State private var typed = KeyboardField.sentinel
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        let landscape = size.width > size.height
        Group {
            if landscape {
                HStack(spacing: 12) {
                    preview
                        .frame(width: size.width * 0.5)
                    VStack(spacing: 10) {
                        actions
                        keyboardRow
                        trackpad
                    }
                }
            } else {
                VStack(spacing: 10) {
                    preview
                        .aspectRatio(windows.desktopSize.width / windows.desktopSize.height, contentMode: .fit)
                    actions
                    keyboardRow
                    trackpad
                }
            }
        }
        .padding(12)
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(Color.black.opacity(0.35))
    }

    // MARK: Pieces

    private var preview: some View {
        ScaledDesktop(session: session, windows: windows, live: previewLive)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            actionButton("Search", symbol: "magnifyingglass") { session.toggleSpotlight() }
            actionButton("Keyboard", symbol: "keyboard", highlighted: keyboardOn) {
                keyboardOn.toggle()
                keyboardFocused = keyboardOn
            }
            actionButton("Desktop", symbol: "rectangle.on.rectangle") { windows.toggleShowDesktop() }
            actionButton("Touch", symbol: "hand.tap", highlighted: session.forceTouchDesktop) {
                session.forceTouchDesktop.toggle()
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(highlighted ? Color.accentColor : Color.white.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var keyboardRow: some View {
        if keyboardOn {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                TextField("Type here — text goes to the desktop", text: $typed)
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
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.14)))
        }
    }

    private var trackpad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
            VStack(spacing: 4) {
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 22))
                Text("Move · tap to click · hold then move to drag · two fingers to scroll")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .foregroundStyle(.white.opacity(0.4))
            .allowsHitTesting(false)

            TrackpadSurface(
                onMove: { session.pointerMove(by: $0) },
                onScroll: { session.pointerScroll(by: $0) },
                onTap: { session.pointerClick() },
                onDragBegan: { session.pointerDown() },
                onDragEnded: { session.pointerUp() }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
