import Foundation
import UIKit
import AsyncDisplayKit
import MediaPlayer
import SwiftSignalKit

private let volumeNotificationKey = "AVSystemController_SystemVolumeDidChangeNotification"
private let volumeParameterKey = "AVSystemController_AudioVolumeNotificationParameter"
private let changeReasonParameterKey = "AVSystemController_AudioVolumeChangeReasonNotificationParameter"
private let explicitChangeReasonValue = "ExplicitVolumeChange"

final class VolumeControlStatusBar: UIView {
    private let control: MPVolumeView
    private var observer: Any?
    private var currentValue: Float
    
    var valueChanged: ((Float, Float) -> Void)?
    
    private var disposable: Disposable?
    private var ignoreAdjustmentOnce = false
    
    init(frame: CGRect, shouldBeVisible: Signal<Bool, NoError>) {
        self.control = MPVolumeView(frame: CGRect(origin: CGPoint(x: -100.0, y: -100.0), size: CGSize(width: 100.0, height: 20.0)))
        self.control.alpha = 0.0001
        self.currentValue = AVAudioSession.sharedInstance().outputVolume
        
        super.init(frame: frame)
        
        self.addSubview(self.control)
        self.observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: volumeNotificationKey), object: nil, queue: OperationQueue.main, using: { [weak self] notification in
            if let strongSelf = self, let userInfo = notification.userInfo {
                if let reason = userInfo[changeReasonParameterKey], reason as? String != explicitChangeReasonValue {
                    return
                }
                
                if let volume = userInfo[volumeParameterKey] as? Float {
                    let previous = strongSelf.currentValue
                    if !previous.isEqual(to: volume) {
                        strongSelf.currentValue = volume
                        if strongSelf.ignoreAdjustmentOnce {
                            strongSelf.ignoreAdjustmentOnce = false
                        } else {
                            if strongSelf.control.superview != nil {
                                strongSelf.valueChanged?(previous, volume)
                            }
                        }
                    }
                }
            }
        })
        
        self.disposable = (shouldBeVisible
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if value {
                if strongSelf.control.superview == nil {
                    strongSelf.ignoreAdjustmentOnce = true
                    strongSelf.addSubview(strongSelf.control)
                }
            } else {
                strongSelf.control.removeFromSuperview()
                strongSelf.ignoreAdjustmentOnce = false
            }
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.disposable?.dispose()
    }
}

final class VolumeControlStatusBarNode: ASDisplayNode {
    var innerGraphics: (UIImage, UIImage, UIImage, Bool)?
    var graphics: (UIImage, UIImage, UIImage)? = nil {
        didSet {
            if self.isDark {
                self.innerGraphics = generateDarkGraphics(self.graphics)
            } else {
                if let graphics = self.graphics {
                    self.innerGraphics = (graphics.0, graphics.1, graphics.2, false)
                } else {
                    self.innerGraphics = nil
                }
            }
        }
    }
    private let backgroundNode: ASImageNode
    private let iconNode: ASImageNode
    private let foregroundNode: ASImageNode
    private let foregroundClippingNode: ASDisplayNode
    
    private var validLayout: ContainerViewLayout?
    
    var isDark: Bool = false {
        didSet {
            if self.isDark != oldValue {
                if self.isDark {
                    self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: UIColor(white: 0.6, alpha: 1.0))
                    self.foregroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: .white)
                    
                    self.innerGraphics = generateDarkGraphics(self.graphics)
                } else {
                    self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: UIColor(rgb: 0xc5c5c5))
                    self.foregroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: .black)
                    
