import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import Markdown
import ComponentFlow
import PremiumStarComponent
import GlassBarButtonComponent
import BundleIconComponent

final class CreateGiveawayHeaderItem: ItemListControllerHeaderItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let title: String
    let text: String
    let isStars: Bool
    let cancel: () -> Void
    
    init(theme: PresentationTheme, strings: PresentationStrings, title: String, text: String, isStars: Bool, cancel: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.title = title
        self.text = text
        self.isStars = isStars
        self.cancel = cancel
    }
    
    func isEqual(to: ItemListControllerHeaderItem) -> Bool {
        if let item = to as? CreateGiveawayHeaderItem {
            return self.theme === item.theme && self.title == item.title && self.text == item.text && self.isStars == item.isStars
        } else {
            return false
        }
    }
    
    func node(current: ItemListControllerHeaderItemNode?) -> ItemListControllerHeaderItemNode {
        if let current = current as? CreateGiveawayHeaderItemNode {
            current.item = self
            return current
        } else {
            return CreateGiveawayHeaderItemNode(item: self)
        }
    }
}

private let titleFont = Font.semibold(20.0)
private let textFont = Font.regular(15.0)

class CreateGiveawayHeaderItemNode: ItemListControllerHeaderItemNode {
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private let cancelButton = ComponentView<Empty>()
    private var hostView: ComponentHostView<Empty>?
    
    private var component: AnyComponent<Empty>?
    private var validLayout: ContainerViewLayout?
        
    fileprivate var item: CreateGiveawayHeaderItem {
        didSet {
            self.updateItem()
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }
    
    init(item: CreateGiveawayHeaderItem) {
        self.item = item
                
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        self.textNode.maximumNumberOfLines = 0
                
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.titleNode)
                
        self.updateItem()
    }

    override func didLoad() {
        super.didLoad()
        
        let hostView = ComponentHostView<Empty>()
        self.hostView = hostView
        self.view.insertSubview(hostView, at: 0)
        
        if let layout = self.validLayout, let component = self.component {
            let containerSize = CGSize(width: min(414.0, layout.size.width), height: 220.0)
            
            let size = hostView.update(
                transition: .immediate,
                component: component,
                environment: {},
                containerSize: containerSize
            )
            hostView.bounds = CGRect(origin: .zero, size: size)
        }
    }
    
    func updateItem() {
        let attributedTitle = NSAttributedString(string: self.item.title, font: titleFont, textColor: self.item.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        let attributedText = NSAttributedString(string: self.item.text, font: textFont, textColor: self.item.theme.list.freeTextColor, paragraphAlignment: .center)
        
        self.titleNode.attributedText = attributedTitle
        self.textNode.attributedText = attributedText
    }
    
    override func updateContentOffset(_ contentOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let layout = self.validLayout else {
            return
        }
        let navigationHeight: CGFloat = 76.0
        let statusBarHeight = layout.statusBarHeight ?? 0.0
        
        let topInset : CGFloat = 0.0
        let titleOffsetDelta = (topInset + 160.0) - (statusBarHeight + (navigationHeight - statusBarHeight) / 2.0)
        let topContentOffset = contentOffset + max(0.0, min(1.0, contentOffset / titleOffsetDelta)) * 10.0
        
        let titleOffset = topContentOffset
        let fraction = max(0.0, min(1.0, titleOffset / titleOffsetDelta))
        let titleScale = 1.0 - fraction * 0.18
                
        let starPosition = CGPoint(
            x: layout.size.width / 2.0,
            y: -contentOffset + 80.0
        )
        if let view = self.hostView {
            transition.updatePosition(layer: view.layer, position: starPosition)
        }
        
        let titlePosition = CGPoint(
            x: layout.size.width / 2.0,
            y: max(topInset + 170.0 - titleOffset, statusBarHeight + (navigationHeight - statusBarHeight) / 2.0)
        )

        transition.updatePosition(node: self.titleNode, position: titlePosition)
        transition.updateTransformScale(node: self.titleNode, scale: titleScale)
        
        let textPosition = CGPoint(
            x: layout.size.width / 2.0,
            y: -contentOffset + 212.0
        )
        transition.updatePosition(node: self.textNode, position: textPosition)
    }
    
    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        let leftInset: CGFloat = 24.0
        
        let constrainedSize = CGSize(width: layout.size.width - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude)
        let titleSize = self.titleNode.updateLayout(constrainedSize)
        let textSize = self.textNode.updateLayout(constrainedSize)
                
        let cancelButtonSize = self.cancelButton.update(
            transition: .immediate,
            component: AnyComponent(
                GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: self.item.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Navigation/Close", tintColor: self.item.theme.chat.inputPanel.panelControlColor))),
                    action: { [weak self] _ in
                        self?.item.cancel()
                    }
                )
            ),
            environment: {},
            containerSize: CGSize(width: 44.0, height: 44.0)
        )
        let cancelButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelButtonSize)
        if let cancelButtonView = self.cancelButton.view {
            if cancelButtonView.superview == nil {
                self.view.addSubview(cancelButtonView)
            }
            cancelButtonView.frame = cancelButtonFrame
        }
               
        let colors: [UIColor]
        let particleColor: UIColor?
        if self.item.isStars {
            colors = [
                UIColor(rgb: 0xe57d02),
                UIColor(rgb: 0xf09903),
                UIColor(rgb: 0xf9b004),
                UIColor(rgb: 0xfdd219)
            ]
            particleColor = UIColor(rgb: 0xf9b004)
        } else {
            colors = [
                UIColor(rgb: 0x6a94ff),
                UIColor(rgb: 0x9472fd),
                UIColor(rgb: 0xe26bd3)
            ]
            particleColor = nil
        }
        
        let component = AnyComponent(PremiumStarComponent(
            theme: self.item.theme,
            isIntro: true,
            isVisible: true,
            hasIdleAnimations: true,
            colors: colors,
            particleColor: particleColor,
            backgroundColor: self.item.theme.list.blocksBackgroundColor
            
        ))
        let containerSize = CGSize(width: min(414.0, layout.size.width), height: 220.0)
        
        if let hostView = self.hostView {
            let size = hostView.update(
                transition: .immediate,
                component: component,
                environment: {},
                containerSize: containerSize
            )
            hostView.bounds = CGRect(origin: .zero, size: size)
        }

        self.titleNode.bounds = CGRect(origin: .zero, size: titleSize)
        self.textNode.bounds = CGRect(origin: .zero, size: textSize)
        
        let contentHeight = titleSize.height + textSize.height + 128.0
        
        self.component = component
        self.validLayout = layout
        
        return contentHeight
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let hostView = self.hostView, hostView.frame.contains(point) {
            return true
        } else {
            return super.point(inside: point, with: event)
        }
    }
}
