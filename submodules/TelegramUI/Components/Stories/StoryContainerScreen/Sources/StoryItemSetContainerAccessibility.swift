import Foundation
import UIKit
import Display
import TelegramCore

/// The story being shown, as one VoiceOver element: whose it is and what it is ("Alice, Photo") and its place in the
/// author's stories ("Story 2 of 5"). Swiping up or down moves to the next or previous story where the right or left
/// tap would (past the last story that is the next author's first one; see `storyAccessibilityNavigate`); the custom
/// actions switch authors where the sideways swipe would. Double tap does nothing: the sighted tap on the story is the
/// navigation above.
final class StoryPagerAccessibilityElement: UIAccessibilityElement {
    weak var owner: StoryItemSetContainerComponent.View?

    init(owner: StoryItemSetContainerComponent.View) {
        self.owner = owner
        super.init(accessibilityContainer: owner)
        self.accessibilityTraits = .adjustable
    }

    override var accessibilityLabel: String? {
        get {
            return self.owner?.storyAccessibilityLabel()
        } set(value) {
        }
    }

    override var accessibilityValue: String? {
        get {
            return self.owner?.storyAccessibilityPosition()
        } set(value) {
        }
    }

    override var accessibilityFrameInContainerSpace: CGRect {
        get {
            return self.owner?.storyAccessibilityContentFrame() ?? .zero
        } set(value) {
        }
    }

    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            return self.owner?.storyAccessibilityPeerActions()
        } set(value) {
        }
    }

    override func accessibilityIncrement() {
        self.owner?.storyAccessibilityNavigateAndFocus(next: true)
    }

    override func accessibilityDecrement() {
        self.owner?.storyAccessibilityNavigateAndFocus(next: false)
    }

    override func accessibilityActivate() -> Bool {
        return true
    }
}

/// The story viewer's author pager (`StoryContainerScreenComponent.View`), as the shown story's element uses it.
protocol StoryAccessibilityPeerNavigating: AnyObject {
    /// The authors a sideways swipe would move to now: none while the swipe is not allowed (the interaction guide or
    /// the viewers sheet is up).
    func accessibilityNeighbourPeers() -> (previous: EnginePeer?, next: EnginePeer?)
    /// Moves to the next or previous author as the sideways swipe does; `false` when there is none or when the swipe
    /// is not allowed now (the interaction guide or the viewers sheet is up).
    func accessibilityNavigatePeer(next: Bool) -> Bool
    /// Moves VoiceOver focus to the story shown once a navigation has settled.
    func accessibilityFocusShownStory()
}

extension StoryItemSetContainerComponent.View {
    /// What VoiceOver reads, in screen order: the header (author, then the trailing controls), the story itself, its
    /// caption, then the reply field or (on your own story) the views and delete row; the viewers sheet while it is up.
    /// Neighbouring stories kept loaded for the carousel and the media areas drawn on the story are not listed.
    func storyAccessibilityElements() -> [Any]? {
        guard let component = self.component else {
            return nil
        }
        func isShown(_ view: UIView?) -> UIView? {
            guard let view, view.superview != nil else {
                return nil
            }
            var current: UIView? = view
            while let item = current, item !== self {
                if item.isHidden || item.alpha < 0.01 || item.accessibilityElementsHidden {
                    return nil
                }
                current = item.superview
            }
            return view
        }

        var elements: [Any] = []

        var reactionPickerView: UIView?
        if let reactionContextNode = self.reactionContextNode, let view = isShown(reactionContextNode.view) {
            if self.displayLikeReactions {
                // The picker opened from Like covers the story and takes every tap until it closes (escape closes it).
                return [view]
            }
            // The quick reactions shown over the focused, empty reply field: read with the field, before it.
            reactionPickerView = view
        }

        if self.viewListDisplayState == .hidden {
            if let view = isShown(self.leftInfoItem?.view.view) {
                elements.append(view)
            }
            if let view = isShown(self.centerInfoItem?.view.view) {
                elements.append(view)
            }
            for item in [self.pictureInPictureIcon, self.privacyIcon] {
                if let view = isShown(item?.view) {
                    elements.append(view)
                }
            }
            if let view = isShown(self.soundButton.view) {
                elements.append(view)
            }
            if let view = isShown(self.moreButton.view) {
                elements.append(view)
            }
        }
        if let view = isShown(self.closeButton) {
            elements.append(view)
        }

        if self.visibleItems[component.slice.item.id] != nil {
            elements.append(self.storyAccessibilityFocusElement())
        }

        if self.viewListDisplayState == .hidden {
            if let view = isShown(self.captionItem?.view.view) {
                elements.append(view)
            }
            if let view = isShown(self.visibleItems[component.slice.item.id]?.footerPanel?.view) {
                elements.append(view)
            }
            if let reactionPickerView {
                elements.append(reactionPickerView)
            }
            if let view = isShown(self.inputPanel.view) {
                elements.append(view)
            }
            if let inputMediaNode = self.sendMessageContext.inputMediaNode, let view = isShown(inputMediaNode.view) {
                elements.append(view)
            }
        } else if let view = isShown(self.viewLists[component.slice.item.id]?.view.view) {
            elements.append(view)
        }

        return elements
    }

