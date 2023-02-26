import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import HexColor

private struct WallpaperColorPanelNodeState: Equatable {
    var selection: Int?
    var colors: [HSBColor]
    var maximumNumberOfColors: Int
    var preview: Bool
    var simpleGradientGeneration: Bool
    var suggestedNewColor: HSBColor?
}

final class ColorPickerComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let isVisible: Bool
    let bottomInset: CGFloat
    let colors: [UInt32]
    let colorsChanged: ([UInt32]) -> Void
    let cancel: () -> Void
    let done: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        isVisible: Bool,
        bottomInset: CGFloat,
        colors: [UInt32],
        colorsChanged: @escaping ([UInt32]) -> Void,
        cancel: @escaping () -> Void,
        done: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.isVisible = isVisible
        self.bottomInset = bottomInset
        self.colors = colors
        self.colorsChanged = colorsChanged
        self.cancel = cancel
        self.done = done
    }
    
    static func ==(lhs: ColorPickerComponent, rhs: ColorPickerComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        return true
    }

    final class View: UIView, UIGestureRecognizerDelegate {
        private var state: WallpaperColorPanelNodeState
        
        private let bottomSeparatorNode: ASDisplayNode
        
        private let addButton: HighlightableButtonNode
        private let colorPickerNode: WallpaperColorPickerNode

        private var sampleItemNodes: [ColorSampleItemNode] = []
        private let multiColorFieldNode: ColorInputFieldNode
        
        private let cancelHighlightView: UIView
        private let cancelButton: HighlightTrackingButton
        private let doneHighlightView: UIView
        private let doneButton: HighlightTrackingButton
        
        private let topSeparatorView: UIView
        private let separatorView: UIView
        
        private var changingColor = false
        
        init(theme: PresentationTheme, strings: PresentationStrings) {
            self.addButton = HighlightableButtonNode()
            
            self.colorPickerNode = WallpaperColorPickerNode(strings: strings)
            self.multiColorFieldNode = ColorInputFieldNode(theme: theme, displaySwatch: false)
            
            self.bottomSeparatorNode =  ASDisplayNode()
            
            self.state = WallpaperColorPanelNodeState(
                selection: 0,
                colors: [],
                maximumNumberOfColors: 4,
                preview: false,
                simpleGradientGeneration: false
            )
            
            self.cancelHighlightView = UIView()
            self.cancelHighlightView.alpha = 0.0
            self.cancelHighlightView.isUserInteractionEnabled = false
            
            self.cancelButton = HighlightTrackingButton()
            self.cancelButton.isExclusiveTouch = true
            
            self.doneHighlightView = UIView()
            self.doneHighlightView.alpha = 0.0
            self.doneHighlightView.isUserInteractionEnabled = false
            
            self.doneButton = HighlightTrackingButton()
            self.doneButton.isExclusiveTouch = true
            
            self.topSeparatorView = UIView()
            self.separatorView = UIView()
            
            super.init(frame: CGRect())
            
            self.layer.allowsGroupOpacity = true
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveKeyboardGestureRecognizer = true
            self.disablesInteractiveTransitionGestureRecognizer = true
            
            self.addSubnode(self.multiColorFieldNode)
            self.addSubnode(self.colorPickerNode)
            self.addSubnode(self.addButton)
            
            self.addSubview(self.cancelHighlightView)
            self.addSubview(self.cancelButton)
            
            self.addSubview(self.doneHighlightView)
            self.addSubview(self.doneButton)
            
            self.addSubview(self.topSeparatorView)
            self.addSubview(self.separatorView)
            
            self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
            self.doneButton.addTarget(self, action: #selector(self.donePressed), for: .touchUpInside)
            
            self.cancelButton.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.cancelHighlightView.layer.removeAnimation(forKey: "opacity")
                        strongSelf.cancelHighlightView.alpha = 1.0
                    } else {
                        strongSelf.cancelHighlightView.alpha = 0.0
                        strongSelf.cancelHighlightView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    }
                }
            }
            
            self.doneButton.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.doneHighlightView.layer.removeAnimation(forKey: "opacity")
                        strongSelf.doneHighlightView.alpha = 1.0
                    } else {
                        strongSelf.doneHighlightView.alpha = 0.0
                        strongSelf.doneHighlightView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    }
                }
            }
            
            self.addButton.addTarget(self, action: #selector(self.addPressed), forControlEvents: .touchUpInside)

            self.multiColorFieldNode.colorChanged = { [weak self] color, ended in
                if let strongSelf = self {
                    strongSelf.updateState({ current in
                        var updated = current
                        updated.preview = !ended
                        if let index = strongSelf.state.selection {
                            updated.colors[index] = HSBColor(color: color)
                        }
                        return updated
                    })
                }
            }
            self.multiColorFieldNode.colorRemoved = { [weak self] in
                if let strongSelf = self {
                    strongSelf.updateState({ current in
                        var updated = current
                        if let index = strongSelf.state.selection {
                            updated.colors.remove(at: index)
                            if updated.colors.isEmpty {
                                updated.selection = nil
                            } else {
                                updated.selection = max(0, min(index - 1, updated.colors.count - 1))
                            }
                        }
                        return updated
                    }, animated: strongSelf.state.colors.count >= 2)
                }
            }
                        
            self.colorPickerNode.colorChanged = { [weak self] color in
                if let strongSelf = self {
                    strongSelf.changingColor = true
                    strongSelf.updateState({ current in
                        var updated = current
                        updated.preview = true
                        if let index = strongSelf.state.selection {
                            updated.colors[index] = color
                        }
                        return updated
                    }, updateLayout: false)
                }
            }
            self.colorPickerNode.colorChangeEnded = { [weak self] color in
                if let strongSelf = self {
                    strongSelf.changingColor = false
                    strongSelf.updateState({ current in
                        var updated = current
                        updated.preview = false
                        if let index = strongSelf.state.selection {
                            updated.colors[index] = color
                        }
                        return updated
                    }, updateLayout: false)
                }
            }
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func cancelPressed() {
            self.component?.cancel()
        }
        
        @objc private func donePressed() {
            self.component?.done()
        }
        
        @objc private func addPressed() {
            self.multiColorFieldNode.setSkipEndEditingIfNeeded()

            self.updateState({ current in
                var current = current
                if current.colors.count < current.maximumNumberOfColors {
                    if current.colors.isEmpty {
                        current.colors.append(HSBColor(rgb: 0xffffff))
                    } else if current.simpleGradientGeneration {
                        var hsb = current.colors[0].values
                        if hsb.1 > 0.5 {
                            hsb.1 -= 0.15
                        } else {
                            hsb.1 += 0.15
                        }
                        if hsb.0 > 0.5 {
                            hsb.0 -= 0.05
                        } else {
                            hsb.0 += 0.05
                        }
                        current.colors.append(HSBColor(values: hsb))
                    } else if let suggestedNewColor = current.suggestedNewColor {
                        current.colors.append(suggestedNewColor)
                    } else {
                        current.colors.append(current.colors[current.colors.count - 1])
                    }
                    current.selection = current.colors.count - 1
                }
                return current
            })
        }
        
        fileprivate func updateState(_ f: (WallpaperColorPanelNodeState) -> WallpaperColorPanelNodeState, updateLayout: Bool = true, notify: Bool = true, animated: Bool = true) {
            var updateLayout = updateLayout
            let previousColors = self.state.colors
            let previousPreview = self.state.preview
            let previousSelection = self.state.selection
            self.state = f(self.state)
            
            let colorWasRemovable = self.multiColorFieldNode.isRemovable
            self.multiColorFieldNode.isRemovable = self.state.colors.count > 1
            if colorWasRemovable != self.multiColorFieldNode.isRemovable {
                updateLayout = true
            }

            if let index = self.state.selection {
                if self.state.colors.count > index {
                    self.colorPickerNode.color = self.state.colors[index]
                }
            }
        
            if updateLayout, let size = self.validLayout {
                self.updateLayout(size: size, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
            }

            if let index = self.state.selection {
                if self.state.colors.count > index {
                    self.multiColorFieldNode.setColor(self.state.colors[index].color, update: false)
                }
            }

            for i in 0 ..< self.state.colors.count {
                if i < self.sampleItemNodes.count {
                    self.sampleItemNodes[i].update(size: self.sampleItemNodes[i].bounds.size, color: self.state.colors[i].color, isSelected: state.selection == i)
                }
            }

            if notify && (self.state.colors != previousColors || self.state.preview != previousPreview || self.state.selection != previousSelection) {
                self.component?.colorsChanged(self.state.colors.map { $0.rgb })
            }
        }
        
        private var validLayout: CGSize?
        func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
            self.validLayout = size
            
            let separatorHeight = UIScreenPixel
            let topPanelHeight: CGFloat = 50.0
            transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(x: 0.0, y: topPanelHeight, width: size.width, height: separatorHeight))
            
            let fieldHeight: CGFloat = 30.0
            let leftInset: CGFloat = 12.0
            let rightInset: CGFloat = 12.0
            
            let buttonSize = CGSize(width: 26.0, height: 26.0)
            let canAddColors = self.state.colors.count < self.state.maximumNumberOfColors

            transition.updateFrame(node: self.addButton, frame: CGRect(origin: CGPoint(x: size.width - rightInset - buttonSize.width, y: floor((topPanelHeight - buttonSize.height) / 2.0)), size: buttonSize))
            transition.updateAlpha(node: self.addButton, alpha: canAddColors ? 1.0 : 0.0)
            transition.updateSublayerTransformScale(node: self.addButton, scale: canAddColors ? 1.0 : 0.1)
            
            self.multiColorFieldNode.isHidden = false

            let sampleItemSize: CGFloat = 30.0
            let sampleItemSpacing: CGFloat = 10.0

            var nextSampleX = leftInset

            for i in 0 ..< self.state.colors.count {
                var animateIn = false
                let itemNode: ColorSampleItemNode
                if self.sampleItemNodes.count > i {
                    itemNode = self.sampleItemNodes[i]
                } else {
                    itemNode = ColorSampleItemNode(action: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        let index = i
                        strongSelf.updateState({ state in
                            var state = state
                            state.selection = index
                            return state
                        })
                    })
                    self.sampleItemNodes.append(itemNode)
                    self.insertSubview(itemNode.view, aboveSubview: self.multiColorFieldNode.view)
                    animateIn = true
                }

                if i != 0 {
                    nextSampleX += sampleItemSpacing
                }
                itemNode.frame = CGRect(origin: CGPoint(x: nextSampleX, y: (topPanelHeight - sampleItemSize) / 2.0), size: CGSize(width: sampleItemSize, height: sampleItemSize))
                nextSampleX += sampleItemSize
                itemNode.update(size: itemNode.bounds.size, color: self.state.colors[i].color, isSelected: self.state.selection == i)

                if animateIn {
                    transition.animateTransformScale(node: itemNode, from: 0.1)
                    itemNode.alpha = 0.0
                    transition.updateAlpha(node: itemNode, alpha: 1.0)
                }
            }
            if self.sampleItemNodes.count > self.state.colors.count {
                for i in self.state.colors.count ..< self.sampleItemNodes.count {
                    let itemNode = self.sampleItemNodes[i]
                    transition.updateTransformScale(node: itemNode, scale: 0.1)
                    transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                        itemNode?.removeFromSupernode()
                    })
                }
                self.sampleItemNodes.removeSubrange(self.state.colors.count ..< self.sampleItemNodes.count)
            }

            let fieldX = nextSampleX + sampleItemSpacing

            let fieldFrame = CGRect(x: fieldX, y: (topPanelHeight - fieldHeight) / 2.0, width: size.width - fieldX - leftInset - (canAddColors ? (buttonSize.width + sampleItemSpacing) : 0.0), height: fieldHeight)
            transition.updateFrame(node: self.multiColorFieldNode, frame: fieldFrame)
            self.multiColorFieldNode.updateLayout(size: fieldFrame.size, condensed: false, transition: transition)
            
            let colorPickerSize = CGSize(width: size.width, height: size.height - topPanelHeight - separatorHeight)
            transition.updateFrame(node: self.colorPickerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight + separatorHeight), size: colorPickerSize))
            self.colorPickerNode.updateLayout(size: colorPickerSize, transition: transition)
        }
        
        private var component: ColorPickerComponent?
        func update(component: ColorPickerComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let themeChanged = self.component?.theme !== component.theme
            let previousIsVisible = self.component?.isVisible ?? false
            self.component = component
            
            let buttonHeight: CGFloat = 44.0
            let size = CGSize(width: availableSize.width, height: availableSize.height - availableSize.width - 32.0 - buttonHeight - 56.0 - component.bottomInset)
            let panelSize = CGSize(width: availableSize.width, height: size.height + buttonHeight)
            
            if themeChanged {
                self.addButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeColorAddIcon"), color: component.theme.chat.inputPanel.panelControlColor), for: .normal)
                
                self.separatorView.backgroundColor = component.theme.rootController.tabBar.separatorColor
                self.topSeparatorView.backgroundColor = component.theme.rootController.tabBar.separatorColor
                self.cancelHighlightView.backgroundColor = component.theme.list.itemHighlightedBackgroundColor
                self.doneHighlightView.backgroundColor = component.theme.list.itemHighlightedBackgroundColor
                self.bottomSeparatorNode.backgroundColor = component.theme.chat.inputPanel.panelSeparatorColor
                
                self.cancelButton.setAttributedTitle(NSAttributedString(string: component.strings.Common_Cancel, font: Font.regular(17.0), textColor: component.theme.list.itemAccentColor), for: [])
                self.doneButton.setAttributedTitle(NSAttributedString(string: component.strings.Common_Done, font: Font.semibold(17.0), textColor: component.theme.list.itemAccentColor), for: [])
            }
            
            transition.setFrame(view: self.cancelButton, frame: CGRect(x: 0.0, y: size.height, width: availableSize.width / 2.0, height: buttonHeight))
            transition.setFrame(view: self.cancelHighlightView, frame: CGRect(x: 0.0, y: size.height, width: availableSize.width / 2.0, height: buttonHeight))
            
            transition.setFrame(view: self.doneButton, frame: CGRect(x: availableSize.width / 2.0, y: size.height, width: availableSize.width / 2.0, height: buttonHeight))
            transition.setFrame(view: self.doneHighlightView, frame: CGRect(x: availableSize.width / 2.0, y: size.height, width: availableSize.width / 2.0, height: buttonHeight))
            
            transition.setFrame(view: self.topSeparatorView, frame: CGRect(x: 0.0, y: size.height, width: availableSize.width, height: UIScreenPixel))
            transition.setFrame(view: self.separatorView, frame: CGRect(x: size.width / 2.0, y: size.height, width: UIScreenPixel, height: buttonHeight))
            
            if !self.changingColor {
                self.updateState({ current in
                    var updated = current
                    updated.colors = component.colors.map { HSBColor(rgb: $0) }
                    
                    if component.isVisible != previousIsVisible && component.isVisible {
                        updated.selection = 0
                    }
                    
                    return updated
                }, updateLayout: true, notify: false, animated: false)
            
                self.updateLayout(size: size, transition: transition.containedViewLayoutTransition)
            }
            return panelSize
        }
    }

    func makeView() -> View {
        return View(theme: self.theme, strings: self.strings)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private let knobBackgroundImage: UIImage? = {
    return generateImage(CGSize(width: 45.0, height: 45.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setShadow(offset: CGSize(width: 0.0, height: -1.5), blur: 4.5, color: UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 3.0 + UIScreenPixel, dy: 3.0 + UIScreenPixel))
        
        context.setBlendMode(.normal)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 3.0, dy: 3.0))
    }, opaque: false, scale: nil)
}()

