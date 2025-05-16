import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ComponentFlow
import AvatarNode
import MultilineTextComponent
import PlainButtonComponent
import ComponentDisplayAdapters
import AccountContext
import TelegramCore
import SwiftSignalKit
import UndoUI
import ShareController

private final class ChatBusinessLinkTitlePanelComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let insets: UIEdgeInsets
    let copyAction: () -> Void
    let shareAction: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        insets: UIEdgeInsets,
        copyAction: @escaping () -> Void,
        shareAction: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.insets = insets
        self.copyAction = copyAction
        self.shareAction = shareAction
    }

    static func ==(lhs: ChatBusinessLinkTitlePanelComponent, rhs: ChatBusinessLinkTitlePanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings != rhs.strings {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }

    final class View: UIView {
        private let copyButton = ComponentView<Empty>()
        private let shareButton = ComponentView<Empty>()
        
        private var component: ChatBusinessLinkTitlePanelComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatBusinessLinkTitlePanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let size = CGSize(width: availableSize.width, height: 40.0)
            
            let copyButtonSize = self.copyButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.GroupInfo_InviteLink_CopyLink, font: Font.regular(17.0), textColor: component.theme.rootController.navigationBar.accentTextColor))
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: floor(availableSize.width * 0.5), height: size.height),
                    contentInsets: UIEdgeInsets(),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.copyAction()
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: availableSize
            )
            if let copyButtonView = self.copyButton.view {
                if copyButtonView.superview == nil {
                    self.addSubview(copyButtonView)
                }
                transition.setFrame(view: copyButtonView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: copyButtonSize))
            }
            
            let shareButtonSize = self.shareButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.GroupInfo_InviteLink_ShareLink, font: Font.regular(17.0), textColor: component.theme.rootController.navigationBar.accentTextColor))
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: floor(availableSize.width * 0.5), height: size.height),
                    contentInsets: UIEdgeInsets(),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.shareAction()
                    },
                    animateAlpha: true,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: availableSize
            )
            if let shareButtonView = self.shareButton.view {
                if shareButtonView.superview == nil {
                    self.addSubview(shareButtonView)
                }
                transition.setFrame(view: shareButtonView, frame: CGRect(origin: CGPoint(x: floor(availableSize.width * 0.5), y: 0.0), size: shareButtonSize))
            }
            
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

final class ChatBusinessLinkTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let separatorNode: ASDisplayNode
    private let content = ComponentView<Empty>()
    
    private var theme: PresentationTheme?
    private var link: TelegramBusinessChatLinks.Link?
    
    init(context: AccountContext) {
        self.context = context
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()

        self.addSubnode(self.separatorNode)
    }

    private func copyAction() {
        guard let link = self.link, let interfaceInteraction = self.interfaceInteraction else {
            return
        }
        
        UIPasteboard.general.string = link.url
        
        let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
        
        let controller = UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.GroupInfo_InviteLink_CopyAlert_Success), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { _ in
            return false
        })
        interfaceInteraction.presentControllerInCurrent(controller, nil)
    }
    
    private func shareAction() {
        guard let link = self.link, let interfaceInteraction = self.interfaceInteraction else {
            return
        }
        
        interfaceInteraction.presentController(ShareController(context: self.context, subject: .url(link.url), showInChat: nil, externalShare: false, immediateExternalShare: false), nil)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        switch interfaceState.subject {
        case let .customChatContents(customChatContents):
            switch customChatContents.kind {
            case .quickReplyMessageInput:
                break
            case let .businessLinkSetup(link):
                self.link = link
            case .hashTagSearch:
                break
            }
        default:
            break
        }
        
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }

        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))

        let contentSize = self.content.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(ChatBusinessLinkTitlePanelComponent(
                context: self.context,
                theme: interfaceState.theme,
                strings: interfaceState.strings,
                insets: UIEdgeInsets(top: 0.0, left: leftInset, bottom: 0.0, right: rightInset),
                copyAction: { [weak self] in
                    self?.copyAction()
                },
                shareAction: { [weak self] in
                    self?.shareAction()
                }
            )),
            environment: {},
            containerSize: CGSize(width: width, height: 1000.0)
        )
        if let contentView = self.content.view {
            if contentView.superview == nil {
                self.view.addSubview(contentView)
            }
            transition.updateFrame(view: contentView, frame: CGRect(origin: CGPoint(), size: contentSize))
        }

        return LayoutResult(backgroundHeight: contentSize.height, insetHeight: contentSize.height, hitTestSlop: 0.0)
        
    }
}
