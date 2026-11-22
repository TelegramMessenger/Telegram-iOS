import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import CheckNode
import TelegramCore
import ChatMessageItemCommon

public final class ChatMessageSelectionNode: ASDisplayNode {
    private let toggle: (Bool) -> Void
    
    public private(set) var selected = false
    private let checkNode: CheckNode
    private var layoutSize = CGSize()
    private var layoutLeftInset: CGFloat = 0.0
    private var layoutCheckX: CGFloat = 6.0
    private var layoutCheckCenterY: CGFloat?
    private var visibleTop: CGFloat = -.greatestFiniteMagnitude
    private var checkBubbleMode: Bool
    
    public init(wallpaper: TelegramWallpaper, theme: PresentationTheme, bubbleMode: Bool = true, toggle: @escaping (Bool) -> Void) {
        self.toggle = toggle
        
        let style = ChatMessageSelectionNode.checkStyle(wallpaper: wallpaper, theme: theme, bubbleMode: bubbleMode)
        self.checkBubbleMode = bubbleMode
        self.checkNode = CheckNode(theme: CheckNodeTheme(theme: theme, style: style, hasInset: true))
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkNode.setSelected(selected, animated: animated)
        }
    }
    
    private static func checkStyle(wallpaper: TelegramWallpaper, theme: PresentationTheme, bubbleMode: Bool) -> CheckNodeTheme.Style {
        if chatMessageSelectionCheckIsPlain(wallpaper: wallpaper, defaultWallpaper: theme.chat.defaultWallpaper, bubbleMode: bubbleMode) {
            return .plain
        }
        return .overlay
    }
    
    /// A selection node outlives a switch of bubble mode while the chat stays in selection: the ring follows the mode. With
    /// the mode unchanged nothing is restyled, as on master.
    public func updateTheme(wallpaper: TelegramWallpaper, theme: PresentationTheme, bubbleMode: Bool) {
        if bubbleMode != self.checkBubbleMode {
            self.checkBubbleMode = bubbleMode
            self.checkNode.theme = CheckNodeTheme(theme: theme, style: ChatMessageSelectionNode.checkStyle(wallpaper: wallpaper, theme: theme, bubbleMode: bubbleMode), hasInset: true)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggle(!self.selected)
        }
    }
    
    /// With the defaults the check sits 6pt in, centred on the row. Without bubbles it sits at `checkX`, centred on
    /// `checkCenterY` (see `ChatMessageBubblelessCheckAnchor`), and a visible top makes it sticky.
    public func updateLayout(size: CGSize, leftInset: CGFloat, checkX: CGFloat = 6.0, checkCenterY: CGFloat? = nil) {
        self.layoutSize = size
        self.layoutLeftInset = leftInset
        self.layoutCheckX = checkX
        self.layoutCheckCenterY = checkCenterY
        self.updateCheckFrame()
    }
    
    /// The chat's visible top in this node's coordinates, while a message taller than the screen is selected without
    /// bubbles: the check stays under it. `-greatestFiniteMagnitude` lets it go.
    public func updateVisibleTop(_ visibleTop: CGFloat) {
        if self.visibleTop != visibleTop {
            self.visibleTop = visibleTop
            if self.layoutCheckCenterY != nil {
                self.updateCheckFrame()
            }
        }
    }
    
    private func updateCheckFrame() {
        let checkSize = CGSize(width: 28.0, height: 28.0)
        var checkY: CGFloat
        if let checkCenterY = self.layoutCheckCenterY {
            checkY = floor(checkCenterY - checkSize.height * 0.5)
            checkY = chatMessageBubblelessStickyCheckY(checkY: checkY, visibleTop: self.visibleTop, rowHeight: self.layoutSize.height)
        } else {
            checkY = floor((self.layoutSize.height - checkSize.height) / 2.0)
        }
        self.checkNode.frame = CGRect(origin: CGPoint(x: self.layoutCheckX + self.layoutLeftInset, y: checkY), size: checkSize)
    }
}