                    if let graphics = self.graphics {
                        self.innerGraphics = (graphics.0, graphics.1, graphics.2, false)
                    }
                }
                self.updateIcon()
            }
        }
    }
    private var value: CGFloat = 1.0
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: UIColor(rgb: 0xc5c5c5))
        
        self.foregroundNode = ASImageNode()
        self.foregroundNode.isLayerBacked = true
        self.foregroundNode.displaysAsynchronously = false
        self.foregroundNode.displayWithoutProcessing = true
        self.foregroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: .black)
        
        self.foregroundClippingNode = ASDisplayNode()
        self.foregroundClippingNode.clipsToBounds = true
        self.foregroundClippingNode.addSubnode(self.foregroundNode)
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.foregroundClippingNode)
        self.addSubnode(self.iconNode)
    }
    
    func generateDarkGraphics(_ graphics: (UIImage, UIImage, UIImage)?) -> (UIImage, UIImage, UIImage, Bool)? {
        if var (offImage, halfImage, onImage) = graphics {
            offImage = generateTintedImage(image: offImage, color: UIColor.white)!
            halfImage = generateTintedImage(image: halfImage, color: UIColor.white)!
            onImage = generateTintedImage(image: onImage, color: UIColor.white)!
            return (offImage, halfImage, onImage, true)
        } else {
            return nil
        }
    }
    
    func updateGraphics() {
        if self.isDark {
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: UIColor(white: 0.6, alpha: 1.0))
            self.foregroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: .white)
        } else {
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: UIColor(white: 0.6, alpha: 1.0))
            self.foregroundNode.image = generateStretchableFilledCircleImage(diameter: 4.0, color: .black)
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        let barHeight: CGFloat = 4.0
        var barWidth: CGFloat
        
        let statusBarHeight: CGFloat
        var sideInset: CGFloat
        if let actual = layout.statusBarHeight {
            statusBarHeight = actual
        } else {
            statusBarHeight = 20.0
        }
        if layout.safeInsets.left.isZero && layout.safeInsets.top.isZero && layout.intrinsicInsets.left.isZero && layout.intrinsicInsets.top.isZero {
            sideInset = 4.0
        } else {
            sideInset = 12.0
        }
        
        let iconRect = CGRect(x: sideInset + 4.0, y: 14.0, width: 21.0, height: 16.0)
        if !layout.intrinsicInsets.bottom.isZero {
            if layout.size.width > 375.0 {
                barWidth = 88.0 - sideInset * 2.0
            } else {
                barWidth = 80.0 - sideInset * 2.0
            }
            if self.graphics != nil {
                self.iconNode.isHidden = false
                barWidth -= iconRect.width - 8.0
                sideInset += iconRect.width + 8.0
            }
        } else {
            self.iconNode.isHidden = true
            barWidth = layout.size.width - sideInset * 2.0
        }
        
        let boundingRect = CGRect(origin: CGPoint(x: sideInset, y: floor((statusBarHeight - barHeight) / 2.0)), size: CGSize(width: barWidth, height: barHeight))
        
        transition.updateFrame(node: self.iconNode, frame: iconRect)
        transition.updateFrame(node: self.backgroundNode, frame: boundingRect)
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(origin: CGPoint(), size: boundingRect.size))
        transition.updateFrame(node: self.foregroundClippingNode, frame: CGRect(origin: boundingRect.origin, size: CGSize(width: self.value * boundingRect.width, height: boundingRect.height)))
    }
    
    func updateValue(from fromValue: CGFloat, to toValue: CGFloat) {
        if let layout = self.validLayout {
            if self.foregroundClippingNode.layer.animation(forKey: "bounds") == nil {
                self.value = fromValue
                self.updateLayout(layout: layout, transition: .immediate)
            }
            self.value = toValue
            self.updateLayout(layout: layout, transition: .animated(duration: 0.25, curve: .spring))
            
            self.updateIcon()
        } else {
            self.value = toValue
        }
    }
    
    private func updateIcon() {
        if let graphics = self.innerGraphics {
            if self.value > 0.5 {
                self.iconNode.image = graphics.2
            } else if self.value > 0.0 {
                self.iconNode.image = graphics.1
            } else {
                self.iconNode.image = graphics.0
            }
        }
    }
}
