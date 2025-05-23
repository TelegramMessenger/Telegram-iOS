import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramNotices
import TelegramPresentationData
import ActivityIndicator
import ChatPresentationInterfaceState
import ChatInputPanelNode
import ComponentFlow
import MultilineTextComponent
import PlainButtonComponent
import ComponentDisplayAdapters
import BundleIconComponent
import AnimatedTextComponent

private let labelFont = Font.regular(15.0)

final class ChatTagSearchInputPanelNode: ChatInputPanelNode {
    private struct Params: Equatable {
        var width: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        var bottomInset: CGFloat
        var additionalSideInsets: UIEdgeInsets
        var maxHeight: CGFloat
        var isSecondary: Bool
        var interfaceState: ChatPresentationInterfaceState
        var metrics: LayoutMetrics
        var isMediaInputExpanded: Bool

        init(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) {
            self.width = width
            self.leftInset = leftInset
            self.rightInset = rightInset
            self.bottomInset = bottomInset
            self.additionalSideInsets = additionalSideInsets
            self.maxHeight = maxHeight
            self.isSecondary = isSecondary
            self.interfaceState = interfaceState
            self.metrics = metrics
            self.isMediaInputExpanded = isMediaInputExpanded
        }
    }

    private struct Layout {
        var params: Params
        var height: CGFloat

        init(params: Params, height: CGFloat) {
            self.params = params
            self.height = height
        }
    }

    private let calendarButton = ComponentView<Empty>()
    private var membersButton: ComponentView<Empty>?
    private var resultsText: ComponentView<Empty>?
    private var listModeButton: ComponentView<Empty>?
    
    private var isUpdating: Bool = false
    
    private var alwaysShowTotalMessagesCount = false
    
    private var currentLayout: Layout?
    
    private var tagMessageCount: (tag: MemoryBuffer, count: Int?, disposable: Disposable?)?
    
    private var totalMessageCount: Int?
    private var totalMessageCountDisposable: Disposable?
    
