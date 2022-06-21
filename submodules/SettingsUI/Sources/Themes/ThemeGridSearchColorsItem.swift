import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ListSectionHeaderNode

private class ThemeGridColorNode: HighlightableButtonNode {
    let action: () -> Void
    
    init(color: WallpaperSearchColor, strokeColor: UIColor, dark: Bool, action: @escaping (WallpaperSearchColor) -> Void) {
        self.action = {
            action(color)
        }
        
        super.init()
        
        let image: UIImage?
        if color == .white && !dark {
            image = generateFilledCircleImage(diameter: 42.0, color: .white, strokeColor: strokeColor, strokeWidth: 1.0)
        } else if color == .black && dark {
            image = generateFilledCircleImage(diameter: 42.0, color: .black, strokeColor: strokeColor, strokeWidth: 1.0)
        } else {
            image = generateFilledCircleImage(diameter: 42.0, color: color.displayColor)
        }
        self.setImage(image, for: .normal)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc func pressed() {
        self.action()
    }
}

private let inset: CGFloat = 15.0
private let diameter: CGFloat = 42.0

final class ThemeGridSearchColorsNode: ASDisplayNode {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let sectionHeaderNode: ListSectionHeaderNode
    private let scrollNode: ASScrollNode
    
    private let colorSelected: (WallpaperSearchColor) -> Void

    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, colorSelected: @escaping (WallpaperSearchColor) -> Void) {
        self.theme = theme
        self.strings = strings
        
        self.colorSelected = colorSelected
    
        self.sectionHeaderNode = ListSectionHeaderNode(theme: theme)
        self.sectionHeaderNode.title = strings.WallpaperSearch_ColorTitle.uppercased()
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        
        super.init()
        
        self.addSubnode(self.sectionHeaderNode)
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.view.contentSize = CGSize(width: (inset + diameter) * CGFloat(WallpaperSearchColor.allCases.count) + inset, height: 71.0)
        
        for color in WallpaperSearchColor.allCases {
            let colorNode = ThemeGridColorNode(color: color, strokeColor: theme.list.controlSecondaryColor, dark: theme.overallDarkAppearance, action: colorSelected)
            self.scrollNode.addSubnode(colorNode)
        }
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        if self.theme !== theme || self.strings !== strings {
            self.theme = theme
            self.strings = strings
            
            self.sectionHeaderNode.title = strings.WallpaperSearch_ColorTitle.uppercased()
            self.sectionHeaderNode.updateTheme(theme: theme)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 100.0)
    }
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        let hadLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset)
        
        self.sectionHeaderNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 29.0))
        self.sectionHeaderNode.updateLayout(size: CGSize(width: size.width, height: 29.0), leftInset: leftInset, rightInset: rightInset)
        
        var insets = UIEdgeInsets()
        insets.left += leftInset
        insets.right += rightInset

        self.scrollNode.frame = CGRect(x: 0.0, y: 29.0, width: size.width, height: size.height - 29.0)
        self.scrollNode.view.contentInset = insets
        if !hadLayout {
            self.scrollNode.view.contentOffset = CGPoint(x: -leftInset, y: 0.0)
        }
        
        var offset: CGFloat = inset
        if let subnodes = self.scrollNode.subnodes {
            for node in subnodes {
                node.frame = CGRect(x: offset, y: inset, width: diameter, height: diameter)
                offset += diameter + inset
            }
        }
    }
}


class ThemeGridSearchColorsItem: ListViewItem {
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let colorSelected: (WallpaperSearchColor) -> Void
    
    let header: ListViewItemHeader?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, colorSelected: @escaping (WallpaperSearchColor) -> Void) {
        self.account = account
        self.theme = theme
        self.strings = strings
        self.colorSelected = colorSelected
        self.header = nil
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeGridSearchColorsItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem != nil)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ThemeGridSearchColorsItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem != nil)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { info in
                            apply().1(info)
                        })
                    }
                }
            }
        }
    }
}

class ThemeGridSearchColorsItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private var colorsNode: ThemeGridSearchColorsNode?
    
    private var item: ThemeGridSearchColorsItem?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, nextItem == nil)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    func asyncLayout() -> (_ item: ThemeGridSearchColorsItem, _ params: ListViewItemLayoutParams, _ last: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        return { [weak self] item, params, last in
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 101.0), insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.theme !== item.theme {
                    updatedTheme = item.theme
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                        }
                        
                        let colorsNode: ThemeGridSearchColorsNode
                        if let currentColorsNode = strongSelf.colorsNode {
                            colorsNode = currentColorsNode
                            colorsNode.updateThemeAndStrings(theme: item.theme, strings: item.strings)
                        } else {
                            colorsNode = ThemeGridSearchColorsNode(account: item.account, theme: item.theme, strings: item.strings, colorSelected: item.colorSelected)
                            strongSelf.colorsNode = colorsNode
                            strongSelf.addSubnode(colorsNode)
                        }
                        
                        colorsNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                        colorsNode.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        
                        let separatorHeight = UIScreenPixel
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = true
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
}
