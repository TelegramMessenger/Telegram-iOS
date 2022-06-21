import Foundation
import UIKit
import MapKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AvatarNode
import AppBundle
import TelegramPresentationData
import LocationResources
import AccountContext

let locationPinReuseIdentifier = "locationPin"

private func generateSmallBackgroundImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 56.0, height: 56.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setShadow(offset: CGSize(), blur: 4.0, color: UIColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 16.0, y: 16.0, width: 24.0, height: 24.0))
        
        context.setShadow(offset: CGSize(), blur: 0.0, color: nil)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: 17.0 + UIScreenPixel, y: 17.0 + UIScreenPixel, width: 22.0 - 2.0 * UIScreenPixel, height: 22.0 - 2.0 * UIScreenPixel))
    })
}

class LocationPinAnnotation: NSObject, MKAnnotation {
    let context: AccountContext
    let theme: PresentationTheme
    var coordinate: CLLocationCoordinate2D {
        willSet {
            self.willChangeValue(forKey: "coordinate")
        }
        didSet {
            self.didChangeValue(forKey: "coordinate")
        }
    }
    let location: TelegramMediaMap?
    let peer: Peer?
    let message: Message?
    let forcedSelection: Bool
    @objc dynamic var heading: NSNumber? {
        willSet {
            self.willChangeValue(forKey: "heading")
        }
        didSet {
            self.didChangeValue(forKey: "heading")
        }
    }
    
    var isSelf = false
    var selfPeer: Peer?
    var title: String? = ""
    var subtitle: String? = ""
    
    init(context: AccountContext, theme: PresentationTheme, peer: Peer) {
        self.context = context
        self.theme = theme
        self.location = nil
        self.peer = peer
        self.message = nil
        self.coordinate = kCLLocationCoordinate2DInvalid
        self.forcedSelection = false
        super.init()
    }
    
    init(context: AccountContext, theme: PresentationTheme, location: TelegramMediaMap, forcedSelection: Bool = false) {
        self.context = context
        self.theme = theme
        self.location = location
        self.peer = nil
        self.message = nil
        self.coordinate = location.coordinate
        self.forcedSelection = forcedSelection
        super.init()
    }
    
    init(context: AccountContext, theme: PresentationTheme, message: Message, selfPeer: Peer?, isSelf: Bool, heading: Int32?) {
        self.context = context
        self.theme = theme
        self.location = nil
        self.peer = nil
        self.isSelf = isSelf
        self.message = message
        if let location = getLocation(from: message) {
            self.coordinate = location.coordinate
        } else {
            self.coordinate = kCLLocationCoordinate2DInvalid
        }
        self.selfPeer = selfPeer
        self.forcedSelection = false
        self.heading = heading.flatMap { NSNumber(value: $0) }
        super.init()
    }
    
    var id: String {
        if let message = self.message {
            return "\(message.id.id)"
        } else if let peer = self.peer {
            return "\(peer.id.toInt64())"
        } else if let venueId = self.location?.venue?.id {
            return venueId
        } else {
            return String(format: "%.5f_%.5f", self.coordinate.latitude, self.coordinate.longitude)
        }
    }
}

class LocationPinAnnotationLayer: CALayer {
    var customZPosition: CGFloat?
    
    override var zPosition: CGFloat {
        get {
            if let zPosition = self.customZPosition {
                return zPosition
            } else {
                return super.zPosition
            }
        } set {
            super.zPosition = newValue
        }
    }
}

private func addPulseAnimations(layer: CALayer) {
    let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
    scaleAnimation.values = [0.0 as NSNumber, 0.72 as NSNumber, 1.0 as NSNumber, 1.0 as NSNumber]
    scaleAnimation.keyTimes = [0.0 as NSNumber, 0.49 as NSNumber, 0.88 as NSNumber, 1.0 as NSNumber]
    scaleAnimation.duration = 3.0
    scaleAnimation.repeatCount = Float.infinity
    scaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
    scaleAnimation.beginTime = 1.0
    layer.add(scaleAnimation, forKey: "pulse-scale")
    
    let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
    opacityAnimation.values = [1.0 as NSNumber, 0.2 as NSNumber, 0.0 as NSNumber, 0.0 as NSNumber]
    opacityAnimation.keyTimes = [0.0 as NSNumber, 0.4 as NSNumber, 0.62 as NSNumber, 1.0 as NSNumber]
    opacityAnimation.duration = 3.0
    opacityAnimation.repeatCount = Float.infinity
    opacityAnimation.beginTime = 1.0
    layer.add(opacityAnimation, forKey: "pulse-opacity")
}

