import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore




public class NotificationExceptionsController: ViewController {
    private let account: Account
    
    private var controllerNode: NotificationExceptionsControllerNode {
        return self.displayNode as! NotificationExceptionsControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var editItem: UIBarButtonItem!
    private var doneItem: UIBarButtonItem!
    
    private let mode: NotificationExceptionMode
    private let updatedMode: (NotificationExceptionMode) -> Void
    public init(account: Account, mode: NotificationExceptionMode, updatedMode: @escaping(NotificationExceptionMode)->Void) {
        self.account = account
        self.mode = mode
        self.updatedMode = updatedMode
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        
        self.editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.editPressed))
        self.doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.Notifications_ExceptionsTitle
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
                    }
                }
            })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = self.presentationData.strings.Settings_AppLanguage
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
        
        
        let editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.editPressed))
        let doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        if self.navigationItem.rightBarButtonItem === self.editItem {
            self.navigationItem.rightBarButtonItem = editItem
        } else if self.navigationItem.rightBarButtonItem === self.doneItem {
            self.navigationItem.rightBarButtonItem = doneItem
        }
        self.editItem = editItem
        self.doneItem = doneItem
    }
    
    override public func loadDisplayNode() {
        self.displayNode = NotificationExceptionsControllerNode(account: self.account, presentationData: self.presentationData, navigationBar: self.navigationBar!, mode: self.mode, updatedMode: self.updatedMode, requestActivateSearch: { [weak self] in
            self?.activateSearch()
            }, requestDeactivateSearch: { [weak self] in
                self?.deactivateSearch()
            }, updateCanStartEditing: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                let item: UIBarButtonItem?
                if let value = value {
                    item = value ? strongSelf.editItem : strongSelf.doneItem
                } else {
                    item = nil
                }
                if strongSelf.navigationItem.rightBarButtonItem !== item {
                    strongSelf.navigationItem.setRightBarButton(item, animated: true)
                }
            }, present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            }, pushController: { [weak self] c in
                (self?.navigationController as? NavigationController)?.pushViewController(c)
            })
        self._ready.set(self.controllerNode._ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func editPressed() {
        self.controllerNode.toggleEditing()
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.controllerNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            self.controllerNode.deactivateSearch()
        }
    }
}



//
//
//public func notificationExceptionsController(account: Account, mode: NotificationExceptionMode, updatedMode:@escaping(NotificationExceptionMode) -> Void) -> ViewController {
//
//
//    var activateSearch:(()->Void)?
//
//
//
//
//    let controller = NotificationExceptionsController(account: account, state: signal, addAction: {
//        arguments.selectPeer()
//    })
//
////    let controller = ItemListController(account: account, state: signal |> afterDisposed {
////       actionsDisposable.dispose()
////    })
//
//
//    activateSearch = { [weak controller] in
////        updateState { state in
////            return state.withUpdatedSearchMode(true)
////        }
//        controller?.activateSearch()
//    }
//
//
//    presentControllerImpl = { [weak controller] c, a in
//        controller?.present(c, in: .window(.root), with: a)
//    }
//    return controller
//}

