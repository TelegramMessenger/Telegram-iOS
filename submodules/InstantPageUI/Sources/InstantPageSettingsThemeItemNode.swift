import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramUIPreferences

private final class InstantPageSettingsThemeSelectorNode: ASDisplayNode {
    private let selectionNode: ASImageNode
    private let colorNode: ASImageNode
    
    private let color: UIColor
    
    var selected: Bool = false {
        didSet {
            self.selectionNode.isHidden = !self.selected
        }
    }
    
    var selectionColor: UIColor {
        didSet {
            if !self.selectionColor.isEqual(oldValue) {
                self.selectionNode.image = generateFilledCircleImage(diameter: 46.0, color: nil, strokeColor: self.selectionColor, strokeWidth: 2.0, backgroundColor: nil)
            }
        }
    }
    
    var edgeColor: UIColor {
        didSet {
            if !self.edgeColor.isEqual(oldValue) {
                self.colorNode.image = generateFilledCircleImage(diameter: 46.0, color: self.color, strokeColor: self.edgeColor, strokeWidth: 1.0, backgroundColor: nil)
            }
        }
    }
    
    init(color: UIColor, edgeColor: UIColor, selectionColor: UIColor) {
        self.color = color
        self.edgeColor = edgeColor
        self.selectionColor = selectionColor
        
        self.selectionNode = ASImageNode()
        self.selectionNode.isLayerBacked = true
        self.selectionNode.displayWithoutProcessing = true
        self.selectionNode.displaysAsynchronously = false
        self.selectionNode.image = generateFilledCircleImage(diameter: 46.0, color: nil, strokeColor: self.selectionColor, strokeWidth: 2.0, backgroundColor: nil)
        self.selectionNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 46.0, height: 46.0))
        
        self.colorNode = ASImageNode()
        self.colorNode.isLayerBacked = true
        self.colorNode.displayWithoutProcessing = true
        self.colorNode.displaysAsynchronously = false
        self.colorNode.image = generateFilledCircleImage(diameter: 46.0, color: self.color, strokeColor: self.edgeColor, strokeWidth: 1.0, backgroundColor: nil)
        self.colorNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 46.0, height: 46.0))
        
        super.init()
        
        self.addSubnode(self.colorNode)
        self.addSubnode(self.selectionNode)
    }
}

final class InstantPageSettingsThemeItemNode: InstantPageSettingsItemNode {
    private let update: (InstantPageThemeType) -> Void
    
    private let themeNodes: [InstantPageSettingsThemeSelectorNode]
    
    var themeType: InstantPageThemeType {
        didSet {
            let selectedIndex: Int
            switch self.themeType {
                case .light:
                    selectedIndex = 0
                case .sepia:
                    selectedIndex = 1
                case .gray:
                    selectedIndex = 2
                case .dark:
                    selectedIndex = 3
            }
            
            self.themeNodes[0].edgeColor = (selectedIndex == 1 || selectedIndex == 2) ? UIColor.lightGray : UIColor.white
            
            for i in 0 ..< self.themeNodes.count {
                self.themeNodes[i].selected = i == selectedIndex
            }
        }
    }
    
    init(theme: InstantPageSettingsItemTheme, themeType: InstantPageThemeType, update: @escaping (InstantPageThemeType) -> Void) {
        self.themeType = themeType
        self.update = update
        
        let selectedIndex: Int
        switch themeType {
            case .light:
                selectedIndex = 0
            case .sepia:
                selectedIndex = 1
            case .gray:
                selectedIndex = 2
            case .dark:
                selectedIndex = 3
        }
        
        let selectionColor = UIColor(rgb: 0x007aff)
        self.themeNodes = [
            InstantPageSettingsThemeSelectorNode(color: .white, edgeColor: (selectedIndex == 1 || selectedIndex == 2) ? UIColor.lightGray : UIColor.white, selectionColor: selectionColor),
            InstantPageSettingsThemeSelectorNode(color: UIColor(rgb: 0xcbb98e), edgeColor: UIColor(rgb: 0xcbb98e), selectionColor: selectionColor),
            InstantPageSettingsThemeSelectorNode(color: UIColor(rgb: 0x48484a), edgeColor: UIColor(rgb: 0x48484a), selectionColor: selectionColor),
            InstantPageSettingsThemeSelectorNode(color: UIColor(rgb: 0x333333), edgeColor: UIColor(rgb: 0x333333), selectionColor: selectionColor)
        ]
        
        super.init(theme: theme, selectable: false)
        
        for i in 0 ..< self.themeNodes.count {
            self.themeNodes[i].selected = i == selectedIndex
            self.addSubnode(self.themeNodes[i])
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    override func updateTheme(_ theme: InstantPageSettingsItemTheme) {
        super.updateTheme(theme)
    }
    
    override func updateInternalLayout(width: CGFloat, insets: UIEdgeInsets, previousItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?), nextItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?)) -> (height: CGFloat, separatorInset: CGFloat?) {
        
        let sideInset: CGFloat = 26.0
        let topInset: CGFloat = 12.0
        let itemSize = CGSize(width: 46.0, height: 46.0)
        let spacing: CGFloat = floor((width - CGFloat(self.themeNodes.count) * itemSize.width - sideInset * 2.0) / CGFloat(self.themeNodes.count - 1))
        
        for i in 0 ..< self.themeNodes.count {
            self.themeNodes[i].frame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i) * (itemSize.width + spacing), y: insets.top + topInset), size: itemSize)
        }
        
        return (70.0 + insets.top + insets.bottom, nil)
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let location = recognizer.location(in: self.view)
            for i in 0 ..< self.themeNodes.count {
                if self.themeNodes[i].frame.contains(location) {
                    let themeType: InstantPageThemeType
                    switch i {
                        case 0:
                            themeType = .light
                        case 1:
                            themeType = .sepia
                        case 2:
                            themeType = .gray
                        case 3:
                            themeType = .dark
                        default:
                            themeType = .light
                    }
                    self.update(themeType)
                    break
                }
            }
        }
    }
}