private func removePulseAnimations(layer: CALayer) {
    layer.removeAnimation(forKey: "pulse-scale")
    layer.removeAnimation(forKey: "pulse-opacity")
}

class LocationPinAnnotationView: MKAnnotationView {
    let shadowNode: ASImageNode
    let pulseNode: ASImageNode
    let backgroundNode: ASImageNode
    let arrowNode: ASImageNode
    let smallNode: ASImageNode
    let iconNode: TransformImageNode
    let smallIconNode: TransformImageNode
    let dotNode: ASImageNode
    var avatarNode: AvatarNode?
    var strokeLabelNode: ImmediateTextNode?
    var labelNode: ImmediateTextNode?
    
    var initialized = false
    var appeared = false
    var animating = false
    
    var hasPulse = false
    
    var headingKvoToken: NSKeyValueObservation?
    
    override class var layerClass: AnyClass {
        return LocationPinAnnotationLayer.self
    }
    
    func setZPosition(_ zPosition: CGFloat?) {
        if let layer = self.layer as? LocationPinAnnotationLayer {
            layer.customZPosition = zPosition
        }
    }
    
    init(annotation: LocationPinAnnotation) {
        self.shadowNode = ASImageNode()
        self.shadowNode.image = UIImage(bundleImageName: "Location/PinShadow")
        if let image = self.shadowNode.image {
            self.shadowNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.pulseNode = ASImageNode()
        self.pulseNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 120.0, height: 120.0))
        self.pulseNode.image = generateFilledCircleImage(diameter: 120.0, color: UIColor(rgb: 0x007aff, alpha: 0.27))
        self.pulseNode.isHidden = true
        
