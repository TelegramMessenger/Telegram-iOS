import Foundation
import CoreGraphics

enum QrStudioExportCanvas: Equatable {
    case screen(size: CGSize, scale: CGFloat)
    case story

    var size: CGSize {
        switch self {
        case let .screen(size, _):
            return size
        case .story:
            return CGSize(width: 360.0, height: 640.0)
        }
    }

    var scale: CGFloat {
        switch self {
        case let .screen(_, scale):
            return scale
        case .story:
            return 3.0
        }
    }

    var pixelSize: CGSize {
        return CGSize(width: (self.size.width * self.scale).rounded(), height: (self.size.height * self.scale).rounded())
    }
}

enum QrStudioExportLayout {
    static func cardRect(canvas: CGSize, cardSize: CGSize) -> CGRect {
        let scale = min(1.0, canvas.width * 0.74 / cardSize.width, canvas.height * 0.62 / cardSize.height)
        let width = cardSize.width * scale
        let height = cardSize.height * scale
        return CGRect(x: canvas.width * 0.5 - width * 0.5, y: canvas.height * 0.5 - height * 0.5, width: width, height: height)
    }

    static func cardRect(canvas: CGSize, cardSize: CGSize, screenSize: CGSize, screenCard: CGRect) -> CGRect {
        if abs(canvas.width - screenSize.width) < 0.5 && abs(canvas.height - screenSize.height) < 0.5 {
            return screenCard
        }
        return self.cardRect(canvas: canvas, cardSize: cardSize)
    }

    static func map(_ point: CGPoint, screenCard: CGRect, card: CGRect) -> CGPoint {
        let scale = card.width / max(1.0, screenCard.width)
        return CGPoint(x: card.midX + (point.x - screenCard.midX) * scale, y: card.midY + (point.y - screenCard.midY) * scale)
    }
}
