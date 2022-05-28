import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import ComponentFlow
import AccountContext

import AppBundle
import UniversalMediaPlayer
import TelegramUniversalVideoContent

private let phoneSize = CGSize(width: 262.0, height: 539.0)
private var phoneBorderImage = {
    return generateImage(phoneSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.5).cgColor)
        try? drawSvgPath(context, path: "M203.506,7.0 C211.281,0.0 217.844,0.0 223.221,0.439253 C228.851,0.899605 234.245,1.90219 239.377,4.51905 C247.173,8.49411 253.512,14.8369 257.484,22.6384 C260.099,27.7743 261.101,33.1718 261.561,38.8062 C262.0,44.1865 262.0,50.754 262.0,58.5351 V480.465 C262.0,488.246 262.0,494.813 261.561,500.194 C261.101,505.828 260.099,511.226 257.484,516.362 C253.512,524.163 247.173,530.506 239.377,534.481 C234.245,537.098 228.851,538.1 223.221,538.561 C217.844,539.0 211.281,539.0 203.506,539.0 H58.4942 C50.7185,539 44.1556,539.0 38.7791,538.561 C33.1486,538.1 27.7549,537.098 22.6226,534.481 C14.8265,530.506 8.48817,524.163 4.51589,516.362 C1.90086,511.226 0.898976,505.828 0.438946,500.194 C0.0,494.813 0.0,488.246 7.0,480.465 V58.5354 C0.0,50.7541 0.0,44.1866 0.438946,38.8062 C0.898976,33.1718 1.90086,27.7743 4.51589,22.6384 C8.48817,14.8369 14.8265,8.49411 22.6226,4.51905 C27.7549,1.90219 33.1486,0.899605 38.7791,0.439253 C44.1557,-0.0 50.7187,0.0 58.4945,7.0 H203.506 Z ")
        context.setBlendMode(.copy)
        context.fill(CGRect(origin: CGPoint(x: 43.0, y: UIScreenPixel), size: CGSize(width: 175.0, height: 8.0)))
        context.fill(CGRect(origin: CGPoint(x: UIScreenPixel, y: 43.0), size: CGSize(width: 8.0, height: 452.0)))
        
        context.setBlendMode(.clear)
        try? drawSvgPath(context, path: "M15.3737,28.1746 C12.1861,34.4352 12.1861,42.6307 12.1861,59.0217 V479.978 C12.1861,496.369 12.1861,504.565 15.3737,510.825 C18.1777,516.332 22.6518,520.81 28.1549,523.615 C34.4111,526.805 42.6009,526.805 58.9805,526.805 H203.02 C219.399,526.805 227.589,526.805 233.845,523.615 C239.348,520.81 243.822,516.332 246.626,510.825 C249.814,504.565 249.814,496.369 249.814,479.978 V59.0217 C249.814,42.6307 249.814,34.4352 246.626,28.1746 C243.822,22.6677 239.348,18.1904 233.845,15.3845 C227.589,12.1946 219.399,12.1946 203.02,12.1946 H58.9805 C42.6009,12.1946 34.4111,12.1946 28.1549,15.3845 C22.6518,18.1904 18.1777,22.6677 15.3737,28.1746 Z ")
        
        context.setBlendMode(.copy)
        context.setFillColor(UIColor.black.cgColor)
        try? drawSvgPath(context, path: "M222.923,4.08542 C217.697,3.65815 211.263,3.65823 203.378,3.65833 H58.6219 C50.7366,3.65823 44.3026,3.65815 39.0768,4.08542 C33.6724,4.52729 28.8133,5.46834 24.2823,7.77863 C17.1741,11.4029 11.395,17.1861 7.77325,24.2992 C5.46457,28.8334 4.52418,33.6959 4.08262,39.1041 C3.65565,44.3336 3.65573,50.7721 3.65583,58.6628 V480.337 C3.65573,488.228 3.65565,494.666 4.08262,499.896 C4.52418,505.304 5.46457,510.167 7.77325,514.701 C11.395,521.814 17.1741,527.597 24.2823,531.221 C28.8133,533.532 33.6724,534.473 39.0768,534.915 C44.3028,535.342 50.737,535.342 58.6226,535.342 H203.377 C211.263,535.342 217.697,535.342 222.923,534.915 C228.328,534.473 233.187,533.532 237.718,531.221 C244.826,527.597 250.605,521.814 254.227,514.701 C256.535,510.167 257.476,505.304 257.917,499.896 C258.344,494.667 258.344,488.228 258.344,480.338 V58.6617 C258.344,50.7714 258.344,44.3333 257.917,39.1041 C257.476,33.6959 256.535,28.8334 254.227,24.2992 C250.605,17.1861 244.826,11.4029 237.718,7.77863 C233.187,5.46834 228.328,4.52729 222.923,4.08542 Z ")
        
        context.setBlendMode(.clear)
        try? drawSvgPath(context, path: "M12.1861,59.0217 C12.1861,42.6306 12.1861,34.4351 15.3737,28.1746 C18.1777,22.6676 22.6519,18.1904 28.1549,15.3844 C34.4111,12.1945 42.6009,12.1945 58.9805,12.1945 H76.6868 L76.8652,12.1966 C78.1834,12.2201 79.0316,12.4428 79.7804,12.8418 C80.5733,13.2644 81.1963,13.8848 81.6226,14.6761 C81.9735,15.3276 82.1908,16.0553 82.2606,17.1064 C82.3128,22.5093 82.9306,24.5829 84.0474,26.6727 C85.2157,28.8587 86.9301,30.5743 89.1145,31.7434 C91.299,32.9124 93.4658,33.535 99.441,33.535 H162.561 C168.537,33.535 170.703,32.9124 172.888,31.7434 C175.072,30.5743 176.787,28.8587 177.955,26.6727 C179.072,24.5829 179.69,22.5093 179.742,17.1051 C179.812,16.0553 180.029,15.3276 180.38,14.6761 C180.806,13.8848 181.429,13.2644 182.222,12.8418 C182.971,12.4428 183.819,12.2201 185.137,12.1966 L185.316,12.1945 H203.02 C219.399,12.1945 227.589,12.1945 233.845,15.3844 C239.348,18.1904 243.822,22.6676 246.626,28.1746 C249.814,34.4351 249.814,42.6306 249.814,59.0217 V479.978 C249.814,496.369 249.814,504.565 246.626,510.825 C243.822,516.332 239.348,520.81 233.845,523.615 C227.589,526.805 219.399,526.805 203.02,526.805 H58.9805 C42.6009,526.805 34.4111,526.805 28.1549,523.615 C22.6519,520.81 18.1777,516.332 15.3737,510.825 C12.1861,504.565 12.1861,496.369 12.1861,479.978 V59.0217 Z")
    })
}()

