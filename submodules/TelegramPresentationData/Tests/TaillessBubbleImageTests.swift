import Foundation
import UIKit
import XCTest
import TelegramCore
import TelegramPresentationData

// Without bubble mode outgoing bubbles keep their shape and corners but lose the tail (spec 5.2).
final class TaillessBubbleImageTests: XCTestCase {
    private func bubble(neighbors: MessageBubbleImageNeighbors, tail: Bool) -> Data {
        let chat = makeDefaultPresentationTheme(reference: .dayClassic, serviceBackgroundColor: nil).chat
        let image = messageBubbleImage(maxCornerRadius: 16.0, minCornerRadius: 8.0, incoming: false, fillColor: .red, strokeColor: .clear, neighbors: neighbors, theme: chat, wallpaper: .color(0xffffff), knockout: false, tail: tail)
        return image.pngData()!
    }

    func testTaillessOutgoingBubbleKeepsItsShapeAndLosesTheTail() {
        let tailless = self.bubble(neighbors: .none, tail: false)
        // A lone bubble without its tail is the bubble a context menu lifts: every corner round, no tail.
        XCTAssertEqual(tailless, self.bubble(neighbors: .extracted, tail: true))
        XCTAssertNotEqual(tailless, self.bubble(neighbors: .none, tail: true))
        // Merged corners stay as they are.
        XCTAssertNotEqual(self.bubble(neighbors: .bottom, tail: false), self.bubble(neighbors: .extracted, tail: true))
    }
}
