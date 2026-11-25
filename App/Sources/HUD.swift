import AppKit

@MainActor
enum HUD {
    private static var current: NSPanel?

    /// `screen` is the shot's screen. `NSScreen.main` follows keyboard focus, which on a second
    /// monitor is the wrong place entirely.
    static func flash(_ text: String, on screen: NSScreen? = nil, action: (() -> Void)? = nil) {
        current?.close()

        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let textWidth = ceil(textSize.width)
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 10
        let width = min(max(textWidth + horizontalPadding * 2, 180), 480)
        let height = ceil(textSize.height + verticalPadding * 2)

        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = action == nil
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false

        let background = HUDBackgroundView(frame: panel.contentView!.bounds)
        background.onClick = action
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        background.layer?.cornerRadius = 12
        background.autoresizingMask = [.width, .height]
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: horizontalPadding),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -horizontalPadding),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
        panel.contentView = background

        if let screen = screen ?? NSScreen.main {
            let origin = CGPoint(
                x: screen.frame.midX - panel.frame.width / 2,
                y: screen.frame.minY + 120
            )
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()
        current = panel

        Task { [weak panel] in
            // A clickable HUD needs long enough to actually be clicked.
            try? await Task.sleep(for: .seconds(action == nil ? 1.6 : 3.2))
            panel?.close()
            if current === panel { current = nil }
        }
    }
}

/// The HUD body. Clickable only when the flash was given somewhere to go, which today means
/// revealing the file that was just saved.
final class HUDBackgroundView: NSView {
    var onClick: (() -> Void)?

    override func resetCursorRects() {
        guard onClick != nil else { return }
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let onClick else { return }
        onClick()
        window?.close()
    }
}
