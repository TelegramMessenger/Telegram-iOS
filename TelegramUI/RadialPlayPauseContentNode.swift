import Foundation
import Display
import AsyncDisplayKit
import LegacyComponents
import SwiftSignalKit

enum RadialPlayPauseMode {
    case play
    case pause
}

class RadialPlayPauseContentNode: RadialStatusContentNode {
    var color: UIColor {
        didSet {
            self.leftShape.fillColor = self.color.cgColor
            self.rightShape.fillColor = self.color.cgColor
            self.setNeedsDisplay()
        }
    }
    
    private var effectiveProgress: CGFloat = 1.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    private var animationCompletionTimer: SwiftSignalKit.Timer?
    
    private var isAnimatingProgress: Bool {
        return self.pop_animation(forKey: "progress") != nil || self.animationCompletionTimer != nil
    }
    
    private var enqueuedReadyForTransition: (() -> Void)?
    
    private let leftShape = CAShapeLayer()
    private let rightShape = CAShapeLayer()
    
    init(color: UIColor, mode: RadialPlayPauseMode) {
        self.color = color
        
        super.init()
        
        self.leftShape.fillColor = self.color.cgColor
        self.rightShape.fillColor = self.color.cgColor
        
        self.isLayerBacked = true
        self.isOpaque = false
        
        self.layer.addSublayer(self.leftShape)
        self.layer.addSublayer(self.rightShape)
    }
    
    override func enqueueReadyForTransition(_ f: @escaping () -> Void) {
        if self.isAnimatingProgress {
            self.enqueuedReadyForTransition = f
        } else {
            f()
        }
    }
}
