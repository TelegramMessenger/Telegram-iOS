import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent

public class EdgeEffectView: UIView {
    public enum Edge {
        case top
        case bottom
    }

    private let contentView: UIView
    private let contentMaskView: UIImageView
    private var blurView: VariableBlurView?
    
    public override init(frame: CGRect) {
        self.contentView = UIView()
        self.contentMaskView = UIImageView()
        self.contentView.mask = self.contentMaskView
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateColor(color: UIColor, transition: ComponentTransition) {
        transition.setBackgroundColor(view: self.contentView, color: color)
    }
    
    public func update(content: UIColor?, blur: Bool = false, alpha: CGFloat = 0.75, rect: CGRect, edge: Edge, edgeSize: CGFloat, transition: ComponentTransition) {
        #if DEBUG && false
        let content: UIColor = .blue
        //let blur: Bool = !"".isEmpty
        #endif
        
        if let content {
            transition.setBackgroundColor(view: self.contentView, color: content)
        }
        transition.setAlpha(view: self.contentView, alpha: alpha)
        
        let bounds = CGRect(origin: CGPoint(), size: rect.size)
        transition.setFrame(view: self.contentView, frame: bounds)
        transition.setFrame(view: self.contentMaskView, frame: bounds)
        
        if self.contentMaskView.image?.size.height != edgeSize {
            if edgeSize > 0.0 {
                self.contentMaskView.image = EdgeEffectView.generateEdgeGradient(baseHeight: edgeSize, isInverted: edge == .bottom)
            } else {
                self.contentMaskView.image = nil
            }
        }
        
        if blur {
            let blurHeight: CGFloat = max(edgeSize, bounds.height - 14.0)
            let blurFrame = CGRect(origin: CGPoint(x: 0.0, y: edge == .bottom ? (bounds.height - blurHeight) : 0.0), size: CGSize(width: bounds.width, height: blurHeight))
            
            let blurView: VariableBlurView
            if let current = self.blurView {
                blurView = current
            } else {
                blurView = VariableBlurView(maxBlurRadius: 1.0)
                self.insertSubview(blurView, at: 0)
                self.blurView = blurView
            }
            
            blurView.update(
                size: blurFrame.size,
                constantHeight: max(1.0, edgeSize - 4.0),
                isInverted: edge == .bottom,
                gradient: EdgeEffectView.generateEdgeGradientData(baseHeight: max(1.0, edgeSize - 4.0)),
                transition: transition.containedViewLayoutTransition
            )
            transition.setFrame(view: blurView, frame: blurFrame)
            blurView.transform = self.contentMaskView.transform
        } else if let blurView = self.blurView {
            self.blurView = nil
            blurView.removeFromSuperview()
        }
    }
    
    public static func generateEdgeGradientData(baseHeight: CGFloat) -> VariableBlurEffect.Gradient {
        let gradientColors: [CGFloat] = [
            0.8470588235294118,
            0.8431372549019608,
            0.8392156862745098,
            0.8352941176470589,
            0.8313725490196078,
            0.8274509803921568,
            0.8235294117647058,
            0.8196078431372549,
            0.8156862745098039,
            0.8117647058823529,
            0.807843137254902,
            0.803921568627451,
            0.8,
            0.7960784313725491,
            0.792156862745098,
            0.788235294117647,
            0.7843137254901961,
            0.7803921568627451,
            0.7764705882352941,
            0.7725490196078432,
            0.7686274509803921,
            0.7647058823529411,
            0.7607843137254902,
            0.7568627450980392,
            0.7529411764705882,
            0.7490196078431373,
            0.7450980392156863,
            0.7411764705882353,
            0.7372549019607844,
            0.7333333333333334,
            0.7294117647058824,
            0.7254901960784313,
            0.7215686274509804,
            0.7176470588235294,
            0.7137254901960784,
            0.7098039215686274,
            0.7019607843137254,
            0.6941176470588235,
            0.6862745098039216,
            0.6784313725490196,
            0.6705882352941177,
            0.6588235294117647,
            0.6509803921568628,
            0.6431372549019607,
            0.6313725490196078,
            0.6235294117647059,
            0.615686274509804,
            0.603921568627451,
            0.596078431372549,
            0.5882352941176471,
            0.5764705882352941,
            0.5647058823529412,
            0.5529411764705883,
            0.5411764705882354,
            0.5294117647058824,
            0.5176470588235293,
            0.5058823529411764,
            0.49411764705882355,
            0.4862745098039216,
            0.4745098039215686,
            0.4627450980392157,
            0.4549019607843138,
            0.44313725490196076,
            0.43137254901960786,
            0.41960784313725485,
            0.4117647058823529,
            0.4,
            0.388235294117647,
            0.3764705882352941,
            0.3647058823529412,
            0.3529411764705882,
            0.3411764705882353,
            0.3294117647058824,
            0.3176470588235294,
            0.3058823529411765,
            0.2941176470588235,
            0.2823529411764706,
            0.2705882352941177,
            0.2588235294117647,
            0.2431372549019608,
            0.2313725490196078,
            0.21568627450980393,
            0.19999999999999996,
            0.18039215686274512,
            0.16078431372549018,
            0.14117647058823535,
            0.11764705882352944,
            0.09019607843137256,
            0.04705882352941182,
            0.0,
        ]
        
        let gradientColorNorm = gradientColors.max()!

        let gradientLocations: [CGFloat] = [
            0.0,
            0.020905923344947737,
            0.059233449477351915,
            0.08710801393728224,
            0.10801393728222997,
            0.12195121951219512,
            0.13240418118466898,
            0.14285714285714285,
            0.15331010452961671,
            0.1602787456445993,
            0.17073170731707318,
            0.18118466898954705,
            0.1916376306620209,
            0.20209059233449478,
            0.20905923344947736,
            0.21254355400696864,
            0.21951219512195122,
            0.2264808362369338,
            0.23344947735191637,
            0.23693379790940766,
            0.24390243902439024,
            0.24738675958188153,
            0.25435540069686413,
            0.2578397212543554,
            0.2613240418118467,
            0.2682926829268293,
            0.27177700348432055,
            0.27526132404181186,
            0.28222996515679444,
            0.2857142857142857,
            0.289198606271777,
            0.2926829268292683,
            0.2961672473867596,
            0.29965156794425085,
            0.30313588850174217,
            0.30662020905923343,
            0.313588850174216,
            0.3205574912891986,
            0.32752613240418116,
            0.3344947735191638,
            0.34146341463414637,
            0.34843205574912894,
            0.3554006968641115,
            0.3623693379790941,
            0.3693379790940767,
            0.37630662020905925,
            0.3797909407665505,
            0.3867595818815331,
            0.39372822299651566,
            0.397212543554007,
            0.40418118466898956,
            0.41114982578397213,
            0.4181184668989547,
            0.4250871080139373,
            0.43205574912891986,
            0.43902439024390244,
            0.445993031358885,
            0.4529616724738676,
            0.4564459930313589,
            0.4634146341463415,
            0.47038327526132406,
            0.4738675958188153,
            0.4808362369337979,
            0.4878048780487805,
            0.49477351916376305,
            0.49825783972125437,
            0.5052264808362369,
            0.5121951219512195,
            0.519163763066202,
            0.5261324041811847,
            0.5331010452961672,
            0.5400696864111498,
            0.5470383275261324,
            0.554006968641115,
            0.5609756097560976,
            0.5679442508710801,
            0.5749128919860628,
            0.5818815331010453,
            0.5888501742160279,
            0.5993031358885017,
            0.6062717770034843,
            0.6167247386759582,
            0.627177700348432,
            0.6411149825783972,
            0.6585365853658537,
            0.6759581881533101,
            0.6968641114982579,
            0.7282229965156795,
            0.7909407665505227,
            1.0,
        ]
        
        return VariableBlurEffect.Gradient(
            height: baseHeight,
            alpha: gradientColors.map { $0 / gradientColorNorm },
            positions: gradientLocations
        )
    }
    
    public static func generateEdgeGradient(baseHeight: CGFloat, isInverted: Bool, extendsInwards: Bool = false) -> UIImage {
        let gradientColors: [CGFloat] = [
            0.8470588235294118,
            0.8431372549019608,
            0.8392156862745098,
            0.8352941176470589,
            0.8313725490196078,
            0.8274509803921568,
            0.8235294117647058,
            0.8196078431372549,
            0.8156862745098039,
            0.8117647058823529,
            0.807843137254902,
            0.803921568627451,
            0.8,
            0.7960784313725491,
            0.792156862745098,
            0.788235294117647,
            0.7843137254901961,
            0.7803921568627451,
            0.7764705882352941,
            0.7725490196078432,
            0.7686274509803921,
            0.7647058823529411,
            0.7607843137254902,
            0.7568627450980392,
            0.7529411764705882,
            0.7490196078431373,
            0.7450980392156863,
            0.7411764705882353,
            0.7372549019607844,
            0.7333333333333334,
            0.7294117647058824,
            0.7254901960784313,
            0.7215686274509804,
            0.7176470588235294,
            0.7137254901960784,
            0.7098039215686274,
            0.7019607843137254,
            0.6941176470588235,
            0.6862745098039216,
            0.6784313725490196,
            0.6705882352941177,
            0.6588235294117647,
            0.6509803921568628,
            0.6431372549019607,
            0.6313725490196078,
            0.6235294117647059,
            0.615686274509804,
            0.603921568627451,
            0.596078431372549,
            0.5882352941176471,
            0.5764705882352941,
            0.5647058823529412,
            0.5529411764705883,
            0.5411764705882354,
            0.5294117647058824,
            0.5176470588235293,
            0.5058823529411764,
            0.49411764705882355,
            0.4862745098039216,
            0.4745098039215686,
            0.4627450980392157,
            0.4549019607843138,
            0.44313725490196076,
            0.43137254901960786,
            0.41960784313725485,
            0.4117647058823529,
            0.4,
            0.388235294117647,
            0.3764705882352941,
            0.3647058823529412,
            0.3529411764705882,
            0.3411764705882353,
            0.3294117647058824,
            0.3176470588235294,
            0.3058823529411765,
            0.2941176470588235,
            0.2823529411764706,
            0.2705882352941177,
            0.2588235294117647,
            0.2431372549019608,
            0.2313725490196078,
            0.21568627450980393,
            0.19999999999999996,
            0.18039215686274512,
            0.16078431372549018,
            0.14117647058823535,
            0.11764705882352944,
            0.09019607843137256,
            0.04705882352941182,
            0.0,
        ]
        
        let gradientColorNorm = gradientColors.max()!

        let gradientLocations: [CGFloat] = [
            0.0,
            0.020905923344947737,
            0.059233449477351915,
            0.08710801393728224,
            0.10801393728222997,
            0.12195121951219512,
            0.13240418118466898,
            0.14285714285714285,
            0.15331010452961671,
            0.1602787456445993,
            0.17073170731707318,
            0.18118466898954705,
            0.1916376306620209,
            0.20209059233449478,
            0.20905923344947736,
            0.21254355400696864,
            0.21951219512195122,
            0.2264808362369338,
            0.23344947735191637,
            0.23693379790940766,
            0.24390243902439024,
            0.24738675958188153,
            0.25435540069686413,
            0.2578397212543554,
            0.2613240418118467,
            0.2682926829268293,
            0.27177700348432055,
            0.27526132404181186,
            0.28222996515679444,
            0.2857142857142857,
            0.289198606271777,
            0.2926829268292683,
            0.2961672473867596,
            0.29965156794425085,
            0.30313588850174217,
            0.30662020905923343,
            0.313588850174216,
            0.3205574912891986,
            0.32752613240418116,
            0.3344947735191638,
            0.34146341463414637,
            0.34843205574912894,
            0.3554006968641115,
            0.3623693379790941,
            0.3693379790940767,
            0.37630662020905925,
            0.3797909407665505,
            0.3867595818815331,
            0.39372822299651566,
            0.397212543554007,
            0.40418118466898956,
            0.41114982578397213,
            0.4181184668989547,
            0.4250871080139373,
            0.43205574912891986,
            0.43902439024390244,
            0.445993031358885,
            0.4529616724738676,
            0.4564459930313589,
            0.4634146341463415,
            0.47038327526132406,
            0.4738675958188153,
            0.4808362369337979,
            0.4878048780487805,
            0.49477351916376305,
            0.49825783972125437,
            0.5052264808362369,
            0.5121951219512195,
            0.519163763066202,
            0.5261324041811847,
            0.5331010452961672,
            0.5400696864111498,
            0.5470383275261324,
            0.554006968641115,
            0.5609756097560976,
            0.5679442508710801,
            0.5749128919860628,
            0.5818815331010453,
            0.5888501742160279,
            0.5993031358885017,
            0.6062717770034843,
            0.6167247386759582,
            0.627177700348432,
            0.6411149825783972,
            0.6585365853658537,
            0.6759581881533101,
            0.6968641114982579,
            0.7282229965156795,
            0.7909407665505227,
            1.0,
        ]
        
        var resizingInverted = isInverted
        if extendsInwards {
            resizingInverted = false
        }
        let _ = resizingInverted
        
        return generateGradientImage(
            size: CGSize(width: 1.0, height: baseHeight),
            colors: gradientColors.map { UIColor(white: 0.0, alpha: $0 / gradientColorNorm) },
            locations: gradientLocations,
            isInverted: isInverted
        )!.resizableImage(withCapInsets: UIEdgeInsets(top: resizingInverted ? baseHeight : 0.0, left: 0.0, bottom: resizingInverted ? 0.0 : baseHeight, right: 0.0), resizingMode: .stretch)
    }
}

public final class EdgeEffectComponent: Component {
    private let color: UIColor
    private let blur: Bool
    private let alpha: CGFloat
    private let size: CGSize
    private let edge: EdgeEffectView.Edge
    private let edgeSize: CGFloat
    