private final class PhoneView: UIView {
    let contentContainerView: UIView
    
    let overlayView: UIView
    let borderView: UIImageView
    
    fileprivate var videoNode: UniversalVideoNode?
    
    var screenRotation: CGFloat = 0.0 {
        didSet {
            if self.screenRotation > 0.0 {
                self.overlayView.backgroundColor = .white
            } else {
                self.overlayView.backgroundColor = .black
            }
            self.contentContainerView.alpha = self.screenRotation > 0.0 ? 1.0 - self.screenRotation : 1.0
            self.overlayView.alpha = self.screenRotation > 0.0 ? self.screenRotation * 0.5 : self.screenRotation * -1.0
        }
    }
    
    override init(frame: CGRect) {
        self.contentContainerView = UIView()
        self.contentContainerView.clipsToBounds = true
        self.contentContainerView.backgroundColor = .darkGray
        self.contentContainerView.layer.cornerRadius = 10.0
        self.contentContainerView.layer.allowsGroupOpacity = true
        
        self.overlayView = UIView()
        self.overlayView.backgroundColor = .black
        
        self.borderView = UIImageView(image: phoneBorderImage)
        
        super.init(frame: frame)
        
        self.addSubview(self.contentContainerView)
        self.contentContainerView.addSubview(self.overlayView)
        self.addSubview(self.borderView)
    }
    
    
    private var position: PhoneDemoComponent.Position = .top
    
