import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import SwiftSignalKit
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatInputContextPanelNode
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import ChatMessageWidgetBubbleContentNode
import CoreList
import CoreListComponentHost
import ListViewItemCoreListHost

private enum VerticalChatContextResultsEntryStableId: Hashable {
    case action
    case result(ChatContextResult)
    /// A result drawn as a widget preview: another identity, so a change of how it draws is a delete and an insert.
    case widgetResult(ChatContextResult)
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .action:
                hasher.combine(0)
            case let .result(result):
                hasher.combine(result.id.hashValue)
            case let .widgetResult(result):
                hasher.combine(1)
                hasher.combine(result.id.hashValue)
        }
    }
    
    static func ==(lhs: VerticalChatContextResultsEntryStableId, rhs: VerticalChatContextResultsEntryStableId) -> Bool {
        switch lhs {
            case .action:
                if case .action = rhs {
                    return true
                } else {
                    return false
                }
            case let .result(lhsResult):
                if case let .result(rhsResult) = rhs, lhsResult == rhsResult {
                    return true
                } else {
                    return false
                }
            case let .widgetResult(lhsResult):
                if case let .widgetResult(rhsResult) = rhs, lhsResult == rhsResult {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum VerticalListContextResultsChatInputContextPanelEntry: Equatable {
    case action(PresentationTheme, String)
    case result(Int, PresentationTheme, ChatContextResult)
    /// widget-sandbox v0.2 (v0.2 W3): a widget result, with how it draws and the height its widget last reported.
    case widgetResult(Int, PresentationTheme, ChatContextResult, TelegramMediaWidget, ChatContextResultWidgetAppearance, CGFloat?)
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> VerticalListContextResultsChatInputContextPanelEntry {
        switch self {
        case let .action(_, value):
            return .action(theme, value)
        case let .result(index, _, result):
            return .result(index, theme, result)
        case let .widgetResult(index, _, result, widget, appearance, reportedHeight):
            return .widgetResult(index, theme, result, widget, appearance, reportedHeight)
        }
    }
    
    var stableId: VerticalChatContextResultsEntryStableId {
        switch self {
            case .action:
                return .action
            case let .result(_, _, result):
                return .result(result)
            case let .widgetResult(_, _, result, _, _, _):
                return .widgetResult(result)
        }
    }
    
    static func ==(lhs: VerticalListContextResultsChatInputContextPanelEntry, rhs: VerticalListContextResultsChatInputContextPanelEntry) -> Bool {
        switch lhs {
        case let .action(lhsTheme, lhsTitle):
                if case let .action(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme && lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .result(lhsIndex, lhsTheme, lhsResult):
                if case let .result(rhsIndex, rhsTheme, rhsResult) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsResult == rhsResult {
                    return true
                } else {
                    return false
                }
            case let .widgetResult(lhsIndex, lhsTheme, lhsResult, _, lhsAppearance, lhsReportedHeight):
                // The widget is the result's own (`lhsResult == rhsResult` compares it).
                if case let .widgetResult(rhsIndex, rhsTheme, rhsResult, _, rhsAppearance, rhsReportedHeight) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsResult == rhsResult, lhsAppearance == rhsAppearance, lhsReportedHeight == rhsReportedHeight {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func item(engine: TelegramEngine, strings: PresentationStrings, actionSelected: @escaping () -> Void, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool, widgetHeightReported: @escaping (String, CGFloat) -> Void) -> ListViewItem {
        switch self {
            case let .action(theme, title):
                return VerticalListContextResultsChatInputPanelButtonItem(theme: theme, title: title, pressed: actionSelected)
            case let .result(_, theme, result):
                return VerticalListContextResultsChatInputPanelItem(engine: engine, theme: theme, result: result, resultSelected: resultSelected)
            case let .widgetResult(_, theme, result, widget, appearance, reportedHeight):
                return VerticalListContextResultsChatInputPanelWidgetItem(theme: theme, strings: strings, result: result, widget: widget, appearance: appearance, reportedHeight: reportedHeight, resultSelected: resultSelected, heightReported: widgetHeightReported)
        }
    }
}

/// The inline bot results as a list (`ChatContextResultCollectionPresentation.list`): CoreList with the chat history's
/// render-server scrolling (`.keyframe`, the user's call of 2026-10-29), its rows the `ListViewItem`s they were under
/// `ListViewImpl` (`ListViewItemCoreListItem`). A large top inset places the first result low, a few rows above the
/// input panel; the rows scroll up into that room and show there, and a short list stacks above the input panel
/// (`stacksFromBottom`). A row is visible wherever it shows: in that room and under the input panel's glass, not behind
/// the keyboard (`coveredBottomInset`, `visibleRectInsets`), so a widget result's preview runs exactly then (v0.2 W3).
final class VerticalListContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    /// The glass under the rows starts at the first result's top and stops at the panel's top once that has scrolled
    /// past it. It rides the content on the list's content motion mirror (`backgroundMover`), which repeats the
    /// render-server flights a per-frame follower trailed by up to 60 pt, outside the list's bottom fade, which it does
    /// not take, and moves on from where it was in a pass (`animateBackground`). Its stop is the fixed clip's: the
    /// clip rounds the panel's top corners as the glass's own corners did when it parked there.
    private let backgroundClipView: UIView
    private let backgroundMover: UIView
    private let backgroundView: GlassBackgroundView
    private var backgroundIsDark = false
    /// The glass as it was presented when this run-loop turn's first pass began, and the turn's first animated
    /// transition: every pass of the turn moves the glass on from there, the last one's choice standing. Between passes
    /// of one turn nothing is committed, so the screen still shows the turn's start (a swap, a layout pass and a widget's
    /// height report can all land in one turn). Cleared after the turn's commit.
    private var turnBackgroundBefore: BackgroundBeforePass?
    private var turnBackgroundTransition: CoreListTransition = .immediate
    private var turnEndObserver: CFRunLoopObserver?
    private let listView: CoreVirtualListView
    private let listMaskView: UIImageView
    private let selectionRecognizer: ListViewItemCoreListSelectionRecognizer
    private var currentExternalResults: ChatContextResultCollection?
    private var currentProcessedResults: ChatContextResultCollection?
    private var currentEntries: [VerticalListContextResultsChatInputContextPanelEntry]?
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    /// Whether the rows have animated in (the first pass with rows does it).
    private var hasAppeared = false
    
    private let loadMoreDisposable = MetaDisposable()
    private var isLoadingMore: Bool = false
    
    /// widget-sandbox v0.2 (v0.2 W3): how widget results draw, from the chat's interface state once laid out, and the
    /// height each result's widget last reported (by result id), which its row is laid out from: a row scrolled out and
    /// back in is a new view, whose widget starts at that height. Ids are the bot's own, so it is cleared when the results
    /// come from another bot (the panel stays for any list-presented results).
    private var widgetAppearance: ChatContextResultWidgetAppearance
    private var widgetPreviewHeights: [String: CGFloat] = [:]
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.widgetAppearance = ChatContextResultWidgetAppearance(theme: theme, wallpaper: .builtin(WallpaperSettings()), fontSize: fontSize, cornerRadius: 16.0)
        self.backgroundClipView = UIView()
        self.backgroundClipView.clipsToBounds = true
        self.backgroundClipView.isUserInteractionEnabled = false
        self.backgroundClipView.layer.cornerRadius = 20.0
        self.backgroundClipView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.backgroundMover = UIView()
        self.backgroundMover.isUserInteractionEnabled = false
        self.backgroundView = GlassBackgroundView()
        
        self.listView = CoreVirtualListView(forEmbedding: CGRect(), deceleration: .keyframe)
        // Before the first rows: a pass measures the old placement with the current value.
        self.listView.stacksFromBottom = true
        self.listView.isHidden = true
        self.listView.disablesInteractiveTransitionGestureRecognizer = true
        self.selectionRecognizer = ListViewItemCoreListSelectionRecognizer(list: self.listView)
        
        self.listMaskView = UIImageView()
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.view.addSubview(self.backgroundClipView)
        self.backgroundClipView.addSubview(self.backgroundMover)
        self.backgroundMover.addSubview(self.backgroundView)
        self.view.addSubview(self.listView)
        self.listView.addContentMotionMirror(self.backgroundMover)
        self.listView.mask = self.listMaskView
        self.listView.scrollGestureHostView.addGestureRecognizer(self.selectionRecognizer)
        
        self.listView.willBeginDragging = { [weak self] in
            self?.selectionRecognizer.cancel()
        }
        self.listView.onLoadedEdgeReached = { [weak self] edge in
            guard edge == .bottom else {
                return
            }
            // Reported at the end of a pass: load on the next turn.
            DispatchQueue.main.async {
                self?.loadMore()
            }
        }
        
        self.backgroundClipView.isHidden = true
        // Rows load and leave as the content moves; the glass's own motion is the mirror's.
        self.listView.onVisibleWindowChanged = { [weak self] in
            self?.placeBackground()
        }
    }
    
    deinit {
        self.loadMoreDisposable.dispose()
    }
    
    func updateResults(_ results: ChatContextResultCollection) {
        if self.currentExternalResults == results {
            return
        }
        if let currentExternalResults = self.currentExternalResults, currentExternalResults.botId != results.botId {
            self.widgetPreviewHeights.removeAll()
        }
        self.currentExternalResults = results
        self.currentProcessedResults = results
        
        self.isLoadingMore = false
        self.loadMoreDisposable.set(nil)
        
        self.updateInternalResults(results)
        // CoreList reports an edge when it is reached, not while it stays reached: new results whose end is already in
        // reach (a short list after a short one) ask for their next page here, as `ListViewImpl` asked after every
        // transaction.
        if self.listView.reachedLoadedEdges.contains(.bottom) {
            self.loadMore()
        }
    }
    
    /// `animated` false for one row's new height: the whole list fading over it would only flicker.
    private func updateInternalResults(_ results: ChatContextResultCollection, animated: Bool = true) {
        var entries: [VerticalListContextResultsChatInputContextPanelEntry] = []
        var index = 0
        var resultIds = Set<VerticalChatContextResultsEntryStableId>()
        // One row: a response that carries both switch_pm and switch_webview still has a single button,
        // and there is only one `.action` stable id for it.
        if let button = ChatContextResultsButton(results: results) {
            let entry: VerticalListContextResultsChatInputContextPanelEntry = .action(self.theme, button.title)
            entries.append(entry)
            resultIds.insert(entry.stableId)
        }
        let widgetsEnabled = chatMessageWidgetRenderingEnabled()
        for result in results.results {
            let entry: VerticalListContextResultsChatInputContextPanelEntry
            if let widget = messageWidgetPreviewWidget(result.message, renderingEnabled: widgetsEnabled) {
                entry = .widgetResult(index, self.theme, result, widget, self.widgetAppearance, self.widgetPreviewHeights[result.id])
            } else {
                entry = .result(index, self.theme, result)
            }
            if resultIds.contains(entry.stableId) {
                continue
            } else {
                resultIds.insert(entry.stableId)
            }
            entries.append(entry)
            index += 1
        }
        
        self.currentEntries = entries
        self.applyEntries(transition: animated && self.hasAppeared ? .easeInOut(duration: 0.2) : .immediate)
    }
    
    /// Hands the entries, the size and the insets to the list in one pass; before the first layout they wait for it.
    private func applyEntries(transition: CoreListTransition) {
        guard let (size, leftInset, rightInset, bottomInset) = self.validLayout, let entries = self.currentEntries, let results = self.currentProcessedResults else {
            return
        }
        let actionSelected: () -> Void = { [weak self] in
            // Resolved at tap time: an `.action` entry compares only its title, so a later answer with the same
            // button text keeps this closure, and the captured `results` would carry the old payload or bot.
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction, let results = strongSelf.currentProcessedResults {
                ChatContextResultsButton(results: results)?.activate(context: strongSelf.context, interfaceInteraction: interfaceInteraction, botId: results.botId)
            }
        }
        let resultSelected: (ChatContextResult, ASDisplayNode, CGRect) -> Bool = { [weak self] result, node, rect in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                strongSelf.selectionRecognizer.clearHighlight(animated: true)
                return interfaceInteraction.sendContextResult(results, result, node, rect)
            } else {
                return false
            }
        }
        let widgetHeightReported: (String, CGFloat) -> Void = { [weak self] resultId, height in
            self?.widgetPreviewHeightReported(resultId: resultId, height: height)
        }
        let listItems = entries.map { $0.item(engine: self.context.engine, strings: self.strings, actionSelected: actionSelected, resultSelected: resultSelected, widgetHeightReported: widgetHeightReported) }
        var items: [CoreListItem] = []
        for (index, entry) in entries.enumerated() {
            let neighbors = ListViewItemNeighbors(previous: index > 0 ? listItems[index - 1].neighborDescriptor : nil, next: index + 1 < listItems.count ? listItems[index + 1].neighborDescriptor : nil)
            items.append(ListViewItemCoreListItem(identity: AnyHashable(entry.stableId), content: AnyEquatable(entry), listItem: listItems[index], neighbors: neighbors, leftInset: leftInset, rightInset: rightInset))
        }
        
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size, bottomInset: bottomInset, hasSwitchPeer: self.currentExternalResults.flatMap(ChatContextResultsButton.init(results:)) != nil)
        insets.bottom = bottomInset
        
        let appears = !self.hasAppeared && !items.isEmpty
        if self.turnEndObserver == nil {
            self.turnBackgroundBefore = self.backgroundBeforePass()
            self.turnBackgroundTransition = .immediate
            // After Core Animation's commit (its observer's order is 2000000): the next turn starts from what this one
            // committed. A pass made during the commit (its layout) adds this too late for that callout, so the next
            // wake-up clears it instead, before anything else runs.
            let activities = CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue | CFRunLoopActivity.afterWaiting.rawValue
            let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, activities, false, CFIndex.max, { [weak self] _, _ in
                self?.turnBackgroundBefore = nil
                self?.turnEndObserver = nil
            })
            self.turnEndObserver = observer
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        }
        if self.turnBackgroundTransition.isImmediate, !transition.isImmediate {
            self.turnBackgroundTransition = transition
        }
        self.listView.applyChanges(items: items, newSize: size, newInsets: insets, transition: appears ? .immediate : transition)
        
        if appears {
            self.hasAppeared = true
            self.listView.isHidden = false
            self.backgroundClipView.isHidden = false
            self.placeBackground()
            if let topItemFrame = self.topItemFrame {
                // From below the panel, as the results arrive.
                let offset = size.height - topItemFrame.minY
                let appearTransition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
                appearTransition.animatePositionAdditive(layer: self.listView.layer, offset: CGPoint(x: 0.0, y: offset))
                appearTransition.animatePositionAdditive(layer: self.backgroundClipView.layer, offset: CGPoint(x: 0.0, y: offset))
            }
        } else {
            self.animateBackground(after: self.turnBackgroundBefore, transition: self.turnBackgroundTransition)
        }
    }
    
    /// Where the glass and its first row were on screen, presented, when the run-loop turn's first pass began, for the
    /// turn's passes to move the glass on from there.
    private struct BackgroundBeforePass {
        let firstRow: UIView?
        /// The glass's top less its first row's, on screen. Both ride the content's motion, so this compares their
        /// presented places in the content, all from the last commit: a row's frame from the list (`presentedFrame(of:)`)
        /// is its model one, without its own slide, at the engine's last sampled offset, a frame behind a flight; and a
        /// model read can be newer than the commit (see `moverMotion`).
        let glassGapFromFirstRow: CGFloat?
        let glassTop: CGFloat
        /// The content's motion under way on the mirror: its presented origin less its model one, as committed. A scroll
        /// tick earlier in the turn can have rebased the content's coordinates, which moves the content's origin and
        /// every row's place in the content together and nothing on screen; only the model has it yet. A committed row
        /// with no slide of its own measures it: its place in the content now, less its presented one.
        let moverMotion: CGFloat
        /// The part of `moverMotion` a viewport animation adds; the rest is a flight's.
        let viewportMotion: CGFloat
    }
    
    /// Keys of the animations the panel puts on the glass.
    private static let glassAnimationKeyPrefix = "panel.glass."
    
    private func backgroundBeforePass() -> BackgroundBeforePass? {
        guard self.hasAppeared else {
            return nil
        }
        var entries = self.listView.loadedItemEntries
        let firstRow = entries.next()?.view
        let glassLayer = self.backgroundView.layer.presentation() ?? self.backgroundView.layer
        let moverLayer = self.backgroundMover.layer.presentation() ?? self.backgroundMover.layer
        var uncommittedRebase: CGFloat = 0.0
        for (_, view) in self.listView.loadedItemEntries {
            let slides = (view.layer.animationKeys() ?? []).contains { key in
                (view.layer.animation(forKey: key) as? CAPropertyAnimation)?.keyPath == "position.y"
            }
            if !slides, let rowTop = self.presentedContentTop(of: view) {
                uncommittedRebase = self.listView.contentFrame(of: view).minY - rowTop
                break
            }
        }
        var glassGapFromFirstRow: CGFloat?
        if let firstRow {
            if let glassPresentation = self.backgroundView.layer.presentation() {
                // A row the last pass inserted can have no presentation yet (the commit is not on screen): it will show at
                // its model place, as committed, while the glass keeps the slide that pass gave it.
                let rowTop = self.presentedContentTop(of: firstRow) ?? (self.listView.contentFrame(of: firstRow).minY - uncommittedRebase)
                glassGapFromFirstRow = glassPresentation.frame.minY - rowTop
            } else {
                glassGapFromFirstRow = self.backgroundView.layer.frame.minY - self.listView.contentFrame(of: firstRow).minY
            }
        }
        return BackgroundBeforePass(
            firstRow: firstRow,
            glassGapFromFirstRow: glassGapFromFirstRow,
            glassTop: glassLayer.frame.minY - moverLayer.bounds.origin.y,
            moverMotion: moverLayer.bounds.origin.y - (self.backgroundMover.layer.bounds.origin.y - uncommittedRebase),
            viewportMotion: self.listView.viewportAnimationOffset
        )
    }
    
    /// A loaded row's top in the content's coordinates as last committed, its own slide included, through the parents it
    /// was committed in (a row back from a crossing carry was committed in another overlay than the one it is in now).
    /// Nil before its first commit.
    private func presentedContentTop(of row: UIView) -> CGFloat? {
        guard let rowPresentation = row.layer.presentation(), let contentPresentation = self.listView.scrollGestureHostView.layer.presentation() else {
            return nil
        }
        return rowPresentation.convert(rowPresentation.bounds, to: contentPresentation).minY
    }
    
    /// Places the glass in the content's coordinates (the mirror's), at once: from the first loaded row's top, which is
    /// the first result's when it is loaded and otherwise a row above the panel's top (the window loads a margin past the
    /// screen), down past the last loaded row by the panel's height, so its bottom is below the panel wherever the content
    /// can be. Returns that first row.
    @discardableResult
    private func placeBackground() -> UIView? {
        guard self.hasAppeared, let (size, _, _, _) = self.validLayout else {
            return nil
        }
        var firstView: UIView?
        var firstFrame: CGRect?
        var lastFrame: CGRect?
        for (_, view) in self.listView.loadedItemEntries {
            let frame = self.listView.contentFrame(of: view)
            if firstFrame == nil {
                firstView = view
                firstFrame = frame
            }
            lastFrame = frame
        }
        guard let firstView, let firstFrame, let lastFrame else {
            return nil
        }
        let top = firstFrame.minY
        // Rounded up, so loading rows rarely resizes the glass.
        let height = ceil((max(lastFrame.maxY - top, 0.0) + size.height + 32.0) / 512.0) * 512.0
        let frame = CGRect(x: 0.0, y: top, width: size.width, height: height)
        if self.backgroundView.bounds.size != frame.size {
            self.backgroundView.update(
                size: frame.size,
                cornerRadius: 20.0,
                isDark: self.backgroundIsDark,
                tintColor: .init(kind: .panel),
                transition: .immediate
            )
        }
        self.backgroundView.frame = frame
        return firstView
    }
    
    /// After a pass: places the glass, and moves it on from where it was at the turn's start (`before`), so its top edge
    /// never steps away from what it is attached to.
    /// - The same first row: the mirror carries the content's motion and the glass copies the row's own slide (a
    ///   survivor whose resting place changed gets an additive track while the resting offset changes at once), so it
    ///   moves as the row does, a jump included; a gap it had from the row (a slide this turn replaces) closes on the
    ///   turn's curve.
    /// - Another first row (one inserted above it, its delete, new results): the glass slides from where it was to the
    ///   new first row's top on the turn's curve, apart from this turn's own viewport motion, which it cancels; motion
    ///   already under way on the mirror stays, as the rows keep it. A top parked at the panel's top looks the same
    ///   wherever above it is, so the slide starts there.
    /// Copies and slides take no completions; each pass replaces them from what it finds.
    private func animateBackground(after before: BackgroundBeforePass?, transition: CoreListTransition) {
        guard let firstRow = self.placeBackground() else {
            return
        }
        let glassLayer = self.backgroundView.layer
        for key in glassLayer.animationKeys() ?? [] where key.hasPrefix(Self.glassAnimationKeyPrefix) {
            glassLayer.removeAnimation(forKey: key)
        }
        guard let before else {
            return
        }
        let layoutTransition = ComponentTransition(transition).containedViewLayoutTransition
        if firstRow === before.firstRow, let gap = before.glassGapFromFirstRow {
            self.copyAdditiveAnimations(from: firstRow.layer, keyPath: "position.y", into: "row.", onlyUncommitted: false)
            self.slideBackground(from: gap, transition: layoutTransition, durationWhenImmediate: 0.2)
        } else if case .animated = layoutTransition {
            let newTop = self.listView.settledFrame(of: firstRow).minY
            guard before.glassTop > 0.0 || newTop > 0.0 else {
                return
            }
            // This turn's viewport track has no `beginTime` yet (this commit resolves it), and CoreList folds what an
            // earlier one had left into it, so the slide starts against a flight's motion alone; with none, the mirror's
            // motion carries on and the slide starts against all of it.
            let cancelsViewportMotion = self.copyAdditiveAnimations(from: self.backgroundMover.layer, keyPath: "bounds.origin.y", into: "viewport.", onlyUncommitted: true)
            let carriedMotion = cancelsViewportMotion ? before.moverMotion - before.viewportMotion : before.moverMotion
            self.slideBackground(from: max(before.glassTop, 0.0) - newTop + carriedMotion, transition: layoutTransition, durationWhenImmediate: nil)
        }
    }
    
    /// Copies `source`'s additive `keyPath` animations onto the glass as `position.y`: the row's slide as it is, the
    /// mirror's `bounds.origin.y` motion as its opposite on screen, which cancels it. Returns whether it copied any.
    @discardableResult
    private func copyAdditiveAnimations(from source: CALayer, keyPath: String, into keyPrefix: String, onlyUncommitted: Bool) -> Bool {
        var copied = false
        for key in source.animationKeys() ?? [] {
            guard let animation = source.animation(forKey: key) as? CAPropertyAnimation, animation.keyPath == keyPath, animation.isAdditive, !onlyUncommitted || animation.beginTime == 0.0, let copy = animation.copy() as? CAPropertyAnimation else {
                continue
            }
            copy.keyPath = "position.y"
            copy.delegate = nil
            self.backgroundView.layer.add(copy, forKey: Self.glassAnimationKeyPrefix + keyPrefix + key)
            copied = true
        }
        return copied
    }
    
    /// An additive slide of the glass from `offset` to its place, on the pass's curve; an immediate pass slides only when
    /// it says how long.
    private func slideBackground(from offset: CGFloat, transition: ContainedViewLayoutTransition, durationWhenImmediate: Double?) {
        guard abs(offset) > 0.5 else {
            return
        }
        let duration: Double
        let curve: ContainedViewLayoutTransitionCurve
        switch transition {
        case let .animated(animatedDuration, animatedCurve):
            duration = animatedDuration
            curve = animatedCurve
        case .immediate:
            guard let durationWhenImmediate else {
                return
            }
            duration = durationWhenImmediate
            curve = .easeInOut
        }
        self.backgroundView.layer.animate(from: offset as NSNumber, to: 0.0 as NSNumber, keyPath: "position.y", timingFunction: curve.timingFunction, duration: duration, mediaTimingFunction: curve.mediaTimingFunction, additive: true, key: Self.glassAnimationKeyPrefix + "slide")
    }
    
    /// A widget result's widget reported a new height: its row lays out again from it.
    private func widgetPreviewHeightReported(resultId: String, height: CGFloat) {
        guard self.widgetPreviewHeights[resultId] != height else {
            return
        }
        self.widgetPreviewHeights[resultId] = height
        if let currentProcessedResults = self.currentProcessedResults {
            self.updateInternalResults(currentProcessedResults, animated: false)
        }
    }
    
    private func topInsetForLayout(size: CGSize, bottomInset: CGFloat, hasSwitchPeer: Bool) -> CGFloat {
        var minimumItemHeights: CGFloat = floor(VerticalListContextResultsChatInputPanelItemNode.itemHeight * 3.5)
        if hasSwitchPeer {
            minimumItemHeights += VerticalListContextResultsChatInputPanelButtonItemNode.itemHeight(style: .regular)
        }
        
        return max(size.height - bottomInset - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        
        if self.backgroundIsDark != interfaceState.theme.overallDarkAppearance {
            self.backgroundIsDark = interfaceState.theme.overallDarkAppearance
            self.backgroundView.update(
                size: self.backgroundView.bounds.size,
                cornerRadius: 20.0,
                isDark: self.backgroundIsDark,
                tintColor: .init(kind: .panel),
                transition: ComponentTransition(transition)
            )
        }
        transition.updateFrame(view: self.backgroundClipView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        // The list's bounds, its content host's, in which the mirror's origin is; set at once, so that no frame animation
        // carries the mirror's origin (`frame` keeps it).
        self.backgroundMover.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        
        transition.updateFrame(view: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
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
        
        // Visible down to what covers the panel's bottom; the input panel above it is glass, which rows show through.
        self.listView.visibleRectInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: self.coveredBottomInset, right: 0.0)
        // `ListViewImpl`'s threshold: load more once the content's bottom is within 40 pt of the visible bottom.
        self.listView.loadedEdgeMargin = bottomInset - 40.0
        
        let widgetAppearance = ChatContextResultWidgetAppearance(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper, fontSize: interfaceState.fontSize, cornerRadius: interfaceState.bubbleCorners.mainRadius)
        if self.widgetAppearance != widgetAppearance {
            self.widgetAppearance = widgetAppearance
            self.theme = interfaceState.theme
            if let currentProcessedResults = self.currentProcessedResults {
                self.updateInternalResults(currentProcessedResults)
            }
        } else if self.theme !== interfaceState.theme, let currentEntries = self.currentEntries {
            self.theme = interfaceState.theme
            self.currentEntries = currentEntries.map({ $0.withUpdatedTheme(interfaceState.theme) })
        }
        self.applyEntries(transition: CoreListTransition(transition))
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        if let topItemFrame = self.topItemFrame {
            let offset = (self.listView.bounds.size.height - topItemFrame.minY)
            
            let position = self.listView.layer.position
            self.listView.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.backgroundClipView.layer.animatePosition(from: self.backgroundClipView.layer.position, to: CGPoint(x: self.backgroundClipView.layer.position.x, y: self.backgroundClipView.layer.position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        } else {
            completion()
        }
    }
    
    /// Only rows take touches, as `ListViewImpl`'s `limitHitTestToNodes`: the room above the results lets them through to
    /// the chat.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let listPoint = self.view.convert(point, to: self.listView)
        for view in self.listView.loadedItemViews where self.listView.presentedFrame(of: view).contains(listPoint) {
            return self.listView.hitTest(listPoint, with: event)
        }
        return nil
    }
    
    private func loadMore() {
        guard !self.isLoadingMore, let currentProcessedResults = self.currentProcessedResults, let nextOffset = currentProcessedResults.nextOffset else {
            return
        }
        self.isLoadingMore = true
        let geoPoint = currentProcessedResults.geoPoint.flatMap { geoPoint -> (Double, Double) in
            return (geoPoint.latitude, geoPoint.longitude)
        }
        self.loadMoreDisposable.set((self.context.engine.messages.requestChatContextResults(botId: currentProcessedResults.botId, peerId: currentProcessedResults.peerId, query: currentProcessedResults.query, location: .single(geoPoint), offset: nextOffset)
        |> map { results -> ChatContextResultCollection? in
            return results?.results
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] nextResults in
            guard let strongSelf = self, let nextResults = nextResults else {
                return
            }
            strongSelf.isLoadingMore = false
            var results: [ChatContextResult] = []
            var existingIds = Set<String>()
            for result in currentProcessedResults.results {
                results.append(result)
                existingIds.insert(result.id)
            }
            for result in nextResults.results {
                if !existingIds.contains(result.id) {
                    results.append(result)
                    existingIds.insert(result.id)
                }
            }
            let mergedResults = ChatContextResultCollection(botId: currentProcessedResults.botId, peerId: currentProcessedResults.peerId, query: currentProcessedResults.query, geoPoint: currentProcessedResults.geoPoint, queryId: nextResults.queryId, nextOffset: nextResults.nextOffset, presentation: currentProcessedResults.presentation, switchPeer: currentProcessedResults.switchPeer, webView: currentProcessedResults.webView, results: results, cacheTimeout: currentProcessedResults.cacheTimeout)
            strongSelf.currentProcessedResults = mergedResults
            strongSelf.updateInternalResults(mergedResults)
            // CoreList reports an edge when it is reached, not while it stays reached: a page that still leaves the end in
            // reach asks for the next one here, as `ListViewImpl` asked on every offset change. Only for a page that
            // added results, so an empty page with an offset does not loop.
            if results.count > currentProcessedResults.results.count, strongSelf.listView.reachedLoadedEdges.contains(.bottom) {
                strongSelf.loadMore()
            }
        }))
    }
    
    override var topItemFrame: CGRect? {
        var entries = self.listView.loadedItemEntries
        return entries.next().map { self.listView.presentedFrame(of: $0.view) }
    }
}
