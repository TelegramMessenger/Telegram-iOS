import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TelegramVoip
import TelegramAudio
import AccountContext
import Postbox
import TelegramCore
import MergeLists
import ItemListUI
import AppBundle
import ContextUI
import ShareController
import DeleteChatPeerActionSheetItem
import UndoUI
import AlertUI
import PresentationDataUtils
import DirectionalPanGesture
import PeerInfoUI
import AvatarNode
import TooltipUI
import LegacyUI
import LegacyComponents
import LegacyMediaPickerUI
import WebSearchUI
import MapResourceToAvatarSizes
import SolidRoundedButtonNode
import AudioBlob
import DeviceAccess
import VoiceChatActionButton

let panelBackgroundColor = UIColor(rgb: 0x1c1c1e)
let secondaryPanelBackgroundColor = UIColor(rgb: 0x2c2c2e)
let fullscreenBackgroundColor = UIColor(rgb: 0x000000)
let smallButtonSize = CGSize(width: 36.0, height: 36.0)
let sideButtonSize = CGSize(width: 56.0, height: 56.0)
let topPanelHeight: CGFloat = 63.0
let bottomAreaHeight: CGFloat = 206.0
let fullscreenBottomAreaHeight: CGFloat = 80.0
let bottomGradientHeight: CGFloat = 70.0

func decorationCornersImage(top: Bool, bottom: Bool, dark: Bool) -> UIImage? {
    if !top && !bottom {
        return nil
    }
    return generateImage(CGSize(width: 50.0, height: 50.0), rotatedContext: { (size, context) in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor((dark ? fullscreenBackgroundColor : panelBackgroundColor).cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        
        var corners: UIRectCorner = []
        if top {
            corners.insert(.topLeft)
            corners.insert(.topRight)
        }
        if bottom {
            corners.insert(.bottomLeft)
            corners.insert(.bottomRight)
        }
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 11.0, height: 11.0))
        context.addPath(path.cgPath)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 25, topCapHeight: 25)
}

func decorationTopCornersImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 50.0, height: 110.0), rotatedContext: { (size, context) in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor((dark ? fullscreenBackgroundColor : panelBackgroundColor).cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        
        var corners: UIRectCorner = []
        corners.insert(.topLeft)
        corners.insert(.topRight)

        let path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: 60.0, width: 50.0, height: 50.0), byRoundingCorners: corners, cornerRadii: CGSize(width: 11.0, height: 11.0))
        context.addPath(path.cgPath)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 25, topCapHeight: 32)
}

func decorationBottomCornersImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 50.0, height: 110.0), rotatedContext: { (size, context) in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor((dark ? fullscreenBackgroundColor : panelBackgroundColor).cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        
        var corners: UIRectCorner = []
        corners.insert(.bottomLeft)
        corners.insert(.bottomRight)

        let path = UIBezierPath(roundedRect: CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0), byRoundingCorners: corners, cornerRadii: CGSize(width: 11.0, height: 11.0))
        context.addPath(path.cgPath)
        context.fillPath()
    })?.resizableImage(withCapInsets: UIEdgeInsets(top: 25.0, left: 25.0, bottom: 0.0, right: 25.0), resizingMode: .stretch)
}

private func decorationBottomGradientImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 24.0, height: bottomGradientHeight), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let color = dark ? fullscreenBackgroundColor : panelBackgroundColor
        let colorsArray = [color.withAlphaComponent(0.0).cgColor, color.cgColor] as CFArray
        var locations: [CGFloat] = [1.0, 0.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    })
}

struct VoiceChatPeerEntry: Identifiable {
    enum State {
        case listening
        case speaking
        case invited
        case raisedHand
    }
    
    var peer: Peer
    var about: String?
    var isMyPeer: Bool
    var videoEndpointId: String?
    var videoPaused: Bool
    var presentationEndpointId: String?
    var presentationPaused: Bool
    var effectiveSpeakerVideoEndpointId: String?
    var state: State
    var muteState: GroupCallParticipantsContext.Participant.MuteState?
    var canManageCall: Bool
    var volume: Int32?
    var raisedHand: Bool
    var displayRaisedHandStatus: Bool
    var active: Bool
    var isLandscape: Bool
    
    var effectiveVideoEndpointId: String? {
        return self.presentationEndpointId ?? self.videoEndpointId
    }

