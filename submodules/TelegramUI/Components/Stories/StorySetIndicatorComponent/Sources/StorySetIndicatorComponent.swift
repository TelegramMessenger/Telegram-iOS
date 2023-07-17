import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import PhotoResources

private final class ShapeImageView: UIView {
    struct Item: Equatable {
        var position: CGPoint
        var diameter: CGFloat
        var image: UIImage?
    }
    
    struct Params: Equatable {
        var items: [Item]
        var innerSpacing: CGFloat
        var lineWidth: CGFloat
        var borderColors: [UInt32]
    }
    
    var params: Params?
    
    override func draw(_ rect: CGRect) {
        guard let params = self.params else {
            return
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        context.setBlendMode(.copy)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(rect)
        
        context.setFillColor(UIColor.black.cgColor)
        for item in params.items {
            context.fillEllipse(in: CGRect(origin: CGPoint(x: item.position.x - item.diameter * 0.5, y: item.position.y - item.diameter * 0.5), size: CGSize(width: item.diameter, height: item.diameter)))
        }
        
        context.setFillColor(UIColor.clear.cgColor)
        for item in params.items {
            context.fillEllipse(in: CGRect(origin: CGPoint(x: item.position.x - item.diameter * 0.5, y: item.position.y - item.diameter * 0.5), size: CGSize(width: item.diameter, height: item.diameter)).insetBy(dx: params.lineWidth, dy: params.lineWidth))
        }
        
        context.setBlendMode(.sourceIn)
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: params.borderColors.map {
            UIColor(argb: $0).cgColor
        } as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: 50.0), options: [])
        
        context.setBlendMode(.copy)
        
        for i in (0 ..< params.items.count).reversed() {
            let item = params.items[i]
            if i != params.items.count - 1 {
                let previousItem = params.items[i]
                
                context.setFillColor(UIColor.clear.cgColor)
                context.setBlendMode(.copy)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: previousItem.position.x - previousItem.diameter * 0.5, y: previousItem.position.y - previousItem.diameter * 0.5), size: CGSize(width: previousItem.diameter, height: previousItem.diameter)).insetBy(dx: params.lineWidth, dy: params.lineWidth))
            }
            
            context.setBlendMode(.normal)
            
            let imageRect = CGRect(origin: CGPoint(x: item.position.x - item.diameter * 0.5, y: item.position.y - item.diameter * 0.5), size: CGSize(width: item.diameter, height: item.diameter)).insetBy(dx: params.lineWidth + params.innerSpacing, dy: params.lineWidth + params.innerSpacing)
            
            if let image = item.image {
                context.translateBy(x: imageRect.midX, y: imageRect.midY)
                context.scaleBy(x: 1.0, y: 1.0)
                context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                
                image.draw(in: imageRect, blendMode: .normal, alpha: 1.0)
                
                context.translateBy(x: imageRect.midX, y: imageRect.midY)
                context.scaleBy(x: 1.0, y: 1.0)
                context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
            } else {
                context.setFillColor(UIColor.black.cgColor)
                context.fillEllipse(in: imageRect)
            }
        }
    }
}

public final class StorySetIndicatorComponent: Component {
    public let context: AccountContext
    public let strings: PresentationStrings
    public let peer: EnginePeer
    public let items: [EngineStoryItem]
    public let hasUnseen: Bool
    public let hasUnseenPrivate: Bool
    public let totalCount: Int
    public let theme: PresentationTheme
    public let action: () -> Void
    
    public init(
        context: AccountContext,
        strings: PresentationStrings,
        peer: EnginePeer,
        items: [EngineStoryItem],
        hasUnseen: Bool,
        hasUnseenPrivate: Bool,
        totalCount: Int,
        theme: PresentationTheme,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.strings = strings
        self.peer = peer
        self.items = items
        self.hasUnseen = hasUnseen
        self.hasUnseenPrivate = hasUnseenPrivate
        self.totalCount = totalCount
        self.theme = theme
        self.action = action
    }
    
