import AppKit
import SnimachCore
import XCTest
@testable import Snimach

final class PreviewLayoutTests: XCTestCase {
    func testLargeShotScalesDownToFitTheBox() {
        let layout = PreviewLayout.make(shot: CGSize(width: 2400, height: 800))
        XCTAssertEqual(layout.thumbnailFrame.size, CGSize(width: 240, height: 80))
        XCTAssertEqual(layout.cardSize, CGSize(width: 240, height: 80 + PreviewLayout.footerHeight))
        XCTAssertEqual(layout.thumbnailFrame.origin, CGPoint(x: 0, y: PreviewLayout.footerHeight))
    }

    func testSmallShotIsNotUpscaledAndCardKeepsMinimumSize() {
        let layout = PreviewLayout.make(shot: CGSize(width: 20, height: 15))
        XCTAssertEqual(layout.thumbnailFrame.size, CGSize(width: 20, height: 15))
        XCTAssertEqual(layout.cardSize, CGSize(width: 120, height: 80 + PreviewLayout.footerHeight))
        // Origin snaps to whole points, so the center may sit half a point off.
        XCTAssertEqual(layout.thumbnailFrame.midX, layout.cardSize.width / 2, accuracy: 0.5)
        // The thumbnail centers in the image area above the footer, not in the whole card.
        let imageCenterY = PreviewLayout.footerHeight + (layout.cardSize.height - PreviewLayout.footerHeight) / 2
        XCTAssertEqual(layout.thumbnailFrame.midY, imageCenterY, accuracy: 0.5)
    }

    func testCardSitsInTheBottomRightCorner() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let frame = PreviewLayout.cornerFrame(cardSize: CGSize(width: 240, height: 160), in: visible)
        XCTAssertEqual(frame.maxX, visible.maxX - PreviewLayout.margin)
        XCTAssertEqual(frame.minY, visible.minY + PreviewLayout.margin)
    }

    @MainActor
    func testControllerBuildsAPanelOfCardSize() {
        let controller = PreviewWindowController(shot: makeTestShot())
        let expected = CGSize(width: PreviewLayout.minCard.width, height: PreviewLayout.minCard.height + PreviewLayout.footerHeight)
        XCTAssertEqual(controller.panel.frame.size, expected)
        XCTAssertEqual(controller.restingFrame.size, expected)
    }

    func testThumbnailNeverOverlapsTheFooter() {
        for shot in [CGSize(width: 2400, height: 800), CGSize(width: 20, height: 15), CGSize(width: 100, height: 400)] {
            let layout = PreviewLayout.make(shot: shot)
            XCTAssertGreaterThanOrEqual(layout.thumbnailFrame.minY, PreviewLayout.footerHeight)
            XCTAssertLessThanOrEqual(layout.thumbnailFrame.maxY, layout.cardSize.height)
        }
    }
}
