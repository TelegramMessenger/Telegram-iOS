import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext


private class CallStatusBarBackgroundNodeDrawingState: NSObject {
    let amplitude: CGFloat
    
    let speaking: Bool
    let transitionArguments: (startTime: Double, duration: Double)?
    
    init(amplitude: CGFloat, speaking: Bool, transitionArguments: (Double, Double)?) {
        self.amplitude = amplitude
        self.speaking = speaking
        self.transitionArguments = transitionArguments
    }
}

private class CallStatusBarBackgroundNode: ASDisplayNode {
    var muted = true
    
    var audioLevel: Float = 0.0
    var presentationAudioLevel: Float = 0.0
    
    private var animator: ConstantDisplayLinkAnimator?
    
    override init() {
        super.init()
                
        self.isOpaque = false
        
        self.updateAnimations()
    }
    
    func updateAnimations() {
        let animator: ConstantDisplayLinkAnimator
        if let current = self.animator {
            animator = current
        } else {
            animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                self?.updateAnimations()
            })
            animator.frameInterval = 2
            self.animator = animator
        }
        animator.isPaused = true
        
        self.setNeedsDisplay()
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return CallStatusBarBackgroundNodeDrawingState(amplitude: 1.0, speaking: false, transitionArguments: nil)
    }

    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        let drawStart = CACurrentMediaTime()

        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }

        guard let parameters = parameters as? CallStatusBarBackgroundNodeDrawingState else {
            return
        }
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0x007fff).cgColor, UIColor(rgb:0x00afff).cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
    }
}

public class CallStatusBarNodeImpl: CallStatusBarNode {
    public enum Content {
        case call(PresentationCall)
        case groupCall(PresentationGroupCall)
    }
    
    private let microphoneNode: VoiceChatMicrophoneNode
    private let backgroundNode: CallStatusBarBackgroundNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private let audioLevelDisposable = MetaDisposable()
    
    private var currentSize: CGSize?
    private var currentContent: Content?
    
    public override init() {
        self.backgroundNode = CallStatusBarBackgroundNode()
        self.microphoneNode = VoiceChatMicrophoneNode()
        self.titleNode = ImmediateTextNode()
        self.subtitleNode = ImmediateTextNode()
        
        super.init()
                
        self.addSubnode(self.backgroundNode)
//        self.addSubnode(self.microphoneNode)
//        self.addSubnode(self.titleNode)
//        self.addSubnode(self.subtitleNode)
    }
    
    deinit {
        self.audioLevelDisposable.dispose()
    }
    
    public func update(content: Content) {
        self.currentContent = content
        self.update()
    }
    
    public override func update(size: CGSize) {
        self.currentSize = size
        self.update()
    }
    
    private func update() {
        guard let size = self.currentSize, let content = self.currentContent else {
            return
        }
        
        self.titleNode.attributedText = NSAttributedString(string: "Voice Chat", font: Font.semibold(13.0), textColor: .white)
        self.subtitleNode.attributedText = NSAttributedString(string: "2 members", font: Font.regular(13.0), textColor: .white)
        
        let animationSize: CGFloat = 25.0
        let iconSpacing: CGFloat = 0.0
        let spacing: CGFloat = 5.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: 160.0, height: size.height))
        
        let totalWidth = animationSize + iconSpacing + titleSize.width + spacing + subtitleSize.width
        let horizontalOrigin: CGFloat = floor((size.width - totalWidth) / 2.0)
        
        let contentHeight: CGFloat = 24.0
        let verticalOrigin: CGFloat = size.height - contentHeight
        
        self.microphoneNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin + floor((contentHeight - animationSize) / 2.0)), size: CGSize(width: animationSize, height: animationSize))
        self.microphoneNode.update(state: VoiceChatMicrophoneNode.State(muted: true, color: UIColor.white), animated: true)
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin + animationSize + iconSpacing, y: verticalOrigin + floor((contentHeight - titleSize.height) / 2.0)), size: titleSize)
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin + animationSize + iconSpacing + titleSize.width + spacing, y: verticalOrigin + floor((contentHeight - subtitleSize.height) / 2.0)), size: subtitleSize)
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
    }
}