private let pointerImage: UIImage? = {
    return generateImage(CGSize(width: 12.0, height: 55.0), opaque: false, scale: nil, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        
        let lineWidth: CGFloat = 1.0
        context.setFillColor(UIColor.black.cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let pointerHeight: CGFloat = 7.0
        context.move(to: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: lineWidth / 2.0 + pointerHeight))
        context.closePath()
        context.drawPath(using: .fillStroke)
        
        context.move(to: CGPoint(x: lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - lineWidth / 2.0 - pointerHeight))
        context.addLine(to: CGPoint(x: size.width - lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        context.closePath()
        context.drawPath(using: .fillStroke)
    })
}()

private let brightnessMaskImage: UIImage? = {
    return generateImage(CGSize(width: 36.0, height: 36.0), opaque: false, scale: nil, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: bounds)
    })?.stretchableImage(withLeftCapWidth: 18, topCapHeight: 18)
}()

private let brightnessGradientImage: UIImage? = {
    return generateImage(CGSize(width: 160.0, height: 1.0), opaque: false, scale: nil, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let gradientColors = [UIColor.black.withAlphaComponent(0.0), UIColor.black].map { $0.cgColor } as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    })
}()

private final class HSBParameter: NSObject {
    let hue: CGFloat
    let saturation: CGFloat
    let value: CGFloat
    