        self.arrowNode = ASImageNode()
        self.arrowNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 88.0, height: 88.0))
        self.arrowNode.image = generateHeadingArrowImage()
        self.arrowNode.isHidden = true
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.image = UIImage(bundleImageName: "Location/PinBackground")
        if let image = self.backgroundNode.image {
            self.backgroundNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.smallNode = ASImageNode()
        self.smallNode.image = UIImage(bundleImageName: "Location/PinSmallBackground")
        if let image = self.smallNode.image {
            self.smallNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.iconNode = TransformImageNode()
        self.iconNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        
        self.smallIconNode = TransformImageNode()
        self.smallIconNode.frame = CGRect(origin: CGPoint(x: 15.0, y: 15.0), size: CGSize(width: 26.0, height: 26.0))
        
        self.dotNode = ASImageNode()
        self.dotNode.image = generateFilledCircleImage(diameter: 6.0, color: annotation.theme.list.itemAccentColor)
        if let image = self.dotNode.image {
            self.dotNode.bounds = CGRect(origin: CGPoint(), size: image.size)
        }
        
        super.init(annotation: annotation, reuseIdentifier: locationPinReuseIdentifier)
        
        self.addSubnode(self.dotNode)
        
        self.addSubnode(self.shadowNode)
        self.addSubnode(self.arrowNode)
        self.shadowNode.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.iconNode)
        
        self.addSubnode(self.smallNode)
        self.smallNode.addSubnode(self.smallIconNode)
        
        self.annotation = annotation
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.headingKvoToken?.invalidate()
    }
    
    var defaultZPosition: CGFloat {
        if let annotation = self.annotation as? LocationPinAnnotation {
            if annotation.forcedSelection {
                return 0.0
            } else if let venueType = annotation.location?.venue?.type, ["home", "work"].contains(venueType) {
                return -0.5
            } else {
                return -1.0
            }
        } else {
            return -1.0
        }
    }
    
    override var annotation: MKAnnotation? {
        didSet {
            if let annotation = self.annotation as? LocationPinAnnotation {
                if let message = annotation.message {
                    self.iconNode.isHidden = true
                    self.dotNode.isHidden = false
                    self.backgroundNode.image = UIImage(bundleImageName: "Location/PinBackground")
                    
                    if let author = message.author {
                        self.setPeer(context: annotation.context, theme: annotation.theme, peer: author)
                    } else if let selfPeer = annotation.selfPeer {
                        self.setPeer(context: annotation.context, theme: annotation.theme, peer: selfPeer)
                    }
                    
                    if !self.isSelected {
                        self.dotNode.alpha = 0.0
                        self.shadowNode.isHidden = true
                        self.smallNode.isHidden = false
                    }
                    
                    if let headingKvoToken = self.headingKvoToken {
                        self.headingKvoToken = nil
                        headingKvoToken.invalidate()
                    }
                    
                    self.headingKvoToken = annotation.observe(\.heading, options: .new) { [weak self] (_, change) in
                        guard let heading = change.newValue else {
                            return
                        }
                        self?.updateHeading(heading)
                    }
                }
                else if let peer = annotation.peer {
                    self.iconNode.isHidden = true
                    self.dotNode.isHidden = true
                    self.backgroundNode.image = UIImage(bundleImageName: "Location/PinBackground")
                    
                    self.setPeer(context: annotation.context, theme: annotation.theme, peer: peer)
                    self.setSelected(true, animated: false)
                    
                    if let headingKvoToken = self.headingKvoToken {
                        self.headingKvoToken = nil
                        headingKvoToken.invalidate()
                    }
                    self.updateHeading(nil)
                } else if let location = annotation.location {
                    let venueType = location.venue?.type ?? ""
                    let color = venueType.isEmpty ? annotation.theme.list.itemAccentColor : venueIconColor(type: venueType)
                    self.backgroundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Location/PinBackground"), color: color)
                    self.iconNode.setSignal(venueIcon(engine: annotation.context.engine, type: venueType, background: false))
                    self.smallIconNode.setSignal(venueIcon(engine: annotation.context.engine, type: venueType, background: false))
                    self.smallNode.image = generateSmallBackgroundImage(color: color)
                    self.dotNode.image = generateFilledCircleImage(diameter: 6.0, color: color)
                    
                    self.iconNode.isHidden = false
                    self.dotNode.isHidden = false
                    
                    if !self.isSelected {
                        self.dotNode.alpha = 0.0
                        self.shadowNode.isHidden = true
                        self.smallNode.isHidden = false
                    }
                    
                    if annotation.forcedSelection {
                        self.setSelected(true, animated: false)
                    }
                    
                    if let avatarNode = self.avatarNode {
                        self.avatarNode = nil
                        avatarNode.removeFromSupernode()
                    }
                    
                    if self.initialized && !self.appeared {
                        self.appeared = true
                        self.animateAppearance()
                    }
                    
                    if let headingKvoToken = self.headingKvoToken {
                        self.headingKvoToken = nil
                        headingKvoToken.invalidate()
                    }
                    self.updateHeading(nil)
                }
            }
        }
    }
    
    private func updateHeading(_ heading: NSNumber?) {
        if let heading = heading?.int32Value {
            self.arrowNode.isHidden = false
            self.arrowNode.transform = CATransform3DMakeRotation(CGFloat(heading) / 180.0 * CGFloat.pi, 0.0, 0.0, 1.0)
        } else {
            self.arrowNode.isHidden = true
            self.arrowNode.transform = CATransform3DIdentity
        }
    }
    
    override func prepareForReuse() {
        self.previousPeerId = nil
        self.smallNode.isHidden = true
        self.backgroundNode.isHidden = false
        self.appeared = false
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if let annotation = self.annotation as? LocationPinAnnotation {
            if annotation.forcedSelection && !selected {
                return
            }
        }
        
        if animated {
            self.layoutSubviews()
            
            self.animating = true
            if selected {
                let avatarSnapshot = self.avatarNode?.view.snapshotContentTree()
                if let avatarSnapshot = avatarSnapshot, let avatarNode = self.avatarNode {
                    self.smallNode.view.addSubview(avatarSnapshot)
                    avatarSnapshot.layer.transform = avatarNode.transform
                    avatarSnapshot.center = CGPoint(x: self.smallNode.frame.width / 2.0, y: self.smallNode.frame.height / 2.0)
                    
                    avatarNode.transform = CATransform3DIdentity
                    self.backgroundNode.addSubnode(avatarNode)
                    avatarNode.position = CGPoint(x: self.backgroundNode.frame.width / 2.0, y: self.backgroundNode.frame.height / 2.0 - 5.0)
                }
                
                self.shadowNode.position = CGPoint(x: self.shadowNode.position.x, y: self.shadowNode.position.y + self.shadowNode.frame.height / 2.0)
                self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                self.shadowNode.isHidden = false
                self.shadowNode.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
                
                UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                    self.smallNode.transform = CATransform3DMakeScale(0.001, 0.001, 1.0)
                    self.shadowNode.transform = CATransform3DIdentity
                    
                    if self.dotNode.isHidden {
                        self.smallNode.alpha = 0.0
                    }
                }) { _ in
                    self.animating = false
                    
                    self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    
                    self.smallNode.isHidden = true
                    self.smallNode.transform = CATransform3DIdentity
                    
                    if let avatarNode = self.avatarNode {
                        self.addSubnode(avatarNode)
                        avatarSnapshot?.removeFromSuperview()
                    }
                }
                                
                self.dotNode.alpha = 1.0
                self.dotNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                
                if let annotation = self.annotation as? LocationPinAnnotation, let venue = annotation.location?.venue {
                    var textColor = UIColor.black
                    var strokeTextColor = UIColor.white
                    if #available(iOS 13.0, *) {
                        if self.traitCollection.userInterfaceStyle == .dark {
                            textColor = .white
                            strokeTextColor = .black
                        }
                    }
                    let strokeLabelNode = ImmediateTextNode()
                    strokeLabelNode.displaysAsynchronously = false
                    strokeLabelNode.isUserInteractionEnabled = false
                    strokeLabelNode.attributedText = NSAttributedString(string: venue.title, font: Font.medium(10), textColor: strokeTextColor)
                    strokeLabelNode.maximumNumberOfLines = 2
                    strokeLabelNode.textAlignment = .center
                    strokeLabelNode.truncationType = .end
                    strokeLabelNode.textStroke = (strokeTextColor, 2.0 - UIScreenPixel)
                    self.strokeLabelNode = strokeLabelNode
                    self.addSubnode(strokeLabelNode)
                    
                    let labelNode = ImmediateTextNode()
                    labelNode.displaysAsynchronously = false
                    labelNode.isUserInteractionEnabled = false
                    labelNode.attributedText = NSAttributedString(string: venue.title, font: Font.medium(10), textColor: textColor)
                    labelNode.maximumNumberOfLines = 2
                    labelNode.textAlignment = .center
                    labelNode.truncationType = .end
                    self.labelNode = labelNode
                    self.addSubnode(labelNode)
                    
                    var size = labelNode.updateLayout(CGSize(width: 120.0, height: CGFloat.greatestFiniteMagnitude))
                    size.height += 2.0
                    labelNode.bounds = CGRect(origin: CGPoint(), size: size)
                    labelNode.position = CGPoint(x: 0.0, y: 10.0 + floor(size.height / 2.0))
                    
                    var strokeSize = strokeLabelNode.updateLayout(CGSize(width: 120.0, height: CGFloat.greatestFiniteMagnitude))
                    strokeSize.height += 2.0
                    strokeLabelNode.bounds = CGRect(origin: CGPoint(), size: strokeSize)
                    strokeLabelNode.position = CGPoint(x: 0.0, y: 10.0 + floor(strokeSize.height / 2.0))
                    
                    strokeLabelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                } else {
                    self.strokeLabelNode?.removeFromSupernode()
                    self.strokeLabelNode = nil
                    self.labelNode?.removeFromSupernode()
                    self.labelNode = nil
                }
            } else {
                let avatarSnapshot = self.avatarNode?.view.snapshotContentTree()
                if let avatarSnapshot = avatarSnapshot, let avatarNode = self.avatarNode {
                    self.backgroundNode.view.addSubview(avatarSnapshot)
                    avatarSnapshot.layer.transform = avatarNode.transform
                    avatarSnapshot.center = CGPoint(x: self.backgroundNode.frame.width / 2.0, y: self.backgroundNode.frame.height / 2.0 - 5.0)
                    
                    avatarNode.transform = CATransform3DMakeScale(0.64, 0.64, 1.0)
                    self.smallNode.addSubnode(avatarNode)
                    avatarNode.position = CGPoint(x: self.smallNode.frame.width / 2.0, y: self.smallNode.frame.height / 2.0)
                }
                
                self.smallNode.isHidden = false
                self.smallNode.transform = CATransform3DMakeScale(0.01, 0.01, 1.0)
                
                self.shadowNode.position = CGPoint(x: self.shadowNode.position.x, y: self.shadowNode.position.y + self.shadowNode.frame.height / 2.0)
                self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 1.0)
                
                UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                    self.smallNode.transform = CATransform3DIdentity
                    self.shadowNode.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
                    
                    if self.dotNode.isHidden {
                        self.smallNode.alpha = 1.0
                    }
                }) { _ in
                    self.animating = false
                    
                    self.shadowNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    
                    self.shadowNode.isHidden = true
                    self.shadowNode.transform = CATransform3DIdentity
                    
                    if let avatarNode = self.avatarNode {
                        self.addSubnode(avatarNode)
                        avatarSnapshot?.removeFromSuperview()
                    }
                }
                
                let previousAlpha = self.dotNode.alpha
                self.dotNode.alpha = 0.0
                self.dotNode.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
                
                if let labelNode = self.labelNode {
                    self.labelNode = nil
                    labelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                        labelNode.removeFromSupernode()
                    })
                    
                    if let strokeLabelNode = self.strokeLabelNode {
                        self.strokeLabelNode = nil
                        strokeLabelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                            strokeLabelNode.removeFromSupernode()
                        })
                    }
                }
            }
        } else {
            self.smallNode.isHidden = selected
            self.shadowNode.isHidden = !selected
            self.dotNode.alpha = selected ? 1.0 : 0.0
            self.smallNode.alpha = 1.0
            
            if !selected {
                self.labelNode?.removeFromSupernode()
                self.labelNode = nil
                self.strokeLabelNode?.removeFromSupernode()
                self.strokeLabelNode = nil
            }
            
            self.layoutSubviews()
        }
    }
    
    var previousPeerId: PeerId?
    func setPeer(context: AccountContext, theme: PresentationTheme, peer: Peer) {
        let avatarNode: AvatarNode
        if let currentAvatarNode = self.avatarNode {
            avatarNode = currentAvatarNode
        } else {
            avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 24.0))
            avatarNode.isLayerBacked = false
            avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 55.0, height: 55.0))
            avatarNode.position = CGPoint()
            self.avatarNode = avatarNode
            self.addSubnode(avatarNode)
        }
        
        if self.previousPeerId != peer.id {
            self.previousPeerId = peer.id
            avatarNode.setPeer(context: context, theme: theme, peer: EnginePeer(peer))
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if let labelNode = self.labelNode {
            var textColor = UIColor.black
            var strokeTextColor = UIColor.white
            if #available(iOS 13.0, *) {
                if self.traitCollection.userInterfaceStyle == .dark {
                    textColor = .white
                    strokeTextColor = .black
                }
            }
            labelNode.attributedText = NSAttributedString(string: labelNode.attributedText?.string ?? "", font: Font.medium(10), textColor: textColor)
            let _ = labelNode.updateLayout(CGSize(width: 120.0, height: CGFloat.greatestFiniteMagnitude))
            
            if let strokeLabelNode = self.strokeLabelNode {
                strokeLabelNode.attributedText = NSAttributedString(string: labelNode.attributedText?.string ?? "", font: Font.bold(10), textColor: strokeTextColor)
                let _ = strokeLabelNode.updateLayout(CGSize(width: 120.0, height: CGFloat.greatestFiniteMagnitude))
            }
        }
    }
    
    var isRaised = false
    func setRaised(_ raised: Bool, animated: Bool, completion: @escaping () -> Void = {}) {
        guard raised != self.isRaised else {
            return
        }
        
        self.isRaised = raised
        self.shadowNode.layer.removeAllAnimations()
        
        if animated {
            self.animating = true
            
            if raised {
                let previousPosition = self.shadowNode.position
                self.shadowNode.position = CGPoint(x: UIScreenPixel, y: -66.0)
                self.shadowNode.layer.animatePosition(from: previousPosition, to: self.shadowNode.position, duration: 0.2, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring) { finished in
                    self.animating = false
                    if finished {
                        completion()
                    }
                }
            } else {
                UIView.animate(withDuration: 0.2, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.0, options: [.allowAnimatedContent], animations: {
                    self.shadowNode.position = CGPoint(x: UIScreenPixel, y: -36.0)
                }) { finished in
                    self.animating = false
                    if finished {
                        completion()
                    }
                }
            }
        } else {
            self.shadowNode.position = CGPoint(x: UIScreenPixel, y: raised ? -66.0 : -36.0)
            completion()
        }
    }
    
    func setCustom(_ custom: Bool, animated: Bool) {
        if let annotation = self.annotation as? LocationPinAnnotation {
            self.iconNode.setSignal(venueIcon(engine: annotation.context.engine, type: "", background: false))
        }
        
        if let avatarNode = self.avatarNode {
            self.backgroundNode.addSubnode(avatarNode)
            avatarNode.position = CGPoint(x: self.backgroundNode.frame.width / 2.0, y: self.backgroundNode.frame.height / 2.0 - 5.0)
        }
        self.shadowNode.position = CGPoint(x: UIScreenPixel, y: -36.0)
        self.backgroundNode.position = CGPoint(x: self.shadowNode.frame.width / 2.0, y: self.shadowNode.frame.height / 2.0)
        self.iconNode.position = CGPoint(x: self.shadowNode.frame.width / 2.0, y: self.shadowNode.frame.height / 2.0 - 5.0)
        
        let transition = {
            let color: UIColor
            if custom, let annotation = self.annotation as? LocationPinAnnotation {
                color = annotation.theme.list.itemAccentColor
            } else {
                color = .white
            }
            self.backgroundNode.image = generateTintedImage(image: UIImage(bundleImageName: "Location/PinBackground"), color: color)
            self.avatarNode?.isHidden = custom
            self.iconNode.isHidden = !custom
        }
        
        let completion = {
            if !custom, let avatarNode = self.avatarNode {
                self.addSubnode(avatarNode)
            }
        }
        
        if animated {
            self.animating = true
            Queue.mainQueue().after(0.01) {
                UIView.transition(with: self.backgroundNode.view, duration: 0.2, options: [.transitionCrossDissolve, .allowAnimatedContent], animations: {
                    transition()
                }) { finished in
                    completion()
                    self.animating = false
                }
            }
            
        } else {
            transition()
            completion()
        }
        self.setNeedsLayout()
        
        self.dotNode.isHidden = !custom
    }
    
    func animateAppearance() {
        guard let annotation = self.annotation as? LocationPinAnnotation, annotation.location != nil && !annotation.forcedSelection else {
            return
        }
        
        self.smallNode.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        
        let avatarNodeTransform = self.avatarNode?.transform
        self.avatarNode?.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        UIView.animate(withDuration: 0.55, delay: 0.0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
            self.smallNode.transform = CATransform3DIdentity
            if let avatarNodeTransform = avatarNodeTransform {
                self.avatarNode?.transform = avatarNodeTransform
            }
        }) { _ in
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    
        guard !self.animating else {
            return
        }
        
        self.dotNode.position = CGPoint()
        self.pulseNode.position = CGPoint()
        self.arrowNode.position = CGPoint()
        self.smallNode.position = CGPoint()
        self.shadowNode.position = CGPoint(x: UIScreenPixel, y: self.isRaised ? -66.0 : -36.0)
        self.backgroundNode.position = CGPoint(x: self.shadowNode.frame.width / 2.0, y: self.shadowNode.frame.height / 2.0)
        self.iconNode.position = CGPoint(x: self.shadowNode.frame.width / 2.0, y: self.shadowNode.frame.height / 2.0 - 5.0)
       
        let smallIconLayout = self.smallIconNode.asyncLayout()
        let smallIconApply = smallIconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: self.smallIconNode.bounds.size, boundingSize: self.smallIconNode.bounds.size, intrinsicInsets: UIEdgeInsets()))
        smallIconApply()
        
        var arguments: VenueIconArguments?
        if let annotation = self.annotation as? LocationPinAnnotation {
            arguments = VenueIconArguments(defaultBackgroundColor: annotation.theme.chat.inputPanel.actionControlFillColor, defaultForegroundColor: annotation.theme.chat.inputPanel.actionControlForegroundColor)
        }
        
        let iconLayout = self.iconNode.asyncLayout()
        let iconApply = iconLayout(TransformImageArguments(corners: ImageCorners(), imageSize: self.iconNode.bounds.size, boundingSize: self.iconNode.bounds.size, intrinsicInsets: UIEdgeInsets(), custom: arguments))
        iconApply()
        
        if let avatarNode = self.avatarNode {
            avatarNode.position = self.isSelected ? CGPoint(x: UIScreenPixel, y: -41.0) : CGPoint()
            avatarNode.transform = self.isSelected ? CATransform3DIdentity : CATransform3DMakeScale(0.64, 0.64, 1.0)
            avatarNode.view.superview?.bringSubviewToFront(avatarNode.view)
        }
        
        if !self.appeared {
            self.appeared = true
            self.initialized = true
            self.animateAppearance()
        }
    }
}
