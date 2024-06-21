import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import ComponentFlow
import TelegramPresentationData
import PhotoResources
import AvatarNode
import AccountContext
import BundleIconComponent
import MultilineTextComponent

public final class StarsAvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: StarsContext.State.Transaction.Peer
    let photo: TelegramMediaWebFile?
    let media: [Media]

    public init(context: AccountContext, theme: PresentationTheme, peer: StarsContext.State.Transaction.Peer, photo: TelegramMediaWebFile?, media: [Media]) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.photo = photo
        self.media = media
    }

    public static func ==(lhs: StarsAvatarComponent, rhs: StarsAvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.photo != rhs.photo {
            return false
        }
        if !areMediaArraysEqual(lhs.media, rhs.media) {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatarNode: AvatarNode
        private let backgroundView = UIImageView()
        private let iconView = UIImageView()
        private var imageNode: TransformImageNode?
        
        private let fetchDisposable = MetaDisposable()
        
        private var component: StarsAvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
            
            super.init(frame: frame)
            
            self.iconView.contentMode = .scaleAspectFit
            
            self.addSubnode(self.avatarNode)
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fetchDisposable.dispose()
        }
        
        func update(component: StarsAvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 40.0, height: 40.0)
            var iconInset: CGFloat = 3.0
            var iconOffset: CGFloat = 0.0
            
            var dimensions = size
            
            switch component.peer {
            case let .peer(peer):
                if !component.media.isEmpty {
                    let imageNode: TransformImageNode
                    if let current = self.imageNode {
                        imageNode = current
                    } else {
                        imageNode = TransformImageNode()
                        imageNode.contentAnimations = [.subsequentUpdates]
                        self.addSubview(imageNode.view)
                        self.imageNode = imageNode
                        
                        if let image = component.media.first as? TelegramMediaImage {
                            if let imageDimensions = largestImageRepresentation(image.representations)?.dimensions {
                                dimensions = imageDimensions.cgSize.aspectFilled(size)
                            }
                            imageNode.setSignal(chatMessagePhotoThumbnail(account: component.context.account, userLocation: .other, photoReference: .standalone(media: image), onlyFullSize: false, blurred: false))
                            self.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: component.context, userLocation: .other, photoReference: .standalone(media: image), displayAtSize: nil, storeToDownloadsPeerId: nil).startStrict())
                        } else if let file = component.media.first as? TelegramMediaFile {
                            if let videoDimensions = file.dimensions {
                                dimensions = videoDimensions.cgSize.aspectFilled(size)
                            }
                            imageNode.setSignal(mediaGridMessageVideo(postbox: component.context.account.postbox, userLocation: .other, videoReference: .standalone(media: file), autoFetchFullSizeThumbnail: true))
                        }
                    }
                                    
                    imageNode.frame = CGRect(origin: .zero, size: size)
                    imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 8.0), imageSize: dimensions, boundingSize: size, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                    
                    self.backgroundView.isHidden = true
                    self.iconView.isHidden = true
                    self.avatarNode.isHidden = true
                } else if let photo = component.photo {
                    let imageNode: TransformImageNode
                    if let current = self.imageNode {
                        imageNode = current
                    } else {
                        imageNode = TransformImageNode()
                        imageNode.contentAnimations = [.subsequentUpdates]
                        self.addSubview(imageNode.view)
                        self.imageNode = imageNode
                        
                        imageNode.setSignal(chatWebFileImage(account: component.context.account, file: photo))
                        self.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: component.context.account, userLocation: .other, image: photo).startStrict())
                    }
                                    
                    imageNode.frame = CGRect(origin: .zero, size: size)
                    imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 8.0), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                    
                    self.backgroundView.isHidden = true
                    self.iconView.isHidden = true
                    self.avatarNode.isHidden = true
                } else {
                    self.avatarNode.setPeer(
                        context: component.context,
                        theme: component.theme,
                        peer: peer,
                        synchronousLoad: true
                    )
                    self.backgroundView.isHidden = true
                    self.iconView.isHidden = true
                    self.avatarNode.isHidden = false
                }
            case .appStore:
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0x2a9ef1).cgColor,
                        UIColor(rgb: 0x72d5fd).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/Apple")
            case .playMarket:
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0x54cb68).cgColor,
                        UIColor(rgb: 0xa0de7e).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/Google")
            case .fragment:
                self.backgroundView.image = generateFilledCircleImage(diameter: size.width, color: UIColor(rgb: 0x1b1f24))
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/Fragment")
                iconOffset = 2.0
            case .premiumBot:
                iconInset = 7.0
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0x6b93ff).cgColor,
                        UIColor(rgb: 0x6b93ff).cgColor,
                        UIColor(rgb: 0x8d77ff).cgColor,
                        UIColor(rgb: 0xb56eec).cgColor,
                        UIColor(rgb: 0xb56eec).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon"), color: .white)
            case .unsupported:
                iconInset = 7.0
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0xb1b1b1).cgColor,
                        UIColor(rgb: 0xcdcdcd).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon"), color: .white)
            }
            
            self.avatarNode.frame = CGRect(origin: .zero, size: size)
            self.iconView.frame = CGRect(origin: .zero, size: size).insetBy(dx: iconInset, dy: iconInset).offsetBy(dx: 0.0, dy: iconOffset)
            self.backgroundView.frame = CGRect(origin: .zero, size: size)

            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class StarsLabelComponent: CombinedComponent {
    let text: NSAttributedString
    
    public init(
        text: NSAttributedString
    ) {
        self.text = text
    }
    
    public static func ==(lhs: StarsLabelComponent, rhs: StarsLabelComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    public static var body: Body {
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)

        return { context in
            let component = context.component
        
            let text = text.update(
                component: MultilineTextComponent(text: .plain(component.text)),
                availableSize: CGSize(width: 100.0, height: 40.0),
                transition: context.transition
            )
            
            let iconSize = CGSize(width: 20.0, height: 20.0)
            let icon = icon.update(
                component: BundleIconComponent(
                    name: "Premium/Stars/StarLarge",
                    tintColor: nil
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let spacing: CGFloat = 3.0
            let totalWidth = text.size.width + spacing + iconSize.width
            let size = CGSize(width: totalWidth, height: iconSize.height)
            
            context.add(text
                .position(CGPoint(x: text.size.width / 2.0, y: size.height / 2.0))
            )
            context.add(icon
                .position(CGPoint(x: totalWidth - iconSize.width / 2.0, y: size.height / 2.0 - UIScreenPixel))
            )
            return size
        }
    }
}

public final class StarsMediaComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: StarsContext.State.Transaction.Peer
    let photo: TelegramMediaWebFile?

    public init(context: AccountContext, theme: PresentationTheme, peer: StarsContext.State.Transaction.Peer, photo: TelegramMediaWebFile?) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.photo = photo
    }

    public static func ==(lhs: StarsMediaComponent, rhs: StarsMediaComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.photo != rhs.photo {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatarNode: AvatarNode
        private let backgroundView = UIImageView()
        private let iconView = UIImageView()
        private var imageNode: TransformImageNode?
        
        private let fetchDisposable = MetaDisposable()
        
        private var component: StarsMediaComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
            
            super.init(frame: frame)
            
            self.iconView.contentMode = .scaleAspectFit
            
            self.addSubnode(self.avatarNode)
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fetchDisposable.dispose()
        }
        
        func update(component: StarsMediaComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 40.0, height: 40.0)
            var iconInset: CGFloat = 3.0
            var iconOffset: CGFloat = 0.0
            
            switch component.peer {
            case let .peer(peer):
                if let photo = component.photo {
                    let imageNode: TransformImageNode
                    if let current = self.imageNode {
                        imageNode = current
                    } else {
                        imageNode = TransformImageNode()
                        imageNode.contentAnimations = [.subsequentUpdates]
                        self.addSubview(imageNode.view)
                        self.imageNode = imageNode
                        
                        imageNode.setSignal(chatWebFileImage(account: component.context.account, file: photo))
                        self.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: component.context.account, userLocation: .other, image: photo).startStrict())
                    }
                                    
                    imageNode.frame = CGRect(origin: .zero, size: size)
                    imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: size.width / 2.0), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                    
                    self.backgroundView.isHidden = true
                    self.iconView.isHidden = true
                    self.avatarNode.isHidden = true
                } else {
                    self.avatarNode.setPeer(
                        context: component.context,
                        theme: component.theme,
                        peer: peer,
                        synchronousLoad: true
                    )
                    self.backgroundView.isHidden = true
                    self.iconView.isHidden = true
                    self.avatarNode.isHidden = false
                }
            case .appStore:
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0x2a9ef1).cgColor,
                        UIColor(rgb: 0x72d5fd).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/Apple")
            case .playMarket:
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0x54cb68).cgColor,
                        UIColor(rgb: 0xa0de7e).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/Google")
            case .fragment:
                self.backgroundView.image = generateFilledCircleImage(diameter: size.width, color: UIColor(rgb: 0x1b1f24))
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/Fragment")
                iconOffset = 2.0
            case .premiumBot:
                iconInset = 7.0
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0x6b93ff).cgColor,
                        UIColor(rgb: 0x6b93ff).cgColor,
                        UIColor(rgb: 0x8d77ff).cgColor,
                        UIColor(rgb: 0xb56eec).cgColor,
                        UIColor(rgb: 0xb56eec).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon"), color: .white)
            case .unsupported:
                iconInset = 7.0
                self.backgroundView.image = generateGradientFilledCircleImage(
                    diameter: size.width,
                    colors: [
                        UIColor(rgb: 0xb1b1b1).cgColor,
                        UIColor(rgb: 0xcdcdcd).cgColor
                    ],
                    direction: .mirroredDiagonal
                )
                self.backgroundView.isHidden = false
                self.iconView.isHidden = false
                self.avatarNode.isHidden = true
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon"), color: .white)
            }
            
            self.avatarNode.frame = CGRect(origin: .zero, size: size)
            self.iconView.frame = CGRect(origin: .zero, size: size).insetBy(dx: iconInset, dy: iconInset).offsetBy(dx: 0.0, dy: iconOffset)
            self.backgroundView.frame = CGRect(origin: .zero, size: size)

            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
