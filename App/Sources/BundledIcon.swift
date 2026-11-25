import AppKit

/// Loads a vendored vector icon as a tintable template image, sized for a toolbar or the menu bar.
enum BundledIcon {
    static func image(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
