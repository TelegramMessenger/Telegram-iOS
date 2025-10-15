import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import SwiftSignalKit
import ChatPresentationInterfaceState
import AnimatedCountLabelNode
import TelegramStringFormatting

private func generateClearImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 17.0, height: 17.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        context.setStrokeColor(UIColor.clear.cgColor)
        context.setLineCap(.round)
        context.setLineWidth(1.66)
        context.move(to: CGPoint(x: 6.0, y: 6.0))
        context.addLine(to: CGPoint(x: 11.0, y: 11.0))
        context.strokePath()
        context.move(to: CGPoint(x: size.width - 6.0, y: 6.0))
        context.addLine(to: CGPoint(x: size.width - 11.0, y: 11.0))
        context.strokePath()
    })
}


final class BoostSlowModeButton: HighlightTrackingButtonNode {
    let containerNode: ASDisplayNode
    let backgroundNode: ASImageNode
    let textNode: ImmediateAnimatedCountLabelNode
    let iconNode: ASImageNode
    
    private var updateTimer: SwiftSignalKit.Timer?
    
    var requestUpdate: () -> Void = {}
    
    override init(pointerStyle: PointerStyle? = nil) {
        self.containerNode = ASDisplayNode()
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.image = generateGradientImage(size: CGSize(width: 100.0, height: 2.0), scale: 1.0, colors: [UIColor(rgb: 0x9076ff), UIColor(rgb: 0xbc6de8)], locations: [0.0, 1.0], direction: .horizontal)
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateClearImage(color: .white)
        
        self.textNode = ImmediateAnimatedCountLabelNode()
        self.textNode.alwaysOneDirection = true
        self.textNode.isUserInteractionEnabled = false
        
        super.init(pointerStyle: pointerStyle)
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.iconNode)
        self.containerNode.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let self {
                if highlighted {
                    self.containerNode.layer.animateScale(from: 1.0, to: 0.75, duration: 0.4, removeOnCompletion: false)
                } else if let presentationLayer = self.containerNode.layer.presentation() {
                    self.containerNode.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                }
            }
        }
    }
        
    func update(size: CGSize, interfaceState: ChatPresentationInterfaceState) -> CGSize {
        var text = ""
        if let slowmodeState = interfaceState.slowmodeState {
            let relativeTimestamp: CGFloat
            switch slowmodeState.variant {
            case let .timestamp(validUntilTimestamp):
                let timestamp = CGFloat(Date().timeIntervalSince1970)
                relativeTimestamp = CGFloat(validUntilTimestamp) - timestamp
            case .pendingMessages:
                relativeTimestamp = CGFloat(slowmodeState.timeout)
            }
            
            self.updateTimer?.invalidate()
            
            if relativeTimestamp >= 0.0 {
                text = stringForDuration(Int32(relativeTimestamp))
                
                self.updateTimer = SwiftSignalKit.Timer(timeout: 1.0 / 60.0, repeat: false, completion: { [weak self] in
                    self?.requestUpdate()
                }, queue: .mainQueue())
                self.updateTimer?.start()
            }
        } else {
            self.updateTimer?.invalidate()
            self.updateTimer = nil
        }
        
        let font = Font.with(size: 15.0, design: .round, weight: .semibold, traits: [.monospacedNumbers])
        let textColor = UIColor.white
        
        var segments: [AnimatedCountLabelNode.Segment] = []
        var textCount = 0
        
        for char in text {
            if let intValue = Int(String(char)) {
                segments.append(.number(intValue, NSAttributedString(string: String(char), font: font, textColor: textColor)))
            } else {
                segments.append(.text(textCount, NSAttributedString(string: String(char), font: font, textColor: textColor)))
                textCount += 1
            }
        }
        self.textNode.segments = segments
        
        let textSize = self.textNode.updateLayout(size: CGSize(width: 200.0, height: 100.0), animated: true)
        let totalSize = CGSize(width: textSize.width > 0.0 ? textSize.width + 38.0 : 33.0, height: 33.0)
        
        self.containerNode.bounds = CGRect(origin: .zero, size: totalSize)
        self.containerNode.position = CGPoint(x: totalSize.width / 2.0, y: totalSize.height / 2.0)
        self.backgroundNode.frame = CGRect(origin: .zero, size: totalSize)
        self.backgroundNode.cornerRadius = totalSize.height / 2.0
        self.textNode.frame = CGRect(origin: CGPoint(x: 9.0, y: floorToScreenPixels((totalSize.height - textSize.height) / 2.0)), size: textSize)
        if let icon = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: totalSize.width - icon.size.width - 7.0, y: floorToScreenPixels((totalSize.height - icon.size.height) / 2.0)), size: icon.size)
        }
        return totalSize
    }
}
