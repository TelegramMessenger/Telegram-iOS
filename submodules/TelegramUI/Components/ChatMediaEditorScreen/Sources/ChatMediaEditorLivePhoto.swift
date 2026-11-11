import Foundation
import UIKit
import ChatMediaSend

public protocol ChatMediaEditorLivePhotoAdapter: AnyObject {
    var isForceLivePhotoEnabled: Bool { get }
    func livePhotoMode(for uniqueId: String) -> ChatMediaSendLivePhotoMode?
    func setLivePhotoMode(_ mode: ChatMediaSendLivePhotoMode, for uniqueId: String)
}

public func chatMediaEditorLivePhotoButtonIsVisible(hasLivePhotoButton: Bool, isLiveAsset: Bool) -> Bool {
    return hasLivePhotoButton && isLiveAsset
}

public let chatMediaEditorLivePhotoButtonSize = CGSize(width: 160.0, height: 18.0)

/// `titleRowMaxY`: on iPhone Duo, the bottom of the chat-name row at the top left. In portrait the badge sits 18pt
/// under it, as it does in landscape (where `48` is that row's bottom, 30, plus 18), wherever the row is: on the status
/// island's clock line unfolded, at the top of the folded screen. Elsewhere it keeps a phone's fixed `145`.
public func chatMediaEditorLivePhotoButtonFrame(size: CGSize, safeInsets: UIEdgeInsets, keyboardHeight: CGFloat, buttonSize: CGSize, titleRowMaxY: CGFloat? = nil, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    if let toolbarSide {
        let notchEdge = chatMediaEditorLandscapeNotchEdge(size: size, safeInsets: safeInsets, side: toolbarSide)
        let x: CGFloat
        switch toolbarSide {
        case .left:
            x = notchEdge - 16.0 - buttonSize.width
        case .right:
            x = notchEdge + 16.0
        }
        return CGRect(origin: CGPoint(x: x, y: safeInsets.top + 48.0), size: buttonSize)
    }
    let y: CGFloat
    if size.width > size.height {
        y = 48.0
    } else if let titleRowMaxY {
        y = titleRowMaxY + 18.0 - keyboardHeight
    } else {
        y = 145.0 - keyboardHeight
    }
    return CGRect(origin: CGPoint(x: safeInsets.left + 16.0, y: y), size: buttonSize)
}

public final class ChatMediaEditorLivePhotoModel {
    public let adapter: ChatMediaEditorLivePhotoAdapter
    public let selection: ChatMediaEditorSelectionModel?

    public init(adapter: ChatMediaEditorLivePhotoAdapter, selection: ChatMediaEditorSelectionModel?) {
        self.adapter = adapter
        self.selection = selection
    }

    public func mode(for uniqueId: String, isLiveAsset: Bool) -> ChatMediaSendLivePhotoMode {
        return chatMediaSendResolvedLivePhotoMode(stored: self.adapter.livePhotoMode(for: uniqueId), isLiveAsset: isLiveAsset, forceLivePhotoEnabled: self.adapter.isForceLivePhotoEnabled)
    }

    public func modeUpdated(_ mode: ChatMediaSendLivePhotoMode, for uniqueId: String) {
        self.adapter.setLivePhotoMode(mode, for: uniqueId)
        self.selection?.autoSelect(uniqueId)
    }
}

public enum ChatMediaEditorLivePhotoPlaybackAction: Equatable {
    case none
    case hide
    case playForward(fromStart: Bool)
    case playBackward
    case fadeOut
}

public let chatMediaEditorLivePhotoHoldDuration: Double = 0.2
public let chatMediaEditorLivePhotoFadeDuration: Double = 0.2

public func chatMediaEditorLivePhotoFadesOut(hasPaintingOverlay: Bool) -> Bool {
    return !hasPaintingOverlay
}

public final class ChatMediaEditorLivePhotoPlaybackModel {
    public private(set) var itemId: String?
    public private(set) var mode: ChatMediaSendLivePhotoMode = .off
    public private(set) var isActive = false
    public private(set) var isHolding = false
    public private(set) var isPlayingBackward = false

    public init() {
    }

    private var isShowing: Bool {
        return self.isActive && self.mode != .off
    }

    public func update(itemId: String?, mode: ChatMediaSendLivePhotoMode, isActive: Bool) -> ChatMediaEditorLivePhotoPlaybackAction {
        guard itemId != self.itemId || mode != self.mode || isActive != self.isActive else {
            return .none
        }
        let wasShowing = self.isShowing
        if itemId != self.itemId || !isActive || mode != .live {
            self.isHolding = false
        }
        self.itemId = itemId
        self.mode = mode
        self.isActive = isActive
        self.isPlayingBackward = false
        if self.isShowing {
            return .playForward(fromStart: true)
        }
        return wasShowing ? .hide : .none
    }

    public func holdBegan() -> ChatMediaEditorLivePhotoPlaybackAction {
        guard self.isActive, self.mode == .live else {
            return .none
        }
        self.isHolding = true
        return .playForward(fromStart: true)
    }

    public func holdEnded() -> ChatMediaEditorLivePhotoPlaybackAction {
        guard self.isHolding else {
            return .none
        }
        self.isHolding = false
        return self.isActive && self.mode == .live ? .fadeOut : .none
    }

    public func reachedEnd() -> ChatMediaEditorLivePhotoPlaybackAction {
        guard self.isShowing, !self.isPlayingBackward else {
            return .none
        }
        switch self.mode {
        case .off:
            return .none
        case .live:
            return self.isHolding ? .playForward(fromStart: true) : .fadeOut
        case .loop:
            return .playForward(fromStart: true)
        case .bounce:
            self.isPlayingBackward = true
            return .playBackward
        }
    }

    public func reachedStart() -> ChatMediaEditorLivePhotoPlaybackAction {
        guard self.isShowing, self.mode == .bounce, self.isPlayingBackward else {
            return .none
        }
        self.isPlayingBackward = false
        return .playForward(fromStart: false)
    }

    public var holdGatesTap: Bool {
        return self.isActive && self.mode == .live
    }

    public var allowsSelectionTap: Bool {
        return !self.isHolding
    }
}
