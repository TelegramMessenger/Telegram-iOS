import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import SearchBarNode
import LocalizedPeerData
import SwiftSignalKit
import AccountContext
import ChatPresentationInterfaceState
import ComponentFlow
import GlassBackgroundComponent
import ActivityIndicator

private let searchBarFont = Font.regular(17.0)

public final class ChatSearchNavigationContentNode: NavigationBarContentNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var preferClearGlass: Bool
    private let strings: PresentationStrings
    private let chatLocation: ChatLocation
    
    private let backgroundContainer: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private let iconView: UIImageView
    private var activityIndicator: ActivityIndicator?
    private let searchBar: SearchBarNode
    private let close: (background: GlassBackgroundView, icon: UIImageView)
    
    private let interaction: ChatPanelInterfaceInteraction
    
    private var hasActivity: Bool = false
    private var searchingActivityDisposable: Disposable?
    
    private var params: (size: CGSize, leftInset: CGFloat, rightInset: CGFloat)?
    
    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, chatLocation: ChatLocation, interaction: ChatPanelInterfaceInteraction, presentationInterfaceState: ChatPresentationInterfaceState) {
        self.context = context
        self.theme = theme
        self.preferClearGlass = presentationInterfaceState.preferredGlassType == .clear
        self.strings = strings
        self.chatLocation = chatLocation
        self.interaction = interaction
        
        self.backgroundContainer = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainer.contentView.addSubview(self.backgroundView)
        self.iconView = UIImageView()
        self.backgroundView.contentView.addSubview(self.iconView)
        
        self.close = (GlassBackgroundView(), UIImageView())
        self.close.background.contentView.addSubview(self.close.icon)
        
        self.searchBar = SearchBarNode(
            theme: SearchBarNodeTheme(
                background: .clear,
                separator: .clear,
                inputFill: .clear,
                primaryText: theme.chat.inputPanel.panelControlColor,
                placeholder: theme.chat.inputPanel.inputPlaceholderColor,
                inputIcon: theme.chat.inputPanel.inputControlColor,
                inputClear: theme.chat.inputPanel.panelControlColor,
                accent: theme.chat.inputPanel.panelControlAccentColor,
                keyboard: theme.rootController.keyboardColor
            ),
            presentationTheme: theme,
            preferClearGlass: presentationInterfaceState.preferredGlassType == .clear,
            strings: strings,
            fieldStyle: .inlineNavigation,
            forceSeparator: false,
            displayBackground: false,
            cancelText: nil
        )
        let placeholderText: String
        switch chatLocation {
        case .peer, .replyThread, .customChatContents:
            if chatLocation.peerId == context.account.peerId, presentationInterfaceState.hasSearchTags {
                if case .standard(.embedded(false)) = presentationInterfaceState.mode {
                    placeholderText = strings.Common_Search
                } else {
                    placeholderText = strings.Chat_SearchTagsPlaceholder
                }
            } else {
                placeholderText = strings.Conversation_SearchPlaceholder
            }
        }
        self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: theme.chat.inputPanel.inputPlaceholderColor)
        
        super.init()
        
        self.view.addSubview(self.backgroundContainer)
        self.backgroundView.contentView.addSubview(self.searchBar.view)
        
        self.backgroundContainer.contentView.addSubview(self.close.background)
        self.close.background.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onCloseTapGesture(_:))))
        
        self.searchBar.cancel = { [weak self] in
            self?.searchBar.deactivate(clear: false)
            self?.interaction.dismissMessageSearch()
        }
        
        self.searchBar.textUpdated = { [weak self] query, _ in
            self?.interaction.updateMessageSearch(query)
        }
        
        self.searchBar.clearPrefix = { [weak self] in
            self?.interaction.toggleMembersSearch(false)
        }
        
        self.searchBar.clearTokens = { [weak self] in
            self?.interaction.toggleMembersSearch(false)
        }
        
        self.searchBar.tokensUpdated = { [weak self] tokens in
            if tokens.isEmpty {
                self?.interaction.toggleMembersSearch(false)
            }
        }
        
        if let statuses = interaction.statuses {
            self.searchingActivityDisposable = (statuses.searching
            |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                guard let self else {
                    return
                }
                if self.hasActivity != value {
                    self.hasActivity = value
                    if let params = self.params {
                        let _ = self.updateLayout(size: params.size, leftInset: params.leftInset, rightInset: params.rightInset, transition: .immediate)
                    }
                }
            })
        }
    }

    deinit {
        self.searchingActivityDisposable?.dispose()
    }
    
    override public var nominalHeight: CGFloat {
        return 60.0
    }
    
    @objc private func onCloseTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.searchBar.cancel?()
        }
    }
    
    override public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        self.params = (size, leftInset, rightInset)
        
        let transition = ComponentTransition(transition)
        
        let backgroundFrame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: 6.0), size: CGSize(width: size.width - 16.0 * 2.0 - leftInset - rightInset - 44.0 - 8.0, height: 44.0))
        let closeFrame = CGRect(origin: CGPoint(x: size.width - 16.0 - rightInset - 44.0, y: backgroundFrame.minY), size: CGSize(width: 44.0, height: 44.0))
        
        transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundContainer.update(size: size, isDark: self.theme.overallDarkAppearance, transition: transition)
        
        transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: self.preferClearGlass ? .clear : .panel), isInteractive: true, transition: transition)

        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: "Navigation/Search")?.withRenderingMode(.alwaysTemplate)
        }
        transition.setTintColor(view: self.iconView, color: self.theme.rootController.navigationSearchBar.inputIconColor)
        
        if let image = self.iconView.image {
            let imageSize: CGSize
            let iconFrame: CGRect
            let iconFraction: CGFloat = 0.8
            imageSize = CGSize(width: image.size.width * iconFraction, height: image.size.height * iconFraction)
            iconFrame = CGRect(origin: CGPoint(x: 12.0, y: floor((backgroundFrame.height - imageSize.height) * 0.5)), size: imageSize)
            transition.setPosition(view: self.iconView, position: iconFrame.center)
            transition.setBounds(view: self.iconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
        }
        
        if self.hasActivity {
            let activityIndicator: ActivityIndicator
            if let current = self.activityIndicator {
                activityIndicator = current
            } else {
                activityIndicator = ActivityIndicator(type: .custom(self.theme.chat.inputPanel.inputControlColor, 14.0, 14.0, false))
                self.activityIndicator = activityIndicator
                self.backgroundView.contentView.addSubview(activityIndicator.view)
            }
            let indicatorSize = activityIndicator.measure(CGSize(width: 32.0, height: 32.0))
            let indicatorFrame = CGRect(origin: CGPoint(x: 15.0, y: floorToScreenPixels((backgroundFrame.height - indicatorSize.height) * 0.5)), size: indicatorSize)
            transition.setPosition(view: activityIndicator.view, position: indicatorFrame.center)
            transition.setBounds(view: activityIndicator.view, bounds: CGRect(origin: CGPoint(), size: indicatorFrame.size))
        } else if let activityIndicator = self.activityIndicator {
            self.activityIndicator = nil
            activityIndicator.view.removeFromSuperview()
        }
        self.iconView.isHidden = self.hasActivity
        
        let searchBarFrame = CGRect(origin: CGPoint(x: 36.0, y: 0.0), size: CGSize(width: backgroundFrame.width - 36.0 - 4.0, height: 44.0))
        transition.setFrame(view: self.searchBar.view, frame: searchBarFrame)
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: 0.0, rightInset: 0.0, transition: transition.containedViewLayoutTransition)
        
        if self.close.icon.image == nil {
            self.close.icon.image = generateImage(CGSize(width: 40.0, height: 40.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.setLineWidth(2.0)
                context.setLineCap(.round)
                context.setStrokeColor(UIColor.white.cgColor)
                
                context.beginPath()
                context.move(to: CGPoint(x: 12.0, y: 12.0))
                context.addLine(to: CGPoint(x: size.width - 12.0, y: size.height - 12.0))
                context.move(to: CGPoint(x: size.width - 12.0, y: 12.0))
                context.addLine(to: CGPoint(x: 12.0, y: size.height - 12.0))
                context.strokePath()
            })?.withRenderingMode(.alwaysTemplate)
        }
        
        if let image = close.icon.image {
            self.close.icon.frame = image.size.centered(in: CGRect(origin: CGPoint(), size: closeFrame.size))
        }
        self.close.icon.tintColor = self.theme.chat.inputPanel.panelControlColor
        
        transition.setFrame(view: self.close.background, frame: closeFrame)
        self.close.background.update(size: closeFrame.size, cornerRadius: closeFrame.height * 0.5, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: self.preferClearGlass ? .clear : .panel), isInteractive: true, transition: transition)
        
        return size
    }
    
    public func activate() {
        self.searchBar.activate()
    }
    
    public func deactivate() {
        self.searchBar.deactivate(clear: false)
    }
    
    public func update(presentationInterfaceState: ChatPresentationInterfaceState) {
        if let search = presentationInterfaceState.search {
            self.searchBar.updateThemeAndStrings(
                theme: SearchBarNodeTheme(
                    background: .clear,
                    separator: .clear,
                    inputFill: .clear,
                    primaryText: presentationInterfaceState.theme.chat.inputPanel.panelControlColor,
                    placeholder: presentationInterfaceState.theme.chat.inputPanel.inputPlaceholderColor,
                    inputIcon: presentationInterfaceState.theme.chat.inputPanel.inputControlColor,
                    inputClear: presentationInterfaceState.theme.chat.inputPanel.panelControlColor,
                    accent: presentationInterfaceState.theme.chat.inputPanel.panelControlAccentColor,
                    keyboard: presentationInterfaceState.theme.rootController.keyboardColor
                ),
                presentationTheme: presentationInterfaceState.theme,
                preferClearGlass: presentationInterfaceState.preferredGlassType == .clear,
                strings: presentationInterfaceState.strings
            )
            
            switch search.domain {
            case .everything, .tag:
                self.searchBar.tokens = []
                self.searchBar.prefixString = nil
                let placeholderText: String
                switch self.chatLocation {
                case .peer, .replyThread, .customChatContents:
                    if presentationInterfaceState.historyFilter != nil {
                        placeholderText = self.strings.Common_Search
                    } else if self.chatLocation.peerId == self.context.account.peerId, presentationInterfaceState.hasSearchTags {
                        if case .standard(.embedded(false)) = presentationInterfaceState.mode {
                            placeholderText = strings.Common_Search
                        } else {
                            placeholderText = self.strings.Chat_SearchTagsPlaceholder
                        }
                    } else {
                        placeholderText = self.strings.Conversation_SearchPlaceholder
                    }
                }
                self.searchBar.placeholderString = NSAttributedString(string: placeholderText, font: searchBarFont, textColor: presentationInterfaceState.theme.chat.inputPanel.inputPlaceholderColor)
            case .members:
                self.searchBar.tokens = []
                self.searchBar.prefixString = NSAttributedString(string: strings.Conversation_SearchByName_Prefix, font: searchBarFont, textColor: presentationInterfaceState.theme.chat.inputPanel.inputTextColor)
                self.searchBar.placeholderString = nil
            case let .member(peer):
                self.searchBar.tokens = [SearchBarToken(id: peer.id, icon: UIImage(bundleImageName: "Chat List/Search/User"), title: EnginePeer(peer).compactDisplayTitle, permanent: false)]
                self.searchBar.prefixString = nil
                self.searchBar.placeholderString = nil
            }
            
            if self.searchBar.text != search.query {
                self.searchBar.text = search.query
                self.interaction.updateMessageSearch(search.query)
            }
        }
        
        if presentationInterfaceState.theme != self.theme || (presentationInterfaceState.preferredGlassType == .clear) != self.preferClearGlass {
            self.theme = presentationInterfaceState.theme
            self.preferClearGlass = presentationInterfaceState.preferredGlassType == .clear
            if let params = self.params {
                let _ = self.updateLayout(size: params.size, leftInset: params.leftInset, rightInset: params.rightInset, transition: .immediate)
            }
        }
    }
}