    init(hue: CGFloat, saturation: CGFloat, value: CGFloat) {
        self.hue = hue
        self.saturation = saturation
        self.value = value
        super.init()
    }
}

private final class WallpaperColorKnobNode: ASDisplayNode {
    var color: HSBColor = HSBColor(hue: 0.0, saturation: 0.0, brightness: 1.0) {
        didSet {
            if self.color != oldValue {
                self.colorNode.backgroundColor = self.color.color
            }
        }
    }
    
    private let backgroundNode: ASImageNode
    private let colorNode: ASDisplayNode
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = knobBackgroundImage
        
        self.colorNode = ASDisplayNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.colorNode)
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
        self.colorNode.frame = self.bounds.insetBy(dx: 7.0 - UIScreenPixel, dy: 7.0 - UIScreenPixel)
        self.colorNode.cornerRadius = self.colorNode.frame.width / 2.0
    }
}

private final class WallpaperColorHueSaturationNode: ASDisplayNode {
    var value: CGFloat = 1.0 {
        didSet {
            if self.value != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = true
        self.displaysAsynchronously = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return HSBParameter(hue: 1.0, saturation: 1.0, value: 1.0)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let parameters = parameters as? HSBParameter else {
            return
        }
        let context = UIGraphicsGetCurrentContext()!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let colors = [UIColor(rgb: 0xff0000).cgColor, UIColor(rgb: 0xffff00).cgColor, UIColor(rgb: 0x00ff00).cgColor, UIColor(rgb: 0x00ffff).cgColor, UIColor(rgb: 0x0000ff).cgColor, UIColor(rgb: 0xff00ff).cgColor, UIColor(rgb: 0xfe0000).cgColor]
        var locations: [CGFloat] = [0.0, 0.16667, 0.33333, 0.5, 0.66667, 0.83334, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
        
        let overlayColors = [UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff).cgColor]
        var overlayLocations: [CGFloat] = [0.0, 1.0]
        let overlayGradient = CGGradient(colorsSpace: colorSpace, colors: overlayColors as CFArray, locations: &overlayLocations)!
        context.drawLinearGradient(overlayGradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.height), options: CGGradientDrawingOptions())
        
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 1.0 - parameters.value).cgColor)
        context.fill(bounds)
    }
    
    var tap: ((CGPoint) -> Void)?
    var panBegan: ((CGPoint) -> Void)?
    var panChanged: ((CGPoint, Bool) -> Void)?
    
    var initialTouchLocation: CGPoint?
    var touchMoved = false
    var previousTouchLocation: CGPoint?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if let touchLocation = touches.first?.location(in: self.view) {
            self.touchMoved = false
            self.initialTouchLocation = touchLocation
            self.previousTouchLocation = nil
        }
        
        self.view.window?.endEditing(true)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        if let touchLocation = touches.first?.location(in: self.view), let initialLocation = self.initialTouchLocation {
            let dX = touchLocation.x - initialLocation.x
            let dY = touchLocation.y - initialLocation.y
            if !self.touchMoved && dX * dX + dY * dY > 3.0 {
                self.touchMoved = true
                self.panBegan?(touchLocation)
                self.previousTouchLocation = touchLocation
            } else if let previousTouchLocation = self.previousTouchLocation  {
                let dX = touchLocation.x - previousTouchLocation.x
                let dY = touchLocation.y - previousTouchLocation.y
                let translation = CGPoint(x: dX, y: dY)
            
                self.panChanged?(translation, false)
                self.previousTouchLocation = touchLocation
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if self.touchMoved {
            if let touchLocation = touches.first?.location(in: self.view), let previousTouchLocation = self.previousTouchLocation {
                let dX = touchLocation.x - previousTouchLocation.x
                let dY = touchLocation.y - previousTouchLocation.y
                let translation = CGPoint(x: dX, y: dY)
            
                self.panChanged?(translation, true)
            }
        } else if let touchLocation = self.initialTouchLocation {
            self.tap?(touchLocation)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
}

private final class WallpaperColorBrightnessNode: ASDisplayNode {
    private let gradientNode: ASImageNode
    private let maskNode: ASImageNode
    
    var hsb: (CGFloat, CGFloat, CGFloat) = (0.0, 1.0, 1.0) {
        didSet {
            if self.hsb.0 != oldValue.0 || self.hsb.1 != oldValue.1 {
                let color = UIColor(hue: hsb.0, saturation: hsb.1, brightness: 1.0, alpha: 1.0)
                self.backgroundColor = color
            }
        }
    }
    
    override init() {
        self.gradientNode = ASImageNode()
        self.gradientNode.displaysAsynchronously = false
        self.gradientNode.displayWithoutProcessing = true
        self.gradientNode.image = brightnessGradientImage
        self.gradientNode.contentMode = .scaleToFill
        
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.displayWithoutProcessing = true
        self.maskNode.image = brightnessMaskImage
        self.maskNode.contentMode = .scaleToFill
        
        super.init()
        
        self.isOpaque = true
        self.addSubnode(self.gradientNode)
        self.addSubnode(self.maskNode)
    }
    
    override func layout() {
        super.layout()
        
        self.gradientNode.frame = self.bounds
        self.maskNode.frame = self.bounds
    }
}

struct HSBColor: Equatable {
    static func == (lhs: HSBColor, rhs: HSBColor) -> Bool {
        return lhs.values.h == rhs.values.h && lhs.values.s == rhs.values.s && lhs.values.b == rhs.values.b
    }
    
    let values: (h: CGFloat, s: CGFloat, b: CGFloat)
    let backingColor: UIColor
    
    var hue: CGFloat {
        return self.values.h
    }
    
    var saturation: CGFloat {
        return self.values.s
    }
    
    var brightness: CGFloat {
        return self.values.b
    }
    
    var rgb: UInt32 {
        return self.color.argb
    }
    
    init(values: (h: CGFloat, s: CGFloat, b: CGFloat)) {
        self.values = values
        self.backingColor = UIColor(hue: values.h, saturation: values.s, brightness: values.b, alpha: 1.0)
    }
    
    init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        self.values = (h: hue, s: saturation, b: brightness)
        self.backingColor = UIColor(hue: self.values.h, saturation: self.values.s, brightness: self.values.b, alpha: 1.0)
    }
    
    init(color: UIColor) {
        self.values = color.hsb
        self.backingColor = color
    }
    
    init(rgb: UInt32) {
        self.init(color: UIColor(rgb: rgb))
    }
    
    var color: UIColor {
        return self.backingColor
    }
}

final class WallpaperColorPickerNode: ASDisplayNode {
    private let brightnessNode: WallpaperColorBrightnessNode
    private let brightnessKnobNode: ASImageNode
    private let colorNode: WallpaperColorHueSaturationNode
    private let colorKnobNode: WallpaperColorKnobNode
    
    private var validLayout: CGSize?
    
    var color: HSBColor = HSBColor(hue: 0.0, saturation: 1.0, brightness: 1.0) {
        didSet {
            if self.color != oldValue {
                self.update()
            }
        }
    }
    
    var colorChanged: ((HSBColor) -> Void)?
    var colorChangeEnded: ((HSBColor) -> Void)?
    
    init(strings: PresentationStrings) {
        self.brightnessNode = WallpaperColorBrightnessNode()
        self.brightnessNode.hitTestSlop = UIEdgeInsets(top: -16.0, left: -16.0, bottom: -16.0, right: -16.0)
        self.brightnessKnobNode = ASImageNode()
        self.brightnessKnobNode.image = pointerImage
        self.brightnessKnobNode.isUserInteractionEnabled = false
        self.colorNode = WallpaperColorHueSaturationNode()
        self.colorNode.hitTestSlop = UIEdgeInsets(top: -16.0, left: -16.0, bottom: -16.0, right: -16.0)
        self.colorKnobNode = WallpaperColorKnobNode()
        
        super.init()
        
        self.backgroundColor = .white
        
        self.addSubnode(self.brightnessNode)
        self.addSubnode(self.brightnessKnobNode)
        self.addSubnode(self.colorNode)
        self.addSubnode(self.colorKnobNode)
        
        self.update()
                
        self.colorNode.tap = { [weak self] location in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            
            let colorHeight = size.height - 66.0
            
            let newHue = max(0.0, min(1.0, location.x / size.width))
            let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
            strongSelf.color = HSBColor(hue: newHue, saturation: newSaturation, brightness: strongSelf.color.brightness)
            
            strongSelf.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
            
            strongSelf.update()
            strongSelf.colorChangeEnded?(strongSelf.color)
        }
        
        self.colorNode.panBegan = { [weak self] location in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            
            let previousColor = strongSelf.color
            
            let colorHeight = size.height - 66.0

            let newHue = max(0.0, min(1.0, location.x / size.width))
            let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
            strongSelf.color = HSBColor(hue: newHue, saturation: newSaturation, brightness: strongSelf.color.brightness)
            
            strongSelf.updateKnobLayout(size: size, panningColor: true, transition: .immediate)
            
            if strongSelf.color != previousColor {
                strongSelf.colorChanged?(strongSelf.color)
            }
        }
        
        self.colorNode.panChanged = { [weak self] translation, ended in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            
            let previousColor = strongSelf.color
            
            let colorHeight = size.height - 66.0
            
            let newHue = max(0.0, min(1.0, strongSelf.color.hue + translation.x / size.width))
            let newSaturation = max(0.0, min(1.0, strongSelf.color.saturation - translation.y / colorHeight))
            strongSelf.color = HSBColor(hue: newHue, saturation: newSaturation, brightness: strongSelf.color.brightness)
            
            if ended {
                strongSelf.updateKnobLayout(size: size, panningColor: false, transition: .animated(duration: 0.3, curve: .easeInOut))
            } else {
                strongSelf.updateKnobLayout(size: size, panningColor: true, transition: .immediate)
            }
                
            if strongSelf.color != previousColor || ended {
                strongSelf.update()
                if ended {
                    strongSelf.colorChangeEnded?(strongSelf.color)
                } else {
                    strongSelf.colorChanged?(strongSelf.color)
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.disablesInteractiveModalDismiss = true
        
        let brightnessPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(WallpaperColorPickerNode.brightnessPan))
        self.brightnessNode.view.addGestureRecognizer(brightnessPanRecognizer)
    }
    
    private func update() {
        self.backgroundColor = .white
        self.colorNode.value = self.color.brightness
        self.brightnessNode.hsb = self.color.values
        self.colorKnobNode.color = self.color
    }
    
    private func updateKnobLayout(size: CGSize, panningColor: Bool, transition: ContainedViewLayoutTransition) {
        let knobSize = CGSize(width: 45.0, height: 45.0)
        
        let colorHeight = size.height - 66.0
        var colorKnobFrame = CGRect(x: floorToScreenPixels(-knobSize.width / 2.0 + size.width * self.color.hue), y: floorToScreenPixels(-knobSize.height / 2.0 + (colorHeight * (1.0 - self.color.saturation))), width: knobSize.width, height: knobSize.height)
        var origin = colorKnobFrame.origin
        if !panningColor {
            origin = CGPoint(x: max(0.0, min(origin.x, size.width - knobSize.width)), y: max(0.0, min(origin.y, colorHeight - knobSize.height)))
        } else {
            origin = origin.offsetBy(dx: 0.0, dy: -32.0)
        }
        colorKnobFrame.origin = origin
        transition.updateFrame(node: self.colorKnobNode, frame: colorKnobFrame)
        
        let inset: CGFloat = 15.0
        let brightnessKnobSize = CGSize(width: 12.0, height: 55.0)
        let brightnessKnobFrame = CGRect(x: inset - brightnessKnobSize.width / 2.0 + (size.width - inset * 2.0) * (1.0 - self.color.brightness), y: size.height - 65.0, width: brightnessKnobSize.width, height: brightnessKnobSize.height)
        transition.updateFrame(node: self.brightnessKnobNode, frame: brightnessKnobFrame)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let colorHeight = size.height - 66.0
        transition.updateFrame(node: self.colorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: colorHeight))
        
        let inset: CGFloat = 15.0
        transition.updateFrame(node: self.brightnessNode, frame: CGRect(x: inset, y: size.height - 55.0, width: size.width - inset * 2.0, height: 35.0))
        
        self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
    }
    
    @objc private func brightnessPan(_ recognizer: UIPanGestureRecognizer) {
        guard let size = self.validLayout else {
            return
        }
        
        let previousColor = self.color
        
        let transition = recognizer.translation(in: recognizer.view)
        let brightnessWidth: CGFloat = size.width - 42.0 * 2.0
        let newValue = max(0.0, min(1.0, self.color.brightness - transition.x / brightnessWidth))
        self.color = HSBColor(hue: self.color.hue, saturation: self.color.saturation, brightness: newValue)
                
        var ended = false
        switch recognizer.state {
            case .changed:
                self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
                recognizer.setTranslation(CGPoint(), in: recognizer.view)
            case .ended:
                self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
                ended = true
            default:
                break
        }
        
        if self.color != previousColor || ended {
            self.update()
            if ended {
                self.colorChangeEnded?(self.color)
            } else {
                self.colorChanged?(self.color)
            }
        }
        
        self.view.window?.endEditing(true)
    }
}

private var currentTextInputBackgroundImage: (UIColor, CGFloat, UIImage)?
private func textInputBackgroundImage(fieldColor: UIColor, diameter: CGFloat) -> UIImage? {
    if let current = currentTextInputBackgroundImage {
        if current.0.isEqual(fieldColor) && current.1.isEqual(to: diameter) {
            return current.2
        }
    }
    
    let image = generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
        context.setFillColor(fieldColor.cgColor)
        context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
    })?.stretchableImage(withLeftCapWidth: Int(diameter) / 2, topCapHeight: Int(diameter) / 2)
    if let image = image {
        currentTextInputBackgroundImage = (fieldColor, diameter, image)
        return image
    } else {
        return nil
    }
}

