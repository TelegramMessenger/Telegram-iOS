import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramVoip
import AccountContext
import AlertComponent

func rateCallAndSendLogs(engine: TelegramEngine, callId: CallId, starsCount: Int, comment: String, userInitiated: Bool, includeLogs: Bool) -> Signal<Void, NoError> {
    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(4244000))

    let rate = engine.calls.rateCall(callId: callId, starsCount: Int32(starsCount), comment: comment, userInitiated: userInitiated)
    if includeLogs {
        let id = Int64.random(in: Int64.min ... Int64.max)
        let name = "\(callId.id)_\(callId.accessHash).log.json"
        let path = callLogsPath(account: engine.account) + "/" + name
        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)], alternativeRepresentations: [])
        let message = EnqueueMessage.message(text: comment, attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        return rate
        |> then(enqueueMessages(account: engine.account, peerId: peerId, messages: [message])
        |> mapToSignal({ _ -> Signal<Void, NoError> in
            return .single(Void())
        }))
    } else if !comment.isEmpty {
        return rate
        |> then(enqueueMessages(account: engine.account, peerId: peerId, messages: [.message(text: comment, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
        |> mapToSignal({ _ -> Signal<Void, NoError> in
            return .single(Void())
        }))
    } else {
        return rate
    }
}

public func callRatingController(
    sharedContext: SharedAccountContext,
    account: Account,
    callId: CallId,
    userInitiated: Bool,
    isVideo: Bool,
    present: @escaping (ViewController, Any) -> Void,
    push: @escaping (ViewController) -> Void
) -> ViewController {
    let strings = sharedContext.currentPresentationData.with { $0 }.strings
    
    var dismissImpl: (() -> Void)?
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(
                title: strings.Calls_RatingTitle,
                alignment: .center
            )
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "stars",
        component: AnyComponent(
            AlertCallRatingComponent(completion: { rating in
                dismissImpl?()
                if rating < 4 {
                    push(callFeedbackController(sharedContext: sharedContext, account: account, callId: callId, rating: rating, userInitiated: userInitiated, isVideo: isVideo))
                } else {
                    let _ = rateCallAndSendLogs(engine: TelegramEngine(account: account), callId: callId, starsCount: rating, comment: "", userInitiated: userInitiated, includeLogs: false).start()
                }
            })
        )
    ))
    
    let alertController = AlertScreen(
        sharedContext: sharedContext,
        content: content,
        actions: [
            .init(title: strings.Common_NotNow)
        ]
    )
    
    dismissImpl = { [weak alertController] in
        alertController?.dismiss(completion: nil)
    }
    
    return alertController
}

private final class AlertCallRatingComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
        
    private let completion: (Int) -> Void

    public init(completion: @escaping (Int) -> Void) {
        self.completion = completion
    }
    
    public static func ==(lhs: AlertCallRatingComponent, rhs: AlertCallRatingComponent) -> Bool {
        return true
    }
    
    public final class View: UIView {
        private var containerView: UIView
        private let starButtons: [HighlightTrackingButton]
        
        var rating: Int?
        
        private var component: AlertCallRatingComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            self.containerView = UIView()
            
            var starButtons: [HighlightTrackingButton] = []
            for _ in 0 ..< 5 {
                starButtons.append(HighlightTrackingButton())
            }
            self.starButtons = starButtons
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            
            for button in self.starButtons {
                button.addTarget(self, action: #selector(self.starPressed(_:)), for: .touchDown)
                button.addTarget(self, action: #selector(self.starReleased(_:)), for: .touchUpInside)
                self.containerView.addSubview(button)
            }
            
            self.containerView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
        }
        
        public required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
            let location = gestureRecognizer.location(in: self.containerView)
            var selectedButton: HighlightTrackingButton?
            for button in self.starButtons {
                if button.frame.contains(location) {
                    selectedButton = button
                    break
                }
            }
            if let selectedButton = selectedButton {
                switch gestureRecognizer.state {
                    case .began, .changed:
                        self.starPressed(selectedButton)
                    case .ended:
                        self.starReleased(selectedButton)
                    case .cancelled:
                        self.resetStars()
                    default:
                        break
                }
            } else {
                self.resetStars()
            }
        }
        
        private func resetStars() {
            for i in 0 ..< self.starButtons.count {
                let node = self.starButtons[i]
                node.isSelected = false
            }
        }
        
        @objc func starPressed(_ sender: HighlightTrackingButton) {
            if let index = self.starButtons.firstIndex(of: sender) {
                self.rating = index + 1
                for i in 0 ..< self.starButtons.count {
                    let node = self.starButtons[i]
                    node.isSelected = i <= index
                }
            }
        }
        
        @objc func starReleased(_ sender: HighlightTrackingButton) {
            guard let component = self.component else {
                return
            }
            if let index = self.starButtons.firstIndex(of: sender) {
                self.rating = index + 1
                for i in 0 ..< self.starButtons.count {
                    let node = self.starButtons[i]
                    node.isSelected = i <= index
                }
                if let rating = self.rating {
                    component.completion(rating)
                }
            }
        }
        
        func update(component: AlertCallRatingComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                for i in 0 ..< self.starButtons.count {
                    let button = self.starButtons[i]
                    button.setImage(UIImage(bundleImageName: "Call/Star")?.withRenderingMode(.alwaysTemplate), for: .normal)
                    button.setImage(UIImage(bundleImageName: "Call/StarHighlighted")?.withRenderingMode(.alwaysTemplate), for: .selected)
                    button.setImage(UIImage(bundleImageName: "Call/StarHighlighted")?.withRenderingMode(.alwaysTemplate), for: [.selected, .highlighted])
                }
            }
            
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
                        
            let buttonCount = CGFloat(self.starButtons.count)
            let starSize = CGSize(width: 42.0, height: 38.0)
            let starsOrigin = floorToScreenPixels((availableSize.width - starSize.width * buttonCount) / 2.0)
            self.containerView.frame = CGRect(origin: CGPoint(x: starsOrigin, y: 0.0), size: CGSize(width: starSize.width * buttonCount, height: starSize.height))
            for i in 0 ..< self.starButtons.count {
                let button = self.starButtons[i]
                button.imageView?.tintColor = environment.theme.actionSheet.controlAccentColor
                
                transition.setFrame(view: button, frame: CGRect(x: starSize.width * CGFloat(i), y: 0.0, width: starSize.width, height: starSize.height))
            }
            
            return CGSize(width: availableSize.width, height: 38.0)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
