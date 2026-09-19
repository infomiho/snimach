import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import SnimachCore

final class ShotOutputTests: XCTestCase {
    private var folder: URL!
    private var pasteboard: NSPasteboard!
    private let fixedDate = Date(timeIntervalSince1970: 1_767_323_045)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("snimach-output-\(UUID().uuidString)")
        pasteboard = NSPasteboard(name: NSPasteboard.Name("dev.twoducks.snimach.test.\(UUID().uuidString)"))
    }

    override func tearDownWithError() throws {
        pasteboard.releaseGlobally()
        if let folder { try? FileManager.default.removeItem(at: folder) }
    }

    private func makeOutput() -> ShotOutput {
        ShotOutput(folder: { self.folder }, pasteboard: pasteboard, now: { self.fixedDate })
    }

    func testCopyDeclaresPNGAndTIFFAtLogicalSize() throws {
        for scale in [CGFloat(1), 2, 3] {
            let image = makeShot(pointSize: CGSize(width: 60, height: 40), scale: scale).image
            try makeOutput().copy(image, scale: scale)

            let items = pasteboard.pasteboardItems
            XCTAssertEqual(items?.count, 1, "scale \(scale)")
            XCTAssertEqual(items?.first?.types, [.png, .tiff], "scale \(scale)")

            let pasted = try XCTUnwrap(NSImage(pasteboard: pasteboard), "scale \(scale)")
            XCTAssertEqual(pasted.size.width, 60, accuracy: 0.5, "scale \(scale)")
            XCTAssertEqual(pasted.size.height, 40, accuracy: 0.5, "scale \(scale)")
        }
    }

    func testCopyPNGCarriesDPIAndDimensions() throws {
        for scale in [CGFloat(1), 2, 3] {
            let image = makeShot(pointSize: CGSize(width: 60, height: 40), scale: scale).image
            try makeOutput().copy(image, scale: scale)

            let data = try XCTUnwrap(pasteboard.data(forType: .png), "scale \(scale)")
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let properties = try XCTUnwrap(
                CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            )
            XCTAssertEqual(properties[kCGImagePropertyDPIWidth] as? Double, 72 * scale, "scale \(scale)")
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(decoded.width, image.width, "scale \(scale)")
            XCTAssertEqual(decoded.height, image.height, "scale \(scale)")
        }
    }

    func testCopyReplacesPreviousContents() throws {
        let output = makeOutput()
        let first = makeShot(pointSize: CGSize(width: 10, height: 10), scale: 2).image
        let second = makeShot(pointSize: CGSize(width: 50, height: 30), scale: 2).image

        try output.copy(first, scale: 2)
        let changeCount = pasteboard.changeCount
        try output.copy(second, scale: 2)

        XCTAssertGreaterThan(pasteboard.changeCount, changeCount)
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(
            try XCTUnwrap(CGImageSourceCreateWithData(try XCTUnwrap(pasteboard.data(forType: .png)) as CFData, nil)),
            0, nil
        ))
        XCTAssertEqual(decoded.width, second.width)
        XCTAssertEqual(decoded.height, second.height)
    }

    func testSaveCreatesMissingFolderAndRoundTripsPixels() throws {
        let image = makeShot(pointSize: CGSize(width: 30, height: 20), scale: 2).image
        let nested = folder.appendingPathComponent("a/b/c")
        let output = ShotOutput(folder: { nested }, pasteboard: pasteboard, now: { self.fixedDate })

        let url = try output.save(image, scale: 2)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let saved = try XCTUnwrap(CGImageSourceCreateImageAtIndex(
            try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil)),
            0, nil
        ))
        XCTAssertEqual(saved.width, image.width)
        XCTAssertEqual(saved.height, image.height)
        XCTAssertEqual(pixels(of: saved), pixels(of: image))
    }

    func testDifferentImagesOfTheSameSizeDoNotShareEncodedBytes() throws {
        let output = makeOutput()
        let red = makeShot(
            pointSize: CGSize(width: 20, height: 20),
            scale: 2,
            color: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        ).image
        let blue = makeShot(
            pointSize: CGSize(width: 20, height: 20),
            scale: 2,
            color: CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        ).image

        let first = try output.save(red, scale: 2)
        let second = try output.save(blue, scale: 2)

        XCTAssertNotEqual(try Data(contentsOf: first), try Data(contentsOf: second))
    }

    func testSaveNeverOverwrites() throws {        let output = makeOutput()
        let image = makeShot(pointSize: CGSize(width: 20, height: 20), scale: 2).image

        let first = try output.save(image, scale: 2)
        let firstData = try Data(contentsOf: first)
        let second = try output.save(image, scale: 2)

        XCTAssertTrue(first.lastPathComponent.hasSuffix(".png"))
        XCTAssertTrue(second.lastPathComponent.hasSuffix(" (2).png"))
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        XCTAssertEqual(try Data(contentsOf: first), firstData)
    }

    func testSaveUnderReadOnlyParentThrowsFolderUnavailable() throws {
        let readOnly = FileManager.default.temporaryDirectory
            .appendingPathComponent("snimach-ro-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: readOnly, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly.path)
            try? FileManager.default.removeItem(at: readOnly)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly.path)

        let output = ShotOutput(
            folder: { readOnly.appendingPathComponent("sub") },
            pasteboard: pasteboard,
            now: { self.fixedDate }
        )
        let image = makeShot(pointSize: CGSize(width: 10, height: 10), scale: 1).image

        XCTAssertThrowsError(try output.save(image, scale: 1)) { error in
            guard case ShotOutputError.folderUnavailable = error else {
                return XCTFail("expected folderUnavailable, got \(error)")
            }
        }
    }

    func testSavedFileBytesMatchPasteboardPNG() throws {
        let output = makeOutput()
        let image = makeShot(pointSize: CGSize(width: 40, height: 30), scale: 2).image

        let url = try output.save(image, scale: 2)
        try output.copy(image, scale: 2)

        XCTAssertEqual(try Data(contentsOf: url), pasteboard.data(forType: .png))
    }

    func testTemporaryPNGWritesAReadableFileWithAFreshNameEachTime() throws {
        let output = makeOutput()
        let image = makeShot(pointSize: CGSize(width: 20, height: 10), scale: 2).image

        let first = try output.temporaryPNG(image, scale: 2)
        let second = try output.temporaryPNG(image, scale: 2)
        defer {
            for url in [first, second] {
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            }
        }

        XCTAssertNotEqual(first, second, "a second drag must not overwrite the first file")
        for url in [first, second] {
            XCTAssertEqual(url.pathExtension, "png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(decoded.width, 40)
            XCTAssertEqual(decoded.height, 20)
        }
    }
}

private func pixels(of image: CGImage) -> Data {
    let context = makeContext(width: image.width, height: image.height)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return Data(bytes: context.data!, count: context.bytesPerRow * context.height)
}
