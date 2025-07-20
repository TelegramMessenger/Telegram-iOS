import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import MultilineTextComponent
import Postbox
import TelegramCore
import TelegramPresentationData
import ContextUI
import PlainButtonComponent
import AvatarNode
import AccountContext
import PhotoResources

final class VideoAdComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let message: EngineMessage
    let initialTimestamp: Int32
    let action: (Bool) -> Void
    let adAction: () -> Void
    let moreAction: (ContextReferenceContentNode) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        message: EngineMessage,
        initialTimestamp: Int32,
        action: @escaping (Bool) -> Void,
        adAction: @escaping () -> Void,
        moreAction: @escaping (ContextReferenceContentNode) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.message = message
        self.initialTimestamp = initialTimestamp
        self.action = action
        self.adAction = adAction
        self.moreAction = moreAction
    }

    static func ==(lhs: VideoAdComponent, rhs: VideoAdComponent) -> Bool {
        if lhs.message != rhs.message {
            return false
        }
        if lhs.initialTimestamp != rhs.initialTimestamp {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: VideoAdComponent?
        private weak var componentState: EmptyComponentState?
        
        private let wrapperView: UIView
        private let backgroundView: UIView
        private let imageNode: TransformImageNode
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        private let buttonNode: ContextReferenceContentNode
        private let progress = ComponentView<Empty>()
        
        private var adIcon: UIImage?
                
        override init(frame: CGRect) {
            self.wrapperView = UIView()
            self.wrapperView.clipsToBounds = true
            self.wrapperView.layer.cornerRadius = 14.0
            if #available(iOS 13.0, *) {
                self.wrapperView.layer.cornerCurve = .continuous
            }
            
            self.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            
            self.imageNode = TransformImageNode()
            self.imageNode.isUserInteractionEnabled = false
            
            self.buttonNode = ContextReferenceContentNode()
            
            super.init(frame: frame)
            
            self.addSubview(self.wrapperView)
            self.wrapperView.addSubview(self.backgroundView)
            self.wrapperView.addSubview(self.buttonNode.view)
            self.wrapperView.addSubview(self.imageNode.view)
            
            self.backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func tapped() {
            if let component = self.component {
                component.adAction()
            }
        }
        
        func update(component: VideoAdComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component

            let titleString = component.message.author?.compactDisplayTitle ?? ""
               
            var media: Media?
            if let photo = component.message.media.first as? TelegramMediaImage {
                media = photo
            } else if let file = component.message.media.first as? TelegramMediaFile {
                media = file
            }
            if isFirstTime {
                let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                if let photo = media as? TelegramMediaImage {
                    signal = mediaGridMessagePhoto(account: component.context.account, userLocation: .other, photoReference: .standalone(media: photo))
                } else if let file = media as? TelegramMediaFile {
                    signal = mediaGridMessageVideo(postbox: component.context.account.postbox, userLocation: .other, videoReference: .standalone(media: file))
                } else {
                    signal = .complete()
                }
                self.imageNode.setSignal(signal)
            }
            
            let leftInset: CGFloat = media != nil ? 51.0 : 16.0
            let rightInset: CGFloat = 60.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: titleString, font: Font.semibold(14.0), textColor: .white)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: availableSize.height)
            )
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.message.text, font: Font.regular(14.0), textColor: .white)),
                        maximumNumberOfLines: 0
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: availableSize.height)
            )
                        
            let contentHeight = titleSize.height + 3.0 + textSize.height
            
            let size = CGSize(width: availableSize.width, height: contentHeight + 24.0)
            
            let imageSize = CGSize(width: 30.0, height: 30.0)
            self.imageNode.frame = CGRect(origin: CGPoint(x: 10.0, y: floor((size.height - imageSize.height) / 2.0)), size: imageSize)
            
            let makeLayout = self.imageNode.asyncLayout()
            let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: imageSize.width / 2.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: .zero))
            apply()
                        
            let contentOriginY = floor((size.height - contentHeight) / 2.0)
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: contentOriginY), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.wrapperView.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let textFrame = CGRect(origin: CGPoint(x: leftInset, y: contentOriginY + contentHeight - textSize.height), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.isUserInteractionEnabled = false
                    self.wrapperView.addSubview(textView)
                }
                textView.frame = textFrame
            }
            
            let color = UIColor(rgb: 0x64d2ff)
            if self.adIcon == nil {
                self.adIcon = generateAdIcon(color: color, strings: component.strings)
            }
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            Image(image: self.adIcon, contentMode: .center)
                        ),
                        effectAlignment: .center,
                        action: { [weak self] in
                            if let self {
                                component.moreAction(self.buttonNode)
                            }
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let buttonFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: floor(titleFrame.midY - buttonSize.height / 2.0) + 1.0), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.wrapperView.addSubview(buttonView)
                }
                buttonView.frame = buttonFrame
            }
            self.buttonNode.frame = buttonFrame
            
            let progressSize = self.progress.update(
                transition: .immediate,
                component: AnyComponent(
                    AdRemainingProgressComponent(
                        initialTimestamp: component.initialTimestamp,
                        minDisplayDuration: 10,
                        maxDisplayDuration: 30,
                        action: { [weak self] available in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.action(available)
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let progressFrame = CGRect(origin: CGPoint(x: size.width - progressSize.width - 16.0, y: floor((size.height - progressSize.height) / 2.0)), size: progressSize)
            if let progressView = self.progress.view {
                if progressView.superview == nil {
                    self.wrapperView.addSubview(progressView)
                }
                progressView.frame = progressFrame
            }
            
            self.wrapperView.frame = CGRect(origin: .zero, size: size)
            self.backgroundView.frame = CGRect(origin: .zero, size: size)
                        
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateAdIcon(color: UIColor, strings: PresentationStrings) -> UIImage? {
    let titleString = NSAttributedString(string: strings.ChatList_Search_Ad, font: Font.regular(11.0), textColor: color, paragraphAlignment: .center)
    let stringRect = titleString.boundingRect(with: CGSize(width: 200.0, height: 20.0), options: .usesLineFragmentOrigin, context: nil)
    
    return generateImage(CGSize(width: floor(stringRect.width) + 18.0, height: 15.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setFillColor(color.withMultipliedAlpha(0.1).cgColor)
        context.addPath(UIBezierPath(roundedRect: bounds, cornerRadius: size.height / 2.0).cgPath)
        context.fillPath()
        
        context.setFillColor(color.cgColor)
        
        let circleSize = CGSize(width: 2.0 - UIScreenPixel, height: 2.0 - UIScreenPixel)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - 8.0, y: 3.0 + UIScreenPixel), size: circleSize))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - 8.0, y: 7.0 - UIScreenPixel), size: circleSize))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - 8.0, y: 10.0), size: circleSize))
        
        let textRect = CGRect(
            x: 5.0,
            y: (size.height - stringRect.height) / 2.0 - UIScreenPixel,
            width: stringRect.width,
            height: stringRect.height
        )
        
        UIGraphicsPushContext(context)
        titleString.draw(in: textRect)
        UIGraphicsPopContext()
    })
}