private func generateSwatchBorderImage(theme: PresentationTheme) -> UIImage? {
    return nil
}

private class ColorInputFieldNode: ASDisplayNode, UITextFieldDelegate {
    private var theme: PresentationTheme
    
    private let swatchNode: ASDisplayNode
    private let borderNode: ASImageNode
    private let removeButton: HighlightableButtonNode
    private let textBackgroundNode: ASImageNode
    private let selectionNode: ASDisplayNode
    let textFieldNode: TextFieldNode
    private let measureNode: ImmediateTextNode
    private let prefixNode: ASTextNode
    
    private var gestureRecognizer: UITapGestureRecognizer?
        
    var colorChanged: ((UIColor, Bool) -> Void)?
    var colorRemoved: (() -> Void)?
    var colorSelected: (() -> Void)?
    
    private var color: UIColor?

    private var isDefault = false {
        didSet {
            self.updateSelectionVisibility()
        }
    }
    
    var isRemovable: Bool = false {
        didSet {
            self.removeButton.isUserInteractionEnabled = self.isRemovable
        }
    }
   
    private var previousIsDefault: Bool?
    private var previousColor: UIColor?
    private var validLayout: (CGSize, Bool)?
    
    private var skipEndEditing = false

    private let displaySwatch: Bool
    
