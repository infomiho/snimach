import AppKit
import SnimachCore

enum EditorOutcome {
    case copy(CGImage)
    case saveAndCopy(CGImage)
    case discard
}

@MainActor
protocol EditorController: AnyObject {
    var document: Document { get set }
    var onFinish: ((EditorOutcome) -> Void)? { get set }
    func show()
    func close()
}

extension NSToolbarItem.Identifier {
    static let output = NSToolbarItem.Identifier("output")
    static let save = NSToolbarItem.Identifier("save")
    static let copy = NSToolbarItem.Identifier("copy")
}

@MainActor
final class EditorWindowController: NSObject, EditorController {
    var onFinish: ((EditorOutcome) -> Void)?
    let panel: EditorPanel
    let canvas: CanvasView
    let accessoryBar = EditorAccessoryBar(frame: .zero)
    let readout = ColorReadoutView(frame: .zero)
    let backdropPicker = BackdropPickerView()
    let backdropPopover = NSPopover()
    private(set) var currentHex: String?
    private let stage: EditorStageView

    var document: Document {
        get { canvas.document }
        set {
            canvas.document = newValue
            refreshChrome()
            stage.needsLayout = true
        }
    }

    init(document: Document) {
        let layout = EditorLayout.make(contentSize: document.stageSize)
        panel = EditorPanel(contentRect: CGRect(origin: .zero, size: layout.contentSize),
                            styleMask: EditorLayout.style, backing: .buffered, defer: false)
        canvas = CanvasView(document: document)
        stage = EditorStageView(canvas: canvas, accessoryBar: accessoryBar, readout: readout)
        super.init()
        panel.title = "Snimach"
        panel.toolbarStyle = .unified
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .windowBackgroundColor
        panel.delegate = self
        panel.canvas = canvas
        canvas.wantsLayer = true
        canvas.layer?.cornerRadius = Brand.cardRadius
        canvas.layer?.borderWidth = 1
        canvas.layer?.borderColor = NSColor.separatorColor.cgColor
        canvas.layer?.masksToBounds = true
        stage.frame = CGRect(origin: .zero, size: layout.contentSize)
        panel.contentView = stage
        readout.isHidden = true

        let toolbar = NSToolbar(identifier: "SnimachEditor")
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.delegate = self
        panel.toolbar = toolbar
        panel.contentMinSize = EditorLayout.minimumContentSize
        fitToScreen()
        panel.setFrame(EditorLayout.clampedFrame(panel.frame, near: document.shot.frame), display: false)

        let pickerController = NSViewController()
        pickerController.view = backdropPicker
        backdropPopover.contentViewController = pickerController
        backdropPopover.contentSize = BackdropPickerView.size
        backdropPopover.behavior = .transient
        backdropPopover.delegate = self
        backdropPicker.onToggle = { [weak self] in self?.toggleBackdrop() }
        backdropPicker.onSelect = { [weak self] id in self?.selectPreset(id) }
        accessoryBar.onTool = { [weak self] tool in
            self?.dismissPresets()
            self?.canvas.apply(.toolSelected(tool))
            self?.focusCanvas()
        }
        accessoryBar.undoButton.onPress = { [weak self] in self?.canvas.apply(.undo) }
        accessoryBar.redoButton.onPress = { [weak self] in self?.canvas.apply(.redo) }
        accessoryBar.backdropButton.onPress = { [weak self] in self?.toggleBackdrop() }
        accessoryBar.presetsButton.onPress = { [weak self] in self?.togglePresets() }
        accessoryBar.pickerButton.onPress = { [weak self] in self?.togglePicker() }
        readout.onCopy = { [weak self] in self?.copyCurrentHex() }
        canvas.onTerminalKey = { [weak self] key in self?.handle(key) }
        canvas.onChange = { [weak self] in self?.refreshChrome() }
        canvas.onStageChange = { [weak self] previous in self?.stage.transition(from: previous) }
        canvas.onColorHover = { [weak self] hover in self?.showHover(hover) }
        sampleCenter()
        refreshChrome()
        stage.needsLayout = true
        stage.layoutSubtreeIfNeeded()
    }

    private func fitToScreen() {
        guard let visible = NSScreen.nearest(document.shot.frame)?.visibleFrame else { return }
        let content = panel.contentRect(forFrameRect: panel.frame)
        let chromeHeight = panel.frame.height - content.height
        let maximum = CGSize(width: visible.width, height: visible.height - chromeHeight)
        let layout = EditorLayout.make(contentSize: document.stageSize, maxContent: maximum)
        panel.setContentSize(layout.contentSize)
        panel.titleVisibility = layout.contentSize.width < 520 ? .hidden : .visible
    }

    func show() {
        panel.animationBehavior = .none
        panel.makeKeyAndOrderFront(nil)
        focusCanvas()
    }

    func close() {
        backdropPopover.close()
        panel.orderOut(nil)
        panel.close()
    }

    private func focusCanvas() { panel.makeFirstResponder(canvas) }

    private func refreshChrome() {
        accessoryBar.update(document: document, picking: canvas.isPickingColor)
        readout.isHidden = !canvas.isPickingColor
        backdropPicker.update(preset: document.backdropPreset, active: document.backdrop == .solid)
        stage.needsLayout = true
    }

    private func sampleCenter() {
        let point = CGPoint(x: document.pointSize.width / 2, y: document.pointSize.height / 2)
        canvas.sampleColor(at: point)
    }

