import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SearchBarNode
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ActivityIndicator

private let searchBarFont = Font.regular(17.0)
public let navigationBarSearchContentHeight: CGFloat = 60.0

public class NavigationBarSearchContentNode: NavigationBarContentNode {
    private struct Params: Equatable {
        let size: CGSize
        let leftInset: CGFloat
        let rightInset: CGFloat
        
        init(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
            self.size = size
            self.leftInset = leftInset
            self.rightInset = rightInset
        }
    }
    
    public var theme: PresentationTheme?
    public var placeholder: String
    public var compactPlaceholder: String
    private let inline: Bool
    
    public let placeholderNode: SearchBarPlaceholderNode
    public var placeholderHeight: CGFloat?
    private var disabledOverlay: ASDisplayNode?
    
    public var expansionProgress: CGFloat = 1.0

    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    public init(theme: PresentationTheme, placeholder: String, compactPlaceholder: String? = nil, inline: Bool = false, activate: @escaping () -> Void) {
        self.theme = theme
        self.placeholder = placeholder
        self.compactPlaceholder = compactPlaceholder ?? placeholder
        self.inline = inline
        
        self.placeholderNode = SearchBarPlaceholderNode(fieldStyle: .glass)
        self.placeholderNode.labelNode.displaysAsynchronously = false
        
        super.init()
        
        self.placeholderNode.isAccessibilityElement = true
        self.placeholderNode.accessibilityLabel = placeholder
        self.placeholderNode.accessibilityTraits = .searchField
        
        self.addSubnode(self.placeholderNode)
        self.placeholderNode.activate = activate
        
        //self.backgroundColor = .red
    }
    
    public func updateThemeAndPlaceholder(theme: PresentationTheme, placeholder: String, compactPlaceholder: String? = nil) {
        self.theme = theme
        self.placeholder = placeholder
        self.compactPlaceholder = compactPlaceholder ?? placeholder
        self.placeholderNode.accessibilityLabel = placeholder
        if let disabledOverlay = self.disabledOverlay {
            disabledOverlay.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor.withAlphaComponent(0.5)
        }
        if let validLayout = self.validLayout {
            self.updatePlaceholder(self.expansionProgress, size: validLayout.0, leftInset: validLayout.1, rightInset: validLayout.2, transition: .immediate)
        }
    }
    
    public func updateListVisibleContentOffset(_ offset: ListViewVisibleContentOffset, transition: ContainedViewLayoutTransition = .immediate) {
        var progress: CGFloat = 0.0
        switch offset {
            case let .known(offset):
                progress = max(0.0, (self.nominalHeight - offset)) / self.nominalHeight
            case .none:
                progress = 1.0
            default:
                break
        }
        self.updateExpansionProgress(progress, animated: transition.isAnimated)
    }
    
    public func updateGridVisibleContentOffset(_ offset: GridNodeVisibleContentOffset) {
        var progress: CGFloat = 0.0
        switch offset {
            case let .known(offset):
                progress = max(0.0, (self.nominalHeight - offset)) / self.nominalHeight
            case .none:
                progress = 1.0
            default:
                break
        }
        self.updateExpansionProgress(progress)
    }
    
    public func updateExpansionProgress(_ progress: CGFloat, animated: Bool = false) {
        let newProgress = max(0.0, min(10.0, progress))
        if abs(newProgress - self.expansionProgress) > 0.0001 {
            self.expansionProgress = newProgress
        
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: ContainedViewLayoutTransitionCurve.slide) : .immediate
            if let validLayout = self.validLayout, animated {
                self.updatePlaceholder(self.expansionProgress, size: validLayout.0, leftInset: validLayout.1, rightInset: validLayout.2, transition: transition)
            }
            self.requestContainerLayout(transition)
        }
    }
    
    public func setIsEnabled(_ enabled: Bool, animated: Bool = false) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.25, curve: .easeInOut) : .immediate
        transition.updateAlpha(node: self.placeholderNode, alpha: enabled ? 1.0 : 0.6)
        self.placeholderNode.isUserInteractionEnabled = enabled
    }
    
    private func updatePlaceholder(_ progress: CGFloat, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let padding: CGFloat = 16.0
        let baseWidth = size.width - padding * 2.0 - leftInset - rightInset
        
        let fieldHeight: CGFloat = 44.0
        let fraction = fieldHeight / self.nominalHeight
        let fullFraction = navigationBarSearchContentHeight / self.nominalHeight
        
        let fromLow: CGFloat = fullFraction - fraction
        let toLow: CGFloat = 0.0
        let fromHigh: CGFloat = fullFraction
        let toHigh: CGFloat = 1.0
        var visibleProgress: CGFloat = toLow + (self.expansionProgress - fromLow) * (toHigh - toLow) / (fromHigh - fromLow)
        visibleProgress = max(0.0, min(1.0, visibleProgress))
        
        let textColor = self.theme?.rootController.navigationSearchBar.inputPlaceholderTextColor ?? UIColor(rgb: 0x8e8e93)
        var fillColor = self.theme?.rootController.navigationSearchBar.inputFillColor ?? .clear
        if self.inline, let theme = self.theme, fillColor.distance(to: theme.list.blocksBackgroundColor) < 100 {
            fillColor = fillColor.withMultipliedBrightnessBy(0.8)
        }
        
        let backgroundColor = self.theme?.chatList.regularSearchBarColor ?? .clear
        let controlColor = self.theme?.chat.inputPanel.panelControlColor ?? .black
        
        let placeholderString = NSAttributedString(string: self.placeholder, font: searchBarFont, textColor: textColor)
        let compactPlaceholderString = NSAttributedString(string: self.compactPlaceholder, font: searchBarFont, textColor: textColor)
        
        let searchBarHeight = self.placeholderNode.updateLayout(placeholderString: placeholderString, compactPlaceholderString: compactPlaceholderString, constrainedSize: CGSize(width: baseWidth, height: fieldHeight), expansionProgress: visibleProgress, iconColor: textColor, foregroundColor: fillColor, backgroundColor: backgroundColor, controlColor: controlColor, transition: transition)
        
        let searchBarFrame = CGRect(origin: CGPoint(x: padding + leftInset, y: size.height + (1.0 - visibleProgress) * fieldHeight - 8.0 - fieldHeight), size: CGSize(width: baseWidth, height: fieldHeight))
        transition.updateFrame(node: self.placeholderNode, frame: searchBarFrame)
        
        self.placeholderHeight = searchBarHeight
        if let disabledOverlay = self.disabledOverlay {
            var disabledOverlayFrame = self.placeholderNode.frame
            disabledOverlayFrame.size.height = searchBarHeight
            transition.updateFrame(node: disabledOverlay, frame: disabledOverlayFrame)
        }
    }
    
    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = (size, leftInset, rightInset)
        
        self.updatePlaceholder(self.expansionProgress, size: size, leftInset: leftInset, rightInset: rightInset, transition: transition)
        
        return size
    }
    
    override public var height: CGFloat {
        return self.nominalHeight * self.expansionProgress
    }
    
    override public var clippedHeight: CGFloat {
        return self.nominalHeight * min(1.0, self.expansionProgress)
    }
    
    override public var nominalHeight: CGFloat {
        return 60.0
    }
    
    override public var mode: NavigationBarContentMode {
        return .expansion
    }
}
