import SwiftUI
import UIKit

/// A UIKit touch surface behaving like a laptop trackpad:
/// one finger moves the pointer, a tap clicks, press-and-hold then move drags,
/// two fingers scroll.
struct TrackpadSurface: UIViewRepresentable {
    var onMove: (CGPoint) -> Void
    var onScroll: (CGPoint) -> Void
    var onTap: () -> Void
    var onDragBegan: () -> Void
    var onDragEnded: () -> Void
    var onPinch: (CGFloat) -> Void = { _ in }
    var onThreeFingerSwipe: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let c = context.coordinator

        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1

        let scroll = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handleScroll(_:)))
        scroll.minimumNumberOfTouches = 2
        scroll.maximumNumberOfTouches = 2

        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleTap(_:)))

        let hold = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.handleHold(_:)))
        hold.minimumPressDuration = 0.35
        hold.allowableMovement = 10_000

        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.handlePinch(_:)))

        let swipe = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handleThreeFinger(_:)))
        swipe.minimumNumberOfTouches = 3
        swipe.maximumNumberOfTouches = 3

        scroll.delegate = c
        pinch.delegate = c
        c.scroll = scroll
        c.pinch = pinch

        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(swipe)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(scroll)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(hold)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TrackpadSurface
        weak var scroll: UIGestureRecognizer?
        weak var pinch: UIGestureRecognizer?
        private var lastHold: CGPoint?
        private let feedback = UIImpactFeedbackGenerator(style: .light)

        init(_ parent: TrackpadSurface) {
            self.parent = parent
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard g.state == .changed else { return }
            let t = g.translation(in: g.view)
            g.setTranslation(.zero, in: g.view)
            let v = g.velocity(in: g.view)
            let acceleration = 1 + min(hypot(v.x, v.y) / 1800, 1.2)
            parent.onMove(CGPoint(x: t.x * acceleration, y: t.y * acceleration))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // Two-finger scroll and pinch may happen together.
            (gestureRecognizer === scroll && other === pinch) || (gestureRecognizer === pinch && other === scroll)
        }

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard g.state == .changed else { return }
            parent.onPinch(g.scale)
            g.scale = 1
        }

        @objc func handleThreeFinger(_ g: UIPanGestureRecognizer) {
            guard g.state == .ended else { return }
            if g.translation(in: g.view).y < -40 {
                feedback.impactOccurred()
                parent.onThreeFingerSwipe()
            }
        }

        @objc func handleScroll(_ g: UIPanGestureRecognizer) {
            guard g.state == .changed else { return }
            let t = g.translation(in: g.view)
            g.setTranslation(.zero, in: g.view)
            parent.onScroll(t)
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended else { return }
            feedback.impactOccurred(intensity: 0.6)
            parent.onTap()
        }

        @objc func handleHold(_ g: UILongPressGestureRecognizer) {
            switch g.state {
            case .began:
                lastHold = g.location(in: g.view)
                feedback.impactOccurred()
                parent.onDragBegan()
            case .changed:
                guard let last = lastHold else { return }
                let p = g.location(in: g.view)
                parent.onMove(CGPoint(x: p.x - last.x, y: p.y - last.y))
                lastHold = p
            case .ended, .cancelled, .failed:
                if lastHold != nil {
                    lastHold = nil
                    parent.onDragEnded()
                }
            default:
                break
            }
        }
    }
}
