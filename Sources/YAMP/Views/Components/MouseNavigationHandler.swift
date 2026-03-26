import SwiftUI
import AppKit

/// Intercepts mouse back/forward buttons (buttons 3 & 4) for browser-style navigation.
struct MouseNavigationHandler: NSViewRepresentable {
    let onBack: () -> Void
    let onForward: () -> Void

    func makeNSView(context: Context) -> MouseButtonView {
        let view = MouseButtonView()
        view.onBack = onBack
        view.onForward = onForward
        return view
    }

    func updateNSView(_ nsView: MouseButtonView, context: Context) {
        nsView.onBack = onBack
        nsView.onForward = onForward
    }

    @MainActor
    class MouseButtonView: NSView {
        var onBack: (() -> Void)?
        var onForward: (() -> Void)?

        nonisolated(unsafe) private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
                    switch event.buttonNumber {
                    case 3:
                        DispatchQueue.main.async { self?.onBack?() }
                        return nil
                    case 4:
                        DispatchQueue.main.async { self?.onForward?() }
                        return nil
                    default:
                        return event
                    }
                }
            }
        }

        override func removeFromSuperview() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            super.removeFromSuperview()
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