//
// private final class NotificationExceptionsController: ViewController {
//    private let account: Account
//
//    private var presentationData: PresentationData
//    private var presentationDataDisposable: Disposable?
//
//    var peerSelected: ((PeerId) -> Void)?
//
//    var inProgress: Bool = false {
//        didSet {
//            if self.inProgress != oldValue {
//                if self.isNodeLoaded {
//                    self.controllerNode.inProgress = self.inProgress
//                }
//
//                if self.inProgress {
//                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: self.presentationData.theme))
//                } else {
//                    self.navigationItem.rightBarButtonItem = nil
//                }
//            }
//        }
//    }
//
//    private var controllerNode: NotificationExceptionsControllerNode {
//        return super.displayNode as! NotificationExceptionsControllerNode
//    }
//
//
//    private let _ready = Promise<Bool>()
//    override public var ready: Promise<Bool> {
//        return self._ready
//    }
//    private let addAction:()->Void
//
//    private let state: Signal<(ItemListControllerState, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>
//
//    public init(account: Account, state: Signal<(ItemListControllerState, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>, addAction: @escaping()->Void) {
//        self.account = account
//        self.state = state
//        self.addAction = addAction
//        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
//
//        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
//        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
//
//        self.title = self.presentationData.strings.Notifications_ExceptionsTitle
//
//
//        self.scrollToTop = { [weak self] in
//            if let strongSelf = self {
//                strongSelf.controllerNode.scrollToTop()
//            }
//        }
//    }
//
//    required public init(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    deinit {
//    }
//
//    @objc private func addExceptionAction() {
//        self.addAction()
//    }
//
//    override public func loadDisplayNode() {
//        let image = PresentationResourcesRootController.navigationAddIcon(presentationData.theme)
//
//        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: UIBarButtonItem.Style.plain, target: self, action: #selector(addExceptionAction))
//
//        let nodeState = self.state |> deliverOnMainQueue |> map { ($0.theme, $1) }
//
//        self.displayNode = NotificationExceptionsControllerNode(account: self.account, navigationBar: self.navigationBar!, state: nodeState)
//        self.displayNode.backgroundColor = .white
//
//        self.controllerNode.navigationBar = self.navigationBar
//
//        self.controllerNode.requestDeactivateSearch = { [weak self] in
//            self?.deactivateSearch()
//        }
//
//        self.controllerNode.requestActivateSearch = { [weak self] in
//            self?.activateSearch()
//        }
//
//        self.displayNodeDidLoad()
//
//        self._ready.set(self.controllerNode.ready)
//    }
//
//    override public func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//    }
//
//    override public func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//
//        //  self.controllerNode.animateIn()
//    }
//
//    override public func viewDidDisappear(_ animated: Bool) {
//        super.viewDidDisappear(animated)
//    }
//
//    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
//        super.containerLayoutUpdated(layout, transition: transition)
//
//        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
//    }
//
//    @objc func cancelPressed() {
//        self.dismiss()
//    }
//
//    func activateSearch() {
//        if self.displayNavigationBar {
//            if let scrollToTop = self.scrollToTop {
//                scrollToTop()
//            }
//            self.controllerNode.activateSearch()
//            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
//        }
//    }
//
//    private func deactivateSearch() {
//        if !self.displayNavigationBar {
//            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
//            self.controllerNode.deactivateSearch()
//        }
//    }
//}
//
//
//
//private final class NotificationExceptionsControllerNode: ASDisplayNode {
//    private let account: Account
//
//    var inProgress: Bool = false {
//        didSet {
//
//        }
//    }
//
//    var navigationBar: NavigationBar?
//
//
//    private let contentNode: ItemListControllerNode<NotificationExceptionEntry>
//
//    private var contactListActive = false
//
//    private var searchDisplayController: SearchDisplayController?
//
//    private var containerLayout: (ContainerViewLayout, CGFloat)?
//
//    var requestActivateSearch: (() -> Void)?
//    var requestDeactivateSearch: (() -> Void)?
//
//    private var presentationData: PresentationData
//    private var presentationDataDisposable: Disposable?
//
//    private var readyValue = Promise<Bool>()
//    var ready: Signal<Bool, NoError> {
//        return self.readyValue.get()
//    }
//
//    private let state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>
//
//    init(account: Account, navigationBar: NavigationBar, state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>) {
//        self.account = account
//        self.state = state
//        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
//
//
//        self.contentNode = ItemListControllerNode(navigationBar: navigationBar, updateNavigationOffset: { _ in
//
//        }, state: state)
//
//        contentNode.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
//        contentNode.listNode.keepBottomItemOverscrollBackground = presentationData.theme.chatList.backgroundColor
//
//        super.init()
//
//        self.setViewBlock({
//            return UITracingLayerView()
//        })
//
//        self.addSubnode(self.contentNode)
//        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
//            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
//                if let strongSelf = self {
//                    let previousTheme = strongSelf.presentationData.theme
//                    let previousStrings = strongSelf.presentationData.strings
//                    strongSelf.presentationData = presentationData
//                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
//                        strongSelf.updateThemeAndStrings()
//                    }
//                }
//            })
//
//        self.readyValue.set(contentNode.ready)
//    }
//
//    deinit {
//        self.presentationDataDisposable?.dispose()
//    }
//
//    private func updateThemeAndStrings() {
//        self.searchDisplayController?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
//    }
//
//    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
//        self.containerLayout = (layout, navigationBarHeight)
//
//        let cleanInsets = layout.insets(options: [])
//
//
//        var controlSize = CGSize(width: 0, height:0)
//        controlSize.width = min(layout.size.width, max(200.0, controlSize.width))
//
//        var insets = layout.insets(options: [.input])
//        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
//        insets.bottom = max(insets.bottom, cleanInsets.bottom)
//        insets.left += layout.safeInsets.left
//        insets.right += layout.safeInsets.right
//
//        self.contentNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
//        self.contentNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
//
//        self.contentNode.containerLayoutUpdated(layout, navigationBarHeight: insets.top, transition: transition)
//
//        if let searchDisplayController = self.searchDisplayController {
//            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
//        }
//    }
//
//    func activateSearch() {
//        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
//            return
//        }
//
//        if self.contentNode.supernode != nil {
//            var maybePlaceholderNode: SearchBarPlaceholderNode?
//            self.contentNode.listNode.forEachItemNode { node in
//                if let node = node as? NotificationSearchItemNode {
//                    maybePlaceholderNode = node.searchBarNode
//                }
//            }
//
//            if let _ = self.searchDisplayController {
//                return
//            }
//
//            if let placeholderNode = maybePlaceholderNode {
//                self.searchDisplayController = SearchDisplayController(theme: self.presentationData.theme, strings: self.presentationData.strings, contentNode: NotificationExceptionsSearchControllerContentNode(account: account, navigationBar: navigationBar, state: self.state), cancel: { [weak self] in
//                    self?.requestDeactivateSearch?()
//                })
//
//                self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
//                self.searchDisplayController?.activate(insertSubnode: { subnode in
//                    self.insertSubnode(subnode, belowSubnode: navigationBar)
//                }, placeholder: placeholderNode)
//            }
//        }
//    }
//
//    func deactivateSearch() {
//        if let searchDisplayController = self.searchDisplayController {
//            if self.contentNode.supernode != nil {
//                var maybePlaceholderNode: SearchBarPlaceholderNode?
//                self.contentNode.listNode.forEachItemNode { node in
//                    if let node = node as? NotificationSearchItemNode {
//                        maybePlaceholderNode = node.searchBarNode
//                    }
//                }
//
//                searchDisplayController.deactivate(placeholder: maybePlaceholderNode)
//                self.searchDisplayController = nil
//            }
//        }
//    }
//
//    func scrollToTop() {
//        if self.contentNode.supernode != nil {
//            self.contentNode.scrollToTop()
//        }
//    }
//
//
//}
//
//
//
//
//
//
//private final class NotificationExceptionsSearchControllerContentNode: SearchDisplayControllerContentNode {
//    private let account: Account
//
//    private let listNode: ItemListControllerNode<NotificationExceptionEntry>
//    private let dimNode: ASDisplayNode
//    private var validLayout: ContainerViewLayout?
//
//
//    private let searchQuery = Promise<String?>()
//    private let searchDisposable = MetaDisposable()
//
//    private var presentationData: PresentationData
//    private var presentationDataDisposable: Disposable?
//
//    private let presentationDataPromise: Promise<ChatListPresentationData>
//
//    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
//    override var isSearching: Signal<Bool, NoError> {
//        return self._isSearching.get()
//    }
//
//    private let state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>
//
//
//    init(account: Account, navigationBar: NavigationBar, state: Signal<(PresentationTheme, (ItemListNodeState<NotificationExceptionEntry>, NotificationExceptionEntry.ItemGenerationArguments)), NoError>) {
//        self.account = account
//        self.state = state
//
//        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
//        self.presentationDataPromise = Promise(ChatListPresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations))
//
//        self.listNode = ItemListControllerNode(navigationBar: navigationBar, updateNavigationOffset: { _ in
//
//        }, state: searchQuery.get() |> mapToSignal { query in
//            return state |> map { values in
//                var values = values
//                let entries = values.1.0.entries.filter { entry in
//                    switch entry {
//                    case .search:
//                        return false
//                    case let .peer(_, peer, _, _, _, _, _):
//                        if let query = query {
//                            return !peer.displayTitle.components(separatedBy: " ").filter({$0.lowercased().hasPrefix(query.lowercased())}).isEmpty && !query.isEmpty
//                        } else {
//                            return false
//                        }
//                    }
//                }
//                values.1.0 = ItemListNodeState(entries: entries, style: values.1.0.style, focusItemTag: nil, emptyStateItem: nil, searchItem: nil, crossfadeState: false, animateChanges: false)
//                return values
//            }
//        })
//
//        listNode.listNode.keepTopItemOverscrollBackground = ListViewKeepTopItemOverscrollBackground(color: presentationData.theme.chatList.backgroundColor, direction: true)
//        listNode.listNode.keepBottomItemOverscrollBackground = presentationData.theme.chatList.backgroundColor
//
//
//        self.dimNode = ASDisplayNode()
//        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
//
//        super.init()
//
//
//        self.addSubnode(self.dimNode)
//        self.addSubnode(self.listNode)
//        self.listNode.isHidden = true
//
//        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
//            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
//                if let strongSelf = self {
//                    let previousTheme = strongSelf.presentationData.theme
//
//                    strongSelf.presentationData = presentationData
//
//                    if previousTheme !== presentationData.theme {
//                        strongSelf.updateTheme(theme: presentationData.theme)
//                    }
//                }
//            })
//
//    }
//
//    deinit {
//        self.searchDisposable.dispose()
//        self.presentationDataDisposable?.dispose()
//    }
//
//    private func updateTheme(theme: PresentationTheme) {
//        self.backgroundColor = theme.chatList.backgroundColor
//    }
//
//    override func didLoad() {
//        super.didLoad()
//
//        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
//    }
//
//    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
//        if case .ended = recognizer.state {
//            self.cancel?()
//        }
//    }
//
//    override func searchTextUpdated(text: String) {
//        if text.isEmpty {
//            self.searchQuery.set(.single(nil))
//            self.listNode.isHidden = true
//        } else {
//            self.searchQuery.set(.single(text))
//            self.listNode.isHidden = false
//        }
//
//    }
//
//    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
//        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
//
//        let hadValidLayout = self.validLayout != nil
//        self.validLayout = layout
//
//        var duration: Double = 0.0
//        var curve: UInt = 0
//        switch transition {
//        case .immediate:
//            break
//        case let .animated(animationDuration, animationCurve):
//            duration = animationDuration
//            switch animationCurve {
//            case .easeInOut:
//                break
//            case .spring:
//                curve = 7
//            }
//        }
//
//
//        let listViewCurve: ListViewAnimationCurve
//        if curve == 7 {
//            listViewCurve = .Spring(duration: duration)
//        } else {
//            listViewCurve = .Default(duration: duration)
//        }
//
//        self.listNode.containerLayoutUpdated(layout, navigationBarHeight: 0, transition: transition)
//
//        let insets = UIEdgeInsets(top: navigationBarHeight - 30, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right)
//
//        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top)))
//
//        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
//        self.listNode.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight - 30, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
//    }
//
//}
