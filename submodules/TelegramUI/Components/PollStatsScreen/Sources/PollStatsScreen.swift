import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import ListSectionComponent
import ListItemComponentAdaptor
import StatisticsUI
import ItemListUI

private final class PollStatsSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let messageId: EngineMessage.Id
    let animateOut: ActionSlot<Action<Void>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        messageId: EngineMessage.Id,
        animateOut: ActionSlot<Action<Void>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.messageId = messageId
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: PollStatsSheetContent, rhs: PollStatsSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.messageId != rhs.messageId {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let pollStatsContext: PollStatsContext
        
        private let animateOut: ActionSlot<Action<Void>>
        private let getController: () -> ViewController?
        private let stateDisposable = MetaDisposable()
        
        var stats: PollStats?
        private var loadedVotesGraphToken: String?
        
        init(
            context: AccountContext,
            messageId: EngineMessage.Id,
            animateOut: ActionSlot<Action<Void>>,
            getController: @escaping () -> ViewController?
        ) {
            self.pollStatsContext = PollStatsContext(account: context.account, messageId: messageId)
            self.animateOut = animateOut
            self.getController = getController
            
            super.init()
            
            self.stateDisposable.set((self.pollStatsContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                self.stats = state.stats
                if let stats = state.stats, case let .OnDemand(token) = stats.votesGraph, !token.isEmpty, self.loadedVotesGraphToken != token {
                    self.loadedVotesGraphToken = token
                    self.pollStatsContext.loadVotesGraph()
                }
                self.updated(transition: .immediate)
            }))
        }
        
        deinit {
            self.stateDisposable.dispose()
        }
        
        func dismiss(animated: Bool) {
            guard let controller = self.getController() else {
                return
            }
            if animated {
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }
    }
    
    func makeState() -> State {
        return State(
            context: self.context,
            messageId: self.messageId,
            animateOut: self.animateOut,
            getController: self.getController
        )
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let title = Child(MultilineTextComponent.self)
        let section = Child(ListSectionComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let sideInset: CGFloat = 16.0
            let sectionWidth = context.availableSize.width - sideInset * 2.0
            let graph = state.stats?.votesGraph ?? .OnDemand(token: "")
            
            var contentSize = CGSize(width: context.availableSize.width, height: 16.0)
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { _ in
                        state.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton.position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: contentSize.height + closeButton.size.height / 2.0)))
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.PollStats_Title,
                        font: Font.semibold(17.0),
                        textColor: theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - 120.0, height: 44.0),
                transition: .immediate
            )
            context.add(title.position(CGPoint(x: context.availableSize.width / 2.0, y: 16.0 + 22.0)))
            contentSize.height += 44.0
            contentSize.height += 19.0
            
            let section = section.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.PollStats_GraphHeader.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                            itemGenerator: StatsGraphItem(
                                presentationData: ItemListPresentationData(presentationData),
                                systemStyle: .glass,
                                graph: graph,
                                type: .lines5Min,
                                getDetailsData: { date, completion in
                                    let _ = state.pollStatsContext.loadDetailedGraph(graph, x: Int64(date.timeIntervalSince1970) * 1000).start(next: { detailedGraph in
                                        if let detailedGraph, case let .Loaded(_, data) = detailedGraph {
                                            completion(data)
                                        } else {
                                            completion(nil)
                                        }
                                    })
                                },
                                sectionId: 0,
                                style: .blocks
                            ),
                            params: ListViewItemLayoutParams(
                                width: sectionWidth,
                                leftInset: 0.0,
                                rightInset: 0.0,
                                availableHeight: 10000.0,
                                isStandalone: true
                            )
                        ))),
                    ],
                    displaySeparators: false
                ),
                availableSize: CGSize(width: sectionWidth, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(section.position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + section.size.height / 2.0)))
            contentSize.height += section.size.height
            contentSize.height += 39.0
            
            return contentSize
        }
    }
}

private final class PollStatsSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let messageId: EngineMessage.Id
    
    init(
        context: AccountContext,
        messageId: EngineMessage.Id
    ) {
        self.context = context
        self.messageId = messageId
    }
    
    static func ==(lhs: PollStatsSheetComponent, rhs: PollStatsSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.messageId != rhs.messageId {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let dismiss: (Bool) -> Void = { animated in
                guard let controller = controller() else {
                    return
                }
                if animated {
                    animateOut.invoke(Action { [weak controller] _ in
                        controller?.dismiss(completion: nil)
                    })
                } else {
                    controller.dismiss(completion: nil)
                }
            }
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(PollStatsSheetContent(
                        context: context.component.context,
                        messageId: context.component.messageId,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {},
                    willDismiss: {}
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))
            
            return context.availableSize
        }
    }
}

public final class PollStatsScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        messageId: EngineMessage.Id
    ) {
        super.init(
            context: context,
            component: PollStatsSheetComponent(
                context: context,
                messageId: messageId
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
}
