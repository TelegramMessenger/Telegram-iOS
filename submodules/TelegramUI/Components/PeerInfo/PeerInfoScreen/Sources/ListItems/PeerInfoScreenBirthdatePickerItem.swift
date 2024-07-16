import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramCore
import AccountContext
import ComponentFlow
import BirthdayPickerScreen

final class PeerInfoScreenBirthdatePickerItem: PeerInfoScreenItem {
    let id: AnyHashable
    let value: TelegramBirthday
    let valueUpdated: (TelegramBirthday) -> Void
    
    init(
        id: AnyHashable,
        value: TelegramBirthday,
        valueUpdated: @escaping (TelegramBirthday) -> Void
    ) {
        self.id = id
        self.value = value
        self.valueUpdated = valueUpdated
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenBirthdatePickerItemNode()
    }
}

private final class PeerInfoScreenBirthdatePickerItemNode: PeerInfoScreenItemNode {
    private let maskNode: ASImageNode
    private let picker = ComponentView<Empty>()
    
    private let bottomSeparatorNode: ASDisplayNode
        
    private var item: PeerInfoScreenBirthdatePickerItem?
    private var presentationData: PresentationData?
    private var theme: PresentationTheme?
    
    override init() {
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
            
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
                        
        super.init()
        
        self.addSubnode(self.bottomSeparatorNode)
        
        self.addSubnode(self.maskNode)
    }
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenBirthdatePickerItem else {
            return 10.0
        }
        
        self.item = item
        self.presentationData = presentationData
        self.theme = presentationData.theme
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let height: CGFloat = 226.0
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
     
        let pickerSize = self.picker.update(
            transition: .immediate,
            component: AnyComponent(BirthdayPickerComponent(
                theme: BirthdayPickerComponent.Theme(presentationTheme: presentationData.theme),
                strings: presentationData.strings,
                value: item.value,
                valueUpdated: item.valueUpdated
            )),
            environment: {},
            containerSize: CGSize(width: width - sideInset * 2.0, height: height)
        )
        let pickerFrame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: pickerSize)
        if let pickerView = self.picker.view {
            if pickerView.superview == nil {
                self.view.addSubview(pickerView)
            }
            transition.updateFrame(view: pickerView, frame: pickerFrame)
        }
       
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        return height
    }
}
