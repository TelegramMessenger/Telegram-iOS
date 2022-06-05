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

private let labelFont = Font.regular(15.0)

final class ChatSearchInputPanelNode: ChatInputPanelNode {
    private let upButton: HighlightableButtonNode
    private let downButton: HighlightableButtonNode
    private let calendarButton: HighlightableButtonNode
    private let membersButton: HighlightableButtonNode
    private let resultsButton: HighlightableButtonNode
    private let measureResultsLabel: TextNode
    private let activityIndicator: ActivityIndicator
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private let activityDisposable = MetaDisposable()
    private var displayActivity = false
    
    private var needsSearchResultsTooltip = true
    
    private var validLayout: (width: CGFloat, leftInset: CGFloat,  rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, metrics: LayoutMetrics, isSecondary: Bool)?
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if let statuses = self.interfaceInteraction?.statuses {
                self.activityDisposable.set((combineLatest((statuses.searching |> deliverOnMainQueue), (statuses.loadingMessage |> deliverOnMainQueue))).start(next: { [weak self] searching, loadingMessage in
                    let value = searching || loadingMessage == .generic
                    if let strongSelf = self, strongSelf.displayActivity != value {
                        strongSelf.displayActivity = value
                        strongSelf.activityIndicator.isHidden = !value
                        if let interfaceState = strongSelf.presentationInterfaceState, let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary) = strongSelf.validLayout {
                            let _ = strongSelf.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: interfaceState, metrics: metrics)
                        }
                    }
                }))
            } else {
                self.activityDisposable.set(nil)
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.upButton = HighlightableButtonNode(pointerStyle: .default)
        self.upButton.isEnabled = false
        self.downButton = HighlightableButtonNode(pointerStyle: .default)
        self.downButton.isEnabled = false
        self.calendarButton = HighlightableButtonNode()
        self.membersButton = HighlightableButtonNode(pointerStyle: .default)
        self.measureResultsLabel = TextNode()
        self.measureResultsLabel.displaysAsynchronously = false
        self.resultsButton = HighlightableButtonNode(pointerStyle: .default)
        self.activityIndicator = ActivityIndicator(type: .navigationAccent(theme.rootController.navigationBar.buttonColor))
        self.activityIndicator.isHidden = true
        
        super.init()
        
        self.addSubnode(self.upButton)
        self.addSubnode(self.downButton)
        self.addSubnode(self.calendarButton)
        self.addSubnode(self.membersButton)
        self.addSubnode(self.resultsButton)
        self.resultsButton.addSubnode(self.measureResultsLabel)
        self.addSubnode(self.activityIndicator)
        
        self.upButton.addTarget(self, action: #selector(self.upPressed), forControlEvents: [.touchUpInside])
        self.downButton.addTarget(self, action: #selector(self.downPressed), forControlEvents: [.touchUpInside])
        self.calendarButton.addTarget(self, action: #selector(self.calendarPressed), forControlEvents: [.touchUpInside])
        self.membersButton.addTarget(self, action: #selector(self.membersPressed), forControlEvents: [.touchUpInside])
        self.resultsButton.addTarget(self, action: #selector(self.resultsPressed), forControlEvents: [.touchUpInside])
    }
    
    deinit {
        self.activityDisposable.dispose()
    }
    
    @objc func upPressed() {
        self.interfaceInteraction?.navigateMessageSearch(.earlier)
        
        guard self.needsSearchResultsTooltip, let context = self.context else {
            return
        }
        
        let _ = (ApplicationSpecificNotice.getChatMessageSearchResultsTip(accountManager: context.sharedContext.accountManager)
        |> deliverOnMainQueue).start(next: { [weak self] counter in
            guard let strongSelf = self else {
                return
            }
            
            if counter >= 3 {
                strongSelf.needsSearchResultsTooltip = false
            } else if arc4random_uniform(4) == 1 {
                strongSelf.needsSearchResultsTooltip = false
                
                let _ = ApplicationSpecificNotice.incrementChatMessageSearchResultsTip(accountManager: context.sharedContext.accountManager).start()
                strongSelf.interfaceInteraction?.displaySearchResultsTooltip(strongSelf.resultsButton, strongSelf.resultsButton.bounds)
            }
        })
    }
    
    @objc func downPressed() {
        self.interfaceInteraction?.navigateMessageSearch(.later)
    }
    
    @objc func calendarPressed() {
        self.interfaceInteraction?.openCalendarSearch()
    }
    
    @objc func membersPressed() {
        self.interfaceInteraction?.toggleMembersSearch(true)
    }
    
    @objc func resultsPressed() {
        self.interfaceInteraction?.openSearchResults()
        
        if let context = self.context {
            let _ = ApplicationSpecificNotice.incrementChatMessageSearchResultsTip(accountManager: context.sharedContext.accountManager, count: 4).start()
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        self.validLayout = (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary)
        
        if self.presentationInterfaceState != interfaceState {
            let themeUpdated = self.presentationInterfaceState?.theme !== interfaceState.theme
            
            self.presentationInterfaceState = interfaceState
            
            if themeUpdated {
                self.upButton.setImage(PresentationResourcesChat.chatInputSearchPanelUpImage(interfaceState.theme), for: [.normal])
                self.upButton.setImage(PresentationResourcesChat.chatInputSearchPanelUpDisabledImage(interfaceState.theme), for: [.disabled])
                self.downButton.setImage(PresentationResourcesChat.chatInputSearchPanelDownImage(interfaceState.theme), for: [.normal])
                self.downButton.setImage(PresentationResourcesChat.chatInputSearchPanelDownDisabledImage(interfaceState.theme), for: [.disabled])
                self.calendarButton.setImage(PresentationResourcesChat.chatInputSearchPanelCalendarImage(interfaceState.theme), for: [])
                
                self.membersButton.setImage(PresentationResourcesChat.chatInputSearchPanelMembersImage(interfaceState.theme), for: [])
            }
        }
        
        let panelHeight: CGFloat
        if case .regular = metrics.widthClass {
            panelHeight = 49.0
        } else {
            panelHeight = 45.0
        }
        
        var width = width
        if additionalSideInsets.right > 0.0 {
            width -= additionalSideInsets.right
        }
        
        self.downButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 48.0, y: 0.0), size: CGSize(width: 40.0, height: panelHeight))
        self.upButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 48.0 - 43.0, y: 0.0), size: CGSize(width: 40.0, height: panelHeight))
        self.calendarButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 60.0, height: panelHeight))
        self.membersButton.frame = CGRect(origin: CGPoint(x: leftInset + 43.0, y: 0.0), size: CGSize(width: 60.0, height: panelHeight))
        
        var resultIndex: Int?
        var resultCount: Int?
        var resultsText: String?
        if let results = interfaceState.search?.resultsState {
            resultCount = results.messageIndices.count
            let displayTotalCount = results.completed ? results.messageIndices.count : Int(results.totalCount)
            if let currentId = results.currentId, let index = results.messageIndices.firstIndex(where: { $0.id == currentId }) {
                let adjustedIndex = results.messageIndices.count - 1 - index
                resultIndex = index
                resultsText = interfaceState.strings.Items_NOfM("\(adjustedIndex + 1)", "\(displayTotalCount)").string
            } else {
                resultsText = interfaceState.strings.Conversation_SearchNoResults
            }
        }
        
        self.upButton.isEnabled = resultIndex != nil && resultIndex != 0
        self.downButton.isEnabled = resultIndex != nil && resultCount != nil && resultIndex != resultCount! - 1
        self.calendarButton.isHidden = (!(interfaceState.search?.query.isEmpty ?? true)) || self.displayActivity
        
        var canSearchMembers = false
        if let search = interfaceState.search {
            if case .everything = search.domain {
                if let _ = interfaceState.renderedPeer?.peer as? TelegramGroup {
                    canSearchMembers = true
                } else if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel, case .group = peer.info {
                    canSearchMembers = true
                }
            } else {
                canSearchMembers = false
            }
        }
        self.membersButton.isHidden = (!(interfaceState.search?.query.isEmpty ?? true)) || self.displayActivity || !canSearchMembers
        
        let resultsEnabled = (resultCount ?? 0) > 0
        //self.resultsButton.setTitle(resultsText ?? "", with: labelFont, with: resultsEnabled ? interfaceState.theme.chat.inputPanel.panelControlAccentColor : interfaceState.theme.chat.inputPanel.primaryTextColor, for: .normal)
        self.resultsButton.isUserInteractionEnabled = resultsEnabled
        
        let makeLabelLayout = TextNode.asyncLayout(self.measureResultsLabel)
        let (labelSize, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: resultsText ?? "", font: labelFont, textColor: resultsEnabled ? interfaceState.theme.chat.inputPanel.panelControlAccentColor : interfaceState.theme.chat.inputPanel.primaryTextColor, paragraphAlignment: .left), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - leftInset - rightInset - 50.0, height: 100.0), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
        let _ = labelApply()
        
        var resultsOffset: CGFloat = 16.0
        if !self.calendarButton.isHidden {
            resultsOffset += 48.0
        }
        self.resultsButton.frame = CGRect(origin: CGPoint(x: leftInset + resultsOffset, y: floor((panelHeight - labelSize.size.height) / 2.0)), size: labelSize.size)
        self.measureResultsLabel.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: labelSize.size)
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 22.0, height: 22.0))
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: width - rightInset - 41.0, y: floor((panelHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
