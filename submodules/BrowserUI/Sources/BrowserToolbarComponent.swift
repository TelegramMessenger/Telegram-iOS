import Foundation
import UIKit
import Display
import ComponentFlow
import BlurredBackgroundComponent
import BundleIconComponent
import TelegramPresentationData
import ContextReferenceButtonComponent

final class BrowserToolbarComponent: CombinedComponent {
    let backgroundColor: UIColor
    let separatorColor: UIColor
    let textColor: UIColor
    let bottomInset: CGFloat
    let sideInset: CGFloat
    let item: AnyComponentWithIdentity<Empty>?
    let collapseFraction: CGFloat
    
    init(
        backgroundColor: UIColor,
        separatorColor: UIColor,
        textColor: UIColor,
        bottomInset: CGFloat,
        sideInset: CGFloat,
        item: AnyComponentWithIdentity<Empty>?,
        collapseFraction: CGFloat
    ) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.textColor = textColor
        self.bottomInset = bottomInset
        self.sideInset = sideInset
        self.item = item
        self.collapseFraction = collapseFraction
    }
    
    static func ==(lhs: BrowserToolbarComponent, rhs: BrowserToolbarComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.item != rhs.item {
            return false
        }
        if lhs.collapseFraction != rhs.collapseFraction {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(BlurredBackgroundComponent.self)
        let separator = Child(Rectangle.self)
        let centerItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        
        return { context in
            let contentHeight: CGFloat = 49.0
            let totalHeight = contentHeight + context.component.bottomInset
            let offset = context.component.collapseFraction * totalHeight
            let size = CGSize(width: context.availableSize.width, height: totalHeight)
            
            let background = background.update(
                component: BlurredBackgroundComponent(color: context.component.backgroundColor),
                availableSize: CGSize(width: size.width, height: size.height),
                transition: context.transition
            )
            
            let separator = separator.update(
                component: Rectangle(color: context.component.separatorColor, height: UIScreenPixel),
                availableSize: CGSize(width: size.width, height: size.height),
                transition: context.transition
            )
            
            let item = context.component.item.flatMap { item in
                return centerItems[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: context.availableSize.width - context.component.sideInset * 2.0, height: contentHeight),
                    transition: context.transition
                )
            }

            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0 + offset))
            )
            
            context.add(separator
                .position(CGPoint(x: size.width / 2.0, y: 0.0 + offset))
            )

            if let centerItem = item {
                context.add(centerItem
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight / 2.0 + offset))
                    .appear(ComponentTransition.Appear({ _, view, transition in
                        transition.animatePosition(view: view, from: CGPoint(x: 0.0, y: size.height), to: .zero, additive: true)
                    }))
                    .disappear(ComponentTransition.Disappear({ view, transition, completion in
                        let from = view.center
                        view.center = from.offsetBy(dx: 0.0, dy: size.height)
                        transition.animatePosition(view: view, from: from, to: view.center, completion: { _ in
                            completion()
                        })
                    }))
                )
            }
            
            return size
        }
    }
}

final class NavigationToolbarContentComponent: CombinedComponent {
    let accentColor: UIColor
    let textColor: UIColor
    let canGoBack: Bool
    let canGoForward: Bool
    let canOpenIn: Bool
    let canShare: Bool
    let isDocument: Bool
    let performAction: ActionSlot<BrowserScreen.Action>
    let performHoldAction: (UIView, ContextGesture?, BrowserScreen.Action) -> Void
    
    init(
        accentColor: UIColor,
        textColor: UIColor,
        canGoBack: Bool,
        canGoForward: Bool,
        canOpenIn: Bool,
        canShare: Bool,
        isDocument: Bool,
        performAction: ActionSlot<BrowserScreen.Action>,
        performHoldAction: @escaping (UIView, ContextGesture?, BrowserScreen.Action) -> Void
    ) {
        self.accentColor = accentColor
        self.textColor = textColor
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.canOpenIn = canOpenIn
        self.canShare = canShare
        self.isDocument = isDocument
        self.performAction = performAction
        self.performHoldAction = performHoldAction
    }
    
