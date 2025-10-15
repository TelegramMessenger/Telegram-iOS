import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatContextQuery
import ChatInputContextPanelNode
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import EdgeEffect

private struct CommandMenuChatInputContextPanelEntryStableId: Hashable {
    let command: PeerCommand
}

private struct CommandMenuChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let command: PeerCommand
    let theme: PresentationTheme
    
    var stableId: CommandMenuChatInputContextPanelEntryStableId {
        return CommandMenuChatInputContextPanelEntryStableId(command: self.command)
    }
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> CommandMenuChatInputContextPanelEntry {
        return CommandMenuChatInputContextPanelEntry(index: self.index, command: self.command, theme: theme)
    }
    
    static func ==(lhs: CommandMenuChatInputContextPanelEntry, rhs: CommandMenuChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.command == rhs.command && lhs.theme === rhs.theme
    }
    
    static func <(lhs: CommandMenuChatInputContextPanelEntry, rhs: CommandMenuChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, fontSize: PresentationFontSize, commandSelected: @escaping (PeerCommand, Bool) -> Void) -> ListViewItem {
        return CommandMenuChatInputPanelItem(context: context, theme: self.theme, fontSize: fontSize, command: self.command, commandSelected: commandSelected)
    }
}

private struct CommandMenuChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [CommandMenuChatInputContextPanelEntry], to toEntries: [CommandMenuChatInputContextPanelEntry], context: AccountContext, fontSize: PresentationFontSize, commandSelected: @escaping (PeerCommand, Bool) -> Void) -> CommandMenuChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, fontSize: fontSize, commandSelected: commandSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, fontSize: fontSize, commandSelected: commandSelected), directionHint: nil) }
    
    return CommandMenuChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class CommandMenuChatInputContextPanelNode: ChatInputContextPanelNode {
    private let backgroundView: GlassBackgroundView
    private let listView: ListView
    private let listMaskView: UIImageView
    private var currentEntries: [CommandMenuChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(CommandMenuChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    
    private let disposable = MetaDisposable()
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, peerId: PeerId, chatPresentationContext: ChatPresentationContext) {
        self.backgroundView = GlassBackgroundView()
        self.backgroundView.layer.anchorPoint = CGPoint()
        
        self.listView = ListView()
        self.listView.clipsToBounds = false
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.limitHitTestToNodes = true
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.listMaskView = UIImageView()
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.view.addSubview(self.backgroundView)
        self.addSubnode(self.listView)
        self.listView.view.mask = self.listMaskView
        
        self.backgroundView.isHidden = true
        self.listView.visibleContentOffsetChanged = { [weak self] offset in
            guard let self else {
                return
            }
            var topOffset: CGFloat = 0.0
            switch offset {
            case let .known(offset):
                topOffset = max(0.0, -offset + self.listView.insets.top)
            case .unknown:
                break
            case .none:
                break
            }
            
            self.backgroundView.isHidden = false
            self.backgroundView.layer.position = CGPoint(x: 0.0, y: topOffset)
        }
        
        self.disposable.set((context.engine.peers.peerCommands(id: peerId)
        |> deliverOnMainQueue).startStrict(next: { [weak self] results in
            if let strongSelf = self {
                strongSelf.updateResults(results.commands)
            }
        }))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func updateResults(_ results: [PeerCommand]) {
        var entries: [CommandMenuChatInputContextPanelEntry] = []
        var index = 0
        var stableIds = Set<CommandMenuChatInputContextPanelEntryStableId>()
        for command in results {
            let entry = CommandMenuChatInputContextPanelEntry(index: index, command: command, theme: self.theme)
            if stableIds.contains(entry.stableId) {
                continue
            }
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        self.prepareTransition(from: self.currentEntries ?? [], to: entries)
    }
    
    private func prepareTransition(from: [CommandMenuChatInputContextPanelEntry]? , to: [CommandMenuChatInputContextPanelEntry]) {
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: from ?? [], to: to, context: self.context, fontSize: self.fontSize, commandSelected: { [weak self] command, sendImmediately in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                if sendImmediately {
                    interfaceInteraction.sendBotCommand(command.peer, "/" + command.command.text)
                } else {
                    interfaceInteraction.updateShowCommands { _ in return false }
                    interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                        var commandQueryRange: NSRange?
                        inner: for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) {
                            if type == [.command] {
                                commandQueryRange = range
                                break inner
                            }
                        }
                        if let range = commandQueryRange {
                            let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                            
                            let replacementText = command.command.text + " "
                            inputText.replaceCharacters(in: range, with: replacementText)
                            
                            let selectionPosition = range.lowerBound + (replacementText as NSString).length
                            
                            return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                        } else {
                            let inputText = NSMutableAttributedString(string: "/" + command.command.text + " ")
                            let selectionPosition = (inputText.string as NSString).length + 1
                            return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                        }
                    }
                }
            }
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: CommandMenuChatInputContextPanelTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let validLayout = self.validLayout, let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                options.insert(.AnimateTopItemPosition)
                options.insert(.AnimateCrossfade)
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: validLayout.0, bottomInset: validLayout.3)
            insets.left = validLayout.1
            insets.right = validLayout.2
            insets.bottom = validLayout.3
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: self.listView.bounds.size, insets: insets, duration: 0.0, curve: .Default(duration: nil))
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: updateSizeAndInsets, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self, firstTime {
                    var topItemOffset: CGFloat?
                    strongSelf.listView.forEachItemNode { itemNode in
                        if topItemOffset == nil {
                            topItemOffset = itemNode.frame.minY
                        }
                    }
                    
                    if let topItemOffset {
                        let offset = strongSelf.listView.bounds.size.height - topItemOffset
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
                        transition.animatePositionAdditive(layer: strongSelf.listView.layer, offset: CGPoint(x: 0.0, y: offset))
                        transition.animatePositionAdditive(layer: strongSelf.backgroundView.layer, offset: CGPoint(x: 0.0, y: offset))
                    }
                }
            })
        }
    }
    
    private func topInsetForLayout(size: CGSize, bottomInset: CGFloat) -> CGFloat {
        let minimumItemHeights: CGFloat = floor(MentionChatInputPanelItemNode.itemHeight * 4.7)
        return max(size.height - bottomInset - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        
        self.backgroundView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + 32.0))
        self.backgroundView.update(
            size: self.backgroundView.bounds.size,
            cornerRadius: 20.0,
            isDark: interfaceState.theme.overallDarkAppearance,
            tintColor: .init(kind: .panel, color: interfaceState.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)),
            transition: ComponentTransition(transition)
        )
        
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size, bottomInset: bottomInset)
        insets.left = leftInset
        insets.right = rightInset
        insets.bottom = bottomInset
        
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        let listMaskHeight: CGFloat = bottomInset + 1.0
        if self.listMaskView.image?.size.height != listMaskHeight {
            let baseGradientAlpha: CGFloat = 0.65
            let numSteps = 8
            let firstStep = 1
            let firstLocation = 0.0
            let colors: [UIColor] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return UIColor(white: 0.0, alpha: 0.0)
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    let value: CGFloat = bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                    return UIColor(white: 0.0, alpha: 1.0 - baseGradientAlpha * value)
                }
            }
            let locations: [CGFloat] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return 0.0
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    return (firstLocation + (1.0 - firstLocation) * step)
                }
            }
            
            self.listMaskView.image = generateGradientImage(
                size: CGSize(width: 8.0, height: listMaskHeight),
                colors: colors,
                locations: locations
            )?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1)
        }
        transition.updateFrame(view: self.listMaskView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            
            let new = self.currentEntries?.map({$0.withUpdatedTheme(interfaceState.theme)}) ?? []
            self.prepareTransition(from: self.currentEntries, to: new)
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        var topItemOffset: CGFloat?
        self.listView.forEachItemNode { itemNode in
            if topItemOffset == nil {
                topItemOffset = itemNode.frame.minY
            }
        }
        
        if let topItemOffset {
            let offset = (self.listView.bounds.size.height - topItemOffset)
            
            let position = self.listView.layer.position
            self.listView.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.backgroundView.layer.animatePosition(from: self.backgroundView.layer.position, to: CGPoint(x: self.backgroundView.layer.position.x, y: self.backgroundView.layer.position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        } else {
            completion()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let listViewFrame = self.listView.frame
        return self.listView.hitTest(CGPoint(x: point.x - listViewFrame.minX, y: point.y - listViewFrame.minY), with: event)
    }
    
    override var topItemFrame: CGRect? {
        var topItemFrame: CGRect?
        self.listView.forEachItemNode { itemNode in
            if topItemFrame == nil {
                topItemFrame = itemNode.frame
            }
        }
        return topItemFrame
    }
}
