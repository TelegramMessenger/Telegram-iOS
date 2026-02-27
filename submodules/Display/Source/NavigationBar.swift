import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private var backArrowImageCache: [Int32: UIImage] = [:]

public final class NavigationBarTheme {
    public static func generateBackArrowImage(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 13.0, height: 22.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)
            
            context.translateBy(x: 0.0, y: -UIScreenPixel)
            
            let _ = try? drawSvgPath(context, path: "M3.60751322,11.5 L11.5468531,3.56066017 C12.1326395,2.97487373 12.1326395,2.02512627 11.5468531,1.43933983 C10.9610666,0.853553391 10.0113191,0.853553391 9.42553271,1.43933983 L0.449102936,10.4157696 C-0.149700979,11.0145735 -0.149700979,11.9854265 0.449102936,12.5842304 L9.42553271,21.5606602 C10.0113191,22.1464466 10.9610666,22.1464466 11.5468531,21.5606602 C12.1326395,20.9748737 12.1326395,20.0251263 11.5468531,19.4393398 L3.60751322,11.5 Z ")
        })
    }
    
    public let overallDarkAppearance: Bool
    public let buttonColor: UIColor
    public let disabledButtonColor: UIColor
    public let primaryTextColor: UIColor
    public let backgroundColor: UIColor
    public let opaqueBackgroundColor: UIColor
    public let enableBackgroundBlur: Bool
    public let separatorColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeStrokeColor: UIColor
    public let badgeTextColor: UIColor
    public let edgeEffectColor: UIColor?
    public let style: NavigationBar.Style
    public let glassStyle: NavigationBar.GlassStyle
    
    public init(overallDarkAppearance: Bool, buttonColor: UIColor, disabledButtonColor: UIColor, primaryTextColor: UIColor, backgroundColor: UIColor, opaqueBackgroundColor: UIColor? = nil, enableBackgroundBlur: Bool, separatorColor: UIColor, badgeBackgroundColor: UIColor, badgeStrokeColor: UIColor, badgeTextColor: UIColor, edgeEffectColor: UIColor? = nil, style: NavigationBar.Style = .legacy, glassStyle: NavigationBar.GlassStyle = .default) {
        self.overallDarkAppearance = overallDarkAppearance
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
        self.primaryTextColor = primaryTextColor
        self.backgroundColor = backgroundColor
        self.opaqueBackgroundColor = opaqueBackgroundColor ?? backgroundColor
        self.enableBackgroundBlur = enableBackgroundBlur
        self.separatorColor = separatorColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeStrokeColor = badgeStrokeColor
        self.badgeTextColor = badgeTextColor
        self.edgeEffectColor = edgeEffectColor
        self.style = style
        self.glassStyle = glassStyle
    }
    
    public func withUpdatedBackgroundColor(_ color: UIColor) -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: self.overallDarkAppearance, buttonColor: self.buttonColor, disabledButtonColor: self.disabledButtonColor, primaryTextColor: self.primaryTextColor, backgroundColor: color, opaqueBackgroundColor: self.opaqueBackgroundColor, enableBackgroundBlur: false, separatorColor: self.separatorColor, badgeBackgroundColor: self.badgeBackgroundColor, badgeStrokeColor: self.badgeStrokeColor, badgeTextColor: self.badgeTextColor, edgeEffectColor: self.edgeEffectColor, style: self.style, glassStyle: self.glassStyle)
    }
    
    public func withUpdatedSeparatorColor(_ color: UIColor) -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: self.overallDarkAppearance, buttonColor: self.buttonColor, disabledButtonColor: self.disabledButtonColor, primaryTextColor: self.primaryTextColor, backgroundColor: self.backgroundColor, opaqueBackgroundColor: self.opaqueBackgroundColor, enableBackgroundBlur: self.enableBackgroundBlur, separatorColor: color, badgeBackgroundColor: self.badgeBackgroundColor, badgeStrokeColor: self.badgeStrokeColor, badgeTextColor: self.badgeTextColor, edgeEffectColor: self.edgeEffectColor, style: self.style, glassStyle: self.glassStyle)
    }
}

public final class NavigationBarStrings {
    public let back: String
    public let close: String
    
    public init(back: String, close: String) {
        self.back = back
        self.close = close
    }
}

public final class NavigationBarPresentationData {
    public let theme: NavigationBarTheme
    public let strings: NavigationBarStrings
    