    static func ==(lhs: NavigationToolbarContentComponent, rhs: NavigationToolbarContentComponent) -> Bool {
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.canGoBack != rhs.canGoBack {
            return false
        }
        if lhs.canGoForward != rhs.canGoForward {
            return false
        }
        if lhs.canOpenIn != rhs.canOpenIn {
            return false
        }
        if lhs.canShare != rhs.canShare {
            return false
        }
        if lhs.isDocument != rhs.isDocument {
            return false
        }
        return true
    }
    
    static var body: Body {
        let back = Child(ContextReferenceButtonComponent.self)
        let forward = Child(ContextReferenceButtonComponent.self)
        let share = Child(Button.self)
        let bookmark = Child(Button.self)
        let openIn = Child(Button.self)
        let search = Child(Button.self)
        let quickLook = Child(Button.self)
        
        return { context in
            let availableSize = context.availableSize
            let performAction = context.component.performAction
            let performHoldAction = context.component.performHoldAction
                        
            let sideInset: CGFloat = 5.0
            let buttonSize = CGSize(width: 50.0, height: availableSize.height)
            
            var buttonCount = 3
            if context.component.canShare {
                buttonCount += 1
            }
            if context.component.canOpenIn {
                buttonCount += 1
            }
            
            let spacing = (availableSize.width - buttonSize.width * CGFloat(buttonCount) - sideInset * 2.0) / CGFloat(buttonCount - 1)
            
            let canShare = context.component.canShare
            let share = share.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Chat List/NavigationShare",
                            tintColor: context.component.accentColor
                        )
                    ),
                    action: {
                        if canShare {
                            performAction.invoke(.share)
                        }
                    }
                ).minSize(buttonSize),
                availableSize: buttonSize,
                transition: .easeInOut(duration: 0.2)
            )
            
            if context.component.isDocument {
                if !context.component.canShare {
                    context.add(share
                        .position(CGPoint(x: availableSize.width / 2.0, y: 10000.0))
                    )
                } else {
                    context.add(share
                        .position(CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
                    )
                }
                
                let search = search.update(
                    component: Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Chat List/SearchIcon",
                                tintColor: context.component.accentColor
                            )
                        ),
                        action: {
                            performAction.invoke(.updateSearchActive(true))
                        }
                    ).minSize(buttonSize),
                    availableSize: buttonSize,
                    transition: .easeInOut(duration: 0.2)
                )
                context.add(search
                    .position(CGPoint(x: sideInset + search.size.width / 2.0, y: availableSize.height / 2.0))
                )
                
                let quickLook = quickLook.update(
                    component: Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/OpenDocument",
                                tintColor: context.component.accentColor
                            )
                        ),
                        action: {
                            performAction.invoke(.openIn)
                        }
                    ).minSize(buttonSize),
                    availableSize: buttonSize,
                    transition: .easeInOut(duration: 0.2)
                )
                context.add(quickLook
                    .position(CGPoint(x: context.availableSize.width - sideInset - quickLook.size.width / 2.0, y: availableSize.height / 2.0))
                )
            } else {
                let canGoBack = context.component.canGoBack
                let back = back.update(
                    component: ContextReferenceButtonComponent(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/Back",
                                tintColor: canGoBack ? context.component.accentColor : context.component.accentColor.withAlphaComponent(0.4)
                            )
                        ),
                        minSize: buttonSize,
                        action: { view, gesture in
                            guard canGoBack else {
                                return
                            }
                            if let gesture {
                                performHoldAction(view, gesture, .navigateBack)
                            } else {
                                performAction.invoke(.navigateBack)
                            }
                        }
                    ),
                    availableSize: buttonSize,
                    transition: .easeInOut(duration: 0.2)
                )
                context.add(back
                    .position(CGPoint(x: sideInset + back.size.width / 2.0, y: availableSize.height / 2.0))
                )
                
                let canGoForward = context.component.canGoForward
                let forward = forward.update(
                    component: ContextReferenceButtonComponent(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/Forward",
                                tintColor: canGoForward ? context.component.accentColor : context.component.accentColor.withAlphaComponent(0.4)
                            )
                        ),
                        minSize: buttonSize,
                        action: { view, gesture in
                            guard canGoForward else {
                                return
                            }
                            if let gesture {
                                performHoldAction(view, gesture, .navigateForward)
                            } else {
                                performAction.invoke(.navigateForward)
                            }
                        }
                    ),
                    availableSize: buttonSize,
                    transition: .easeInOut(duration: 0.2)
                )
                context.add(forward
                    .position(CGPoint(x: sideInset + back.size.width + spacing + forward.size.width / 2.0, y: availableSize.height / 2.0))
                )
                
                context.add(share
                    .position(CGPoint(x: sideInset + back.size.width + spacing + forward.size.width + spacing + share.size.width / 2.0, y: availableSize.height / 2.0))
                )
                
                let bookmark = bookmark.update(
                    component: Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/Bookmark",
                                tintColor: context.component.accentColor
                            )
                        ),
                        action: {
                            performAction.invoke(.openBookmarks)
                        }
                    ).minSize(buttonSize),
                    availableSize: buttonSize,
                    transition: .easeInOut(duration: 0.2)
                )
                context.add(bookmark
                    .position(CGPoint(x: sideInset + back.size.width + spacing + forward.size.width + spacing + share.size.width + spacing + bookmark.size.width / 2.0, y: availableSize.height / 2.0))
                )
                
                if context.component.canOpenIn {
                    let openIn = openIn.update(
                        component: Button(
                            content: AnyComponent(
                                BundleIconComponent(
                                    name: "Instant View/Browser",
                                    tintColor: context.component.accentColor
                                )
                            ),
                            action: {
                                performAction.invoke(.openIn)
                            }
                        ).minSize(buttonSize),
                        availableSize: buttonSize,
                        transition: .easeInOut(duration: 0.2)
                    )
                    context.add(openIn
                        .position(CGPoint(x: sideInset + back.size.width + spacing + forward.size.width + spacing + share.size.width + spacing + bookmark.size.width + spacing + openIn.size.width / 2.0, y: availableSize.height / 2.0))
                    )
                }
            }
            
            return availableSize
        }
    }
}