    init(theme: PresentationTheme, displaySwatch: Bool = true) {
        self.theme = theme

        self.displaySwatch = displaySwatch
        
        self.textBackgroundNode = ASImageNode()
        self.textBackgroundNode.image = textInputBackgroundImage(fieldColor: theme.list.itemInputField.backgroundColor, diameter: 30.0)
        self.textBackgroundNode.displayWithoutProcessing = true
        self.textBackgroundNode.displaysAsynchronously = false
        
        self.selectionNode = ASDisplayNode()
        self.selectionNode.backgroundColor = theme.chat.inputPanel.panelControlAccentColor.withAlphaComponent(0.2)
        self.selectionNode.cornerRadius = 3.0
        self.selectionNode.isUserInteractionEnabled = false
        
        self.textFieldNode = TextFieldNode()
        self.measureNode = ImmediateTextNode()
        
        self.prefixNode = ASTextNode()
        self.prefixNode.attributedText = NSAttributedString(string: "#", font: Font.regular(17.0), textColor: self.theme.chat.inputPanel.inputTextColor)
        
        self.swatchNode = ASDisplayNode()
        self.swatchNode.cornerRadius = 10.5
        
        self.borderNode = ASImageNode()
        self.borderNode.displaysAsynchronously = false
        self.borderNode.displayWithoutProcessing = true
        self.borderNode.image = generateSwatchBorderImage(theme: theme)
        
        self.removeButton = HighlightableButtonNode()
        self.removeButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeColorRemoveIcon"), color: theme.chat.inputPanel.inputControlColor), for: .normal)
                
        super.init()
        
        self.addSubnode(self.textBackgroundNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.textFieldNode)
        self.addSubnode(self.prefixNode)
        self.addSubnode(self.swatchNode)
        self.addSubnode(self.borderNode)
        self.addSubnode(self.removeButton)
        
        self.removeButton.addTarget(self, action: #selector(self.removePressed), forControlEvents: .touchUpInside)
    }
        
    override func didLoad() {
        super.didLoad()
        
        self.textFieldNode.textField.font = Font.regular(17.0)
        self.textFieldNode.textField.textColor = self.theme.chat.inputPanel.inputTextColor
        self.textFieldNode.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.textFieldNode.textField.autocorrectionType = .no
        self.textFieldNode.textField.autocapitalizationType = .allCharacters
        self.textFieldNode.textField.keyboardType = .asciiCapable
        self.textFieldNode.textField.returnKeyType = .done
        self.textFieldNode.textField.delegate = self
        self.textFieldNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textFieldNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textFieldNode.textField.tintColor = self.theme.list.itemAccentColor
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped(_:)))
        self.view.addGestureRecognizer(gestureRecognizer)
        self.gestureRecognizer = gestureRecognizer
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.textBackgroundNode.image = textInputBackgroundImage(fieldColor: self.theme.list.itemInputField.backgroundColor, diameter: 30.0)
        
