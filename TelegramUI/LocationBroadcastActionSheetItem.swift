import Foundation
import AsyncDisplayKit
import Display

public class LocationBroadcastActionSheetItem: ActionSheetItem {
    public let title: String
    public let beginTimestamp: Double
    public let timeout: Double
    public let strings: PresentationStrings
    public let action: () -> Void
    
    public init(title: String, beginTimestamp: Double, timeout: Double, strings: PresentationStrings, action: @escaping () -> Void) {
        self.title = title
        self.beginTimestamp = beginTimestamp
        self.timeout = timeout
        self.strings = strings
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = LocationBroadcastActionSheetItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? LocationBroadcastActionSheetItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
    }
}

public class LocationBroadcastActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    
    public static let defaultFont: UIFont = Font.regular(20.0)
    
    private var item: LocationBroadcastActionSheetItem?
    
    private let button: HighlightTrackingButton
    private let label: ImmediateTextNode
    private let timerNode: ChatMessageLiveLocationTimerNode
    
    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.button = HighlightTrackingButton()
        
        self.label = ImmediateTextNode()
        self.label.isLayerBacked = true
        self.label.displaysAsynchronously = false
        self.label.maximumNumberOfLines = 1
        
        self.timerNode = ChatMessageLiveLocationTimerNode()
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        self.addSubnode(self.label)
        self.addSubnode(self.timerNode)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemBackgroundColor
                    })
                }
            }
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    func setItem(_ item: LocationBroadcastActionSheetItem) {
        self.item = item
        
        let textColor: UIColor = self.theme.standardActionTextColor
        self.label.attributedText = NSAttributedString(string: item.title, font: ActionSheetButtonNode.defaultFont, textColor: textColor)
        
        self.timerNode.update(backgroundColor: self.theme.controlAccentColor.withAlphaComponent(0.4), foregroundColor: self.theme.controlAccentColor, textColor: self.theme.controlAccentColor, beginTimestamp: item.beginTimestamp, timeout: item.timeout, strings: item.strings)
        
        self.setNeedsLayout()
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 57.0)
    }
    
    public override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let labelSize = self.label.updateLayout(CGSize(width: max(1.0, size.width - 10.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: 16.0, y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        let timerSize = CGSize(width: 28.0, height: 28.0)
        self.timerNode.frame = CGRect(origin: CGPoint(x: size.width - 16.0 - timerSize.width, y: floorToScreenPixels((size.height - timerSize.height) / 2.0)), size: timerSize)
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            item.action()
        }
    }
}

