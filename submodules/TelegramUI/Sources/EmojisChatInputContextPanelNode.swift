import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import Emoji
import ChatPresentationInterfaceState

private struct EmojisChatInputContextPanelEntryStableId: Hashable, Equatable {
    let symbol: String
}

private func backgroundCenterImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 55.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        let lineWidth = UIScreenPixel
        context.setLineWidth(lineWidth)
        
        context.translateBy(x: 460.5, y: 364.0 - 27.0)
        let path: StaticString = "M-490.476836,-365 L-394.167708,-365 L-394.167708,-291.918214 C-394.167708,-291.918214 -383.538396,-291.918214 -397.691655,-291.918214 C-402.778486,-291.918214 -424.555168,-291.918214 -434.037301,-291.918214 C-440.297129,-291.918214 -440.780682,-283.5 -445.999879,-283.5 C-450.393041,-283.5 -452.491241,-291.918214 -456.502636,-291.918214 C-465.083339,-291.918214 -476.209155,-291.918214 -483.779021,-291.918214 C-503.033963,-291.918214 -490.476836,-291.918214 -490.476836,-291.918214 L-490.476836,-365 "
        let _ = try? drawSvgPath(context, path: path)
        context.fillPath()
        context.translateBy(x: 0.0, y: lineWidth / 2.0)
        let _ = try? drawSvgPath(context, path: path)
        context.strokePath()
        context.translateBy(x: -460.5, y: -lineWidth / 2.0 - 364.0 + 27.0)
        context.move(to: CGPoint(x: 0.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width, y: lineWidth / 2.0))
        context.strokePath()
    })
}

private func backgroundLeftImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 16.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        let lineWidth = UIScreenPixel
        context.setLineWidth(lineWidth)
        
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.height, height: size.height)))
        context.strokeEllipse(in: CGRect(origin: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0), size: CGSize(width: size.height - lineWidth, height: size.height - lineWidth)))
    })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
}

private struct EmojisChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let theme: PresentationTheme
    let symbol: String
    let text: String
    
    var stableId: EmojisChatInputContextPanelEntryStableId {
        return EmojisChatInputContextPanelEntryStableId(symbol: self.symbol)
    }
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> EmojisChatInputContextPanelEntry {
        return EmojisChatInputContextPanelEntry(index: self.index, theme: theme, symbol: self.symbol, text: self.text)
    }
    
    static func ==(lhs: EmojisChatInputContextPanelEntry, rhs: EmojisChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.symbol == rhs.symbol && lhs.text == rhs.text && lhs.theme === rhs.theme
    }
    
    static func <(lhs: EmojisChatInputContextPanelEntry, rhs: EmojisChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, emojiSelected: @escaping (String) -> Void) -> ListViewItem {
        return EmojisChatInputPanelItem(theme: self.theme, symbol: self.symbol, text: self.text, emojiSelected: emojiSelected)
    }
}