        self.textFieldNode.textField.textColor = self.isDefault ? self.theme.chat.inputPanel.inputPlaceholderColor : self.theme.chat.inputPanel.inputTextColor
        self.textFieldNode.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.textFieldNode.textField.tintColor = self.theme.list.itemAccentColor
        
        self.selectionNode.backgroundColor = theme.chat.inputPanel.panelControlAccentColor.withAlphaComponent(0.2)
        self.borderNode.image = generateSwatchBorderImage(theme: theme)
        self.updateBorderVisibility()
    }
    
    func setColor(_ color: UIColor, isDefault: Bool = false, update: Bool = true, ended: Bool = true) {
        self.color = color
        self.isDefault = isDefault
        let text = color.hexString.uppercased()
        self.textFieldNode.textField.text = text
        self.textFieldNode.textField.textColor = isDefault ? self.theme.chat.inputPanel.inputPlaceholderColor : self.theme.chat.inputPanel.inputTextColor
        if let (size, _) = self.validLayout {
            self.updateSelectionLayout(size: size, transition: .immediate)
        }
        if update {
            self.colorChanged?(color, ended)
        }
        self.swatchNode.backgroundColor = color
        self.updateBorderVisibility()
    }
    
    private func updateBorderVisibility() {
        guard let color = self.swatchNode.backgroundColor else {
            return
        }
        let inputBackgroundColor = self.theme.chat.inputPanel.inputBackgroundColor
        if color.distance(to: inputBackgroundColor) < 200 {
            self.borderNode.alpha = 1.0
        } else {
            self.borderNode.alpha = 0.0
        }
    }
    
    @objc private func removePressed() {
        if self.textFieldNode.textField.isFirstResponder {
            self.skipEndEditing = true
        }
        
        self.colorRemoved?()
    }
    
    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.colorSelected?()
        }
    }
        
    @objc internal func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var updated = textField.text ?? ""
        updated.replaceSubrange(updated.index(updated.startIndex, offsetBy: range.lowerBound) ..< updated.index(updated.startIndex, offsetBy: range.upperBound), with: string)
        if updated.hasPrefix("#") {
            updated.removeFirst()
        }
        if updated.count <= 6 && updated.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil {
            textField.text = updated.uppercased()
            textField.textColor = self.theme.chat.inputPanel.inputTextColor
            
            if updated.count == 6, let color = UIColor(hexString: updated) {
                self.setColor(color)
            }
            
            if let (size, _) = self.validLayout {
                self.updateSelectionLayout(size: size, transition: .immediate)
            }
        }
        return false
    }
    
    @objc func textFieldTextChanged(_ sender: UITextField) {
        if let color = self.colorFromCurrentText() {
            self.setColor(color)
        }
        
        if let (size, _) = self.validLayout {
            self.updateSelectionLayout(size: size, transition: .immediate)
        }
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.skipEndEditing = true
        if let color = self.colorFromCurrentText() {
            self.setColor(color)
        } else {
            self.setColor(self.previousColor ?? .black, isDefault: self.previousIsDefault ?? false)
        }
        self.textFieldNode.textField.resignFirstResponder()
        return false
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        self.skipEndEditing = false
        self.previousColor = self.color
        self.previousIsDefault = self.isDefault

        textField.textColor = self.theme.chat.inputPanel.inputTextColor

        return true
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        if !self.skipEndEditing {
            if let color = self.colorFromCurrentText() {
                self.setColor(color)
            } else {
                self.setColor(self.previousColor ?? .black, isDefault: self.previousIsDefault ?? false)
            }
        }
    }
    
    func setSkipEndEditingIfNeeded() {
        if self.textFieldNode.textField.isFirstResponder && self.colorFromCurrentText() != nil {
            self.skipEndEditing = true
        }
    }
    
    private func colorFromCurrentText() -> UIColor? {
        if let text = self.textFieldNode.textField.text, text.count == 6, let color = UIColor(hexString: text) {
            return color
        } else {
            return nil
        }
    }
    
    private func updateSelectionLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.measureNode.attributedText = NSAttributedString(string: self.textFieldNode.textField.text ?? "", font: self.textFieldNode.textField.font)
        let size = self.measureNode.updateLayout(size)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(x: self.textFieldNode.frame.minX, y: 6.0, width: max(0.0, size.width), height: 20.0))
    }
    
    private func updateSelectionVisibility() {
        self.selectionNode.isHidden = true
    }
    
    func updateLayout(size: CGSize, condensed: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, condensed)
        
        let swatchFrame = CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 21.0, height: 21.0))
        transition.updateFrame(node: self.swatchNode, frame: swatchFrame)
        transition.updateFrame(node: self.borderNode, frame: swatchFrame)

        self.swatchNode.isHidden = !self.displaySwatch
        
        let textPadding: CGFloat
        if self.displaySwatch {
            textPadding = condensed ? 31.0 : 37.0
        } else {
            textPadding = 12.0
        }
        
        transition.updateFrame(node: self.textBackgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        transition.updateFrame(node: self.textFieldNode, frame: CGRect(x: textPadding + 10.0, y: 1.0, width: size.width - (21.0 + textPadding), height: size.height - 2.0))
        
        self.updateSelectionLayout(size: size, transition: transition)
        
        let prefixSize = self.prefixNode.measure(size)
        transition.updateFrame(node: self.prefixNode, frame: CGRect(origin: CGPoint(x: textPadding - UIScreenPixel, y: 6.0), size: prefixSize))
        
        let removeSize = CGSize(width: 30.0, height: 30.0)
        let removeOffset: CGFloat = condensed ? 3.0 : 0.0
        transition.updateFrame(node: self.removeButton, frame: CGRect(origin: CGPoint(x: size.width - removeSize.width + removeOffset, y: 0.0), size: removeSize))
        self.removeButton.alpha = self.isRemovable ? 1.0 : 0.0
    }
}

private final class ColorSampleItemNode: ASImageNode {
    private struct State: Equatable {
        var color: UInt32
        var size: CGSize
        var isSelected: Bool
    }

    private var action: () -> Void
    private var validState: State?

    init(action: @escaping () -> Void) {
        self.action = action

        super.init()

        self.isUserInteractionEnabled = true
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }

    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action()
        }
    }

    func update(size: CGSize, color: UIColor, isSelected: Bool) {
        let state = State(color: color.rgb, size: size, isSelected: isSelected)
        if self.validState != state {
            self.validState = state

            self.image = generateImage(CGSize(width: size.width, height: size.height), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))

                context.setBlendMode(.softLight)
                context.setStrokeColor(UIColor(white: 0.0, alpha: 0.3).cgColor)
                context.setLineWidth(UIScreenPixel)
                context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: UIScreenPixel, dy: UIScreenPixel))

                if isSelected {
                    context.setBlendMode(.copy)
                    context.setStrokeColor(UIColor.clear.cgColor)
                    let lineWidth: CGFloat = 2.0
                    context.setLineWidth(lineWidth)
                    let inset: CGFloat = 2.0 + lineWidth / 2.0
                    context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset))
                }
            })
        }
    }
}