    public init(
        color: UIColor,
        blur: Bool,
        alpha: CGFloat,
        size: CGSize,
        edge: EdgeEffectView.Edge,
        edgeSize: CGFloat
    ) {
        self.color = color
        self.blur = blur
        self.alpha = alpha
        self.size = size
        self.edge = edge
        self.edgeSize = edgeSize
    }
    
    public static func == (lhs: EdgeEffectComponent, rhs: EdgeEffectComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.blur != rhs.blur {
            return false
        }
        if lhs.alpha != rhs.alpha {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.edge != rhs.edge {
            return false
        }
        if lhs.edgeSize != rhs.edgeSize {
            return false
        }
        return true
    }
    
    public final class View: EdgeEffectView {
        func update(component: EdgeEffectComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.update(content: component.color, blur: component.blur, alpha: component.alpha, rect: CGRect(origin: .zero, size: component.size), edge: component.edge, edgeSize: component.edgeSize, transition: transition)
            
            return component.size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class VariableBlurEffect {
    private struct Params: Equatable {
        let size: CGSize
        let constantHeight: CGFloat
        let placement: Placement
        let gradient: Gradient
        
        init(size: CGSize, constantHeight: CGFloat, placement: Placement, gradient: Gradient) {
            self.size = size
            self.constantHeight = constantHeight
            self.placement = placement
            self.gradient = gradient
        }
    }
    
    public final class Gradient: Equatable {
        public let height: CGFloat
        public let alpha: [CGFloat]
        public let positions: [CGFloat]
        
        public init(height: CGFloat, alpha: [CGFloat], positions: [CGFloat]) {
            self.height = height
            self.alpha = alpha
            self.positions = positions
        }
        
        public static func ==(lhs: Gradient, rhs: Gradient) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.height != rhs.height {
                return false
            }
            if lhs.alpha != rhs.alpha {
                return false
            }
            if lhs.positions != rhs.positions {
                return false
            }
            return true
        }
    }
    
    public struct Placement: Equatable {
        public enum Position {
            case top
            case bottom
        }
        
        public let position: Position
        public let inwardsExtension: CGFloat?
        
        public init(position: Position, inwardsExtension: CGFloat?) {
            self.position = position
            self.inwardsExtension = inwardsExtension
        }
    }
    
    private let layer: CALayer
    private let isTransparent: Bool
    private let maxBlurRadius: CGFloat
    
    private var params: Params?
    private var gradientImage: UIImage?
    
    private let imageSubview: UIImageView?
    
    public init(layer: CALayer, isTransparent: Bool = false, maxBlurRadius: CGFloat = 20.0) {
        self.layer = layer
        self.isTransparent = isTransparent
        self.maxBlurRadius = maxBlurRadius
        
        if #available(iOS 26.0, *) {
            let imageSubview = UIImageView()
            self.imageSubview = imageSubview
            imageSubview.layer.name = "mask_source"
            
            if let variableBlur = CALayer.variableBlur() {
                variableBlur.setValue(self.maxBlurRadius, forKey: "inputRadius")
                variableBlur.setValue("mask_source", forKey: "inputSourceSublayerName")
                if isTransparent {
                    variableBlur.setValue(true, forKey: "inputNormalizeEdgesTransparent")
                } else {
                    variableBlur.setValue(true, forKey: "inputNormalizeEdges")
                }
                self.layer.filters = [variableBlur]
            }
            
            self.layer.addSublayer(imageSubview.layer)
        } else {
            self.imageSubview = nil
        }
    }
    
    private func updateLegacyEffect() {
        guard let params = self.params else {
            return
        }
        guard let variableBlur = CALayer.variableBlur() else {
            return
        }
        guard let gradientImage = self.gradientImage else {
            return
        }
        variableBlur.setValue(self.maxBlurRadius, forKey: "inputRadius")
        
        if self.isTransparent {
            variableBlur.setValue(true, forKey: "inputNormalizeEdgesTransparent")
        } else {
            variableBlur.setValue(true, forKey: "inputNormalizeEdges")
        }
        
        let image: UIImage? = generateImage(CGSize(width: 1.0, height: min(800.0, params.size.height)), rotatedContext: { size, context in
            UIGraphicsPushContext(context)
            defer {
                UIGraphicsPopContext()
            }
            
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let mainEffectFrame: CGRect
            let additionalEffectFrame: CGRect
            
            if params.placement.inwardsExtension != nil {
                mainEffectFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height))
                additionalEffectFrame = CGRect()
            } else if params.placement.position == .bottom {
                mainEffectFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: params.constantHeight))
                additionalEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: params.constantHeight), size: CGSize(width: size.width, height: max(0.0, size.height - params.constantHeight)))
            } else {
                mainEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - params.constantHeight), size: CGSize(width: size.width, height: params.constantHeight))
                additionalEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: max(0.0, size.height - params.constantHeight)))
            }
            
            context.setFillColor(UIColor(white: 0.0, alpha: 1.0).cgColor)
            context.fill(additionalEffectFrame)
            
            gradientImage.draw(in: mainEffectFrame, blendMode: .normal, alpha: 1.0)
        })
        
        if let cgImage = image?.cgImage {
            variableBlur.setValue(cgImage, forKey: "inputMaskImage")
        }
        
        self.layer.filters = [variableBlur]
    }
    
    public func update(size: CGSize, constantHeight: CGFloat, placement: Placement, gradient: Gradient, transition: ContainedViewLayoutTransition) {
        let params = Params(size: size, constantHeight: constantHeight, placement: placement, gradient: gradient)
        if params == self.params {
            return
        }
        
        let isGradientUpdated = gradient != self.params?.gradient
        let isHeightUpdated = gradient.height != self.params?.gradient.height || size.height != self.params?.size.height
        
        if isGradientUpdated {
            if let inwardsExtension = params.placement.inwardsExtension {
                let baseHeight = max(1.0, params.gradient.height + inwardsExtension)
                let resizingInverted = params.placement.position != .bottom
                self.gradientImage = generateImage(CGSize(width: 1.0, height: baseHeight), opaque: false, rotatedContext: { size, context in
                    let bounds = CGRect(origin: CGPoint(), size: size)
                    context.clear(bounds)
                    
                    let gradientColors = [UIColor.white.withAlphaComponent(1.0).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray
                    
                    var locations: [CGFloat] = [0.0, 1.0]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                    if params.placement.position == .bottom {
                        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: max(0.0, size.height - inwardsExtension)), end: CGPoint(x: 0.0, y: 0.0), options: CGGradientDrawingOptions())
                        if inwardsExtension > 0.0 {
                            context.setFillColor(UIColor.white.cgColor)
                            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - inwardsExtension), size: CGSize(width: size.width, height: inwardsExtension)))
                        }
                    } else {
                        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                    }
                })?.resizableImage(withCapInsets: UIEdgeInsets(top: resizingInverted ? baseHeight : 0.0, left: 0.0, bottom: resizingInverted ? 0.0 : baseHeight, right: 0.0), resizingMode: .stretch)
            } else {
                self.gradientImage = EdgeEffectView.generateEdgeGradient(baseHeight: max(1.0, params.gradient.height), isInverted: params.placement.position == .bottom, extendsInwards: params.placement.inwardsExtension != nil)
            }
        }
        
        self.params = params
        
        let transition = ComponentTransition(transition)
        
        if let imageSubview = self.imageSubview {
            if isGradientUpdated {
                imageSubview.image = self.gradientImage
            }
            transition.setFrame(layer: self.layer, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: imageSubview, frame: CGRect(origin: CGPoint(), size: size))
        } else {
            if isHeightUpdated || isGradientUpdated {
                self.updateLegacyEffect()
                transition.setFrame(layer: self.layer, frame: CGRect(origin: CGPoint(), size: size))
            } else {
                transition.setFrame(layer: self.layer, frame: CGRect(origin: CGPoint(), size: size))
            }
        }
    }
}