    init(
        peer: Peer,
        about: String?,
        isMyPeer: Bool,
        videoEndpointId: String?,
        videoPaused: Bool,
        presentationEndpointId: String?,
        presentationPaused: Bool,
        effectiveSpeakerVideoEndpointId: String?,
        state: State,
        muteState: GroupCallParticipantsContext.Participant.MuteState?,
        canManageCall: Bool,
        volume: Int32?,
        raisedHand: Bool,
        displayRaisedHandStatus: Bool,
        active: Bool,
        isLandscape: Bool
    ) {
        self.peer = peer
        self.about = about
        self.isMyPeer = isMyPeer
        self.videoEndpointId = videoEndpointId
        self.videoPaused = videoPaused
        self.presentationEndpointId = presentationEndpointId
        self.presentationPaused = presentationPaused
        self.effectiveSpeakerVideoEndpointId = effectiveSpeakerVideoEndpointId
        self.state = state
        self.muteState = muteState
        self.canManageCall = canManageCall
        self.volume = volume
        self.raisedHand = raisedHand
        self.displayRaisedHandStatus = displayRaisedHandStatus
        self.active = active
        self.isLandscape = isLandscape
    }
    
    var stableId: PeerId {
        return self.peer.id
    }
    
    static func ==(lhs: VoiceChatPeerEntry, rhs: VoiceChatPeerEntry) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if lhs.about != rhs.about {
            return false
        }
        if lhs.isMyPeer != rhs.isMyPeer {
            return false
        }
        if lhs.videoEndpointId != rhs.videoEndpointId {
            return false
        }
        if lhs.videoPaused != rhs.videoPaused {
            return false
        }
        if lhs.presentationEndpointId != rhs.presentationEndpointId {
            return false
        }
        if lhs.presentationPaused != rhs.presentationPaused {
            return false
        }
        if lhs.effectiveSpeakerVideoEndpointId != rhs.effectiveSpeakerVideoEndpointId {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.muteState != rhs.muteState {
            return false
        }
        if lhs.canManageCall != rhs.canManageCall {
            return false
        }
        if lhs.volume != rhs.volume {
            return false
        }
        if lhs.raisedHand != rhs.raisedHand {
            return false
        }
        if lhs.displayRaisedHandStatus != rhs.displayRaisedHandStatus {
            return false
        }
        if lhs.active != rhs.active {
            return false
        }
        if lhs.isLandscape != rhs.isLandscape {
            return false
        }
        return true
    }
}

public protocol VoiceChatController: ViewController {
    var call: VideoChatCall { get }
    var currentOverlayController: VoiceChatOverlayController? { get }
    var parentNavigationController: NavigationController? { get set }
    var onViewDidAppear: (() -> Void)? { get set }
    var onViewDidDisappear: (() -> Void)? { get set }
    
    func updateCall(call: VideoChatCall)
    
    func dismiss(closing: Bool, manual: Bool)
}

private final class VoiceChatContextExtractedContentSource: ContextExtractedContentSource {
    var keepInPlace: Bool
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool
    let maskView: UIView?
  
    private var animateTransitionIn: () -> Void
    private var animateTransitionOut: () -> Void
    
    private let sourceNode: ContextExtractedContentContainingNode
    
    var centerVertically: Bool
    var shouldBeDismissed: Signal<Bool, NoError>
    
    init(sourceNode: ContextExtractedContentContainingNode, maskView: UIView?, keepInPlace: Bool, blurBackground: Bool, centerVertically: Bool, shouldBeDismissed: Signal<Bool, NoError>, animateTransitionIn: @escaping () -> Void, animateTransitionOut: @escaping () -> Void) {
        self.sourceNode = sourceNode
        self.maskView = maskView
        self.keepInPlace = keepInPlace
        self.blurBackground = blurBackground
        self.centerVertically = centerVertically
        self.shouldBeDismissed = shouldBeDismissed
        self.animateTransitionIn = animateTransitionIn
        self.animateTransitionOut = animateTransitionOut
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        self.animateTransitionIn()
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds, maskView: self.maskView)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        self.animateTransitionOut()
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds, maskView: self.maskView)
    }
}

final class VoiceChatContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

public func shouldUseV2VideoChatImpl(context: AccountContext) -> Bool {
    var useV2 = true
    if context.sharedContext.immediateExperimentalUISettings.disableCallV2 {
        useV2 = false
    }
    if let data = context.currentAppConfiguration.with({ $0 }).data, let _ = data["ios_killswitch_disable_videochatui_v2"] {
        useV2 = false
    }
    return useV2
}

public func makeVoiceChatControllerInitialData(sharedContext: SharedAccountContext, accountContext: AccountContext, call: VideoChatCall) -> Signal<Any, NoError> {
    return VideoChatScreenV2Impl.initialData(call: call) |> map { $0 as Any }
}

public func makeVoiceChatController(sharedContext: SharedAccountContext, accountContext: AccountContext, call: VideoChatCall, initialData: Any, sourceCallController: CallController?) -> VoiceChatController {
    return VideoChatScreenV2Impl(initialData: initialData as! VideoChatScreenV2Impl.InitialData, call: call, sourceCallController: sourceCallController)
}
