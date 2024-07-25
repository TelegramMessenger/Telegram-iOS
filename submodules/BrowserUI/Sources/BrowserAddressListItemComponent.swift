import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import MultilineTextComponent
import TelegramPresentationData
import PhotoResources
import AccountContext

final class BrowserAddressListItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let webPage: TelegramMediaWebpage
    var message: Message?
    let hasNext: Bool
    let insets: UIEdgeInsets
    let action: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        webPage: TelegramMediaWebpage,
        message: Message?,
        hasNext: Bool,
        insets: UIEdgeInsets,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.webPage = webPage
        self.message = message
        self.hasNext = hasNext
        self.insets = insets
        self.action = action
    }
    
    static func ==(lhs: BrowserAddressListItemComponent, rhs: BrowserAddressListItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.webPage != rhs.webPage {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let containerButton: HighlightTrackingButton
        
        private var emptyIcon: UIImageView?
        private var icon = TransformImageNode()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private let separatorLayer: SimpleLayer
        
        private var component: BrowserAddressListItemComponent?
        private weak var state: EmptyComponentState?
        
        private var currentIconImageRepresentation: TelegramMediaImageRepresentation?
        
        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            
            self.containerButton = HighlightTrackingButton()
                        
            super.init(frame: frame)
            
            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.containerButton)
            
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        func update(component: BrowserAddressListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            let currentIconImageRepresentation = self.currentIconImageRepresentation
                                
            let iconSize = CGSize(width: 40.0, height: 40.0)
            let height: CGFloat = 60.0
            let leftInset: CGFloat = component.insets.left + 11.0 + iconSize.width + 11.0
            let rightInset: CGFloat = 16.0
            let titleSpacing: CGFloat = 2.0
                
            let title: String
            let subtitle: String
            var iconImageReferenceAndRepresentation: (AnyMediaReference, TelegramMediaImageRepresentation)?
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            if case let .Loaded(content) = component.webPage.content {
                title = content.title ?? content.url
                subtitle = content.url
                
                if let image = content.image {
                    if let representation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 80, height: 80)) {
                        if let message = component.message {
                            iconImageReferenceAndRepresentation = (.message(message: MessageReference(message), media: image), representation)
                        } else {
                            iconImageReferenceAndRepresentation = (.standalone(media: image), representation)
                        }
                    }
                } else if let file = content.file {
                    if let representation = smallestImageRepresentation(file.previewRepresentations) {
                        if let message = component.message {
                            iconImageReferenceAndRepresentation = (.message(message: MessageReference(message), media: file), representation)
                        } else {
                            iconImageReferenceAndRepresentation = (.standalone(media: file), representation)
                        }
                    }
                }
                
                if currentIconImageRepresentation != iconImageReferenceAndRepresentation?.1 {
                    if let iconImageReferenceAndRepresentation = iconImageReferenceAndRepresentation {
                        if let imageReference = iconImageReferenceAndRepresentation.0.concrete(TelegramMediaImage.self) {
                            updateIconImageSignal = chatWebpageSnippetPhoto(account: component.context.account, userLocation: (component.message?.id.peerId).flatMap(MediaResourceUserLocation.peer) ?? .other, photoReference: imageReference)
                        } else if let fileReference = iconImageReferenceAndRepresentation.0.concrete(TelegramMediaFile.self) {
                            updateIconImageSignal = chatWebpageSnippetFile(account: component.context.account, userLocation: (component.message?.id.peerId).flatMap(MediaResourceUserLocation.peer) ?? .other, mediaReference: fileReference.abstract, representation: iconImageReferenceAndRepresentation.1)
                        }
                    } else {
                        updateIconImageSignal = .complete()
                    }
                }
            } else {
                title = ""
                subtitle = ""
            }
            
            self.component = component
            self.state = state
            self.currentIconImageRepresentation = iconImageReferenceAndRepresentation?.1
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: subtitle, font: Font.regular(15.0), textColor: component.theme.list.itemAccentColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            
            let centralContentHeight = titleSize.height + subtitleSize.height + titleSpacing

            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - centralContentHeight) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    subtitleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(subtitleView)
                }
                subtitleView.frame = subtitleFrame
            }
            
            
            let iconFrame = CGRect(origin: CGPoint(x: 11.0 + component.insets.left, y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize)
            
            let iconImageLayout = self.icon.asyncLayout()
            var iconImageApply: (() -> Void)?
            if let iconImageReferenceAndRepresentation = iconImageReferenceAndRepresentation {
                let imageCorners = ImageCorners(radius: 6.0)
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageReferenceAndRepresentation.1.dimensions.cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor)
                iconImageApply = iconImageLayout(arguments)
            }
            
            if let iconImageApply = iconImageApply {
                if let updateImageSignal = updateIconImageSignal {
                    self.icon.setSignal(updateImageSignal)
                }
                
                if self.icon.supernode == nil {
                    self.addSubview(self.icon.view)
                    self.icon.frame = iconFrame
                } else {
                    transition.setFrame(view: self.icon.view, frame: iconFrame)
                }
                
                iconImageApply()
                
//                if strongSelf.iconTextBackgroundNode.supernode != nil {
//                    strongSelf.iconTextBackgroundNode.removeFromSupernode()
//                }
//                if strongSelf.iconTextNode.supernode != nil {
//                    strongSelf.iconTextNode.removeFromSupernode()
//                }
            } else {
                if self.icon.supernode != nil {
                    self.icon.view.removeFromSuperview()
                }
                
//                if strongSelf.iconTextBackgroundNode.supernode == nil {
//                    strongSelf.iconTextBackgroundNode.image = applyIconTextBackgroundImage
//                    strongSelf.offsetContainerNode.addSubnode(strongSelf.iconTextBackgroundNode)
//                    strongSelf.iconTextBackgroundNode.frame = iconFrame
//                } else {
//                    transition.updateFrame(node: strongSelf.iconTextBackgroundNode, frame: iconFrame)
//                }
//                if strongSelf.iconTextNode.supernode == nil {
//                    strongSelf.offsetContainerNode.addSubnode(strongSelf.iconTextNode)
//                }
            }
            
            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext
            
            let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: height))
            transition.setFrame(view: self.containerButton, frame: containerFrame)
            
            return CGSize(width: availableSize.width, height: height)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
