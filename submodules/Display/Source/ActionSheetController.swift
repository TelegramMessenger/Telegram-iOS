import Foundation
import UIKit
import AsyncDisplayKit

public protocol ActionSheetGroupOverlayNode: ASDisplayNode {
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}

open class ActionSheetController: ViewController, PresentableController, StandalonePresentableController, KeyShortcutResponder {
    private var actionSheetNode: ActionSheetControllerNode {
        return self.displayNode as! ActionSheetControllerNode
    }
    
    public var theme: ActionSheetControllerTheme {
        didSet {
            if oldValue != self.theme {
                self.actionSheetNode.theme = self.theme
            }
        }
    }
    
    private var groups: [ActionSheetItemGroup] = []
    
    private var isDismissed: Bool = false
    private weak var previousAccessibilityFocus: AnyObject?
    private var contentSizeCategoryObserver: NSObjectProtocol?
    private var reduceTransparencyObserver: NSObjectProtocol?
    
    public var dismissed: ((Bool) -> Void)?
    
    private var allowInputInset: Bool
    
    public init(theme: ActionSheetControllerTheme, allowInputInset: Bool = false) {
        self.theme = theme
        self.allowInputInset = allowInputInset
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.blocksBackgroundWhenInOverlay = true

        self.contentSizeCategoryObserver = NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self, self.isViewLoaded else {
                return
            }
            self.actionSheetNode.setGroups(self.groups)
            UIAccessibility.post(notification: .layoutChanged, argument: firstAccessibilityElement(in: self.actionSheetNode.view) ?? self.actionSheetNode.view)
        })
        self.reduceTransparencyObserver = NotificationCenter.default.addObserver(forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self, self.isViewLoaded else {
                return
            }
            self.actionSheetNode.setGroups(self.groups)
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let contentSizeCategoryObserver = self.contentSizeCategoryObserver {
            NotificationCenter.default.removeObserver(contentSizeCategoryObserver)
        }
        if let reduceTransparencyObserver = self.reduceTransparencyObserver {
            NotificationCenter.default.removeObserver(reduceTransparencyObserver)
        }
    }
    
    public func dismissAnimated() {
        if !self.isDismissed {
            self.isDismissed = true
            self.actionSheetNode.animateOut(cancelled: false)
        }
    }
    
    open override func accessibilityPerformEscape() -> Bool {
        if self.isDismissed {
            return false
        }
        self.isDismissed = true
        self.actionSheetNode.animateOut(cancelled: true)
        return true
    }

    open override func loadDisplayNode() {
        self.displayNode = ActionSheetControllerNode(theme: self.theme, allowInputInset: self.allowInputInset)
        self.displayNodeDidLoad()
        
        self.actionSheetNode.dismiss = { [weak self] cancelled in
            guard let self else {
                return
            }
            self.dismissed?(cancelled)
            self.presentingViewController?.dismiss(animated: false, completion: { [weak self] in
                self?.restoreAccessibilityFocus()
            })
        }
        
        self.actionSheetNode.setGroups(self.groups)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.actionSheetNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppear(completion: {})
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.previousAccessibilityFocus == nil {
            self.previousAccessibilityFocus = UIAccessibility.focusedElement(using: .notificationVoiceOver) as AnyObject?
        }
    }

    public func viewDidAppear(completion: @escaping () -> Void) {
        self.actionSheetNode.animateIn { [weak self] in
            completion()

            guard let self else {
                return
            }
            UIAccessibility.post(notification: .screenChanged, argument: firstAccessibilityElement(in: self.actionSheetNode.view) ?? self.actionSheetNode.view)
        }
    }

    private func restoreAccessibilityFocus() {
        guard let previousAccessibilityFocus = self.previousAccessibilityFocus else {
            return
        }
        self.previousAccessibilityFocus = nil
        UIAccessibility.post(notification: .layoutChanged, argument: previousAccessibilityFocus)
    }
    
    public func setItemGroups(_ groups: [ActionSheetItemGroup]) {
        self.groups = groups
        if self.isViewLoaded {
            self.actionSheetNode.setGroups(groups)
        }
    }
    
    public func updateItem(groupIndex: Int, itemIndex: Int, _ f: (ActionSheetItem) -> ActionSheetItem) {
        if self.isViewLoaded {
            self.actionSheetNode.updateItem(groupIndex: groupIndex, itemIndex: itemIndex, f)
        }
    }
    
    public func setItemGroupOverlayNode(groupIndex: Int, node: ActionSheetGroupOverlayNode) {
        if self.isViewLoaded {
            self.actionSheetNode.setItemGroupOverlayNode(groupIndex: groupIndex, node: node)
        }
    }
    
    public var keyShortcuts: [KeyShortcut] {
        return [
            KeyShortcut(
                input: UIKeyCommand.inputEscape,
                modifiers: [],
                action: { [weak self] in
                    self?.dismissAnimated()
                }
            ),
            KeyShortcut(
                input: "W",
                modifiers: [.command],
                action: { [weak self] in
                    self?.dismissAnimated()
                }
            ),
            KeyShortcut(
                input: "\r",
                modifiers: [],
                action: { [weak self] in
                    self?.actionSheetNode.performHighlightedAction()
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputUpArrow,
                modifiers: [],
                action: { [weak self] in
                    self?.actionSheetNode.decreaseHighlightedIndex()
                }
            ),
            KeyShortcut(
                input: UIKeyCommand.inputDownArrow,
                modifiers: [],
                action: { [weak self] in
                    self?.actionSheetNode.increaseHighlightedIndex()
                }
            )
        ]
    }
}
