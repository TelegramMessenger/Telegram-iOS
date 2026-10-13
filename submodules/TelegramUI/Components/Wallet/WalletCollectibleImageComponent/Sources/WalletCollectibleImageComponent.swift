import Foundation
import UIKit
import ImageIO
import AsyncDisplayKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import ComponentFlow
import PhotoResources

private func walletCollectibleWebFileImage(
    account: Account,
    file: TelegramMediaWebFile
) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return account.postbox.mediaBox.resourceData(file.resource)
    |> map { fullSizeData in
        return { arguments in
            guard let context = DrawingContext(size: arguments.drawingSize, clear: true) else {
                return nil
            }

            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if fullSizeData.complete {
                let options = NSMutableDictionary()
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: fullSizeData.path) as CFURL, nil),
                   let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    imageOrientation = imageOrientationFromSource(imageSource)
                    fullSizeImage = image
                }

                if let fullSizeImage {
                    let drawingRect = arguments.drawingRect
                    var fittedSize = CGSize(width: CGFloat(fullSizeImage.width), height: CGFloat(fullSizeImage.height)).aspectFilled(drawingRect.size)
                    if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.width = arguments.boundingSize.width
                    }
                    if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.height = arguments.boundingSize.height
                    }

                    let fittedRect = CGRect(
                        origin: CGPoint(
                            x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0,
                            y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0
                        ),
                        size: fittedSize
                    )

                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                            c.fill(arguments.drawingRect)
                        }
                        c.setBlendMode(.copy)
                        c.interpolationQuality = .medium
                        drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                        c.setBlendMode(.normal)
                    }
                }
            } else {
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                    c.fill(arguments.drawingRect)
                    c.setBlendMode(.normal)
                }
            }

            addCorners(context, arguments: arguments)
            return context
        }
    }
}

public final class WalletCollectibleImageComponent: Component {
    public let context: AccountContext
    public let file: WalletNftFile?
    public let placeholderColor: UIColor
    public let cornerRadius: CGFloat

    public init(
        context: AccountContext,
        file: WalletNftFile?,
        placeholderColor: UIColor,
        cornerRadius: CGFloat
    ) {
        self.context = context
        self.file = file
        self.placeholderColor = placeholderColor
        self.cornerRadius = cornerRadius
    }

    public static func ==(lhs: WalletCollectibleImageComponent, rhs: WalletCollectibleImageComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.file == rhs.file
            && lhs.placeholderColor == rhs.placeholderColor
            && lhs.cornerRadius == rhs.cornerRadius
    }

    public final class View: UIView {
        private let placeholder = ComponentView<Empty>()
        private let imageNode = TransformImageNode()
        private let fetchDisposable = MetaDisposable()

        private weak var accountContext: AccountContext?
        private var file: WalletNftFile?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
            self.imageNode.isUserInteractionEnabled = false
            self.imageNode.isHidden = true
            self.addSubview(self.imageNode.view)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.fetchDisposable.dispose()
        }

        func update(
            component: WalletCollectibleImageComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let _ = self.placeholder.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: component.placeholderColor,
                    cornerRadius: component.cornerRadius
                )),
                environment: {},
                containerSize: availableSize
            )
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, belowSubview: self.imageNode.view)
                }
                transition.setFrame(
                    view: placeholderView,
                    frame: CGRect(origin: .zero, size: availableSize)
                )
            }

            transition.setFrame(
                view: self.imageNode.view,
                frame: CGRect(origin: .zero, size: availableSize)
            )
            self.imageNode.asyncLayout()(TransformImageArguments(
                corners: ImageCorners(radius: component.cornerRadius),
                imageSize: availableSize,
                boundingSize: availableSize,
                intrinsicInsets: UIEdgeInsets(),
                emptyColor: component.placeholderColor
            ))()

            if self.accountContext !== component.context || self.file != component.file {
                self.accountContext = component.context
                self.file = component.file
                self.fetchDisposable.set(nil)
                self.imageNode.reset()

                if let file = component.file {
                    let image = TelegramMediaWebFile(
                        resource: file.resource,
                        mimeType: file.mimeType,
                        size: file.size,
                        attributes: []
                    )
                    self.imageNode.isHidden = false
                    self.imageNode.setSignal(walletCollectibleWebFileImage(
                        account: component.context.account,
                        file: image
                    ))
                    self.fetchDisposable.set(chatMessageWebFileInteractiveFetched(
                        account: component.context.account,
                        userLocation: .other,
                        image: image
                    ).startStrict())
                } else {
                    self.imageNode.isHidden = true
                }
            }

            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            transition: transition
        )
    }
}