    private func showHover(_ hover: CanvasView.HoverColor) {
        currentHex = hover.hex
        readout.update(hex: hover.hex, color: hover.color, selected: canvas.isColorFrozen)
    }

    func selectPreset(_ id: BackdropPresetID) {
        canvas.apply(.backdropPresetSelected(BackdropPreset.preset(id)))
        canvas.apply(.backdropSelected(.solid))
        dismissPresets()
        focusCanvas()
    }

    private func toggleBackdrop() {
        dismissPresets()
        canvas.apply(.backdropSelected(document.backdrop.next))
        focusCanvas()
    }

    private func togglePicker() {
        dismissPresets()
        canvas.isPickingColor.toggle()
        if canvas.isPickingColor { sampleCenter() }
        refreshChrome()
        stage.layoutSubtreeIfNeeded()
        focusCanvas()
    }

    private func togglePresets() {
        if backdropPopover.isShown {
            dismissPresets()
            return
        }
        canvas.isPickingColor = false
        refreshChrome()
        backdropPopover.animates = !EditorStyle.reducesMotion
        backdropPopover.show(relativeTo: accessoryBar.presetsButton.bounds,
                             of: accessoryBar.presetsButton, preferredEdge: .maxY)
        accessoryBar.presetsButton.state = .on
        if let selection = backdropPicker.selection,
           let index = backdropPicker.presets.firstIndex(where: { $0.id == selection }) {
            backdropPicker.window?.makeFirstResponder(backdropPicker.buttons[index])
        } else {
            backdropPicker.window?.makeFirstResponder(backdropPicker)
        }
    }

    private func dismissPresets() {
        backdropPopover.close()
        accessoryBar.presetsButton.state = .off
    }

    @objc private func saveShot() { handle(.save) }
    @objc private func copyShot() { handle(.commit) }

    private func handle(_ key: EditorKey) {
        switch key {
        case .commit:
            guard let image = render() else { return }
            finish(.copy(image))
        case .save:
            guard let image = render() else { return }
            finish(.saveAndCopy(image))
        case .discard:
            if backdropPopover.isShown {
                dismissPresets()
            } else if canvas.isPickingColor {
                canvas.isPickingColor = false
                refreshChrome()
            } else {
                finish(.discard)
            }
        case .copyHex:
            if canvas.isPickingColor { copyCurrentHex() }
        case .togglePicker:
            togglePicker()
        default:
            break
        }
    }

    private func copyCurrentHex() {
        guard canvas.isPickingColor, let hex = currentHex else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(hex, forType: .string) { readout.flash("Copied") }
        focusCanvas()
    }

    private func render() -> CGImage? {
        do {
            return try document.render()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t export the screenshot"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return nil
        }
    }

    private func finish(_ outcome: EditorOutcome) {
        let callback = onFinish
        onFinish = nil
        close()
        callback?(outcome)
    }
}

extension EditorWindowController: NSWindowDelegate, NSPopoverDelegate {
    func windowDidResize(_ notification: Notification) {
        panel.titleVisibility = stage.bounds.width < 520 ? .hidden : .visible
        dismissPresets()
        stage.needsLayout = true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard onFinish != nil else { return true }
        finish(.discard)
        return false
    }

    func popoverDidClose(_ notification: Notification) {
        accessoryBar.presetsButton.state = .off
        focusCanvas()
    }
}

extension EditorWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .output]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch id {
        case .output:
            let group = NSToolbarItemGroup(itemIdentifier: id)
            group.label = "Output"
            group.controlRepresentation = .expanded
            group.subitems = [
                buttonItem(.save, icon: "diskette-linear", label: "Save", tip: "Save and copy (⌘S)", action: #selector(saveShot)),
                buttonItem(.copy, icon: "copy-linear", label: "Copy", tip: "Copy (⌘C)", action: #selector(copyShot)),
            ]
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 0
            for item in group.subitems {
                let button = EditorButton(label: item.label)
                button.image = item.image
                button.toolTip = item.toolTip
                button.target = item.target
                button.action = item.action
                button.translatesAutoresizingMaskIntoConstraints = false
                button.widthAnchor.constraint(equalToConstant: 34).isActive = true
                button.heightAnchor.constraint(equalToConstant: 30).isActive = true
                row.addArrangedSubview(button)
            }
            let width = CGFloat(group.subitems.count) * 34
            row.frame = CGRect(origin: .zero, size: CGSize(width: width, height: 30))
            group.view = row
            row.widthAnchor.constraint(equalToConstant: width).isActive = true
            row.heightAnchor.constraint(equalToConstant: 30).isActive = true
            group.visibilityPriority = .high
            return group
        case .save:
            return buttonItem(id, icon: "diskette-linear", label: "Save", tip: "Save and copy (⌘S)", action: #selector(saveShot))
        case .copy:
            return buttonItem(id, icon: "copy-linear", label: "Copy", tip: "Copy (⌘C)", action: #selector(copyShot))
        default:
            return nil
        }
    }

    private func buttonItem(_ id: NSToolbarItem.Identifier, icon: String, label: String,
                            tip: String, action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.toolTip = tip
        item.image = BundledIcon.image(icon)
        item.target = self
        item.action = action
        return item
    }
}

final class EditorPanel: NSPanel {
    weak var canvas: CanvasView?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let canvas {
            if canvas.handle(event) { return }
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
