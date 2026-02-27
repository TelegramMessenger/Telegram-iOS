import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import TelegramPresentationData

final class ButtonGroupView: OverlayMaskContainerView {
    final class Button {
        enum Content: Equatable {
            enum Key: Hashable {
                case speaker
                case flipCamera
                case video
                case microphone
                case end
            }
            
            case speaker(audioOutput: PrivateCallScreen.State.AudioOutput)
            case flipCamera
            case video(isActive: Bool)
            case microphone(isMuted: Bool)
            case end
            
            var key: Key {
                switch self {
                case .speaker:
                    return .speaker
                case .flipCamera:
                    return .flipCamera
                case .video:
                    return .video
                case .microphone:
                    return .microphone
                case .end:
                    return .end
                }
            }
        }
        
        let content: Content
        let isEnabled: Bool
        let action: () -> Void
        
        init(content: Content, isEnabled: Bool, action: @escaping () -> Void) {
            self.content = content
            self.isEnabled = isEnabled
            self.action = action
        }
    }
    
    final class Notice {
        let id: AnyHashable
        let icon: String
        let text: String
        
        init(id: AnyHashable, icon: String, text: String) {
            self.id = id
            self.icon = icon
            self.text = text
        }
    }
    
    private var buttons: [Button]?
    private var buttonViews: [Button.Content.Key: ContentOverlayButton] = [:]
    private var noticeViews: [AnyHashable: NoticeView] = [:]
    private var closeButtonView: CloseButtonView?
    