final class SearchToolbarContentComponent: CombinedComponent {
    let strings: PresentationStrings
    let textColor: UIColor
    let index: Int
    let count: Int
    let isEmpty: Bool
    let performAction: ActionSlot<BrowserScreen.Action>
    
    init(
        strings: PresentationStrings,
        textColor: UIColor,
        index: Int,
        count: Int,
        isEmpty: Bool,
        performAction: ActionSlot<BrowserScreen.Action>
    ) {
        self.strings = strings
        self.textColor = textColor
        self.index = index
        self.count = count
        self.isEmpty = isEmpty
        self.performAction = performAction
    }
    
    static func ==(lhs: SearchToolbarContentComponent, rhs: SearchToolbarContentComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.index != rhs.index {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.isEmpty != rhs.isEmpty {
            return false
        }
        return true
    }
    
    static var body: Body {
        let down = Child(Button.self)
        let up = Child(Button.self)
        let text = Child(Text.self)
        
        return { context in
            let availableSize = context.availableSize
            let performAction = context.component.performAction
            
            let sideInset: CGFloat = 3.0
            let buttonSize = CGSize(width: 50.0, height: availableSize.height)
                        
            let down = down.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Chat/Input/Search/DownButton",
                            tintColor: context.component.textColor
                        )
                    ),
                    isEnabled: context.component.count > 0,
                    action: {
                        performAction.invoke(.scrollToNextSearchResult)
                    }
                ).minSize(buttonSize),
                availableSize: buttonSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(down
                .position(CGPoint(x: availableSize.width - sideInset - down.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
            let up = up.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Chat/Input/Search/UpButton",
                            tintColor: context.component.textColor
                        )
                    ),
                    isEnabled: context.component.count > 0,
                    action: {
                        performAction.invoke(.scrollToPreviousSearchResult)
                    }
                ).minSize(buttonSize),
                availableSize: buttonSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(up
                .position(CGPoint(x: availableSize.width - sideInset - down.size.width + 7.0 - up.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
            let currentText: String
            if context.component.isEmpty {
                currentText = ""
            } else if context.component.count == 0 {
                currentText = context.component.strings.Conversation_SearchNoResults
            } else {
                currentText = context.component.strings.Items_NOfM("\(context.component.index + 1)", "\(context.component.count)").string
            }
            
            let text = text.update(
                component: Text(
                    text: currentText,
                    font: Font.regular(15.0),
                    color: context.component.textColor
                ),
                availableSize: availableSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(text
                .position(CGPoint(x: availableSize.width - sideInset - down.size.width - up.size.width - text.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
            return availableSize
        }
    }
}
