import Foundation
import Display
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import TelegramCore

final class ThemeAccentColorActionSheet: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(account: Account, currentValue: Int32, applyValue: @escaping (Int32) -> Void) {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let theme = presentationData.theme
        let strings = presentationData.strings
        
        super.init(theme: ActionSheetControllerTheme(presentationTheme: theme))
       
        self.presentationDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationTheme: presentationData.theme)
            }
        })
        
        self._ready.set(.single(true))
        
        var items: [ActionSheetItem] = []
        items.append(ThemeAccentColorActionSheetItem(strings: strings, currentValue: currentValue, valueChanged: { [weak self] value in
            self?.dismissAnimated()
            applyValue(value)
        }))

        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                }),
            ])
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}

private final class ThemeAccentColorActionSheetItem: ActionSheetItem {
    let strings: PresentationStrings
    
    let currentValue: Int32
    let valueChanged: (Int32) -> Void
    
    init(strings: PresentationStrings, currentValue: Int32, valueChanged: @escaping (Int32) -> Void) {
        self.strings = strings
        self.currentValue = currentValue
        self.valueChanged = valueChanged
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ThemeAccentColorActionSheetItemNode(theme: theme, strings: self.strings, currentValue: self.currentValue, valueChanged: self.valueChanged)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ThemeAccentColorActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let titleNode: ImmediateTextNode
    
    private let valueChanged: (Int32) -> Void
    private let items: [Int32]
    private let itemNodes: [ASImageNode]
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, currentValue: Int32, valueChanged: @escaping (Int32) -> Void) {
        self.theme = theme
        self.strings = strings
        self.valueChanged = valueChanged
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isLayerBacked = true
        self.titleNode.attributedText = NSAttributedString(string: strings.Appearance_PickAccentColor, font: Font.medium(18.0), textColor: theme.primaryTextColor)
        
        self.items = [
            0xf83b4c, // red
            0xff7519, // orange
            0xeba239, // yellow
            0x29b327, // green
            0x00c2ed, // light blue
            0x007ee5, // blue
            0x7748ff, // purple
            0xff5da2
        ]
        self.itemNodes = self.items.map { color in
            let imageNode = ASImageNode()
            imageNode.displaysAsynchronously = false
            imageNode.displayWithoutProcessing = true
            
            imageNode.image = generateImage(CGSize(width: 60.0, height: 60.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.draw(generateFilledCircleImage(diameter: size.width, color: UIColor(rgb: UInt32(bitPattern: color)))!.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    if color == currentValue {
                        context.scaleBy(x: 0.333, y: 0.333)
                        context.translateBy(x: 62.0, y: 72.0)
                        context.setLineWidth(10.0)
                        context.setLineCap(.round)
                        context.setStrokeColor(UIColor.white.cgColor)
                        
                        let _ = try? drawSvgPath(context, path: "M0,23.173913 L16.699191,39.765981 C17.390617,40.452972 18.503246,40.464805 19.209127,39.792676 L61,0 S ")
                    }
                })
            return imageNode
        }
        
        super.init(theme: theme)
        
        self.addSubnode(self.titleNode)
        
        for itemNode in self.itemNodes {
            itemNode.isUserInteractionEnabled = true
            self.addSubnode(itemNode)
            itemNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            for i in 0 ..< self.itemNodes.count {
                if self.itemNodes[i].view == recognizer.view {
                    self.valueChanged(self.items[i])
                    break
                }
            }
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let topInset: CGFloat = 12.0
        let maximumItemSpacing: CGFloat = 18.0
        let sideInset: CGFloat = 10.0
        let columnCount: CGFloat = 4.0
        let rowCount: CGFloat = 2.0
        let itemSide: CGFloat = 60.0
        
        let itemsWidth = itemSide * columnCount
        let remainingWidth = constrainedSize.width - itemsWidth - sideInset * 2.0
        let proposedSpacing = floor(remainingWidth / (columnCount - 1.0))
        let itemSpacing = min(proposedSpacing, maximumItemSpacing)
        
        let titleSpacing: CGFloat = itemSpacing
        let bottomInset: CGFloat = itemSpacing
        
        let titleSize = self.titleNode.updateLayout(constrainedSize)
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((constrainedSize.width - titleSize.width) / 2.0), y: topInset), size: titleSize)
        
        let itemsWidthWithSpacing = itemSpacing * (columnCount - 1.0) + itemSide * columnCount
        let itemsLeftOrigin = floor((constrainedSize.width - itemsWidthWithSpacing) / 2.0)
        
        for i in 0 ..< self.itemNodes.count {
            let row = CGFloat(i / 4)
            let column = CGFloat(i % 4)
            self.itemNodes[i].frame = CGRect(origin: CGPoint(x: itemsLeftOrigin + column * (itemSide + itemSpacing), y: topInset + titleSize.height + titleSpacing + row * (itemSide + itemSpacing)), size: CGSize(width: itemSide, height: itemSide))
        }
        
        return CGSize(width: constrainedSize.width, height: topInset + titleSize.height + titleSpacing + rowCount * itemSide + (rowCount - 1.0) * itemSpacing + bottomInset)
    }
    
    override func layout() {
        super.layout()
    }
}