    public static func ==(lhs: StorySetIndicatorComponent, rhs: StorySetIndicatorComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        if lhs.hasUnseenPrivate != rhs.hasUnseenPrivate {
            return false
        }
        if lhs.totalCount != rhs.totalCount {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    private final class ImageContext {
        private var fetchDisposable: Disposable?
        private var imageDisposable: Disposable?
        private let updated: () -> Void
        
        private(set) var image: UIImage?
        
        init(context: AccountContext, peer: EnginePeer, item: EngineStoryItem, updated: @escaping () -> Void) {
            self.updated = updated
            
            let peerReference = PeerReference(peer._asPeer())
            
            var messageMedia: EngineMedia?
            switch item.media {
            case let .image(image):
                messageMedia = .image(image)
            case let .file(file):
                messageMedia = .file(file)
            default:
                break
            }
            
            let reloadMedia = true
            
            if reloadMedia, let messageMedia, let peerReference {
                var signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var fetchSignal: Signal<Never, NoError>?
                switch messageMedia {
                case let .image(image):
                    signal = chatMessagePhoto(
                        postbox: context.account.postbox,
                        userLocation: .peer(peerReference.id),
                        userContentType: .story,
                        photoReference: .story(peer: peerReference, id: item.id, media: image),
                        synchronousLoad: false,
                        highQuality: true
                    )
                    if let representation = image.representations.last {
                        fetchSignal = fetchedMediaResource(
                            mediaBox: context.account.postbox.mediaBox,
                            userLocation: .peer(peerReference.id),
                            userContentType: .story,
                            reference: ImageMediaReference.story(peer: peerReference, id: item.id, media: image).resourceReference(representation.resource)
                        )
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                    }
                case let .file(file):
                    signal = mediaGridMessageVideo(
                        postbox: context.account.postbox,
                        userLocation: .peer(peerReference.id),
                        userContentType: .story,
                        videoReference: .story(peer: peerReference, id: item.id, media: file),
                        onlyFullSize: false,
                        useLargeThumbnail: true,
                        synchronousLoad: false,
                        autoFetchFullSizeThumbnail: true,
                        overlayColor: nil,
                        nilForEmptyResult: false,
                        useMiniThumbnailIfAvailable: false,
                        blurred: false
                    )
                    fetchSignal = fetchedMediaResource(
                        mediaBox: context.account.postbox.mediaBox,
                        userLocation: .peer(peerReference.id),
                        userContentType: .story,
                        reference: FileMediaReference.story(peer: peerReference, id: item.id, media: file).resourceReference(file.resource)
                    )
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, NoError> in
                        return .complete()
                    }
                default:
                    break
                }
                
                if let signal {
                    var wasSynchronous = true
                    self.imageDisposable = (signal
                    |> deliverOnMainQueue).start(next: { [weak self] process in
                        guard let self else {
                            return
                        }
                        
                        let outerSize = CGSize(width: 1080.0, height: 1920.0)
                        let innerSize = CGSize(width: 26.0, height: 26.0)
                        
                        let result = process(TransformImageArguments(corners: ImageCorners(radius: innerSize.width * 0.5), imageSize: outerSize.aspectFilled(innerSize), boundingSize: innerSize, intrinsicInsets: UIEdgeInsets()))
                        if let result {
                            self.image = result.generateImage()
                            if !wasSynchronous {
                                self.updated()
                            }
                        }
                    })
                    wasSynchronous = false
                }
                
                self.fetchDisposable?.dispose()
                self.fetchDisposable = nil
                if let fetchSignal {
                    self.fetchDisposable = (fetchSignal |> deliverOnMainQueue).start()
                }
            }
        }
        
        deinit {
            self.fetchDisposable?.dispose()
            self.imageDisposable?.dispose()
        }
    }
    
    public final class View: UIView {
        private let button: HighlightTrackingButton
        private let imageView: ShapeImageView
        private let text = ComponentView<Empty>()
        
        private var imageContexts: [Int32: ImageContext] = [:]
        
        private var component: StorySetIndicatorComponent?
        private weak var state: EmptyComponentState?
        
        private var effectiveItemsWidth: CGFloat = 0.0
        
        public var transitionView: (UIView, CGRect) {
            return (self.imageView, CGRect(origin: CGPoint(), size: CGSize(width: self.effectiveItemsWidth, height: self.imageView.bounds.height)))
        }
        
        override init(frame: CGRect) {
            self.button = HighlightTrackingButton()
            
            self.imageView = ShapeImageView(frame: CGRect())
            self.imageView.isUserInteractionEnabled = false
            self.imageView.backgroundColor = nil
            self.imageView.isOpaque = false
            
            super.init(frame: frame)
            
            self.button.addSubview(self.imageView)
            self.addSubview(self.button)
            
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.button.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    let transition = Transition(animation: .curve(duration: 0.16, curve: .easeInOut))
                    transition.setSublayerTransform(view: self.button, transform: CATransform3DMakeScale(0.8, 0.8, 1.0))
                } else {
                    let transition = Transition(animation: .curve(duration: 0.24, curve: .easeInOut))
                    transition.setSublayerTransform(view: self.button, transform: CATransform3DIdentity)
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.action()
        }
        
        func update(component: StorySetIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let innerDiameter: CGFloat = 26.0
            let innerSpacing: CGFloat = 1.33
            let lineWidth: CGFloat = 1.33
            let outerDiameter: CGFloat = innerDiameter + innerSpacing * 2.0 + lineWidth * 2.0
            let overflow: CGFloat = 14.0
            
            var validIds: [Int32] = []
            var items: [ShapeImageView.Item] = []
            for i in 0 ..< min(3, component.items.count) {
                validIds.append(component.items[i].id)
                
                let imageContext: ImageContext
                if let current = self.imageContexts[component.items[i].id] {
                    imageContext = current
                } else {
                    var update = false
                    imageContext = ImageContext(context: component.context, peer: component.peer, item: component.items[i], updated: { [weak self] in
                        guard let self else {
                            return
                        }
                        if update {
                            self.state?.updated(transition: .immediate)
                        }
                    })
                    self.imageContexts[component.items[i].id] = imageContext
                    update = true
                }
                
                items.append(ShapeImageView.Item(
                    position: CGPoint(x: outerDiameter * 0.5 + CGFloat(i) * (outerDiameter - overflow), y: outerDiameter * 0.5),
                    diameter: outerDiameter,
                    image: imageContext.image
                ))
            }
            
            var removeIds: [Int32] = []
            for (id, _) in self.imageContexts {
                if !validIds.contains(id) {
                    removeIds.append(id)
                }
            }
            for id in removeIds {
                self.imageContexts.removeValue(forKey: id)
            }
            
            let maxItemsWidth: CGFloat = outerDiameter * 0.5 + CGFloat(max(0, 3 - 1)) * (outerDiameter - overflow) + outerDiameter * 0.5
            let effectiveItemsWidth: CGFloat = outerDiameter * 0.5 + CGFloat(max(0, items.count - 1)) * (outerDiameter - overflow) + outerDiameter * 0.5
            self.effectiveItemsWidth = effectiveItemsWidth
            
            let borderColors: [UInt32]
            
            if component.hasUnseenPrivate {
                borderColors = [component.theme.chatList.storyUnseenPrivateColors.topColor.argb, component.theme.chatList.storyUnseenPrivateColors.bottomColor.argb]
            } else if component.hasUnseen {
                borderColors = [component.theme.chatList.storyUnseenColors.topColor.argb, component.theme.chatList.storyUnseenColors.bottomColor.argb]
            } else {
                borderColors = [UIColor(white: 1.0, alpha: 0.3).argb, UIColor(white: 1.0, alpha: 0.3).argb]
            }
            
            let imageSize = CGSize(width: maxItemsWidth, height: outerDiameter)
            let params = ShapeImageView.Params(
                items: items,
                innerSpacing: innerSpacing,
                lineWidth: lineWidth,
                borderColors: borderColors
            )
            if self.imageView.params != params || self.imageView.bounds.size != imageSize {
                self.imageView.params = params
                self.imageView.frame = CGRect(origin: CGPoint(), size: imageSize)
                self.imageView.setNeedsDisplay()
            }
            
            let textValue: String
            if component.totalCount == 0 {
                textValue = ""
            } else {
                textValue = component.strings.Profile_AvatarStoryCount(Int32(component.totalCount))
            }
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(Text(text: textValue, font: Font.semibold(17.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: 300.0, height: 100.0)
            )
            let textFrame = CGRect(origin: CGPoint(x: effectiveItemsWidth + 6.0, y: 5.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    textView.isUserInteractionEnabled = false
                    self.button.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.origin)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            let size = CGSize(width: effectiveItemsWidth + 6.0 + textSize.width, height: outerDiameter)
            transition.setFrame(view: self.button, frame: CGRect(origin: CGPoint(), size: size))
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
