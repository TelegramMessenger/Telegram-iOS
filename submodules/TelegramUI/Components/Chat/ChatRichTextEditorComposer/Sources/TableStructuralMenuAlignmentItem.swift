import Foundation
import UIKit
import Display
import ContextUI
import TelegramPresentationData
import RichTextEditorCore
import RichTextEditorUIKit
import TelegramCore
import AsyncDisplayKit
import ComponentFlow
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent

final class TableStructuralMenuAlignmentItem: ContextMenuCustomItem {
    let initialHorizontal: TableHorizontalAlignment?
    let initialVertical: TableVerticalAlignment?
    let action: (TableHorizontalAlignment?, TableVerticalAlignment?) -> Void

    init(initialHorizontal: TableHorizontalAlignment?, initialVertical: TableVerticalAlignment?,
         action: @escaping (TableHorizontalAlignment?, TableVerticalAlignment?) -> Void) {
        self.initialHorizontal = initialHorizontal
        self.initialVertical = initialVertical
        self.action = action
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return TableStructuralMenuAlignmentItemNode(presentationData: presentationData, getController: getController, actionSelected: actionSelected, item: self)
    }
}

/// Renders the per-cell alignment control as two rows of three segmented buttons (H: Left/Center/Right,
/// V: Top/Middle/Bottom), modeled on `BrowserFontSizeContextMenuItemNode` (background + touch-highlight overlay
/// + separators per button, `updateTheme` re-applying colors, `updateLayout` returning a fixed-height control).
/// The current selection (seeded from `item.initialHorizontal`/`initialVertical`) is shown via accent color +
/// semibold weight; `nil` (mixed across the selected cells) shows no highlighted segment in that row. A tap on a
/// horizontal button reports only the horizontal axis (`item.action(h, nil)`); a vertical tap reports only the
/// vertical axis (`item.action(nil, v)`) — the other axis is left unchanged by the caller's `apply`.
private final class TableStructuralMenuAlignmentItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    let item: TableStructuralMenuAlignmentItem

    let needsPadding: Bool = false

    private let title = ComponentView<Empty>()
    private var currentHorizontal: TableHorizontalAlignment?
    private var currentVertical: TableVerticalAlignment?

    private let horizontalItems: [ComponentView<Empty>]
    private let verticalItems: [ComponentView<Empty>]
    private let horizontalSelection = UIImageView()
    private let verticalSelection = UIImageView()

    private var validLayout: (constrainedWidth: CGFloat, constrainedHeight: CGFloat, resultSize: CGSize)?

    init(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void, item: TableStructuralMenuAlignmentItem) {
        self.presentationData = presentationData
        self.item = item
        self.currentHorizontal = item.initialHorizontal
        self.currentVertical = item.initialVertical
        
        self.horizontalItems = (0 ..< 3).map { _ in ComponentView() }
        self.verticalItems = (0 ..< 3).map { _ in ComponentView() }

        super.init()

        self.isUserInteractionEnabled = true
        
        self.view.addSubview(self.horizontalSelection)
        self.view.addSubview(self.verticalSelection)
    }

    override func didLoad() {
        super.didLoad()
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        if let validLayout = self.validLayout {
            let (_, apply) = self.updateLayout(constrainedWidth: validLayout.constrainedWidth, constrainedHeight: validLayout.constrainedHeight)
            apply(validLayout.resultSize, .immediate)
        }
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let size = CGSize(width: constrainedWidth, height: 68.0)

        return (size, { [weak self] size, transition in
            guard let self else {
                return
            }

            self.validLayout = (constrainedWidth, constrainedHeight, size)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: self.presentationData.strings.RichText_TableMenu_Alignment, font: Font.regular(13.0), textColor: self.presentationData.theme.contextMenu.secondaryColor))
                )),
                environment: {},
                containerSize: CGSize(width: 1000.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) * 0.5), y: 11.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.view.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }

            let spacing: CGFloat = 2.0
            let itemSize = CGSize(width: 34.0, height: 34.0)
            
            enum ItemKind {
                case left
                case right
                case hcenter
                case top
                case bottom
                case vcenter
                
                var icon: String {
                    switch self {
                    case .left:
                        return "Chat/Context Menu/AlignLeft"
                    case .right:
                        return "Chat/Context Menu/AlignRight"
                    case .hcenter:
                        return "Chat/Context Menu/AlignHCenter"
                    case .top:
                        return "Chat/Context Menu/AlignTop"
                    case .bottom:
                        return "Chat/Context Menu/AlignBottom"
                    case .vcenter:
                        return "Chat/Context Menu/AlignVCenter"
                    }
                }
            }
            
            let hItems: [ItemKind] = [
                .left, .hcenter, .right
            ]
            let vItems: [ItemKind] = [
                .top, .vcenter, .bottom
            ]
            
            for itemSet in 0 ..< 2 {
                let items = itemSet == 0 ? self.horizontalItems : self.verticalItems
                let itemKinds = itemSet == 0 ? hItems : vItems
                let baseX: CGFloat = itemSet == 0 ? 10.0 : (size.width - 10.0 - CGFloat(items.count) * itemSize.width - CGFloat(items.count - 1) * spacing)
                let selectionView = itemSet == 0 ? self.horizontalSelection : self.verticalSelection
                
                var selectionFrame: CGRect?
                
                for i in 0 ..< items.count {
                    let item = items[i]
                    let itemKind = itemKinds[i]
                    
                    let isSelected: Bool
                    switch itemKind {
                    case .left:
                        isSelected = self.currentHorizontal == .left
                    case .right:
                        isSelected = self.currentHorizontal == .right
                    case .hcenter:
                        isSelected = self.currentHorizontal == .center
                    case .top:
                        isSelected = self.currentVertical == .top
                    case .bottom:
                        isSelected = self.currentVertical == .bottom
                    case .vcenter:
                        isSelected = self.currentVertical == .middle
                    }
                    
                    let _ = item.update(
                        transition: .immediate,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(BundleIconComponent(
                                name: itemKind.icon,
                                tintColor: self.presentationData.theme.contextMenu.primaryColor,
                            )),
                            minSize: itemSize,
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                switch itemKind {
                                case .left:
                                    self.currentHorizontal = .left
                                    self.item.action(.left, nil)
                                case .right:
                                    self.currentHorizontal = .right
                                    self.item.action(.right, nil)
                                case .hcenter:
                                    self.currentHorizontal = .center
                                    self.item.action(.center, nil)
                                case .top:
                                    self.currentVertical = .top
                                    self.item.action(nil, .top)
                                case .bottom:
                                    self.currentVertical = .bottom
                                    self.item.action(nil, .bottom)
                                case .vcenter:
                                    self.currentVertical = .middle
                                    self.item.action(nil, .middle)
                                }
                                
                                if let validLayout = self.validLayout {
                                    let (_, apply) = self.updateLayout(constrainedWidth: validLayout.constrainedWidth, constrainedHeight: validLayout.constrainedHeight)
                                    apply(validLayout.resultSize, .animated(duration: 0.4, curve: .spring))
                                }
                            }
                        )),
                        environment: {},
                        containerSize: itemSize
                    )
                    
                    let itemFrame = CGRect(origin: CGPoint(x: baseX + CGFloat(i) * (itemSize.width + spacing), y: 34.0), size: itemSize)
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.view.addSubview(itemView)
                        }
                        itemView.frame = itemFrame
                    }
                    if selectionFrame == nil || isSelected {
                        selectionFrame = itemFrame
                    }
                }
                
                if let selectionFrame {
                    transition.updateFrame(view: selectionView, frame: selectionFrame)
                    if selectionView.image == nil {
                        selectionView.image = generateStretchableFilledCircleImage(radius: 8.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                    }
                    selectionView.tintColor = self.presentationData.theme.contextMenu.itemHighlightedBackgroundColor
                }
            }
        })
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
    }
}
