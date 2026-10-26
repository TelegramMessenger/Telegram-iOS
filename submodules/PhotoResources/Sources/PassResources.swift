import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Display
import MediaResources
import PassRenderer

public let chatMessagePassImageSize: CGSize = passRenderDesignSize

private enum PassImageState {
    case loading
    case image(CGImage)
    case unreadable
}

private func passCappedFileName(_ fileName: String) -> String {
    let scalars = fileName.unicodeScalars
    guard let end = scalars.index(scalars.startIndex, offsetBy: 128, limitedBy: scalars.endIndex), end != scalars.endIndex else {
        return fileName
    }
    return String(scalars[scalars.startIndex ..< end])
}

private func unreadablePassImage(size: CGSize, fileName: String) -> CGImage? {
    return generateImage(size, rotatedContext: { size, context in
        context.setFillColor(UIColor(rgb: 0x8e8e93).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))

        UIGraphicsPushContext(context)
        defer {
            UIGraphicsPopContext()
        }
        let title = NSAttributedString(string: passCappedFileName(fileName), font: Font.medium(15.0), textColor: .white, paragraphAlignment: .center)
        let titleSize = title.boundingRect(with: CGSize(width: size.width - 32.0, height: 40.0), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil).size
        let icon = UIImage(systemName: "wallet.pass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 34.0))?.withTintColor(.white, renderingMode: .alwaysOriginal)
        let iconSize = icon?.size ?? CGSize()
        let spacing: CGFloat = icon != nil ? 8.0 : 0.0
        let top = floor((size.height - iconSize.height - spacing - titleSize.height) / 2.0)
        icon?.draw(at: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: top))
        title.draw(with: CGRect(x: 16.0, y: top + iconSize.height + spacing, width: size.width - 32.0, height: ceil(titleSize.height)), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    })?.cgImage
}

public func chatMessagePassImage(account: Account, fileReference: FileMediaReference, language: String) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let resource = fileReference.media.resource
    let representation = CachedPassImageRepresentation(language: language, scale: min(3, max(1, Int(UIScreenScale))), layoutVersion: passRenderLayoutVersion)
    let fileName = fileReference.media.fileName ?? ""

    let state: Signal<PassImageState, NoError> = Signal { subscriber in
        return account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: false, fetch: true).start(next: { data in
            if !data.complete {
                subscriber.putNext(.loading)
            } else if data.size != 0, let image = UIImage(contentsOfFile: data.path)?.cgImage {
                subscriber.putNext(.image(image))
            } else if let image = unreadablePassImage(size: chatMessagePassImageSize, fileName: fileName) {
                subscriber.putNext(.image(image))
            } else {
                subscriber.putNext(.unreadable)
            }
        })
    }

    return state
    |> map { state in
        return { arguments in
            guard let context = DrawingContext(size: arguments.drawingSize, clear: true) else {
                return nil
            }
            let drawingRect = arguments.drawingRect
            context.withFlippedContext { c in
                switch state {
                case .loading, .unreadable:
                    c.setFillColor((arguments.emptyColor ?? UIColor(rgb: 0x8e8e93)).cgColor)
                    c.fill(drawingRect)
                case let .image(image):
                    let fittedSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height)).aspectFilled(drawingRect.size)
                    c.interpolationQuality = .high
                    c.draw(image, in: CGRect(x: drawingRect.midX - fittedSize.width / 2.0, y: drawingRect.maxY - fittedSize.height, width: fittedSize.width, height: fittedSize.height))
                }
            }
            addCorners(context, arguments: arguments)
            return context
        }
    }
}