public final class VariableBlurView: UIView {
    public let maxBlurRadius: CGFloat
    
    private var effect: VariableBlurEffect?
    private let effectLayerDelegate: SimpleLayerDelegate
    private var mainEffectLayer: CALayer?
    
    public init(maxBlurRadius: CGFloat = 20.0) {
        self.maxBlurRadius = maxBlurRadius
        
        self.effectLayerDelegate = SimpleLayerDelegate()
        
        self.mainEffectLayer = createBackdropLayer()
        if let mainEffectLayer = self.mainEffectLayer {
            self.effect = VariableBlurEffect(layer: mainEffectLayer, maxBlurRadius: maxBlurRadius)
        }
        
        super.init(frame: CGRect())

        if let mainEffectLayer = self.mainEffectLayer {
            mainEffectLayer.delegate = self.effectLayerDelegate
            mainEffectLayer.setValue(0.5, forKey: "scale")
            
            self.layer.addSublayer(mainEffectLayer)
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, constantHeight: CGFloat, isInverted: Bool, gradient: VariableBlurEffect.Gradient, transition: ContainedViewLayoutTransition) {
        self.effect?.update(size: size, constantHeight: constantHeight, placement: VariableBlurEffect.Placement(position: isInverted ? .bottom : .top, inwardsExtension: nil), gradient: gradient, transition: transition)
    }
}

public final class EdgeMaskView: UIView {
    private struct MaskParams: Equatable {
        let gradientHeight: CGFloat
        let extensionHeight: CGFloat
        
