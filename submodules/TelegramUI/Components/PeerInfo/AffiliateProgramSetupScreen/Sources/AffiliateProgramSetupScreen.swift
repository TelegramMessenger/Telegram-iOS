import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import MultilineTextComponent
import ButtonComponent
import UndoUI
import BundleIconComponent
import ListSectionComponent
import ListItemSliderSelectorComponent
import ListActionItemComponent
import Markdown
import BlurredBackgroundComponent
import PremiumUI
import PresentationDataUtils
import PeerListItemComponent
import TelegramStringFormatting
import ContextUI
import BalancedTextComponent
import AlertComponent

private func textForTimeout(value: Int32) -> String {
    if value < 3600 {
        let minutes = value / 60
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(minutes):\(secondsPadding)\(seconds)"
    } else {
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let minutesPadding = minutes < 10 ? "0" : ""
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(hours):\(minutesPadding)\(minutes):\(secondsPadding)\(seconds)"
    }
}

final class AffiliateProgramSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialContent: AffiliateProgramSetupScreen.Content

    init(
        context: AccountContext,
        initialContent: AffiliateProgramSetupScreen.Content
    ) {
        self.context = context
        self.initialContent = initialContent
    }

    static func ==(lhs: AffiliateProgramSetupScreenComponent, rhs: AffiliateProgramSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }

        return true
    }
    
    private class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: UIScrollView
        
        private let coinIcon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let titleTransformContainer: UIView
        private let subtitle = ComponentView<Empty>()
        
        private let introBackground = ComponentView<Empty>()
        private var introIconItems: [Int: ComponentView<Empty>] = [:]
        private var introTitleItems: [Int: ComponentView<Empty>] = [:]
        private var introTextItems: [Int: ComponentView<Empty>] = [:]
        
        private let commissionSection = ComponentView<Empty>()
        private let durationSection = ComponentView<Empty>()
        private let existingProgramsSection = ComponentView<Empty>()
        private let endProgramSection = ComponentView<Empty>()
        
        private let activeProgramsSection = ComponentView<Empty>()
        private let suggestedProgramsSection = ComponentView<Empty>()
        
        private let bottomPanelSeparator = SimpleLayer()
        private let bottomPanelBackground = ComponentView<Empty>()
        private let bottomPanelButton = ComponentView<Empty>()
        private let bottomPanelText = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: AffiliateProgramSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var commissionSliderValue: CGFloat = 0.0
        private var commissionPermille: Int = 10
        private var commissionMinPermille: Int = 10
        
        private var durationValue: Int = 0
        private var durationMinValue: Int = 0
        
        private var isApplying: Bool = false
        private var applyDisposable: Disposable?
        
        private var currentProgram: TelegramStarRefProgram?
        private var programEndTimer: Foundation.Timer?
        
        private var connectedStarBotList: TelegramConnectedStarRefBotList?
        private var connectedStarBotListDisposable: Disposable?
        
        private var suggestedStarBotList: TelegramSuggestedStarRefBotList?
        private var suggestedStarBotListDisposable: Disposable?
        private var suggestedSortMode: TelegramSuggestedStarRefBotList.SortMode = .profitability
        private var isSuggestedSortModeUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.titleTransformContainer = UIView()
            self.titleTransformContainer.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.layer.addSublayer(self.bottomPanelSeparator)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.applyDisposable?.dispose()
            self.programEndTimer?.invalidate()
            self.connectedStarBotListDisposable?.dispose()
            self.suggestedStarBotListDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        private func requestApplyProgram() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            let programPermille: Int32 = Int32(self.commissionPermille)
            let programDuration: Int32? = self.durationValue == Int(Int32.max) ? nil : Int32(self.durationValue)
            
            let commissionTitle: String = "\(programPermille / 10)%"
            let durationTitle: String
            if let durationMonths = programDuration {
                durationTitle = timeIntervalString(strings: environment.strings, value: durationMonths * (24 * 60 * 60))
            } else {
                durationTitle = "Lifetime"
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            self.environment?.controller()?.present(tableAlert(
                theme: presentationData.theme,
                title: "Warning",
                text: "Once you start the affiliate program, you won't be able to decrease its commission or duration. You can only increase these parameters or end the program, whuch will disable all previously distributed referral links.",
                table: TableComponent(theme: environment.theme, items: [
                    TableComponent.Item(id: 0, title: "Commission", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: commissionTitle, font: Font.regular(17.0), textColor: environment.theme.actionSheet.primaryTextColor))
                    ))),
                    TableComponent.Item(id: 1, title: "Duration", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: durationTitle, font: Font.regular(17.0), textColor: environment.theme.actionSheet.primaryTextColor))
                    )))
                ]),
                actions: [
                    ComponentAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                    ComponentAlertAction(type: .defaultAction, title: "Start", action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.applyProgram()
                    })
                ]
            ), in: .window(.root))
        }
        
        private func requestApplyEndProgram() {
            guard let component = self.component else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            self.environment?.controller()?.present(standardTextAlertController(
                theme: AlertControllerTheme(presentationData: presentationData),
                title: "Warning",
                text:
"""
If you end your affiliate program:

• Any referral links already shared will be disabled in 24 hours.

• All participating affiliates will be notified.

• You will be able to start a new affiliate program only in 24 hours.
""",
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultDestructiveAction, title: "End Anyway", action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.applyEndProgram()
                    })
                ],
                actionLayout: .horizontal
            ), in: .window(.root))
        }
        
        private func applyProgram() {
            if self.isApplying {
                return
            }
            guard let component = self.component else {
                return
            }
            let programPermille: Int32 = Int32(self.commissionPermille)
            let programDuration: Int32? = self.durationValue == Int(Int32.max) ? nil : Int32(self.durationValue)
            
            if let currentRefProgram = self.currentProgram {
                if currentRefProgram.commissionPermille == programPermille && currentRefProgram.durationMonths == programDuration {
                    self.environment?.controller()?.dismiss()
                    return
                }
            }
            
            self.isApplying = true
            self.applyDisposable = (component.context.engine.peers.updateStarRefProgram(
                id: component.initialContent.peerId,
                program: (commissionPermille: programPermille, durationMonths: programDuration)
            )
            |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                guard let self else {
                    return
                }
                self.isApplying = false
                self.environment?.controller()?.dismiss()
            })
            
            self.state?.updated(transition: .immediate)
        }
        
        private func applyEndProgram() {
            if self.isApplying {
                return
            }
            guard let component = self.component else {
                return
            }
            if self.currentProgram == nil {
                self.environment?.controller()?.dismiss()
                return
            }
            
            self.isApplying = true
            self.applyDisposable = (component.context.engine.peers.updateStarRefProgram(
                id: component.initialContent.peerId,
                program: nil
            )
            |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                guard let self, let component = self.component, let controller = self.environment?.controller() else {
                    return
                }
                self.isApplying = false
                
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                
                if let navigationController = controller.navigationController, let index = navigationController.viewControllers.firstIndex(where: { $0 === controller }), index != 0 {
                    if let previousController = navigationController.viewControllers[index - 1] as? ViewController {
                        previousController.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_link_broken", scale: 0.065, colors: [:], title: "Affiliate Program Ended", text: "Participating affiliates have been notified. All referral links will be disabled in 24 hours.", customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    }
                }
                controller.dismiss()
            })
            
            self.state?.updated(transition: .immediate)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment else {
                return
            }
            
            let titleCenterY: CGFloat = environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) * 0.5
            
            let titleTransformDistance: CGFloat = 20.0
            let titleY: CGFloat = max(titleCenterY, self.titleTransformContainer.center.y - self.scrollView.contentOffset.y)
            
            transition.setSublayerTransform(view: self.titleTransformContainer, transform: CATransform3DMakeTranslation(0.0, titleY - self.titleTransformContainer.center.y, 0.0))
            
            let titleYDistance: CGFloat = titleY - titleCenterY
            let titleTransformFraction: CGFloat = 1.0 - max(0.0, min(1.0, titleYDistance / titleTransformDistance))
            let titleMinScale: CGFloat = 17.0 / 30.0
            let titleScale: CGFloat = 1.0 * (1.0 - titleTransformFraction) + titleMinScale * titleTransformFraction
            if let titleView = self.title.view {
                transition.setScale(view: titleView, scale: titleScale)
            }
            
            let navigationAlpha: CGFloat = titleTransformFraction
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
            
            let bottomPanelAlphaDistance: CGFloat = 20.0
            let bottomPanelDistance: CGFloat = self.scrollView.contentSize.height - self.scrollView.bounds.maxY
            let bottomPanelAlphaFraction: CGFloat = max(0.0, min(1.0, bottomPanelDistance / bottomPanelAlphaDistance))
            
            let bottomPanelAlpha: CGFloat = bottomPanelAlphaFraction
            if let bottomPanelBackgroundView = self.bottomPanelBackground.view, bottomPanelBackgroundView.alpha != bottomPanelAlpha{
                let alphaTransition = transition
                alphaTransition.setAlpha(view: bottomPanelBackgroundView, alpha: bottomPanelAlpha)
                alphaTransition.setAlpha(layer: self.bottomPanelSeparator, alpha: bottomPanelAlpha)
            }
        }
        
        private func openConnectedBot(bot: TelegramConnectedStarRefBotList.Item) {
            guard let component = self.component else {
                return
            }
            
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.initialContent.peerId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] targetPeer in
                guard let self, let component = self.component else {
                    return
                }
                guard let targetPeer else {
                    return
                }
                
                self.environment?.controller()?.push(JoinAffiliateProgramScreen(
                    context: component.context,
                    sourcePeer: bot.peer,
                    commissionPermille: bot.commissionPermille,
                    programDuration: bot.durationMonths,
                    revenuePerUser: bot.participants == 0 ? 0.0 : Double(bot.revenue) / Double(bot.participants),
                    mode: .active(JoinAffiliateProgramScreenMode.Active(
                        targetPeer: targetPeer,
                        bot: bot,
                        copyLink: { [weak self] bot in
                            guard let self, let component = self.component else {
                                return
                            }
                            UIPasteboard.general.string = bot.url
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                            self.environment?.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: "Link copied to clipboard", text: "Share this link and earn **\(bot.commissionPermille / 10)%** of what people who use it spend in **\(bot.peer.compactDisplayTitle)**!"), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }
                    ))
                ))
            })
        }
        
        private func leaveProgram(bot: TelegramConnectedStarRefBotList.Item) {
            guard let component = self.component else {
                return
            }
            
            let _ = (component.context.engine.peers.removeConnectedStarRefBot(id: component.initialContent.peerId, link: bot.url)
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                guard let self else {
                    return
                }
                if let connectedStarBotList = self.connectedStarBotList {
                    var updatedItems = connectedStarBotList.items
                    if let index = updatedItems.firstIndex(where: { $0.peer.id == bot.peer.id }) {
                        updatedItems.remove(at: index)
                    }
                    self.connectedStarBotList = TelegramConnectedStarRefBotList(
                        items: updatedItems,
                        totalCount: connectedStarBotList.totalCount + 1
                    )
                    self.state?.updated(transition: .immediate)
                }
            })
        }
        
        private func openSortModeMenu(sourceView: UIView) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            
            var items: [ContextMenuItem] = []
            
            let availableModes: [(TelegramSuggestedStarRefBotList.SortMode, String)] = [
                (.profitability, "Profitability"),
                (.revenue, "Revenue"),
                (.date, "Date")
            ]
            for (mode, title) in availableModes {
                let isSelected = mode == self.suggestedSortMode
                items.append(.action(ContextMenuActionItem(text: title, icon: { theme in
                    if isSelected {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                    } else {
                        return nil
                    }
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    guard let self else {
                        return
                    }
                    if self.suggestedSortMode != mode {
                        self.suggestedSortMode = mode
                        self.isSuggestedSortModeUpdating = true
                        self.state?.updated(transition: .immediate)
                        
                        self.suggestedStarBotListDisposable?.dispose()
                        self.suggestedStarBotListDisposable = (component.context.engine.peers.requestSuggestedStarRefBots(
                            id: component.initialContent.peerId,
                            sortMode: self.suggestedSortMode,
                            offset: nil,
                            limit: 100)
                        |> deliverOnMainQueue).startStrict(next: { [weak self] list in
                            guard let self else {
                                return
                            }
                            self.suggestedStarBotList = list
                            self.isSuggestedSortModeUpdating = false
                            self.state?.updated(transition: .immediate)
                        })
                    }
                })))
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, actionsOnTop: false)), items: .single(ContextController.Items(id: AnyHashable(0), content: .list(items))), gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
        
        private func openExistingAffiliatePrograms() {
            guard let component = self.component else {
                return
            }
            let _ = (component.context.sharedContext.makeAffiliateProgramSetupScreenInitialData(context: component.context, peerId: component.initialContent.peerId, mode: .connectedPrograms)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] initialData in
                guard let self, let component = self.component else {
                    return
                }
                let setupScreen = component.context.sharedContext.makeAffiliateProgramSetupScreen(context: component.context, initialData: initialData)
                self.environment?.controller()?.push(setupScreen)
            })
        }
        
        func update(component: AffiliateProgramSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let durationItems: [(months: Int32, title: String, selectedTitle: String)] = [
                (1, "1m", "1 MONTH"),
                (3, "3m", "3 MONTHS"),
                (6, "6m", "6 MONTHS"),
                (12, "1y", "1 YEAR"),
                (2 * 12, "2y", "2 YEARS"),
                (3 * 12, "3y", "3 YEARS"),
                (Int32.max, "∞", "LIFETIME")
            ]
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
                self.bottomPanelSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            if self.component == nil {
                switch component.initialContent.mode {
                case let .editProgram(editProgram):
                    if let currentRefProgram = editProgram.currentRefProgram {
                        var ignoreCurrentProgram = false
                        if let endDate = currentRefProgram.endDate {
                            let timestamp = Int32(Date().timeIntervalSince1970)
                            let remainingTime: Int32 = max(0, endDate - timestamp)
                            if remainingTime <= 0 {
                                ignoreCurrentProgram = true
                            }
                        }
                        
                        if !ignoreCurrentProgram {
                            self.commissionPermille = Int(currentRefProgram.commissionPermille)
                            let commissionPercentValue = CGFloat(self.commissionPermille) / 1000.0
                            self.commissionSliderValue = (commissionPercentValue - 0.01) / (0.9 - 0.01)
                            
                            self.durationValue = Int(currentRefProgram.durationMonths ?? Int32.max)
                            
                            self.commissionMinPermille = Int(currentRefProgram.commissionPermille)
                            self.durationMinValue = Int(currentRefProgram.durationMonths ?? Int32.max)
                            
                            self.currentProgram = currentRefProgram
                            
                            if let endDate = currentRefProgram.endDate {
                                self.programEndTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    
                                    let timestamp = Int32(Date().timeIntervalSince1970)
                                    let remainingTime: Int32 = max(0, endDate - timestamp)
                                    if remainingTime <= 0 {
                                        self.currentProgram = nil
                                        self.programEndTimer?.invalidate()
                                        self.programEndTimer = nil
                                        
                                        self.commissionSliderValue = 0.0
                                        self.commissionPermille = 10
                                        self.commissionMinPermille = 10
                                        
                                        self.durationValue = 0
                                        self.durationMinValue = 0
                                    }
                                    
                                    self.state?.updated(transition: .immediate)
                                })
                            }
                        } else {
                            self.commissionPermille = 10
                            self.commissionSliderValue = 0.0
                            self.commissionMinPermille = 10
                            self.durationValue = 10
                        }
                    } else {
                        self.commissionPermille = 10
                        self.commissionSliderValue = 0.0
                        self.commissionMinPermille = 10
                        self.durationValue = 10
                    }
                case .connectedPrograms:
                    self.connectedStarBotListDisposable = (component.context.engine.peers.requestConnectedStarRefBots(
                        id: component.initialContent.peerId,
                        offset: nil,
                        limit: 100)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] list in
                        guard let self else {
                            return
                        }
                        self.connectedStarBotList = list
                        self.state?.updated(transition: .immediate)
                    })
                    
                    self.suggestedStarBotListDisposable = (component.context.engine.peers.requestSuggestedStarRefBots(
                        id: component.initialContent.peerId,
                        sortMode: self.suggestedSortMode,
                        offset: nil,
                        limit: 100)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] list in
                        guard let self else {
                            return
                        }
                        self.suggestedStarBotList = list
                        self.state?.updated(transition: .immediate)
                    })
                }
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = environment.navigationHeight + 90.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 16.0
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += topInset
            
            let coinIconSize = self.coinIcon.update(
                transition: transition,
                component: AnyComponent(PremiumCoinComponent(
                    mode: .affiliate,
                    isIntro: true,
                    isVisible: true,
                    hasIdleAnimations: true
                )),
                environment: {},
                containerSize: CGSize(width: min(414.0, availableSize.width), height: 184.0)
            )
            let coinIconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - coinIconSize.width) * 0.5), y: contentHeight - coinIconSize.height + 30.0), size: coinIconSize)
            if let coinIconView = self.coinIcon.view {
                if coinIconView.superview == nil {
                    self.scrollView.addSubview(coinIconView)
                }
                transition.setFrame(view: coinIconView, frame: coinIconFrame)
            }
            
            let titleValue: String
            let subtitleValue: String
            switch component.initialContent.mode {
            case .editProgram:
                titleValue = "Affiliate Program"
                subtitleValue = "Reward those who help grow your userbase."
            case .connectedPrograms:
                titleValue = "Affiliate Programs"
                subtitleValue = "Earn a commission each time a user who first accessed a mini app through your referral link spends **Stars** within it."
            }
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleValue, font: Font.bold(30.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - textSideInset * 2.0, height: 1000.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if self.titleTransformContainer.superview == nil {
                    if let controller = environment.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.superview?.insertSubview(self.titleTransformContainer, aboveSubview: navigationBar.view)
                    } else {
                        self.addSubview(self.titleTransformContainer)
                    }
                }
                if titleView.superview == nil {
                    self.titleTransformContainer.addSubview(titleView)
                }
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setPosition(view: self.titleTransformContainer, position: titleFrame.center)
            }
            contentHeight += titleSize.height
            contentHeight += 10.0
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .markdown(text: subtitleValue, attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                        linkAttribute: { url in
                            return ("URL", url)
                        }
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - textSideInset * 2.0, height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.scrollView.addSubview(subtitleView)
                    subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
                    transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                }
            }
            contentHeight += subtitleSize.height
            contentHeight += 24.0
            
            let introItems: [(icon: String, title: String, text: String)]
            switch component.initialContent.mode {
            case .editProgram:
                introItems = [
                    (
                        "Chat/Context Menu/Smile",
                        "Share revenue with affiliates",
                        "Set the commission for revenue generated by users referred to you."
                    ),
                    (
                        "Chat/Context Menu/Channels",
                        "Launch your affiliate program",
                        "Telegram will feature your program for millions of potential affiliates."
                    ),
                    (
                        "Chat/Context Menu/Link",
                        "Let affiliates promote you",
                        "Affiliates will share your referral link with their audience."
                    )
                ]
            case .connectedPrograms:
                introItems = [
                    (
                        "Peer Info/RefProgram/IntroListSecure",
                        "Reliable",
                        "Receive guaranteed commissions for spending by users you refer."
                    ),
                    (
                        "Peer Info/RefProgram/IntroListEye",
                        "Transparent",
                        "Track your commissions from referred users in real time."
                    ),
                    (
                        "Peer Info/RefProgram/IntroListLike",
                        "Simple",
                        "Choose a mini app below, get your referral link, and start earning Stars."
                    )
                ]
            }
            var introItemsHeight: CGFloat = 17.0
            let introItemIconX: CGFloat = sideInset + 19.0
            let introItemTextX: CGFloat = sideInset + 56.0
            let introItemTextRightInset: CGFloat = sideInset + 10.0
            let introItemSpacing: CGFloat = 22.0
            for i in 0 ..< introItems.count {
                if i != 0 {
                    introItemsHeight += introItemSpacing
                }
                
                let item = introItems[i]
                
                let itemIcon: ComponentView<Empty>
                let itemTitle: ComponentView<Empty>
                let itemText: ComponentView<Empty>
                
                if let current = self.introIconItems[i] {
                    itemIcon = current
                } else {
                    itemIcon = ComponentView()
                    self.introIconItems[i] = itemIcon
                }
                
                if let current = self.introTitleItems[i] {
                    itemTitle = current
                } else {
                    itemTitle = ComponentView()
                    self.introTitleItems[i] = itemTitle
                }
                
                if let current = self.introTextItems[i] {
                    itemText = current
                } else {
                    itemText = ComponentView()
                    self.introTextItems[i] = itemText
                }
                
                let iconSize = itemIcon.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(
                        name: item.icon,
                        tintColor: environment.theme.list.itemAccentColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let titleSize = itemTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.title, font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - introItemTextRightInset - introItemTextX, height: 1000.0)
                )
                let textSize = itemText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.text, font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - introItemTextRightInset - introItemTextX, height: 1000.0)
                )
                
                let itemIconFrame = CGRect(origin: CGPoint(x: introItemIconX, y: contentHeight + introItemsHeight + 3.0), size: iconSize)
                let itemTitleFrame = CGRect(origin: CGPoint(x: introItemTextX, y: contentHeight + introItemsHeight), size: titleSize)
                let itemTextFrame = CGRect(origin: CGPoint(x: introItemTextX, y: itemTitleFrame.maxY + 5.0), size: textSize)
                
                if let itemIconView = itemIcon.view {
                    if itemIconView.superview == nil {
                        self.scrollView.addSubview(itemIconView)
                    }
                    transition.setFrame(view: itemIconView, frame: itemIconFrame)
                }
                if let itemTitleView = itemTitle.view {
                    if itemTitleView.superview == nil {
                        itemTitleView.layer.anchorPoint = CGPoint()
                        self.scrollView.addSubview(itemTitleView)
                    }
                    transition.setPosition(view: itemTitleView, position: itemTitleFrame.origin)
                    itemTitleView.bounds = CGRect(origin: CGPoint(), size: itemTitleFrame.size)
                }
                if let itemTextView = itemText.view {
                    if itemTextView.superview == nil {
                        itemTextView.layer.anchorPoint = CGPoint()
                        self.scrollView.addSubview(itemTextView)
                    }
                    transition.setPosition(view: itemTextView, position: itemTextFrame.origin)
                    itemTextView.bounds = CGRect(origin: CGPoint(), size: itemTextFrame.size)
                }
                introItemsHeight = itemTextFrame.maxY - contentHeight
            }
            introItemsHeight += 19.0
            
            let introBackgroundFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: introItemsHeight))
            let _ = self.introBackground.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: environment.theme.list.itemBlocksBackgroundColor,
                    cornerRadius: .value(5.0),
                    smoothCorners: true
                )),
                environment: {},
                containerSize: introBackgroundFrame.size
            )
            if let introBackgroundView = self.introBackground.view {
                if introBackgroundView.superview == nil, let firstIconItemView = self.introIconItems[0]?.view {
                    self.scrollView.insertSubview(introBackgroundView, belowSubview: firstIconItemView)
                }
                transition.setFrame(view: introBackgroundView, frame: introBackgroundFrame)
            }
            contentHeight += introItemsHeight
            contentHeight += sectionSpacing + 6.0
            
            switch component.initialContent.mode {
            case .editProgram:
                let commissionMinPercentValue = CGFloat(self.commissionMinPermille) / 1000.0
                let commissionMinSliderValue = (commissionMinPercentValue - 0.01) / (0.9 - 0.01)
                
                let commissionSectionSize = self.commissionSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "COMMISSION",
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Define the percentage of star revenue your affiliates earn for referring users to your bot.",
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemSliderSelectorComponent(
                                theme: environment.theme,
                                content: .continuous(ListItemSliderSelectorComponent.Continuous(
                                    value: max(commissionMinSliderValue, self.commissionSliderValue),
                                    minValue: commissionMinSliderValue,
                                    lowerBoundTitle: "1%",
                                    upperBoundTitle: "90%",
                                    title: "\(self.commissionPermille / 10)%",
                                    valueUpdated: { [weak self] value in
                                        guard let self else {
                                            return
                                        }
                                        self.commissionSliderValue = value
                                        
                                        let commissionPercentValue = value * 0.89 + 0.01
                                        self.commissionPermille = max(self.commissionMinPermille, Int(commissionPercentValue * 1000.0))
                                        
                                        self.state?.updated(transition: .immediate)
                                    }
                                ))
                            )))
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let commissionSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: commissionSectionSize)
                if let commissionSectionView = self.commissionSection.view {
                    if commissionSectionView.superview == nil {
                        self.scrollView.addSubview(commissionSectionView)
                    }
                    commissionSectionView.isUserInteractionEnabled = self.currentProgram?.endDate == nil
                    transition.setFrame(view: commissionSectionView, frame: commissionSectionFrame)
                }
                contentHeight += commissionSectionSize.height
                contentHeight += sectionSpacing + 12.0
                
                var selectedDurationIndex = 0
                var durationMinValueIndex = 0
                for i in 0 ..< durationItems.count {
                    if self.durationValue == Int(durationItems[i].months) {
                        selectedDurationIndex = i
                    }
                    if self.durationMinValue == Int(durationItems[i].months) {
                        durationMinValueIndex = i
                    }
                }
                let durationSectionSize = self.durationSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: "DURATION",
                                    font: Font.regular(13.0),
                                    textColor: environment.theme.list.freeTextColor
                                )),
                                maximumNumberOfLines: 0
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: durationItems[selectedDurationIndex].selectedTitle,
                                    font: Font.regular(13.0),
                                    textColor: environment.theme.list.freeTextColor
                                )),
                                maximumNumberOfLines: 0
                            )))
                        ], spacing: 4.0, alignment: .alternatingLeftRight)),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Set the duration for which affiliates will earn commissions from referred users.",
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemSliderSelectorComponent(
                                theme: environment.theme,
                                content: .discrete(ListItemSliderSelectorComponent.Discrete(
                                    values: durationItems.map(\.title),
                                    markPositions: true,
                                    selectedIndex: max(durationMinValueIndex, selectedDurationIndex),
                                    minSelectedIndex: durationMinValueIndex,
                                    title: nil,
                                    selectedIndexUpdated: { [weak self] value in
                                        guard let self else {
                                            return
                                        }
                                        self.durationValue = Int(durationItems[value].months)
                                        self.state?.updated(transition: .immediate)
                                    }
                                ))
                            )))
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let durationSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: durationSectionSize)
                if let durationSectionView = self.durationSection.view {
                    if durationSectionView.superview == nil {
                        self.scrollView.addSubview(durationSectionView)
                    }
                    durationSectionView.isUserInteractionEnabled = self.currentProgram?.endDate == nil
                    transition.setFrame(view: durationSectionView, frame: durationSectionFrame)
                }
                contentHeight += durationSectionSize.height
                contentHeight += sectionSpacing + 12.0
                
                let existingProgramsSectionSize = self.existingProgramsSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Explore what other mini apps offer.",
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: "View Existing Programs",
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: environment.theme.list.itemPrimaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))),
                                ], alignment: .left, spacing: 2.0)),
                                accessory: .arrow,
                                action: { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    self.openExistingAffiliatePrograms()
                                }
                            )))
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let existingProgramsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: existingProgramsSectionSize)
                if let existingProgramsSectionView = self.existingProgramsSection.view {
                    if existingProgramsSectionView.superview == nil {
                        self.scrollView.addSubview(existingProgramsSectionView)
                    }
                    transition.setFrame(view: existingProgramsSectionView, frame: existingProgramsSectionFrame)
                }
                contentHeight += existingProgramsSectionSize.height
                contentHeight += sectionSpacing + 12.0
                
                let endProgramSectionSize = self.endProgramSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(VStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: "End Affiliate Program",
                                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                            textColor: environment.theme.list.itemDestructiveColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))),
                                ], alignment: .center, spacing: 2.0)),
                                accessory: nil,
                                action: { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    
                                    self.requestApplyEndProgram()
                                }
                            )))
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let endProgramSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: endProgramSectionSize)
                if let endProgramSectionView = self.endProgramSection.view {
                    if endProgramSectionView.superview == nil {
                        self.scrollView.addSubview(endProgramSectionView)
                    }
                    transition.setFrame(view: endProgramSectionView, frame: endProgramSectionFrame)
                    transition.setAlpha(view: endProgramSectionView, alpha: (self.currentProgram != nil && self.currentProgram?.endDate == nil) ? 1.0 : 0.0)
                }
                if (self.currentProgram != nil && self.currentProgram?.endDate == nil) {
                    contentHeight += endProgramSectionSize.height
                    contentHeight += sectionSpacing
                }
                
                contentHeight += bottomInset
                
                let bottomPanelTextSize = self.bottomPanelText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(
                            text: "By creating an affiliate program, you afree to the [terms and conditions](https://telegram.org/terms) of Affiliate Programs.",
                            attributes: MarkdownAttributes(
                                body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                                bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                                link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                                linkAttribute: { url in
                                    return ("URL", url)
                                }
                            )
                        ),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                
                let bottomPanelButtonInsets = UIEdgeInsets(top: 10.0, left: sideInset, bottom: 10.0, right: sideInset)
                
                let buttonText: String
                if let endDate = self.currentProgram?.endDate {
                    let timestamp = Int32(Date().timeIntervalSince1970)
                    let remainingTime: Int32 = max(0, endDate - timestamp)
                    buttonText = textForTimeout(value: remainingTime)
                } else if self.currentProgram != nil {
                    buttonText = "Update Affiliate Program"
                } else {
                    buttonText = "Start Affiliate Program"
                }
                let bottomPanelButtonSize = self.bottomPanelButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            color: environment.theme.list.itemCheckColors.fillColor,
                            foreground: environment.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                        ),
                        content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(Text(text: buttonText, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor))),
                        isEnabled: self.currentProgram?.endDate == nil,
                        allowActionWhenDisabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.requestApplyProgram()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - bottomPanelButtonInsets.left - bottomPanelButtonInsets.right, height: 50.0)
                )
                
                let bottomPanelHeight: CGFloat = bottomPanelButtonInsets.top + bottomPanelButtonSize.height + bottomPanelButtonInsets.bottom + bottomPanelTextSize.height + 8.0 + environment.safeInsets.bottom
                let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight), size: CGSize(width: availableSize.width, height: bottomPanelHeight))
                
                let _ = self.bottomPanelBackground.update(
                    transition: transition,
                    component: AnyComponent(BlurredBackgroundComponent(
                        color: environment.theme.rootController.navigationBar.blurredBackgroundColor
                    )),
                    environment: {},
                    containerSize: bottomPanelFrame.size
                )
                
                if let bottomPanelBackgroundView = self.bottomPanelBackground.view {
                    if bottomPanelBackgroundView.superview == nil {
                        self.addSubview(bottomPanelBackgroundView)
                    }
                    transition.setFrame(view: bottomPanelBackgroundView, frame: bottomPanelFrame)
                }
                transition.setFrame(layer: self.bottomPanelSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomPanelFrame.minY - UIScreenPixel), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
                
                let bottomPanelButtonFrame = CGRect(origin: CGPoint(x: bottomPanelFrame.minX + bottomPanelButtonInsets.left, y: bottomPanelFrame.minY + bottomPanelButtonInsets.top), size: bottomPanelButtonSize)
                if let bottomPanelButtonView = self.bottomPanelButton.view {
                    if bottomPanelButtonView.superview == nil {
                        self.addSubview(bottomPanelButtonView)
                    }
                    transition.setFrame(view: bottomPanelButtonView, frame: bottomPanelButtonFrame)
                }
                
                let bottomPanelTextFrame = CGRect(origin: CGPoint(x: bottomPanelFrame.minX + floor((bottomPanelFrame.width - bottomPanelTextSize.width) * 0.5), y: bottomPanelButtonFrame.maxY + bottomPanelButtonInsets.bottom), size: bottomPanelTextSize)
                if let bottomPanelTextView = self.bottomPanelText.view {
                    if bottomPanelTextView.superview == nil {
                        self.addSubview(bottomPanelTextView)
                    }
                    transition.setPosition(view: bottomPanelTextView, position: bottomPanelTextFrame.center)
                    bottomPanelTextView.bounds = CGRect(origin: CGPoint(), size: bottomPanelTextFrame.size)
                }
                
                contentHeight += bottomPanelFrame.height
            case .connectedPrograms:
                if let connectedStarBotList = self.connectedStarBotList, let suggestedStarBotList = self.suggestedStarBotList {
                    let suggestedStarBotListItems = suggestedStarBotList.items.filter({ item in !connectedStarBotList.items.contains(where: { $0.peer.id == item.peer.id }) })
                    
                    do {
                        var activeSectionItems: [AnyComponentWithIdentity<Empty>] = []
                        for item in connectedStarBotList.items {
                            let durationTitle: String
                            if let durationMonths = item.durationMonths {
                                durationTitle = timeIntervalString(strings: environment.strings, value: durationMonths * (24 * 60 * 60))
                            } else {
                                durationTitle = "Lifetime"
                            }
                            let commissionTitle = "\(item.commissionPermille / 10)%"
                            
                            let itemContextAction: (EnginePeer, ContextExtractedContentContainingView, ContextGesture?) -> Void = { [weak self] peer, sourceView, gesture in
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                                
                                var itemList: [ContextMenuItem] = []
                                
                                let openTitle: String
                                if case let .user(user) = item.peer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                                    openTitle = "Open App"
                                } else {
                                    openTitle = "Open Bot"
                                }
                                itemList.append(.action(ContextMenuActionItem(text: openTitle, textColor: .primary, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
                                }, action: { [weak self] c, _ in
                                    c?.dismiss(completion: {
                                        guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                                            return
                                        }
                                        
                                        if case let .user(user) = item.peer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                                            component.context.sharedContext.openWebApp(
                                                context: component.context,
                                                parentController: controller,
                                                updatedPresentationData: nil,
                                                botPeer: .user(user),
                                                chatPeer: nil,
                                                threadId: nil,
                                                buttonText: "",
                                                url: "",
                                                simple: true,
                                                source: .generic,
                                                skipTermsOfService: true,
                                                payload: nil
                                            )
                                        } else if let navigationController = controller.navigationController as? NavigationController {
                                            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(item.peer), subject: nil, keepStack: .always, animated: true, pushController: { [weak navigationController] chatController, animated, completion in
                                                guard let navigationController else {
                                                    return
                                                }
                                                navigationController.pushViewController(chatController)
                                            }))
                                        }
                                    })
                                })))
                                
                                itemList.append(.action(ContextMenuActionItem(text: "Copy Link", textColor: .primary, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                                }, action: { [weak self] _, f in
                                    f(.default)
                                    
                                    guard let self, let component = self.component, let environment = self.environment else {
                                        return
                                    }
                                    
                                    let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                                    
                                    UIPasteboard.general.string = item.url
                                    environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: "Link copied to clipboard", text: "Share this link and earn **\(item.commissionPermille / 10)%** of what people who use it spend in **\(item.peer.compactDisplayTitle)**!"), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                })))
                                
                                itemList.append(.action(ContextMenuActionItem(text: "Leave", textColor: .destructive, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                                }, action: { [weak self] c, _ in
                                    c?.dismiss(completion: {
                                        guard let self else {
                                            return
                                        }
                                        self.leaveProgram(bot: item)
                                    })
                                })))
                                
                                let items = ContextController.Items(content: .list(itemList))
                                
                                let controller = ContextController(
                                    presentationData: presentationData,
                                    source: .extracted(ListContextExtractedContentSource(contentView: sourceView)),
                                    items: .single(items),
                                    recognizer: nil,
                                    gesture: gesture
                                )
                                environment.controller()?.presentInGlobalOverlay(controller, with: nil)
                            }
                            
                            activeSectionItems.append(AnyComponentWithIdentity(id: item.peer.id, component: AnyComponent(PeerListItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                style: .generic,
                                sideInset: 0.0,
                                title: item.peer.compactDisplayTitle,
                                avatarComponent: AnyComponent(PeerBadgeAvatarComponent(
                                    context: component.context,
                                    peer: item.peer,
                                    theme: environment.theme,
                                    hasBadge: true
                                )),
                                peer: item.peer,
                                subtitle: nil,
                                subtitleComponent: AnyComponent(AffiliatePeerSubtitleComponent(
                                    theme: environment.theme,
                                    percentText: commissionTitle,
                                    text: durationTitle
                                )),
                                subtitleAccessory: .none,
                                presence: nil,
                                rightAccessory: .disclosure,
                                selectionState: .none,
                                hasNext: false,
                                extractedTheme: PeerListItemComponent.ExtractedTheme(
                                    inset: 2.0,
                                    background: environment.theme.list.itemBlocksBackgroundColor
                                ),
                                insets: UIEdgeInsets(top: -1.0, left: 0.0, bottom: -1.0, right: 0.0),
                                action: { [weak self] peer, _, itemView in
                                    guard let self else {
                                        return
                                    }
                                    self.openConnectedBot(bot: item)
                                },
                                inlineActions: PeerListItemComponent.InlineActionsState(actions: [
                                    PeerListItemComponent.InlineAction(id: 0, title: "Leave", color: .destructive, action: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        self.leaveProgram(bot: item)
                                    })
                                ]),
                                contextAction: { peer, sourceView, gesture in
                                    itemContextAction(peer, sourceView, gesture)
                                }
                            ))))
                        }
                        
                        let activeProgramsSectionSize = self.activeProgramsSection.update(
                            transition: transition,
                            component: AnyComponent(ListSectionComponent(
                                theme: environment.theme,
                                header: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: "MY PROGRAMS",
                                        font: Font.regular(13.0),
                                        textColor: environment.theme.list.freeTextColor
                                    )),
                                    maximumNumberOfLines: 0
                                )),
                                footer: nil,
                                items: activeSectionItems,
                                displaySeparators: true
                            )),
                            environment: {},
                            containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                        )
                        let activeProgramsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: activeProgramsSectionSize)
                        if let activeProgramsSectionView = self.activeProgramsSection.view {
                            if activeProgramsSectionView.superview == nil {
                                self.scrollView.addSubview(activeProgramsSectionView)
                            }
                            transition.setFrame(view: activeProgramsSectionView, frame: activeProgramsSectionFrame)
                            if let connectedStarBotList = self.connectedStarBotList, !connectedStarBotList.items.isEmpty {
                                activeProgramsSectionView.isHidden = false
                            } else {
                                activeProgramsSectionView.isHidden = true
                            }
                        }
                        if let connectedStarBotList = self.connectedStarBotList, !connectedStarBotList.items.isEmpty {
                            contentHeight += activeProgramsSectionSize.height
                            contentHeight += sectionSpacing
                        }
                    }
                    do {
                        var suggestedSectionItems: [AnyComponentWithIdentity<Empty>] = []
                        if suggestedStarBotListItems.isEmpty {
                            suggestedSectionItems.append(AnyComponentWithIdentity(id: "empty", component: AnyComponent(TransformContents(
                                content: AnyComponent(),
                                fixedSize: CGSize(width: 1.0, height: 100.0),
                                translation: CGPoint()
                            ))))
                        }
                        for item in suggestedStarBotListItems {
                            let commissionTitle = "\(item.program.commissionPermille / 10)%"
                            let durationTitle: String
                            if let durationMonths = item.program.durationMonths {
                                durationTitle = timeIntervalString(strings: environment.strings, value: durationMonths * (24 * 60 * 60))
                            } else {
                                durationTitle = "Lifetime"
                            }
                            
                            suggestedSectionItems.append(AnyComponentWithIdentity(id: item.peer.id, component: AnyComponent(PeerListItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                style: .generic,
                                sideInset: 0.0,
                                title: item.peer.compactDisplayTitle,
                                avatarComponent: AnyComponent(PeerBadgeAvatarComponent(
                                    context: component.context,
                                    peer: item.peer,
                                    theme: environment.theme,
                                    hasBadge: false
                                )),
                                peer: item.peer,
                                subtitle: nil,
                                subtitleComponent: AnyComponent(AffiliatePeerSubtitleComponent(
                                    theme: environment.theme,
                                    percentText: commissionTitle,
                                    text: durationTitle
                                )),
                                subtitleAccessory: .none,
                                presence: nil,
                                rightAccessory: .disclosure,
                                selectionState: .none,
                                hasNext: false,
                                extractedTheme: PeerListItemComponent.ExtractedTheme(
                                    inset: 2.0,
                                    background: environment.theme.list.itemBlocksBackgroundColor
                                ),
                                insets: UIEdgeInsets(top: -1.0, left: 0.0, bottom: -1.0, right: 0.0),
                                action: { [weak self] peer, _, itemView in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    
                                    let _ = (component.context.engine.data.get(
                                        TelegramEngine.EngineData.Item.Peer.Peer(id: item.peer.id),
                                        TelegramEngine.EngineData.Item.Peer.Peer(id: component.initialContent.peerId)
                                    )
                                    |> deliverOnMainQueue).startStandalone(next: { [weak self] botPeer, targetPeer in
                                        guard let self, let component = self.component else {
                                            return
                                        }
                                        guard let botPeer, let targetPeer else {
                                            return
                                        }
                                        self.environment?.controller()?.push(JoinAffiliateProgramScreen(
                                            context: component.context,
                                            sourcePeer: botPeer,
                                            commissionPermille: item.program.commissionPermille,
                                            programDuration: item.program.durationMonths,
                                            revenuePerUser: item.program.dailyRevenuePerUser?.totalValue ?? 0.0,
                                            mode: .join(JoinAffiliateProgramScreenMode.Join(
                                                initialTargetPeer: targetPeer,
                                                canSelectTargetPeer: false,
                                                completion: { [weak self] _ in
                                                    guard let self, let component = self.component else {
                                                        return
                                                    }
                                                    let _ = (component.context.engine.peers.connectStarRefBot(id: component.initialContent.peerId, botId: peer.id)
                                                    |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
                                                        guard let self else {
                                                            return
                                                        }
                                                        if let connectedStarBotList = self.connectedStarBotList {
                                                            var updatedItems = connectedStarBotList.items
                                                            if !updatedItems.contains(where: { $0.peer.id == peer.id }) {
                                                                updatedItems.insert(result, at: 0)
                                                            }
                                                            self.connectedStarBotList = TelegramConnectedStarRefBotList(
                                                                items: updatedItems,
                                                                totalCount: connectedStarBotList.totalCount + 1
                                                            )
                                                            self.state?.updated(transition: .immediate)
                                                            
                                                            self.openConnectedBot(bot: result)
                                                        }
                                                    })
                                                }
                                            ))
                                        ))
                                    })
                                },
                                inlineActions: nil,
                                contextAction: nil
                            ))))
                        }
                        
                        let suggestedProgramsSectionSize = self.suggestedProgramsSection.update(
                            transition: transition,
                            component: AnyComponent(ListSectionComponent(
                                theme: environment.theme,
                                header: AnyComponent(HStack([
                                    AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: "PROGRAMS",
                                            font: Font.regular(13.0),
                                            textColor: environment.theme.list.freeTextColor
                                        )),
                                        maximumNumberOfLines: 0
                                    ))),
                                    AnyComponentWithIdentity(id: 1, component: AnyComponent(BotSectionSortButtonComponent(
                                        theme: environment.theme,
                                        strings: environment.strings,
                                        sortMode: self.suggestedSortMode,
                                        action: { [weak self] sourceView in
                                            guard let self else {
                                                return
                                            }
                                            self.openSortModeMenu(sourceView: sourceView)
                                        }
                                    )))
                                ], spacing: 4.0, alignment: .alternatingLeftRight)),
                                footer: nil,
                                items: suggestedSectionItems,
                                displaySeparators: true
                            )),
                            environment: {},
                            containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                        )
                        let suggestedProgramsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: suggestedProgramsSectionSize)
                        if let suggestedProgramsSectionView = self.suggestedProgramsSection.view as? ListSectionComponent.View {
                            if suggestedProgramsSectionView.superview == nil {
                                suggestedProgramsSectionView.contentViewImpl.layer.allowsGroupOpacity = true
                                self.scrollView.addSubview(suggestedProgramsSectionView)
                            }
                            transition.setFrame(view: suggestedProgramsSectionView, frame: suggestedProgramsSectionFrame)
                            if !suggestedStarBotListItems.isEmpty {
                                suggestedProgramsSectionView.isHidden = false
                            } else {
                                suggestedProgramsSectionView.isHidden = true
                            }
                            
                            suggestedProgramsSectionView.contentViewImpl.alpha = self.isSuggestedSortModeUpdating ? 0.6 : 1.0
                            suggestedProgramsSectionView.contentViewImpl.isUserInteractionEnabled = !self.isSuggestedSortModeUpdating
                        }
                        if !suggestedStarBotListItems.isEmpty {
                            contentHeight += suggestedProgramsSectionSize.height
                            contentHeight += sectionSpacing
                        }
                    }
                }
            }
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
            }
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class AffiliateProgramSetupScreen: ViewControllerComponentContainer {
    enum Mode {
        final class EditProgram {
            let currentRefProgram: TelegramStarRefProgram?
            
            init(currentRefProgram: TelegramStarRefProgram?) {
                self.currentRefProgram = currentRefProgram
            }
        }
        
        final class ConnectedPrograms {
            init() {
            }
        }
        
        case editProgram(EditProgram)
        case connectedPrograms(ConnectedPrograms)
    }
    
    final class Content: AffiliateProgramSetupScreenInitialData {
        let peerId: EnginePeer.Id
        let mode: Mode

        init(
            peerId: EnginePeer.Id,
            mode: Mode
        ) {
            self.peerId = peerId
            self.mode = mode
        }
    }
    
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        initialContent: AffiliateProgramSetupScreenInitialData
    ) {
        self.context = context
        
        let initialContent = initialContent as! AffiliateProgramSetupScreen.Content
        
        super.init(context: context, component: AffiliateProgramSetupScreenComponent(
            context: context,
            initialContent: initialContent
        ), navigationBarAppearance: .default, theme: .default)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? AffiliateProgramSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? AffiliateProgramSetupScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public static func content(context: AccountContext, peerId: EnginePeer.Id, mode: AffiliateProgramSetupScreenMode) -> Signal<AffiliateProgramSetupScreenInitialData, NoError> {
        switch mode {
        case .editProgram:
            return context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.StarRefProgram(id: peerId)
            )
            |> map { starRefProgram in
                return Content(
                    peerId: peerId,
                    mode: .editProgram(Mode.EditProgram(
                        currentRefProgram: starRefProgram
                    ))
                )
            }
        case .connectedPrograms:
            return .single(Content(
                peerId: peerId,
                mode: .connectedPrograms(Mode.ConnectedPrograms(
                ))
            ))
        }
    }
}

private final class ListContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .right
        
    private let contentView: ContextExtractedContentContainingView
    
    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    private let actionsOnTop: Bool

    init(controller: ViewController, sourceView: UIView, actionsOnTop: Bool) {
        self.controller = controller
        self.sourceView = sourceView
        self.actionsOnTop = actionsOnTop
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: self.actionsOnTop ? .top : .bottom)
    }
}
