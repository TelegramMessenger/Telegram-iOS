import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let compactNameFont = Font.regular(28.0)
private let regularNameFont = Font.regular(36.0)

private let compactStatusFont = Font.regular(18.0)
private let regularStatusFont = Font.regular(18.0)

enum CallControllerStatusValue: Equatable {
    case text(string: String, displayLogo: Bool)
    case timer((String, Bool) -> String, Double)
    
    static func ==(lhs: CallControllerStatusValue, rhs: CallControllerStatusValue) -> Bool {
        switch lhs {
            case let .text(text, displayLogo):
                if case .text(text, displayLogo) = rhs {
                    return true
                } else {
                    return false
                }
            case let .timer(_, referenceTime):
                if case .timer(_, referenceTime) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class CallControllerStatusNode: ASDisplayNode {
    private let titleNode: TextNode
    private let statusContainerNode: ASDisplayNode
    private let statusNode: TextNode
    private let statusMeasureNode: TextNode
    private let receptionNode: CallControllerReceptionNode
    private let logoNode: ASImageNode
    
    var title: String = ""
    var subtitle: String = ""
    var status: CallControllerStatusValue = .text(string: "", displayLogo: false) {
        didSet {
            if self.status != oldValue {
                self.statusTimer?.invalidate()
                
                if let snapshotView = self.statusContainerNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = self.statusContainerNode.frame
                    self.view.insertSubview(snapshotView, belowSubview: self.statusContainerNode.view)
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    snapshotView.layer.animateScale(from: 1.0, to: 0.3, duration: 0.3, removeOnCompletion: false)
                    snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: snapshotView.frame.height / 2.0), duration: 0.3, delay: 0.0, removeOnCompletion: false, additive: true)
                    
                    self.statusContainerNode.layer.animateScale(from: 0.3, to: 1.0, duration: 0.3)
                    self.statusContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    self.statusContainerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -snapshotView.frame.height / 2.0), to: CGPoint(), duration: 0.3, delay: 0.0, additive: true)
                }
                                
                if case .timer = self.status {
                    self.statusTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        if let strongSelf = self, let validLayoutWidth = strongSelf.validLayoutWidth {
                            let _ = strongSelf.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                        }
                    }, queue: Queue.mainQueue())
                    self.statusTimer?.start()
                } else {
                    if let validLayoutWidth = self.validLayoutWidth {
                        let _ = self.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                    }
                }
            }
        }
    }
    var reception: Int32? {
        didSet {
            if self.reception != oldValue {
                if let reception = self.reception {
                    self.receptionNode.reception = reception
                    
                    if oldValue == nil {
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
                        transition.updateAlpha(node: self.receptionNode, alpha: 1.0)
                    }
                } else if self.reception == nil, oldValue != nil {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
                    transition.updateAlpha(node: self.receptionNode, alpha: 0.0)
                }
                
                if (oldValue == nil) != (self.reception != nil) {
                    if let validLayoutWidth = self.validLayoutWidth {
                        let _ = self.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                    }
                }
            }
        }
    }
    
    private var statusTimer: SwiftSignalKit.Timer?
    private var validLayoutWidth: CGFloat?
    
    override init() {
        self.titleNode = TextNode()
        self.statusContainerNode = ASDisplayNode()
        self.statusNode = TextNode()
        self.statusNode.displaysAsynchronously = false
        self.statusMeasureNode = TextNode()
       
        self.receptionNode = CallControllerReceptionNode()
        self.receptionNode.alpha = 0.0
        
        self.logoNode = ASImageNode()
        self.logoNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallTitleLogo"), color: .white)
        self.logoNode.isHidden = true
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusContainerNode)
        self.statusContainerNode.addSubnode(self.statusNode)
        self.statusContainerNode.addSubnode(self.receptionNode)
        self.statusContainerNode.addSubnode(self.logoNode)
    }
    
    deinit {
        self.statusTimer?.invalidate()
    }
    
    func setVisible(_ visible: Bool, transition: ContainedViewLayoutTransition) {
        let alpha: CGFloat = visible ? 1.0 : 0.0
        transition.updateAlpha(node: self.titleNode, alpha: alpha)
        transition.updateAlpha(node: self.statusContainerNode, alpha: alpha)
    }
    
    func updateLayout(constrainedWidth: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayoutWidth = constrainedWidth
        
        let nameFont: UIFont
        let statusFont: UIFont
        if constrainedWidth < 330.0 {
            nameFont = compactNameFont
            statusFont = compactStatusFont
        } else {
            nameFont = regularNameFont
            statusFont = regularStatusFont
        }
        
        var statusOffset: CGFloat = 0.0
        let statusText: String
        let statusMeasureText: String
        var statusDisplayLogo: Bool = false
        switch self.status {
        case let .text(text, displayLogo):
            statusText = text
            statusMeasureText = text
            statusDisplayLogo = displayLogo
            if displayLogo {
                statusOffset += 10.0
            }
        case let .timer(format, referenceTime):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            let measureDurationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
                measureDurationString = "00:00:00"
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
                measureDurationString = "00:00"
            }
            statusText = format(durationString, false)
            statusMeasureText = format(measureDurationString, true)
            if self.reception != nil {
                statusOffset += 8.0
            }
        }
        
        let spacing: CGFloat = 1.0
        let (titleLayout, titleApply) = TextNode.asyncLayout(self.titleNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.title, font: nameFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        let (statusMeasureLayout, statusMeasureApply) = TextNode.asyncLayout(self.statusMeasureNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusMeasureText, font: statusFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        let (statusLayout, statusApply) = TextNode.asyncLayout(self.statusNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusText, font: statusFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        
        let _ = titleApply()
        let _ = statusApply()
        let _ = statusMeasureApply()
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((constrainedWidth - titleLayout.size.width) / 2.0), y: 0.0), size: titleLayout.size)
        self.statusContainerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: titleLayout.size.height + spacing), size: CGSize(width: constrainedWidth, height: statusLayout.size.height))
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor((constrainedWidth - statusMeasureLayout.size.width) / 2.0) + statusOffset, y: 0.0), size: statusLayout.size)
        self.receptionNode.frame = CGRect(origin: CGPoint(x: self.statusNode.frame.minX - receptionNodeSize.width, y: 9.0), size: receptionNodeSize)
        self.logoNode.isHidden = !statusDisplayLogo
        if let image = self.logoNode.image, let firstLineRect = statusMeasureLayout.linesRects().first {
            let firstLineOffset = floor((statusMeasureLayout.size.width - firstLineRect.width) / 2.0)
            self.logoNode.frame = CGRect(origin: CGPoint(x: self.statusNode.frame.minX + firstLineOffset - image.size.width - 7.0, y: 5.0), size: image.size)
        }
        
        return titleLayout.size.height + spacing + statusLayout.size.height
    }
}


private final class CallControllerReceptionNodeParameters: NSObject {
    let reception: Int32
    
    init(reception: Int32) {
        self.reception = reception
    }
}

private let receptionNodeSize = CGSize(width: 24.0, height: 10.0)

final class CallControllerReceptionNode : ASDisplayNode {
    var reception: Int32 = 4 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = false
        self.isLayerBacked = true
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return CallControllerReceptionNodeParameters(reception: self.reception)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        
        if let parameters = parameters as? CallControllerReceptionNodeParameters{
            let width: CGFloat = 3.0
            var spacing: CGFloat = 1.5
            if UIScreenScale > 2 {
                spacing = 4.0 / 3.0
            }
            
            for i in 0 ..< 4 {
                let height = 4.0 + 2.0 * CGFloat(i)
                let rect = CGRect(x: bounds.minX + CGFloat(i) * (width + spacing), y: receptionNodeSize.height - height, width: width, height: height)
                
                if i >= parameters.reception {
                    context.setAlpha(0.4)
                }
                
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 0.5)
                context.addPath(path.cgPath)
                context.fillPath()
            }
        }
    }
}
