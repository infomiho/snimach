import CoreGraphics
import XCTest
@testable import SnimachCore

final class BackdropTests: XCTestCase {
    private let baseColor = CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)

    private func makeDocument() -> Document {
        Document(shot: makeShot(pointSize: CGSize(width: 60, height: 40), scale: 2, color: baseColor))
    }

    private func drawBackdropped(_ document: Document) throws -> Bitmap {
        bitmap(try document.render(), scale: document.shot.scale)
    }

    func testModeToggles() {
        XCTAssertEqual(BackdropMode.transparent.next, .solid)
        XCTAssertEqual(BackdropMode.solid.next, .transparent)
    }

    func testDefaultsAreTransparentGotham() {
        let document = Document(shot: makeShot(pointSize: CGSize(width: 60, height: 40), scale: 2))
        XCTAssertEqual(document.backdrop, .transparent)
        XCTAssertEqual(document.backdropPreset.id, .gotham)
    }

    func testActionsSetModeAndPreset() {
        var document = Document(shot: makeShot(pointSize: CGSize(width: 60, height: 40), scale: 2))
        document.apply(.backdropSelected(.solid))
        XCTAssertEqual(document.backdrop, .solid)
        document.apply(.backdropPresetSelected(BackdropPreset.preset(.arendelle)))
        XCTAssertEqual(document.backdropPreset.id, .arendelle)
    }

    func testSolidRenderPadsAndPaintsPreset() throws {
        var document = Document(shot: makeShot(
            pointSize: CGSize(width: 60, height: 40),
            scale: 2,
            color: baseColor
        ))
        document.apply(.backdropSelected(.solid))

        let image = try document.render()
        // 48pt pad on every side at scale 2.
        XCTAssertEqual(image.width, 120 + 192)
        XCTAssertEqual(image.height, 80 + 192)

        let rendered = bitmap(image, scale: 2)
        // Corner is the first Gotham stop; the shot shadow never reaches the edge.
        assertNear(rendered.pixel(x: 0, y: 0), BackdropPreset.preset(.gotham).stops[0].color)
        // Centre of the card is still the base shot.
        assertNear(rendered.pixel(at: CGPoint(x: 78, y: 68)), baseColor)
    }

    func testAnnotationsSurviveOntoCard() throws {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 10, y: 10)))
        document.apply(.pointerDragged(CGPoint(x: 40, y: 10)))
        document.apply(.pointerUp(CGPoint(x: 40, y: 10)))
        document.apply(.backdropSelected(.solid))

        // Shaft midpoint shifts right and down by the 48pt pad.
        XCTAssertGreaterThan(try drawBackdropped(document).count(of: Style.standard.strokeColor), 0)
    }

    func testBackdropChangesAreNotUndoable() {
        var document = makeDocument()
        document.apply(.pointerDown(CGPoint(x: 10, y: 10)))
        document.apply(.pointerDragged(CGPoint(x: 40, y: 10)))
        document.apply(.pointerUp(CGPoint(x: 40, y: 10)))
        XCTAssertTrue(document.canUndo)

        document.apply(.backdropSelected(.solid))
        document.apply(.backdropPresetSelected(BackdropPreset.preset(.arendelle)))
        XCTAssertTrue(document.canUndo)
        XCTAssertEqual(document.annotations.count, 1)

        document.apply(.undo)
        XCTAssertEqual(document.annotations.count, 0)
        XCTAssertEqual(document.backdrop, .solid, "undo pops annotations, never chrome")
    }

    func testStageMatchesShotWithoutBackdrop() {
        let document = makeDocument()
        XCTAssertEqual(document.stageSize, document.pointSize)
        XCTAssertEqual(document.stageOrigin, .zero)
    }

    func testStageAddsPadWithBackdrop() {
        var document = makeDocument()
        document.apply(.backdropSelected(.solid))
        XCTAssertEqual(document.stageSize, CGSize(width: 60 + 96, height: 40 + 96))
        XCTAssertEqual(document.stageOrigin, CGPoint(x: 48, y: 48))
    }

    func testPresetTableIsValid() {
        XCTAssertEqual(BackdropPresetID.allCases.count, 11)
        for id in BackdropPresetID.allCases {
            let preset = BackdropPreset.preset(id)
            XCTAssertFalse(preset.name.isEmpty, "\(id)")
            XCTAssertGreaterThanOrEqual(preset.stops.count, 2, "\(id)")
            let locations = preset.stops.map { $0.location }
            XCTAssertEqual(locations, locations.sorted(), "\(id) stops run down the line")
            for stop in preset.stops {
                XCTAssertTrue(stop.location >= 0 && stop.location <= 1, "\(id)")
                XCTAssertNotNil(stop.hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression), "\(id) \(stop.hex)")
            }
        }
    }
}