private struct EmojisChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [EmojisChatInputContextPanelEntry], to toEntries: [EmojisChatInputContextPanelEntry], account: Account, emojiSelected: @escaping (String) -> Void) -> EmojisChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, emojiSelected: emojiSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, emojiSelected: emojiSelected), directionHint: nil) }
    
    return EmojisChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class EmojisChatInputContextPanelNode: ChatInputContextPanelNode {
    private let backgroundLeftNode: ASImageNode
    private let backgroundNode: ASImageNode
    private let backgroundRightNode: ASImageNode
    private let clippingNode: ASDisplayNode
    private let listView: ListView
    
    private var currentEntries: [EmojisChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(EmojisChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = backgroundCenterImage(theme)
        
        self.backgroundLeftNode = ASImageNode()
        self.backgroundLeftNode.displayWithoutProcessing = true
        self.backgroundLeftNode.displaysAsynchronously = false
        self.backgroundLeftNode.image = backgroundLeftImage(theme)
        
        self.backgroundRightNode = ASImageNode()
        self.backgroundRightNode.displayWithoutProcessing = true
        self.backgroundRightNode.displaysAsynchronously = false
        self.backgroundRightNode.image = backgroundLeftImage(theme)
        self.backgroundRightNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize)
        
        self.placement = .overTextInput
        self.isOpaque = false
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.backgroundLeftNode)
        self.addSubnode(self.backgroundRightNode)
        
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.listView)
    }
    
    func updateResults(_ results: [(String, String)]) {
        var entries: [EmojisChatInputContextPanelEntry] = []
        var index = 0
        var stableIds = Set<EmojisChatInputContextPanelEntryStableId>()
        for (symbol, text) in results {
            let entry = EmojisChatInputContextPanelEntry(index: index, theme: self.theme, symbol: symbol.normalizedEmoji, text: text)
            if stableIds.contains(entry.stableId) {
                continue
            }
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        self.prepareTransition(from: self.currentEntries, to: entries)
    }
    
    private func prepareTransition(from: [EmojisChatInputContextPanelEntry]? , to: [EmojisChatInputContextPanelEntry]) {
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: from ?? [], to: to, account: self.context.account, emojiSelected: { [weak self] text in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                    var hashtagQueryRange: NSRange?
                    inner: for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) {
                        if type == [.emojiSearch] {
                            var range = range
                            range.location -= 1
                            range.length += 1
                            hashtagQueryRange = range
                            break inner
                        }
                    }
                    
                    if let range = hashtagQueryRange {
                        let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                        
                        let replacementText = text
                        
                        inputText.replaceCharacters(in: range, with: replacementText)
                        
                        let selectionPosition = range.lowerBound + (replacementText as NSString).length
                        
                        return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                    }
                    return (textInputState, inputMode)
                }
            }
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime)
        
        if let presentationInterfaceState = presentationInterfaceState, let (size, leftInset, rightInset, bottomInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, transition: .immediate, interfaceState: presentationInterfaceState)
        }
    }
    
    private func enqueueTransition(_ transition: EmojisChatInputContextPanelTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let validLayout = self.validLayout, let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.Synchronous)
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: validLayout.0, insets: UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0), duration: 0.0, curve: .Default(duration: nil))
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: updateSizeAndInsets, updateOpaqueState: nil)
        }
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        self.presentationInterfaceState = interfaceState
        
        let sideInsets: CGFloat = 10.0 + leftInset
        let contentWidth = min(size.width - sideInsets - sideInsets, max(24.0, CGFloat(self.currentEntries?.count ?? 0) * 45.0))
        
        var contentLeftInset: CGFloat = 40.0
        var leftOffset: CGFloat = 0.0
        if sideInsets + floor(contentWidth / 2.0) < sideInsets + contentLeftInset + 15.0 {
            let updatedLeftInset = sideInsets + floor(contentWidth / 2.0) - 15.0 - sideInsets
            leftOffset = contentLeftInset - updatedLeftInset
            contentLeftInset = updatedLeftInset
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: sideInsets + leftOffset, y: size.height - 55.0 + 4.0), size: CGSize(width: contentWidth, height: 55.0))
        let backgroundLeftFrame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: contentLeftInset, height: backgroundFrame.size.height - 10.0 + UIScreenPixel))
        let backgroundCenterFrame = CGRect(origin: CGPoint(x: backgroundLeftFrame.maxX, y: backgroundFrame.minY), size: CGSize(width: 30.0, height: 55.0))
        let backgroundRightFrame = CGRect(origin: CGPoint(x: backgroundCenterFrame.maxX, y: backgroundFrame.minY), size: CGSize(width: max(0.0, backgroundFrame.minX + backgroundFrame.size.width - backgroundCenterFrame.maxX), height: backgroundFrame.size.height - 10.0 + UIScreenPixel))
        transition.updateFrame(node: self.backgroundLeftNode, frame: backgroundLeftFrame)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundCenterFrame)
        transition.updateFrame(node: self.backgroundRightNode, frame: backgroundRightFrame)
        
        let gridFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY + 2.0), size: CGSize(width: backgroundFrame.size.width, height: 45.0))
        transition.updateFrame(node: self.clippingNode, frame: gridFrame)
        self.listView.frame = CGRect(origin: CGPoint(), size: CGSize(width: gridFrame.size.height, height: gridFrame.size.width))
        
        let gridBounds = self.listView.bounds
        self.listView.bounds = CGRect(x: gridBounds.minX, y: gridBounds.minY, width: gridFrame.size.height, height: gridFrame.size.width)
        self.listView.position = CGPoint(x: gridFrame.size.width / 2.0, y: gridFrame.size.height / 2.0)
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: gridFrame.size.height, height: gridFrame.size.width), insets: UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0), duration: 0.0, curve: .Default(duration: 0.0))

        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme

            let updatedEntries = self.currentEntries?.map({$0.withUpdatedTheme(interfaceState.theme)}) ?? []
            self.prepareTransition(from: self.currentEntries, to: updatedEntries)
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.clippingNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

