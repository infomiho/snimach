import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ShotOutputError: Error, Equatable {
    case encodingFailed
    case folderUnavailable(URL, underlying: Error)
    case writeFailed(URL, underlying: Error)

    public static func == (lhs: ShotOutputError, rhs: ShotOutputError) -> Bool {
        switch (lhs, rhs) {
        case (.encodingFailed, .encodingFailed):
            return true
        case let (.folderUnavailable(l, _), .folderUnavailable(r, _)):
            return l == r
        case let (.writeFailed(l, _), .writeFailed(r, _)):
            return l == r
        default:
            return false
        }
    }
}

/// Delivers a flattened shot to the pasteboard or to disk. Configuration is the whole seam:
/// pass a different folder, pasteboard or clock and the module behaves identically.
///
/// Thread: main thread. Both methods are synchronous and return only when the side effect is
/// complete, so the caller may close the editor immediately afterwards.
public final class ShotOutput {
    /// `~/Pictures/Snimach`. ~/Pictures is not TCC-protected, so writing never prompts.
    public static let defaultFolder: URL = {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("Snimach")
    }()

    /// Read on every save, because the user can change the folder while the app runs.
    private let folder: () -> URL
    private let pasteboard: NSPasteboard
    private let now: () -> Date
    private weak var cachedImage: CGImage?
    private var cachedScale: CGFloat = 0
    private var cachedPNG: Data?

    public init(folder: @escaping () -> URL = { defaultFolder },
                pasteboard: NSPasteboard = .general,
                now: @escaping () -> Date = Date.init) {
        self.folder = folder
        self.pasteboard = pasteboard
        self.now = now
    }

    /// Replaces the pasteboard contents with the shot. Previous contents are gone even on failure.
    /// The PNG is written at once. The TIFF, for readers that skip PNG, costs about twice as
    /// much to encode, so it is promised and encoded on the first read. The pasteboard keeps the
    /// promise alive until then.
    public func copy(_ image: CGImage, scale: CGFloat) throws {
        pasteboard.clearContents()

        let png = try encodePNG(image, scale: scale)
        let promise = TIFFPromise(image: image, scale: scale)

        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setDataProvider(promise, forTypes: [.tiff])
        pasteboard.writeObjects([item])
    }

    /// Writes the shot as PNG and returns the file written. Never overwrites.
    @discardableResult
    public func save(_ image: CGImage, scale: CGFloat) throws -> URL {
        let data = try encodePNG(image, scale: scale)
        let folder = folder()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw ShotOutputError.folderUnavailable(folder, underlying: error)
        }

        let base = Self.filenameBase(now())
        var lastURL = folder
        for attempt in 0..<100 {
            let url = folder.appendingPathComponent(Self.filename(base: base, attempt: attempt))
            lastURL = url
            do {
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch CocoaError.fileWriteFileExists {
                continue
            } catch {
                throw ShotOutputError.writeFailed(url, underlying: error)
            }
        }
        let collision = NSError(
            domain: "dev.twoducks.snimach",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "More than 99 files share this timestamp."]
        )
        throw ShotOutputError.writeFailed(lastURL, underlying: collision)
    }

    /// Writes the shot to a temporary PNG so it can be dragged out as a real file. The name is
    /// what the receiving app shows, so it matches the save folder's naming.
    public func temporaryPNG(_ image: CGImage, scale: CGFloat) throws -> URL {
        let data = try encodePNG(image, scale: scale)
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Snimach-drag-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(Self.filename(base: Self.filenameBase(now()), attempt: 0))
        try data.write(to: url)
        return url
    }

    /// The capture path's drag. A Shot carries its own scale.
    public func temporaryPNG(_ shot: Shot) throws -> URL {
        try temporaryPNG(shot.image, scale: shot.scale)
    }

    private func encodePNG(_ image: CGImage, scale: CGFloat) throws -> Data {
        if let data = cachedPNG, cachedImage === image, cachedScale == scale {
            return data
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ShotOutputError.encodingFailed
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: 72 * scale,
            kCGImagePropertyDPIHeight: 72 * scale,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ShotOutputError.encodingFailed
        }

        let result = data as Data
        cachedImage = image
        cachedScale = scale
        cachedPNG = result
        return result
    }


    private static func filenameBase(_ date: Date) -> String {
        "Snimach \(filenameDateFormatter.string(from: date))"
    }

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()

    private static func filename(base: String, attempt: Int) -> String {
        attempt == 0 ? "\(base).png" : "\(base) (\(attempt + 1)).png"
    }
}

private final class TIFFPromise: NSObject, NSPasteboardItemDataProvider {
    private let image: CGImage
    private let scale: CGFloat

    init(image: CGImage, scale: CGFloat) {
        self.image = image
        self.scale = scale
    }

    func pasteboard(_ pasteboard: NSPasteboard?,
                    item: NSPasteboardItem,
                    provideDataForType type: NSPasteboard.PasteboardType) {
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = NSSize(
            width: CGFloat(image.width) / scale,
            height: CGFloat(image.height) / scale
        )
        guard let tiff = rep.tiffRepresentation(using: .lzw, factor: 0) else { return }
        item.setData(tiff, forType: type)
    }
}