    var closePressed: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result === self {
            return nil
        }
        return result
    }
    
    func update(size: CGSize, insets: UIEdgeInsets, minWidth: CGFloat, controlsHidden: Bool, displayClose: Bool, strings: PresentationStrings, buttons: [Button], notices: [Notice], isAnimatedOutToGroupCall: Bool, transition: ComponentTransition) -> CGFloat {
        self.buttons = buttons
        
        let buttonSize: CGFloat = 56.0
        let buttonSpacing: CGFloat = 36.0
        
        let buttonNoticeSpacing: CGFloat = 16.0
        let controlsHiddenNoticeSpacing: CGFloat = 0.0
        var nextNoticeY: CGFloat
        if isAnimatedOutToGroupCall {
            nextNoticeY = size.height + 4.0
        } else if controlsHidden {
            nextNoticeY = size.height - insets.bottom - 4.0
        } else {
            nextNoticeY = size.height - insets.bottom - 52.0 - buttonSize - buttonNoticeSpacing
        }
        let noticeSpacing: CGFloat = 8.0
        
        var validNoticeIds: [AnyHashable] = []
        var noticesHeight: CGFloat = 0.0
        for notice in notices {
            validNoticeIds.append(notice.id)
            
            let noticeView: NoticeView
            var noticeTransition = transition
            var animateIn = false
            if let current = self.noticeViews[notice.id] {
                noticeView = current
            } else {
                noticeTransition = noticeTransition.withAnimation(.none)
                animateIn = true
                noticeView = NoticeView()
                self.noticeViews[notice.id] = noticeView
                self.addSubview(noticeView)
            }
            
            if noticesHeight != 0.0 {
                noticesHeight += noticeSpacing
            } else {
                if controlsHidden {
                    noticesHeight += controlsHiddenNoticeSpacing
                } else {
                    noticesHeight += buttonNoticeSpacing
                }
            }
            let noticeSize = noticeView.update(icon: notice.icon, text: notice.text, constrainedWidth: size.width - insets.left * 2.0 - 16.0 * 2.0, transition: noticeTransition)
            let noticeFrame = CGRect(origin: CGPoint(x: floor((size.width - noticeSize.width) * 0.5), y: isAnimatedOutToGroupCall ? nextNoticeY : (nextNoticeY - noticeSize.height)), size: noticeSize)
            noticesHeight += noticeSize.height
            if !isAnimatedOutToGroupCall {
                nextNoticeY -= noticeSize.height + noticeSpacing
            }
            
            noticeTransition.setFrame(view: noticeView, frame: noticeFrame)
            if animateIn, !transition.animation.isImmediate {
                noticeView.animateIn()
            }
        }
        if noticesHeight != 0.0 {
            noticesHeight += 5.0
        }
        if isAnimatedOutToGroupCall {
            noticesHeight = 0.0
        }
        var removedNoticeIds: [AnyHashable] = []
        for (id, noticeView) in self.noticeViews {
            if !validNoticeIds.contains(id) {
                removedNoticeIds.append(id)
                if !transition.animation.isImmediate {
                    noticeView.animateOut(completion: { [weak noticeView] in
                        noticeView?.removeFromSuperview()
                    })
                } else {
                    noticeView.removeFromSuperview()
                }
            }
        }
        for id in removedNoticeIds {
            self.noticeViews.removeValue(forKey: id)
        }
        
        let buttonY: CGFloat
        let resultHeight: CGFloat
        if controlsHidden || isAnimatedOutToGroupCall {
            buttonY = size.height + 12.0
            resultHeight = insets.bottom + 4.0 + noticesHeight
        } else {
            buttonY = size.height - insets.bottom - 52.0 - buttonSize
            resultHeight = size.height - buttonY + noticesHeight
        }
        var buttonX: CGFloat = floor((size.width - buttonSize * CGFloat(buttons.count) - buttonSpacing * CGFloat(buttons.count - 1)) * 0.5)
        
        if displayClose {
            let closeButtonView: CloseButtonView
            var closeButtonTransition = transition
            var animateIn = false
            if let current = self.closeButtonView {
                closeButtonView = current
            } else {
                closeButtonTransition = closeButtonTransition.withAnimation(.none)
                animateIn = true
                
                closeButtonView = CloseButtonView()
                self.closeButtonView = closeButtonView
                self.addSubview(closeButtonView)
                closeButtonView.pressAction = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.closePressed?()
                }
            }
            let closeButtonSize = CGSize(width: minWidth, height: buttonSize)
            closeButtonView.update(text: strings.Common_Close, size: closeButtonSize, transition: closeButtonTransition)
            closeButtonTransition.setFrame(view: closeButtonView, frame: CGRect(origin: CGPoint(x: floor((size.width - closeButtonSize.width) * 0.5), y: buttonY), size: closeButtonSize))
            
            if animateIn && !transition.animation.isImmediate {
                closeButtonView.animateIn()
            }
        } else {
            if let closeButtonView = self.closeButtonView {
                self.closeButtonView = nil
                if !transition.animation.isImmediate {
                    closeButtonView.animateOut(completion: { [weak closeButtonView] in
                        closeButtonView?.removeFromSuperview()
                    })
                } else {
                    closeButtonView.removeFromSuperview()
                }
            }
        }
        
        for button in buttons {
            let title: String
            let image: UIImage?
            let isActive: Bool
            var isDestructive: Bool = false
            switch button.content {
            case let .speaker(audioOutput):
                switch audioOutput {
                case .internalSpeaker, .speaker:
                    title = strings.Call_Speaker
                default:
                    title = strings.Call_Audio
                }
                
                switch audioOutput {
                case .internalSpeaker:
                    image = UIImage(bundleImageName: "Call/Speaker")
                    isActive = false
                case .speaker:
                    image = UIImage(bundleImageName: "Call/Speaker")
                    isActive = true
                case .airpods:
                    image = UIImage(bundleImageName: "Call/CallAirpodsButton")
                    isActive = true
                case .airpodsPro:
                    image = UIImage(bundleImageName: "Call/CallAirpodsProButton")
                    isActive = true
                case .airpodsMax:
                    image = UIImage(bundleImageName: "Call/CallAirpodsMaxButton")
                    isActive = true
                case .headphones:
                    image = UIImage(bundleImageName: "Call/CallHeadphonesButton")
                    isActive = true
                case .bluetooth:
                    image = UIImage(bundleImageName: "Call/CallBluetoothButton")
                    isActive = true
                }
            case .flipCamera:
                title = strings.Call_Flip
                image = UIImage(bundleImageName: "Call/Flip")
                isActive = false
            case let .video(isActiveValue):
                title = strings.Call_Video
                image = UIImage(bundleImageName: "Call/Video")
                isActive = isActiveValue
            case let .microphone(isActiveValue):
                title = strings.Call_Mute
                image = UIImage(bundleImageName: "Call/Mute")
                isActive = isActiveValue
            case .end:
                title = strings.Call_End
                image = UIImage(bundleImageName: "Call/End")
                isActive = false
                isDestructive = true
            }
            
            var buttonTransition = transition
            let buttonView: ContentOverlayButton
            if let current = self.buttonViews[button.content.key] {
                buttonView = current
            } else {
                buttonTransition = transition.withAnimation(.none)
                buttonView = ContentOverlayButton(frame: CGRect())
                self.addSubview(buttonView)
                self.buttonViews[button.content.key] = buttonView
                
                let key = button.content.key
                buttonView.action = { [weak self] in
                    guard let self, let button = self.buttons?.first(where: { $0.content.key == key }) else {
                        return
                    }
                    button.action()
                }
                
                ComponentTransition.immediate.setScale(view: buttonView, scale: 0.001)
                buttonView.alpha = 0.0
                transition.setScale(view: buttonView, scale: 1.0)
            }
            
            transition.setAlpha(view: buttonView, alpha: displayClose ? 0.0 : 1.0)
            
            buttonTransition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(x: buttonX, y: buttonY), size: CGSize(width: buttonSize, height: buttonSize)))
            buttonView.update(size: CGSize(width: buttonSize, height: buttonSize), image: image, isSelected: isActive, isDestructive: isDestructive, isEnabled: button.isEnabled, title: title, transition: buttonTransition)
            buttonX += buttonSize + buttonSpacing
        }
        
        var removeKeys: [Button.Content.Key] = []
        for (key, buttonView) in self.buttonViews {
            if !buttons.contains(where: { $0.content.key == key }) {
                removeKeys.append(key)
                transition.setScale(view: buttonView, scale: 0.001)
                transition.setAlpha(view: buttonView, alpha: 0.0, completion: { [weak buttonView] _ in
                    buttonView?.removeFromSuperview()
                })
            }
        }
        for key in removeKeys {
            self.buttonViews.removeValue(forKey: key)
        }
        
        return resultHeight
    }
}