    func setup(context: AccountContext, videoName: String?, position: PhoneDemoComponent.Position) {
        self.position = position
        
        guard self.videoNode == nil, let videoName = videoName, let path = getAppBundle().path(forResource: videoName, ofType: "mp4"), let size = fileSize(path) else {
            return
        }
        
        self.contentContainerView.backgroundColor = .clear
        
        let dimensions = PixelDimensions(width: 1170, height: 1754)
        
        let id = Int64.random(in: 0..<Int64.max)
        let dummyFile = TelegramMediaFile(fileId: MediaId(namespace: 0, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: size, attributes: [.Video(duration: 3, size: dimensions, flags: [])])
        
        let videoContent = NativeVideoContent(id: .message(1, MediaId(namespace: 0, id: id)), fileReference: .standalone(media: dummyFile), streamVideo: .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear)
        
        let videoNode = UniversalVideoNode(postbox: context.account.postbox, audioSession: context.sharedContext.mediaManager.audioSession, manager: context.sharedContext.mediaManager.universalVideoManager, decoration: VideoDecoration(), content: videoContent, priority: .embedded)
        videoNode.canAttachContent = true
        self.videoNode = videoNode
        
        self.contentContainerView.insertSubview(videoNode.view, at: 0)
        
        videoNode.pause()
        
        self.setNeedsLayout()
    }
    
    private var isPlaying = false
    func play() {
        if let videoNode = self.videoNode, !self.isPlaying {
            self.isPlaying = true
            videoNode.play()
        }
    }
    
    func reset() {
        if let videoNode = self.videoNode {
            self.isPlaying = false
            videoNode.pause()
            videoNode.seek(0.0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let phoneImage = self.borderView.image {
            self.borderView.frame = CGRect(origin: .zero, size: phoneImage.size)
            self.contentContainerView.frame = CGRect(origin: CGPoint(x: 12.0, y: 12.0), size: CGSize(width: phoneImage.size.width - 24.0, height: phoneImage.size.height - 24.0))
            self.overlayView.frame = self.contentContainerView.bounds
            
            if let videoNode = self.videoNode {
                let videoSize = CGSize(width: self.contentContainerView.frame.width, height: 353.0)
                videoNode.view.frame = CGRect(origin: CGPoint(x: 0.0, y: self.position == .top ? 0.0 : self.contentContainerView.frame.height - videoSize.height), size: videoSize)
                videoNode.updateLayout(size: videoSize, transition: .immediate)
            }
        }
    }
}

final class PhoneDemoComponent: Component {
    typealias EnvironmentType = DemoPageEnvironment
    
    enum Position {
        case top
        case bottom
    }
    
    let context: AccountContext
    let position: Position
    let videoName: String?
    
    public init(
        context: AccountContext,
        position: PhoneDemoComponent.Position,
        videoName: String?
    ) {
        self.context = context
        self.position = position
        self.videoName = videoName
    }
    
    public static func ==(lhs: PhoneDemoComponent, rhs: PhoneDemoComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        if lhs.videoName != rhs.videoName {
            return false
        }
        return true
    }
    
    final class View: UIView, ComponentTaggedView {
        final class Tag {
        }
        
        func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag, self.isCentral {
                return true
            }
            return false
        }
        
        private var isCentral = false
        private var component: PhoneDemoComponent?
        
        private let containerView: UIView
        private let phoneView: PhoneView
        
        public var ready: Signal<Bool, NoError> {
            if let videoNode = self.phoneView.videoNode {
                return videoNode.ready
                |> map { _ in
                    return true
                }
            } else {
                return .single(true)
            }
        }
        
        public override init(frame: CGRect) {
            self.containerView = UIView(frame: frame)
            self.containerView.clipsToBounds = true
            self.phoneView = PhoneView(frame: CGRect(origin: .zero, size: phoneSize))
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.phoneView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: PhoneDemoComponent, availableSize: CGSize, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
            self.component = component
            
            
            self.phoneView.setup(context: component.context, videoName: component.videoName, position: component.position)
            
            self.containerView.frame = CGRect(origin: .zero, size: availableSize)
            self.phoneView.bounds = CGRect(origin: .zero, size: phoneSize)

            var mappedPosition = environment[DemoPageEnvironment.self].position
            mappedPosition *= abs(mappedPosition)
            
            let phoneY: CGFloat
            switch component.position {
                case .top:
                    phoneY = phoneSize.height / 2.0 + 24.0 + abs(mappedPosition) * 24.0
                case .bottom:
                    phoneY = availableSize.height - phoneSize.height / 2.0 - 24.0 - abs(mappedPosition) * 24.0
            }
            
            let isVisible = environment[DemoPageEnvironment.self].isDisplaying
            let isCentral = environment[DemoPageEnvironment.self].isCentral
            self.isCentral = isCentral
            
            self.phoneView.center = CGPoint(x: availableSize.width / 2.0 + mappedPosition * 50.0, y: phoneY)
            self.phoneView.screenRotation = mappedPosition * -0.7
            
            var perspective = CATransform3DIdentity
            perspective.m34 = mappedPosition / 50.0
            self.phoneView.layer.transform = CATransform3DRotate(perspective, 0.1, 0, 1, 0)
            
            if abs(mappedPosition) < .ulpOfOne {
                self.phoneView.play()
            } else if !isVisible {
                self.phoneView.reset()
            }
            
            if let _ = transition.userData(DemoAnimateInTransition.self), abs(mappedPosition) < .ulpOfOne {
                let from: CGFloat
                switch component.position {
                    case .top:
                        from = -200.0
                    case .bottom:
                        from = 200.0
                }
                self.containerView.layer.animateBoundsOriginYAdditive(from: from, to: 0.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class VideoDecoration: UniversalVideoDecoration {
    public let backgroundNode: ASDisplayNode? = nil
    public let contentContainerNode: ASDisplayNode
    public let foregroundNode: ASDisplayNode? = nil
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    public init() {
        self.contentContainerNode = ASDisplayNode()
    }
    
    public func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?) {
        if self.contentNode !== contentNode {
            let previous = self.contentNode
            self.contentNode = contentNode
            
            if let previous = previous {
                if previous.supernode === self.contentContainerNode {
                    previous.removeFromSupernode()
                }
            }
            
            if let contentNode = contentNode {
                if contentNode.supernode !== self.contentContainerNode {
                    self.contentContainerNode.addSubnode(contentNode)
                    if let validLayoutSize = self.validLayoutSize {
                        contentNode.frame = CGRect(origin: CGPoint(), size: validLayoutSize)
                        contentNode.updateLayout(size: validLayoutSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    public func updateCorners(_ corners: ImageCorners) {
        self.contentContainerNode.clipsToBounds = true
        if isRoundEqualCorners(corners) {
            self.contentContainerNode.cornerRadius = corners.topLeft.radius
        } else {
            let boundingSize: CGSize = CGSize(width: max(corners.topLeft.radius, corners.bottomLeft.radius) + max(corners.topRight.radius, corners.bottomRight.radius), height: max(corners.topLeft.radius, corners.topRight.radius) + max(corners.bottomLeft.radius, corners.bottomRight.radius))
            let size: CGSize = CGSize(width: boundingSize.width + corners.extendedEdges.left + corners.extendedEdges.right, height: boundingSize.height + corners.extendedEdges.top + corners.extendedEdges.bottom)
            let arguments = TransformImageArguments(corners: corners, imageSize: size, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
            let context = DrawingContext(size: size, clear: true)
            context.withContext { ctx in
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(arguments.drawingRect)
            }
            addCorners(context, arguments: arguments)
            
            if let maskImage = context.generateImage() {
                let mask = CALayer()
                mask.contents = maskImage.cgImage
                mask.contentsScale = maskImage.scale
                mask.contentsCenter = CGRect(x: max(corners.topLeft.radius, corners.bottomLeft.radius) / maskImage.size.width, y: max(corners.topLeft.radius, corners.topRight.radius) / maskImage.size.height, width: (maskImage.size.width - max(corners.topLeft.radius, corners.bottomLeft.radius) - max(corners.topRight.radius, corners.bottomRight.radius)) / maskImage.size.width, height: (maskImage.size.height - max(corners.topLeft.radius, corners.topRight.radius) - max(corners.bottomLeft.radius, corners.bottomRight.radius)) / maskImage.size.height)
                
                self.contentContainerNode.layer.mask = mask
                self.contentContainerNode.layer.mask?.frame = self.contentContainerNode.bounds
            }
        }
    }
    
    public func updateClippingFrame(_ frame: CGRect, completion: (() -> Void)?) {
        self.contentContainerNode.layer.animate(from: NSValue(cgRect: self.contentContainerNode.bounds), to: NSValue(cgRect: frame), keyPath: "bounds", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
        })

        if let maskLayer = self.contentContainerNode.layer.mask {
            maskLayer.animate(from: NSValue(cgRect: self.contentContainerNode.bounds), to: NSValue(cgRect: frame), keyPath: "bounds", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
            
            maskLayer.animate(from: NSValue(cgPoint: maskLayer.position), to: NSValue(cgPoint: CGPoint(x: frame.midX, y: frame.midY)), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            })
        }
        
        if let contentNode = self.contentNode {
            contentNode.layer.animate(from: NSValue(cgPoint: contentNode.layer.position), to: NSValue(cgPoint: CGPoint(x: frame.midX, y: frame.midY)), keyPath: "position", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion?()
            })
        }
    }
    
    public func updateContentNodeSnapshot(_ snapshot: UIView?) {
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        if let backgroundNode = self.backgroundNode {
            transition.updateFrame(node: backgroundNode, frame: bounds)
        }
        if let foregroundNode = self.foregroundNode {
            transition.updateFrame(node: foregroundNode, frame: bounds)
        }
        transition.updateFrame(node: self.contentContainerNode, frame: bounds)
        if let maskLayer = self.contentContainerNode.layer.mask {
            transition.updateFrame(layer: maskLayer, frame: bounds)
        }
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
    }
    
    public func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    public func tap() {
    }
}
