import Foundation
import UIKit
import Display
import ComponentFlow
import ListSectionComponent
import TelegramPresentationData
import AppBundle
import AccountContext
import ChatEmptyNode
import AsyncDisplayKit
import WallpaperBackgroundNode
import ComponentDisplayAdapters
import TelegramCore
import ChatPresentationInterfaceState

final class ChatIntroItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let stickerFile: TelegramMediaFile?
    let title: String
    let text: String
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        stickerFile: TelegramMediaFile?,
        title: String,
        text: String
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.stickerFile = stickerFile
        self.title = title
        self.text = text
    }

    static func ==(lhs: ChatIntroItemComponent, rhs: ChatIntroItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.stickerFile != rhs.stickerFile {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }

    final class View: UIView, ListSectionComponent.ChildView {
        private var component: ChatIntroItemComponent?
        private weak var componentState: EmptyComponentState?
        
        private var backgroundNode: WallpaperBackgroundNode?
        private var emptyNode: ChatEmptyNode?
        
        var customUpdateIsHighlighted: ((Bool) -> Void)?
        private(set) var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatIntroItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })

            let size = CGSize(width: availableSize.width, height: 346.0)
            
            let backgroundNode: WallpaperBackgroundNode
            if let current = self.backgroundNode {
                backgroundNode = current
            } else {
                backgroundNode = createWallpaperBackgroundNode(context: component.context, forChatDisplay: false)
                self.backgroundNode = backgroundNode
                self.addSubview(backgroundNode.view)
            }
            
            transition.setFrame(view: backgroundNode.view, frame: CGRect(origin: CGPoint(), size: size))
            backgroundNode.update(wallpaper: presentationData.chatWallpaper, animated: false)
            backgroundNode.updateLayout(size: size, displayMode: .aspectFill, transition: transition.containedViewLayoutTransition)
            
            let emptyNode: ChatEmptyNode
            if let current = self.emptyNode {
                emptyNode = current
            } else {
                emptyNode = ChatEmptyNode(context: component.context, interaction: nil)
                self.emptyNode = emptyNode
                self.addSubview(emptyNode.view)
            }
            
            let interfaceState = ChatPresentationInterfaceState(
                chatWallpaper: presentationData.chatWallpaper,
                theme: component.theme,
                strings: component.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                limitsConfiguration: component.context.currentLimitsConfiguration.with { $0 },
                fontSize: presentationData.chatFontSize,
                bubbleCorners: presentationData.chatBubbleCorners,
                accountPeerId: component.context.account.peerId,
                mode: .standard(.default),
                chatLocation: .peer(id: component.context.account.peerId),
                subject: nil,
                peerNearbyData: nil,
                greetingData: nil,
                pendingUnpinnedAllMessages: false,
                activeGroupCallInfo: nil,
                hasActiveGroupCall: false,
                importState: nil,
                threadData: nil,
                isGeneralThreadClosed: nil,
                replyMessage: nil,
                accountPeerColor: nil,
                businessIntro: nil
            )
            
            transition.setFrame(view: emptyNode.view, frame: CGRect(origin: CGPoint(), size: size))
            emptyNode.updateLayout(
                interfaceState: interfaceState,
                subject: .emptyChat(.customGreeting(
                    sticker: component.stickerFile,
                    title: component.title,
                    text: component.text
                )),
                loadingNode: nil,
                backgroundNode: backgroundNode,
                size: size,
                insets: UIEdgeInsets(),
                leftInset: 0.0,
                rightInset: 0.0,
                transition: .immediate
            )
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