        init(gradientHeight: CGFloat, extensionHeight: CGFloat) {
            self.gradientHeight = gradientHeight
            self.extensionHeight = extensionHeight
        }
    }
    
    private let imageView: UIImageView
    
    private var maskParams: MaskParams?
    
    override public init(frame: CGRect) {
        self.imageView = UIImageView()
        
        super.init(frame: frame)
        
        self.addSubview(self.imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, color: UIColor, gradientHeight: CGFloat, extensionHeight: CGFloat, transition: ComponentTransition) {
        let maskParams = MaskParams(gradientHeight: gradientHeight, extensionHeight: extensionHeight)
        if maskParams != self.maskParams {
            self.maskParams = maskParams
            
            let baseHeight = max(1.0, maskParams.gradientHeight + maskParams.extensionHeight)
            let resizingInverted = !"".isEmpty
            self.imageView.image = generateImage(CGSize(width: 1.0, height: baseHeight), opaque: false, rotatedContext: { size, context in
                let bounds = CGRect(origin: CGPoint(), size: size)
                context.clear(bounds)
                
                let gradientColors = [UIColor.white.withAlphaComponent(1.0).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray
                
                var locations: [CGFloat] = [0.0, 1.0]
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                if "".isEmpty {
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height - maskParams.extensionHeight), options: CGGradientDrawingOptions())
                } else {
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                }
            })?.resizableImage(withCapInsets: UIEdgeInsets(top: resizingInverted ? baseHeight : 0.0, left: 0.0, bottom: resizingInverted ? 0.0 : baseHeight, right: 0.0), resizingMode: .stretch).withRenderingMode(.alwaysTemplate)
        }
        self.imageView.tintColor = color
        transition.setFrame(view: self.imageView, frame: CGRect(origin: CGPoint(), size: size))
    }
}