    func storyAccessibilityLabel() -> String? {
        guard let component = self.component else {
            return nil
        }
        let kind: String
        switch component.slice.item.storyItem.media {
        case .image:
            kind = component.strings.VoiceOver_Chat_Photo
        default:
            kind = component.strings.VoiceOver_Chat_Video
        }
        // The author as the header names it, so a move to another author's story says whose it is.
        let author: String
        if component.slice.effectivePeer.id == component.context.account.peerId {
            author = component.strings.Story_HeaderYourStory
        } else {
            author = component.slice.effectivePeer.compactDisplayTitle
        }
        return author + ", " + kind
    }

    func storyAccessibilityPosition() -> String? {
        guard let component = self.component else {
            return nil
        }
        let slice = component.slice
        let position: Int
        let totalCount: Int
        if let value = slice.item.position {
            position = value
            totalCount = max(slice.totalCount, value + 1)
        } else if let index = slice.allItems.firstIndex(where: { $0.id == slice.item.id }) {
            position = index
            totalCount = slice.allItems.count
        } else {
            return nil
        }
        return component.strings.VoiceOver_Stories_Position("\(position + 1)", "\(totalCount)").string
    }

    func storyAccessibilityContentFrame() -> CGRect {
        guard let component = self.component, let visibleItem = self.visibleItems[component.slice.item.id], visibleItem.contentContainerView.window != nil else {
            return self.bounds
        }
        var frame = visibleItem.contentContainerView.convert(visibleItem.contentContainerView.bounds, to: self)
        // Below the header's controls, which lie over the story's top, so touch exploration finds them.
        if self.viewListDisplayState == .hidden, self.closeButton.alpha >= 0.01 {
            let headerMaxY = self.closeButton.convert(self.closeButton.bounds, to: self).maxY
            if headerMaxY > frame.minY && headerMaxY < frame.maxY {
                frame.size.height -= headerMaxY - frame.minY
                frame.origin.y = headerMaxY
            }
        }
        return frame
    }

    func storyAccessibilityNavigateAndFocus(next: Bool) {
        let containerView = self.storyContainerView()
        if self.storyAccessibilityNavigate(next: next) {
            containerView?.accessibilityFocusShownStory()
        }
    }

    func storyAccessibilityPeerActions() -> [UIAccessibilityCustomAction]? {
        guard let component = self.component, let containerView = self.storyContainerView() else {
            return nil
        }
        let peers = containerView.accessibilityNeighbourPeers()
        var actions: [UIAccessibilityCustomAction] = []
        if let peer = peers.next {
            actions.append(UIAccessibilityCustomAction(name: component.strings.VoiceOver_Stories_NextPeer(peer.compactDisplayTitle).string, actionHandler: { [weak containerView] _ in
                guard let containerView, containerView.accessibilityNavigatePeer(next: true) else {
                    return false
                }
                containerView.accessibilityFocusShownStory()
                return true
            }))
        }
        if let peer = peers.previous {
            actions.append(UIAccessibilityCustomAction(name: component.strings.VoiceOver_Stories_PreviousPeer(peer.compactDisplayTitle).string, actionHandler: { [weak containerView] _ in
                guard let containerView, containerView.accessibilityNavigatePeer(next: false) else {
                    return false
                }
                containerView.accessibilityFocusShownStory()
                return true
            }))
        }
        return actions.isEmpty ? nil : actions
    }

    private func storyContainerView() -> StoryAccessibilityPeerNavigating? {
        var current = self.superview
        while let view = current {
            if let view = view as? StoryAccessibilityPeerNavigating {
                return view
            }
            current = view.superview
        }
        return nil
    }

    /// The story element, created when VoiceOver first asks for it.
    func storyAccessibilityFocusElement() -> StoryPagerAccessibilityElement {
        if let current = self.storyPagerAccessibilityElement {
            return current
        }
        let pagerElement = StoryPagerAccessibilityElement(owner: self)
        self.storyPagerAccessibilityElement = pagerElement
        return pagerElement
    }
}
