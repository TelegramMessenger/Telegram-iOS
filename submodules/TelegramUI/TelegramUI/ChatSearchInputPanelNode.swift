import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ActivityIndicator

private let labelFont = Font.regular(15.0)

final class ChatSearchInputPanelNode: ChatInputPanelNode {
    private let upButton: HighlightableButtonNode
    private let downButton: HighlightableButtonNode
    private let calendarButton: HighlightableButtonNode
    private let membersButton: HighlightableButtonNode
    private let resultsLabel: TextNode
    private let activityIndicator: ActivityIndicator
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private let activityDisposable = MetaDisposable()
    private var displayActivity = false
    
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if let statuses = self.interfaceInteraction?.statuses {
                self.activityDisposable.set((combineLatest((statuses.searching |> deliverOnMainQueue), (statuses.loadingMessage |> deliverOnMainQueue))).start(next: { [weak self] searching, loadingMessage in
                    let value = searching || loadingMessage
                    if let strongSelf = self, strongSelf.displayActivity != value {
                        strongSelf.displayActivity = value
                        strongSelf.activityIndicator.isHidden = !value
                        if let interfaceState = strongSelf.presentationInterfaceState {
                            strongSelf.calendarButton.isHidden = !((interfaceState.search?.query.isEmpty ?? true)) || strongSelf.displayActivity
                        }
                    }
                }))
            } else {
                self.activityDisposable.set(nil)
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.upButton = HighlightableButtonNode()
        self.upButton.isEnabled = false
        self.downButton = HighlightableButtonNode()
        self.downButton.isEnabled = false
        self.calendarButton = HighlightableButtonNode()
        self.membersButton = HighlightableButtonNode()
        self.resultsLabel = TextNode()
        self.resultsLabel.isUserInteractionEnabled = false
        self.resultsLabel.displaysAsynchronously = false
        self.activityIndicator = ActivityIndicator(type: .navigationAccent(theme))
        self.activityIndicator.isHidden = true
        
        super.init()
        
        self.addSubnode(self.upButton)
        self.addSubnode(self.downButton)
        self.addSubnode(self.calendarButton)
        self.addSubnode(self.membersButton)
        self.addSubnode(self.resultsLabel)
        self.addSubnode(self.activityIndicator)
        
        self.upButton.addTarget(self, action: #selector(self.upPressed), forControlEvents: [.touchUpInside])
        self.downButton.addTarget(self, action: #selector(self.downPressed), forControlEvents: [.touchUpInside])
        self.calendarButton.addTarget(self, action: #selector(self.calendarPressed), forControlEvents: [.touchUpInside])
        self.membersButton.addTarget(self, action: #selector(self.membersPressed), forControlEvents: [.touchUpInside])
    }
    
    deinit {
        self.activityDisposable.dispose()
    }
    
    @objc func upPressed() {
        self.interfaceInteraction?.navigateMessageSearch(.earlier)
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
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
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
        
        self.downButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 48.0, y: 0.0), size: CGSize(width: 40.0, height: panelHeight))
        self.upButton.frame = CGRect(origin: CGPoint(x: width - rightInset - 48.0 - 43.0, y: 0.0), size: CGSize(width: 40.0, height: panelHeight))
        self.calendarButton.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: 60.0, height: panelHeight))
        self.membersButton.frame = CGRect(origin: CGPoint(x: leftInset + 43.0, y: 0.0), size: CGSize(width: 60.0, height: panelHeight))
        
        var resultIndex: Int?
        var resultCount: Int?
        var resultsText: NSAttributedString?
        if let results = interfaceState.search?.resultsState {
            resultCount = results.messageIndices.count
            let displayTotalCount = results.completed ? results.messageIndices.count : Int(results.totalCount)
            if let currentId = results.currentId, let index = results.messageIndices.firstIndex(where: { $0.id == currentId }) {
                let adjustedIndex = results.messageIndices.count - 1 - index
                resultIndex = index
                resultsText = NSAttributedString(string: interfaceState.strings.Items_NOfM("\(adjustedIndex + 1)", "\(displayTotalCount)").0, font: labelFont, textColor: interfaceState.theme.chat.inputPanel.primaryTextColor)
            } else {
                resultsText = NSAttributedString(string: interfaceState.strings.Conversation_SearchNoResults, font: labelFont, textColor: interfaceState.theme.chat.inputPanel.primaryTextColor)
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
        
        let makeLabelLayout = TextNode.asyncLayout(self.resultsLabel)
        let (labelSize, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: resultsText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - leftInset - rightInset - 50.0, height: 100.0), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
        let _ = labelApply()
        
        var resultsOffset: CGFloat = 16.0
        if !self.calendarButton.isHidden {
            resultsOffset += 48.0
        }
        self.resultsLabel.frame = CGRect(origin: CGPoint(x: leftInset + resultsOffset, y: floor((panelHeight - labelSize.size.height) / 2.0)), size: labelSize.size)
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 22.0, height: 22.0))
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: width - rightInset - 41.0, y: floor((panelHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