    public var externalSearchResultsCount: Int32? {
        didSet {
            if let params = self.currentLayout?.params {
                let _ = self.update(params: params, transition: .spring(duration: 0.4))
            }
        }
    }
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
        }
    }
    
    init(theme: PresentationTheme, alwaysShowTotalMessagesCount: Bool) {
        self.alwaysShowTotalMessagesCount = alwaysShowTotalMessagesCount
        
        super.init()
    }
    
    deinit {
        self.tagMessageCount?.disposable?.dispose()
        self.totalMessageCountDisposable?.dispose()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        let params = Params(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, interfaceState: interfaceState, metrics: metrics, isMediaInputExpanded: isMediaInputExpanded)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.height
        }

        let height = self.update(params: params, transition: ComponentTransition(transition))
        self.currentLayout = Layout(params: params, height: height)

        return height
    }
    
    func prepareSwitchToFilter(tag: MemoryBuffer, count: Int) {
        self.tagMessageCount?.disposable?.dispose()
        self.tagMessageCount = (tag, count, nil)
    }
    
    private func update(transition: ComponentTransition) {
        if self.isUpdating {
            return
        }
        if let params = self.currentLayout?.params {
            let _ = self.update(params: params, transition: transition)
        }
    }

    private func update(params: Params, transition: ComponentTransition) -> CGFloat {
        self.isUpdating = true
        defer {
            self.isUpdating = false
        }
        
        if self.totalMessageCountDisposable == nil, let context = self.context, case let .peer(peerId) = params.interfaceState.chatLocation, peerId == context.account.peerId {
            self.totalMessageCountDisposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Messages.MessageCount(
                    peerId: peerId,
                    threadId: nil,
                    tag: []
                )
            )
            |> distinctUntilChanged
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                if self.totalMessageCount != value {
                    self.totalMessageCount = value
                    if !self.isUpdating {
                        self.update(transition: .easeInOut(duration: 0.25))
                    }
                }
            })
        }
        
        if let historyFilter = params.interfaceState.historyFilter, let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: historyFilter.customTag) {
            let tag = historyFilter.customTag
            
            if let current = self.tagMessageCount, current.tag == tag {
            } else {
                self.tagMessageCount = (tag, nil, nil)
            }
            
            if self.tagMessageCount?.disposable == nil {
                if let context = self.context {
                    self.tagMessageCount?.disposable = (context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Messages.ReactionTagMessageCount(peerId: context.account.peerId, threadId: params.interfaceState.chatLocation.threadId, reaction: reaction)
                    )
                    |> deliverOnMainQueue).startStrict(next: { [weak self] count in
                        guard let self else {
                            return
                        }
                        if self.tagMessageCount?.tag == tag {
                            if self.tagMessageCount?.count != count {
                                self.tagMessageCount?.count = count
                                if !self.isUpdating {
                                    self.update(transition: .easeInOut(duration: 0.25))
                                }
                            }
                        }
                    })
                }
            }
        } else {
            if let tagMessageCount = self.tagMessageCount {
                self.tagMessageCount = nil
                tagMessageCount.disposable?.dispose()
            }
        }
        
        
        var canSearchMembers = false
        if let search = params.interfaceState.search {
            if case .everything = search.domain {
                if let _ = params.interfaceState.renderedPeer?.peer as? TelegramGroup {
                    canSearchMembers = true
                } else if let peer = params.interfaceState.renderedPeer?.peer as? TelegramChannel, case .group = peer.info, !peer.isMonoForum {
                    canSearchMembers = true
                }
            } else {
                canSearchMembers = false
            }
        }
        let displaySearchMembers = (params.interfaceState.search?.query.isEmpty ?? true) && canSearchMembers
        
        var canChangeListMode = false
        
        var resultsTextString: [AnimatedTextComponent.Item] = []
        if let externalSearchResultsCount = self.externalSearchResultsCount {
            let value = presentationStringsFormattedNumber(externalSearchResultsCount, params.interfaceState.dateTimeFormat.groupingSeparator)
            let suffix = params.interfaceState.strings.Chat_BottomSearchPanel_StoryCount(externalSearchResultsCount)
            resultsTextString = [AnimatedTextComponent.Item(
                id: "stories",
                isUnbreakable: true,
                content: .text(params.interfaceState.strings.Chat_BottomSearchPanel_MessageCountFormat(value, suffix).string)
            )]
        } else if let results = params.interfaceState.search?.resultsState {
            let displayTotalCount = results.completed ? results.messageIndices.count : Int(results.totalCount)
            if let currentId = results.currentId, let index = results.messageIndices.firstIndex(where: { $0.id == currentId }) {
                canChangeListMode = true
                
                if self.alwaysShowTotalMessagesCount {
                    let value = presentationStringsFormattedNumber(Int32(displayTotalCount), params.interfaceState.dateTimeFormat.groupingSeparator)
                    let suffix = params.interfaceState.strings.Chat_BottomSearchPanel_MessageCount(Int32(displayTotalCount))
                    resultsTextString = [AnimatedTextComponent.Item(
                        id: "text",
                        isUnbreakable: true,
                        content: .text(params.interfaceState.strings.Chat_BottomSearchPanel_MessageCountFormat(value, suffix).string)
                    )]
                } else if params.interfaceState.displayHistoryFilterAsList {
                    resultsTextString = AnimatedTextComponent.extractAnimatedTextString(string: params.interfaceState.strings.Chat_BottomSearchPanel_MessageCountFormat(
                        ".",
                        "."
                    ), id: "total_count", mapping: [
                        0: .number(displayTotalCount, minDigits: 1),
                        1: .text(params.interfaceState.strings.Chat_BottomSearchPanel_MessageCount(Int32(displayTotalCount)))
                    ])
                } else {
                    let adjustedIndex = results.messageIndices.count - 1 - index
                    
                    resultsTextString = AnimatedTextComponent.extractAnimatedTextString(string: params.interfaceState.strings.Items_NOfM(
                        ".",
                        "."
                    ), id: "position", mapping: [
                        0: .number(adjustedIndex + 1, minDigits: 1),
                        1: .number(displayTotalCount, minDigits: 1)
                    ])
                }
            } else {
                canChangeListMode = false
                
                resultsTextString.append(AnimatedTextComponent.Item(id: AnyHashable("search_no_results"), isUnbreakable: true, content: .text(params.interfaceState.strings.Conversation_SearchNoResults)))
            }
        } else if let count = self.tagMessageCount?.count ?? self.totalMessageCount {
            canChangeListMode = count != 0
            
            resultsTextString = AnimatedTextComponent.extractAnimatedTextString(string: params.interfaceState.strings.Chat_BottomSearchPanel_MessageCountFormat(
                ".",
                "."
            ), id: "total_count", mapping: [
                0: .number(count, minDigits: 1),
                1: .text(params.interfaceState.strings.Chat_BottomSearchPanel_MessageCount(Int32(count)))
            ])
        } else if let context = self.context, case .peer(context.account.peerId) = params.interfaceState.chatLocation {
            canChangeListMode = true
        }
        
        if let channel = params.interfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, params.interfaceState.chatLocation.threadId == nil, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = params.interfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.sendSomething) {
            canChangeListMode = false
        }
        
        let height: CGFloat
        if case .regular = params.metrics.widthClass {
            height = 49.0
        } else {
            height = 45.0
        }
        
        var modeButtonTitle: [AnimatedTextComponent.Item] = []
        modeButtonTitle = AnimatedTextComponent.extractAnimatedTextString(string: params.interfaceState.strings.Chat_BottomSearchPanel_DisplayModeFormat("."), id: "mode", mapping: [
            0: params.interfaceState.displayHistoryFilterAsList ? .text(params.interfaceState.strings.Chat_BottomSearchPanel_DisplayModeChat) : .text(params.interfaceState.strings.Chat_BottomSearchPanel_DisplayModeList)
        ])

        let size = CGSize(width: params.width - params.additionalSideInsets.left * 2.0 - params.leftInset * 2.0, height: height)
        
        if canChangeListMode {
            var listModeButtonTransition = transition
            let listModeButton: ComponentView<Empty>
            if let current = self.listModeButton {
                listModeButton = current
            } else {
                listModeButtonTransition = listModeButtonTransition.withAnimation(.none)
                listModeButton = ComponentView()
                self.listModeButton = listModeButton
            }
            
            let buttonSize = listModeButton.update(
                transition: listModeButtonTransition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(AnimatedTextComponent(
                        font: Font.regular(15.0),
                        color: params.interfaceState.theme.rootController.navigationBar.accentTextColor,
                        items: modeButtonTitle
                    )),
                    effectAlignment: .right,
                    minSize: CGSize(width: 1.0, height: size.height),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    action: { [weak self] in
                        guard let self, let params = self.currentLayout?.params else {
                            return
                        }
                        self.interfaceInteraction?.updateDisplayHistoryFilterAsList(!params.interfaceState.displayHistoryFilterAsList)
                    },
                    animateScale: false,
                    animateContents: true
                )),
                environment: {},
                containerSize: size
            )
            if let buttonView = listModeButton.view {
                if buttonView.superview == nil {
                    buttonView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.5)
                    buttonView.alpha = 0.0
                    self.view.addSubview(buttonView)
                }
                let listModeFrame = CGRect(origin: CGPoint(x: size.width - params.rightInset - 11.0 - buttonSize.width, y: floor((size.height - buttonSize.height) * 0.5)), size: buttonSize)
                listModeButtonTransition.setPosition(view: buttonView, position: CGPoint(x: listModeFrame.minX + listModeFrame.width * buttonView.layer.anchorPoint.x, y: listModeFrame.minY + listModeFrame.height * buttonView.layer.anchorPoint.y))
                listModeButtonTransition.setBounds(view: buttonView, bounds: CGRect(origin: CGPoint(), size: listModeFrame.size))
                transition.setAlpha(view: buttonView, alpha: 1.0)
            }
        } else {
            if let listModeButton = self.listModeButton {
                self.listModeButton = nil
                if let listModeButtonView = listModeButton.view {
                    transition.setAlpha(view: listModeButtonView, alpha: 0.0, completion: { [weak listModeButtonView] _ in
                        listModeButtonView?.removeFromSuperview()
                    })
                }
            }
        }
        
        var nextLeftX: CGFloat = 16.0
        
        if !self.alwaysShowTotalMessagesCount && self.externalSearchResultsCount == nil {
            nextLeftX = 12.0
            let calendarButtonSize = self.calendarButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Chat/Input/Search/Calendar",
                        tintColor: params.interfaceState.theme.rootController.navigationBar.accentTextColor
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: 1.0, height: size.height),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.interfaceInteraction?.openCalendarSearch()
                    }
                )),
                environment: {},
                containerSize: size
            )
            let calendarButtonFrame = CGRect(origin: CGPoint(x: nextLeftX, y: floor((size.height - calendarButtonSize.height) * 0.5)), size: calendarButtonSize)
            if let calendarButtonView = self.calendarButton.view {
                if calendarButtonView.superview == nil {
                    self.view.addSubview(calendarButtonView)
                    
                    if !transition.animation.isImmediate {
                        calendarButtonView.alpha = 1.0
                        transition.animateAlpha(view: calendarButtonView, from: 0.0, to: 1.0)
                        transition.animateScale(view: calendarButtonView, from: 0.01, to: 1.0)
                    }
                }
                transition.setFrame(view: calendarButtonView, frame: calendarButtonFrame)
            }
            nextLeftX += calendarButtonSize.width + 8.0
        } else if let calendarButtonView = self.calendarButton.view {
            if transition.animation.isImmediate {
                calendarButtonView.removeFromSuperview()
            } else {
                transition.setAlpha(view: calendarButtonView, alpha: 0.0, completion: { finished in
                    if finished {
                        calendarButtonView.removeFromSuperview()
                    }
                    calendarButtonView.alpha = 1.0
                })
                transition.animateScale(view: calendarButtonView, from: 1.0, to: 0.01)
            }
        }
        
        if displaySearchMembers {
            let membersButton: ComponentView<Empty>
            if let current = self.membersButton {
                membersButton = current
            } else {
                membersButton = ComponentView()
                self.membersButton = membersButton
            }
            
            let buttonSize = membersButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Chat/Input/Search/Members",
                        tintColor: params.interfaceState.theme.rootController.navigationBar.accentTextColor
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: 1.0, height: size.height),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.interfaceInteraction?.toggleMembersSearch(true)
                    }
                )),
                environment: {},
                containerSize: size
            )
            if let buttonView = membersButton.view {
                var membersButtonTransition = transition
                var animateIn = false
                if buttonView.superview == nil {
                    membersButtonTransition = membersButtonTransition.withAnimation(.none)
                    buttonView.alpha = 0.0
                    animateIn = true
                    self.view.addSubview(buttonView)
                }
                membersButtonTransition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(x: nextLeftX, y: floor((size.height - buttonSize.height) * 0.5)), size: buttonSize))
                
                transition.setAlpha(view: buttonView, alpha: 1.0)
                if animateIn {
                    transition.animateScale(view: buttonView, from: 0.001, to: 1.0)
                }
            }
            nextLeftX += buttonSize.width + 8.0
        } else {
            if let membersButton = self.membersButton {
                self.membersButton = nil
                if let membersButtonView = membersButton.view {
                    transition.setAlpha(view: membersButtonView, alpha: 0.0, completion: { [weak membersButtonView] _ in
                        membersButtonView?.removeFromSuperview()
                    })
                    transition.setScale(view: membersButtonView, scale: 0.001)
                }
            }
        }
        
        if !resultsTextString.isEmpty {
            var resultsTextTransition = transition
            let resultsText: ComponentView<Empty>
            if let current = self.resultsText {
                resultsText = current
            } else {
                resultsTextTransition = resultsTextTransition.withAnimation(.none)
                resultsText = ComponentView()
                self.resultsText = resultsText
            }
            
            if self.alwaysShowTotalMessagesCount {
                resultsTextTransition = .immediate
            }
            
            let resultsTextSize = resultsText.update(
                transition: resultsTextTransition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(AnimatedTextComponent(
                        font: Font.regular(15.0),
                        color: (params.interfaceState.displayHistoryFilterAsList && canChangeListMode) ? params.interfaceState.theme.rootController.navigationBar.accentTextColor : params.interfaceState.theme.rootController.navigationBar.secondaryTextColor,
                        items: resultsTextString
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self, let params = self.currentLayout?.params else {
                            return
                        }
                        self.interfaceInteraction?.updateDisplayHistoryFilterAsList(!params.interfaceState.displayHistoryFilterAsList)
                    },
                    isEnabled: params.interfaceState.displayHistoryFilterAsList && canChangeListMode
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 100.0)
            )
            let resultsTextFrame = CGRect(origin: CGPoint(x: nextLeftX - 3.0, y: floor((size.height - resultsTextSize.height) * 0.5)), size: resultsTextSize)
            if let resultsTextView = resultsText.view {
                if resultsTextView.superview == nil {
                    resultsTextView.alpha = 0.0
                    self.view.addSubview(resultsTextView)
                }
                resultsTextTransition.setFrame(view: resultsTextView, frame: resultsTextFrame)
                transition.setAlpha(view: resultsTextView, alpha: 1.0)
            }
            nextLeftX += -3.0 + resultsTextSize.width
        } else {
            if let resultsText = self.resultsText {
                self.resultsText = nil
                if let resultsTextView = resultsText.view {
                    transition.setAlpha(view: resultsTextView, alpha: 0.0, completion: { [weak resultsTextView] _ in
                        resultsTextView?.removeFromSuperview()
                    })
                }
            }
        }

        return height
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
