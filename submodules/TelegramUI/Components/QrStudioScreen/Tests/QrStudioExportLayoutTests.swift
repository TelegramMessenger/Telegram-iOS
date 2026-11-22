import XCTest
@testable import QrStudioScreen

final class QrStudioExportLayoutTests: XCTestCase {
    private let canvas = QrStudioExportCanvas.story.size
    private let cardSize = CGSize(width: 264.0, height: 318.0)

    func testStoryCanvas() {
        XCTAssertEqual(QrStudioExportCanvas.story.pixelSize, CGSize(width: 1080.0, height: 1920.0))
    }

    func testCardIsCentredAndFits() {
        let card = QrStudioExportLayout.cardRect(canvas: self.canvas, cardSize: self.cardSize)
        XCTAssertEqual(card.midX, self.canvas.width * 0.5, accuracy: 0.001)
        XCTAssertEqual(card.midY, self.canvas.height * 0.5, accuracy: 0.001)
        XCTAssertLessThanOrEqual(card.width, self.canvas.width * 0.74 + 0.001)
        XCTAssertLessThanOrEqual(card.height, self.canvas.height * 0.62 + 0.001)
    }

    func testScreenCanvasKeepsTheScreenCard() {
        let screen = CGSize(width: 402.0, height: 874.0)
        let screenCard = CGRect(x: 69.0, y: 250.0, width: 264.0, height: 318.0)
        let card = QrStudioExportLayout.cardRect(canvas: screen, cardSize: screenCard.size, screenSize: screen, screenCard: screenCard)
        XCTAssertEqual(card, screenCard)
    }

    func testCanonicalEmojiPatternIsTheSameEveryTime() {
        let size = CGSize(width: 402.0, height: 874.0)
        let a = QrStudioEmojiPatternView.canonicalExportItems(size: size, fileCount: 3)
        let b = QrStudioEmojiPatternView.canonicalExportItems(size: size, fileCount: 3)
        XCTAssertFalse(a.isEmpty)
        XCTAssertEqual(a.map { $0.point }, b.map { $0.point })
        XCTAssertEqual(a.map { $0.content }, b.map { $0.content })
    }

    func testPatternPointsFollowTheCard() {
        let screen = CGSize(width: 402.0, height: 874.0)
        let screenCard = CGRect(x: 69.0, y: 250.0, width: 264.0, height: 318.0)
        let card = QrStudioExportLayout.cardRect(canvas: self.canvas, cardSize: screenCard.size, screenSize: screen, screenCard: screenCard)
        let point = CGPoint(x: screenCard.midX + 40.0, y: screenCard.minY - 30.0)
        let mapped = QrStudioExportLayout.map(point, screenCard: screenCard, card: card)
        let scale = card.width / screenCard.width
        XCTAssertEqual(mapped.x, card.midX + 40.0 * scale, accuracy: 0.001)
        XCTAssertEqual(mapped.y, card.midY - (screenCard.height * 0.5 + 30.0) * scale, accuracy: 0.001)
    }
}