    public init(theme: NavigationBarTheme, strings: NavigationBarStrings) {
        self.theme = theme
        self.strings = strings
    }
}

public enum NavigationPreviousAction: Equatable {
    case item(UINavigationItem)
    case close
    
    public static func ==(lhs: NavigationPreviousAction, rhs: NavigationPreviousAction) -> Bool {
        switch lhs {
        case let .item(lhsItem):
            if case let .item(rhsItem) = rhs, lhsItem === rhsItem {
                return true
            } else {
                return false
            }
        case .close:
            if case .close = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public enum NavigationBarStyle {
    case legacy
    case glass
}

public func navigationBarBackArrowImage(color: UIColor) -> UIImage? {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    let key = (Int32(alpha * 255.0) << 24) | (Int32(red * 255.0) << 16) | (Int32(green * 255.0) << 8) | Int32(blue * 255.0)
    if let image = backArrowImageCache[key] {
        return image
    } else {
        if let image = NavigationBarTheme.generateBackArrowImage(color: color) {
            backArrowImageCache[key] = image
            return image
        } else {
            return nil
        }
    }
}

public protocol NavigationButtonCustomDisplayNode {
    var isHighlightable: Bool { get }
}

public protocol NavigationButtonNode: ASDisplayNode {
    func updateManualAlpha(alpha: CGFloat, transition: ContainedViewLayoutTransition)
    var mainContentNode: ASDisplayNode? { get }
    var contentsColor: UIColor? { get set }
}

public enum NavigationBarGlassStyle {
    case `default`
    case clear
}

public protocol NavigationBar: ASDisplayNode {
    typealias Style = NavigationBarStyle
    typealias GlassStyle = NavigationBarGlassStyle
    
    var backPressed: () -> Void { get set }
    
    var userInfo: Any? { get set }
    var makeCustomTransitionNode: ((NavigationBar, Bool) -> CustomNavigationTransitionNode?)? { get set }
    var allowsCustomTransition: (() -> Bool)? { get set }
    
    var stripeNode: ASDisplayNode { get }
    var clippingNode: SparseNode { get }
    
    var backgroundView: UIView { get }
    var customOverBackgroundContentView: UIView { get }
    var contentNode: NavigationBarContentNode? { get }
    var secondaryContentNode: ASDisplayNode? { get }
    var secondaryContentNodeDisplayFraction: CGFloat { get set }
    
    var item: UINavigationItem? { get set }
    var customBackButtonText: String? { get }
    var titleView: UIView? { get }
    var layoutSuspended: Bool { get set }
    
    var enableAutomaticBackButton: Bool { get set }
    var previousItem: NavigationPreviousAction? { get set }
    
    var backgroundNode: NavigationBackgroundNode { get }
    var backButtonNode: NavigationButtonNode { get }
    var badgeNode: NavigationBarBadgeNode { get }
    var backButtonArrow: ASImageNode { get }
    var leftButtonNode: NavigationButtonNode { get }
    var rightButtonNode: NavigationButtonNode { get }
    var additionalContentNode: SparseNode { get }

    func reattachAdditionalContentNode()
    
    var secondaryContentHeight: CGFloat { get set }
    
    var isBackgroundVisible: Bool { get }
    
    func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition)
    func updatePresentationData(_ presentationData: NavigationBarPresentationData, transition: ContainedViewLayoutTransition)
    
    var intrinsicCanTransitionInline: Bool { get set }
    
    var passthroughTouches: Bool { get set }
    
    var canTransitionInline: Bool { get }
    
    func contentHeight(defaultHeight: CGFloat) -> CGFloat
    func setContentNode(_ contentNode: NavigationBarContentNode?, animated: Bool)
    func setSecondaryContentNode(_ secondaryContentNode: ASDisplayNode?, animated: Bool)
    func executeBack() -> Bool
    func setHidden(_ hidden: Bool, animated: Bool)
    
    var requestContainerLayout: ((ContainedViewLayoutTransition) -> Void)? { get set }
    
    func updateLayout(size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, additionalCutout: CGSize?, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, isLandscape: Bool, transition: ContainedViewLayoutTransition)
    
    func updateEdgeEffectExtension(value: CGFloat, transition: ContainedViewLayoutTransition)
    
    func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer?
}

public var defaultNavigationBarImpl: ((NavigationBarPresentationData) -> NavigationBar)?
