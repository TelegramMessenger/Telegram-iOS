import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

private let labelFont = Font.regular(15.0)

final class ChatSearchInputPanelNode: ChatInputPanelNode {
    private let upButton: HighlightableButtonNode
    private let downButton: HighlightableButtonNode
    private let calendarButton: HighlightableButtonNode
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
        self.resultsLabel = TextNode()
        self.resultsLabel.isLayerBacked = true
        self.resultsLabel.displaysAsynchronously = false
        self.activityIndicator = ActivityIndicator(type: .navigationAccent(theme))
        self.activityIndicator.isHidden = true
        
        super.init()
        
        self.addSubnode(self.upButton)
        self.addSubnode(self.downButton)
        self.addSubnode(self.calendarButton)
        self.addSubnode(self.resultsLabel)
        self.addSubnode(self.activityIndicator)
        
        self.upButton.addTarget(self, action: #selector(self.upPressed), forControlEvents: [.touchUpInside])
        self.downButton.addTarget(self, action: #selector(self.downPressed), forControlEvents: [.touchUpInside])
        self.calendarButton.addTarget(self, action: #selector(self.calendarPressed), forControlEvents: [.touchUpInside])
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
    
    override func updateLayout(width: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            let themeUpdated = self.presentationInterfaceState?.theme !== interfaceState.theme
            
            self.presentationInterfaceState = interfaceState
            
            if themeUpdated {
                self.upButton.setImage(PresentationResourcesChat.chatInputSearchPanelUpImage(interfaceState.theme), for: [.normal])
                self.upButton.setImage(PresentationResourcesChat.chatInputSearchPanelUpDisabledImage(interfaceState.theme), for: [.disabled])
                self.downButton.setImage(PresentationResourcesChat.chatInputSearchPanelDownImage(interfaceState.theme), for: [.normal])
                self.downButton.setImage(PresentationResourcesChat.chatInputSearchPanelDownDisabledImage(interfaceState.theme), for: [.disabled])
                self.calendarButton.setImage(PresentationResourcesChat.chatInputSearchPanelCalendarImage(interfaceState.theme), for: [])
            }
        }
        
        let panelHeight: CGFloat = 47.0
        
        transition.updateFrame(node: self.downButton, frame: CGRect(origin: CGPoint(x: 12.0, y: 0.0), size: CGSize(width: 40.0, height: panelHeight)))
        transition.updateFrame(node: self.upButton, frame: CGRect(origin: CGPoint(x: 12.0 + 43.0, y: 0.0), size: CGSize(width: 40.0, height: panelHeight)))
        transition.updateFrame(node: self.calendarButton, frame: CGRect(origin: CGPoint(x: width - 60.0, y: 0.0), size: CGSize(width: 60.0, height: panelHeight)))
        
        var resultIndex: Int?
        var resultCount: Int?
        var resultsText: NSAttributedString?
        if let results = interfaceState.search?.resultsState {
            resultCount = results.messageIds.count
            if let currentId = results.currentId, let index = results.messageIds.index(of: currentId) {
                resultIndex = index
                resultsText = NSAttributedString(string: "\(index + 1) \(interfaceState.strings.Common_of) \(results.messageIds.count)", font: labelFont, textColor: interfaceState.theme.chat.inputPanel.primaryTextColor)
            } else {
                resultsText = NSAttributedString(string: interfaceState.strings.Conversation_SearchNoResults, font: labelFont, textColor: interfaceState.theme.chat.inputPanel.primaryTextColor)
            }
        }
        
        self.upButton.isEnabled = resultIndex != nil && resultIndex != 0
        self.downButton.isEnabled = resultIndex != nil && resultCount != nil && resultIndex != resultCount! - 1
        self.calendarButton.isHidden = (!(interfaceState.search?.query.isEmpty ?? true)) || self.displayActivity
        
        let makeLabelLayout = TextNode.asyncLayout(self.resultsLabel)
        let (labelSize, labelApply) = makeLabelLayout(resultsText, nil, 1, .end, CGSize(width: 200.0, height: 100.0), .left, nil, UIEdgeInsets())
        let _ = labelApply()
        self.resultsLabel.frame = CGRect(origin: CGPoint(x: 105.0, y: floor((panelHeight - labelSize.size.height) / 2.0)), size: labelSize.size)
        
        let indicatorSize = self.activityIndicator.measure(CGSize(width: 22.0, height: 22.0))
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: width - 41.0, y: floor((panelHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        
        return panelHeight
    }
}
