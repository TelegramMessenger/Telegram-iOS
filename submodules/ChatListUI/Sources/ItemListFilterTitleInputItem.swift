import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TextNodeWithEntities
import AccountContext
import ItemListUI
import ComponentFlow
import ListComposePollOptionComponent
import TextFieldComponent

public class ItemListFilterTitleInputItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let text: NSAttributedString
    let enableAnimations: Bool
    let placeholder: String
    let maxLength: Int
    let inputMode: ListComposePollOptionComponent.InputMode?
    let enabled: Bool
    public let sectionId: ItemListSectionId
    let textUpdated: (NSAttributedString) -> Void
    let updatedFocus: ((Bool) -> Void)?
    let toggleInputMode: () -> Void
    public let tag: ItemListItemTag?
    
    public init(
        context: AccountContext,
        presentationData: ItemListPresentationData,
        text: NSAttributedString,
        enableAnimations: Bool,
        placeholder: String,
        maxLength: Int = 0,
        inputMode: ListComposePollOptionComponent.InputMode?,
        enabled: Bool = true,
        tag: ItemListItemTag? = nil,
        sectionId: ItemListSectionId,
        textUpdated: @escaping (NSAttributedString) -> Void,
        updatedFocus: ((Bool) -> Void)? = nil,
        toggleInputMode: @escaping () -> Void
    ) {
        self.context = context
        self.presentationData = presentationData
        self.text = text
        self.enableAnimations = enableAnimations
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.inputMode = inputMode
        self.enabled = enabled
        self.tag = tag
        self.sectionId = sectionId
        self.textUpdated = textUpdated
        self.updatedFocus = updatedFocus
        self.toggleInputMode = toggleInputMode
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListFilterTitleInputItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListFilterTitleInputItemNode {
            
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

public class ItemListFilterTitleInputItemNode: ListViewItemNode, UITextFieldDelegate, ItemListItemNode, ItemListItemFocusableNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    let textFieldState = TextFieldComponent.ExternalState()
    private let textField = ComponentView<Empty>()
    private let componentState = EmptyComponentState()
    
    private var item: ItemListFilterTitleInputItem?
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    var textFieldView: ListComposePollOptionComponent.View? {
        return self.textField.view as? ListComposePollOptionComponent.View
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    override public func didLoad() {
        super.didLoad()
    }
    
    public func asyncLayout() -> (_ item: ItemListFilterTitleInputItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        return { [weak self] item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            let _ = rightInset
            
            let separatorHeight = UIScreenPixel
                        
            let contentSize = CGSize(width: params.width, height: 44.0)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(item.presentationData.fontSize.itemListBaseFontSize), textColor: item.presentationData.theme.list.itemPlaceholderTextColor)
            let _ = attributedPlaceholderText
            
            return (layout, {
                guard let self else {
                    return
                }
                self.item = item
                
                if let _ = updatedTheme {
                    self.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    self.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    self.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                }
                
                if self.backgroundNode.supernode == nil {
                    self.insertSubnode(self.backgroundNode, at: 0)
                }
                if self.topStripeNode.supernode == nil {
                    self.insertSubnode(self.topStripeNode, at: 1)
                }
                if self.bottomStripeNode.supernode == nil {
                    self.insertSubnode(self.bottomStripeNode, at: 2)
                }
                if self.maskNode.supernode == nil {
                    self.insertSubnode(self.maskNode, at: 3)
                }
                
                let hasCorners = itemListHasRoundedBlockLayout(params)
                var hasTopCorners = false
                var hasBottomCorners = false
                switch neighbors.top {
                    case .sameSection(false):
                        self.topStripeNode.isHidden = true
                    default:
                        hasTopCorners = true
                        self.topStripeNode.isHidden = hasCorners
                }
                let bottomStripeInset: CGFloat
                switch neighbors.bottom {
                    case .sameSection(false):
                        bottomStripeInset = leftInset
                        self.bottomStripeNode.isHidden = false
                    default:
                        bottomStripeInset = 0.0
                        hasBottomCorners = true
                        self.bottomStripeNode.isHidden = hasCorners
                }
                
                self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                
                self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                self.maskNode.frame = self.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                self.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                self.textField.parentState = self.componentState
                self.componentState._updated = { [weak self] transition, _ in
                    guard let self, let item = self.item else {
                        return
                    }
                    guard let textFieldView = self.textFieldView else {
                        return
                    }
                    item.textUpdated(textFieldView.currentAttributedText)
                }
                let textFieldSize = self.textField.update(
                    transition: .immediate,
                    component: AnyComponent(ListComposePollOptionComponent(
                        externalState: self.textFieldState,
                        context: item.context,
                        theme: item.presentationData.theme,
                        strings: item.presentationData.strings,
                        placeholder: NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: item.presentationData.theme.list.itemPlaceholderTextColor),
                        resetText: self.textField.view == nil ? ListComposePollOptionComponent.ResetText(value: item.text) : nil,
                        characterLimit: item.maxLength,
                        enableInlineAnimations: item.enableAnimations,
                        emptyLineHandling: .notAllowed,
                        returnKeyAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            let _ = self
                        },
                        backspaceKeyAction: nil,
                        selection: nil,
                        inputMode: item.inputMode,
                        alwaysDisplayInputModeSelector: true,
                        toggleInputMode: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.item?.toggleInputMode()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: layout.size.width - params.leftInset - params.rightInset, height: layout.size.height)
                )
                let textFieldFrame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: textFieldSize)
                if let textFieldView = self.textField.view {
                    if textFieldView.superview == nil {
                        self.view.addSubview(textFieldView)
                    }
                    textFieldView.frame = textFieldFrame
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    public func focus() {
        if let textFieldView = self.textField.view as? ListComposePollOptionComponent.View {
            textFieldView.activateInput()
        }
    }
    
    public func selectAll() {
    }
}
