import Foundation
import UIKit
import Display
import ComponentFlow
import BlurredBackgroundComponent
import BundleIconComponent
import TelegramPresentationData
import ContextReferenceButtonComponent
import GlassBackgroundComponent
import EdgeEffect

final class BrowserToolbarComponent: CombinedComponent {
    let theme: PresentationTheme
    let bottomInset: CGFloat
    let sideInset: CGFloat
    let item: AnyComponentWithIdentity<Empty>?
    let collapseFraction: CGFloat
    
    init(
        theme: PresentationTheme,
        bottomInset: CGFloat,
        sideInset: CGFloat,
        item: AnyComponentWithIdentity<Empty>?,
        collapseFraction: CGFloat
    ) {
        self.theme = theme
        self.bottomInset = bottomInset
        self.sideInset = sideInset
        self.item = item
        self.collapseFraction = collapseFraction
    }
    
    static func ==(lhs: BrowserToolbarComponent, rhs: BrowserToolbarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
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
        let edgeEffect = Child(EdgeEffectComponent.self)
        let background = Child(GlassBackgroundComponent.self)
        let centerItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        
        return { context in
            let contentHeight: CGFloat = 56.0
            let totalHeight = contentHeight + context.component.bottomInset
            let offset = context.component.collapseFraction * totalHeight
            let size = CGSize(width: context.availableSize.width, height: totalHeight)
            
            let backgroundHeight: CGFloat = 48.0
            let edgeEffectHeight = totalHeight
            let edgeEffect = edgeEffect.update(
                component: EdgeEffectComponent(
                    color: .clear,
                    blur: true,
                    alpha: 1.0,
                    size: CGSize(width: size.width, height: edgeEffectHeight),
                    edge: .bottom,
                    edgeSize: edgeEffectHeight
                ),
                availableSize: CGSize(width: size.width, height: edgeEffectHeight),
                transition: context.transition
            )
            context.add(edgeEffect
                .position(CGPoint(x: size.width / 2.0, y: size.height / 2.0 + offset))
            )
                        
            let item = context.component.item.flatMap { item in
                return centerItems[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: context.availableSize.width - context.component.sideInset * 2.0, height: backgroundHeight),
                    transition: context.transition
                )
            }

            let contentWidth = item?.size.width ?? 0.0
            
            let backgroundSize = CGSize(width: contentWidth, height: backgroundHeight)
            let background = background.update(
                component: GlassBackgroundComponent(
                    size: backgroundSize,
                    cornerRadius: backgroundHeight * 0.5,
                    isDark: context.component.theme.overallDarkAppearance,
                    tintColor: .init(kind: .panel),
                    isInteractive: true
                ),
                availableSize: backgroundSize,
                transition: context.transition
            )
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: backgroundSize.height / 2.0 + offset))
            )
            
            if let centerItem = item {
                context.add(centerItem
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: backgroundSize.height / 2.0 + offset))
                    .appear(ComponentTransition.Appear({ _, view, transition in
                        transition.animateBlur(layer: view.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                    }))
                    .disappear(ComponentTransition.Disappear({ view, transition, completion in
                        transition.animateBlur(layer: view.layer, fromRadius: 0.0, toRadius: 10.0)
                        transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
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
    let theme: PresentationTheme
    let canGoBack: Bool
    let canGoForward: Bool
    let canOpenIn: Bool
    let canShare: Bool
    let isDocument: Bool
    let performAction: ActionSlot<BrowserScreen.Action>
    let performHoldAction: (UIView, ContextGesture?, BrowserScreen.Action) -> Void
    
    init(
        theme: PresentationTheme,
        canGoBack: Bool,
        canGoForward: Bool,
        canOpenIn: Bool,
        canShare: Bool,
        isDocument: Bool,
        performAction: ActionSlot<BrowserScreen.Action>,
        performHoldAction: @escaping (UIView, ContextGesture?, BrowserScreen.Action) -> Void
    ) {
        self.theme = theme
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.canOpenIn = canOpenIn
        self.canShare = canShare
        self.isDocument = isDocument
        self.performAction = performAction
        self.performHoldAction = performHoldAction
    }
    
    static func ==(lhs: NavigationToolbarContentComponent, rhs: NavigationToolbarContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
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
                        
            var size = CGSize(width: 0.0, height: 48.0)
            let buttonSize = CGSize(width: 50.0, height: size.height)
            
            let sideInset: CGFloat = 34.0
            let spacing: CGFloat = 66.0
            let textColor = context.component.theme.rootController.navigationBar.primaryTextColor
            
            let canShare = context.component.canShare
            let share = share.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Instant View/Share",
                            tintColor: textColor
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
                var originX: CGFloat = sideInset
                                
                let search = search.update(
                    component: Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/Search",
                                tintColor: textColor
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
                    .position(CGPoint(x: originX, y: availableSize.height / 2.0))
                )
                originX += spacing
                
                if !context.component.canShare {
                    context.add(share
                        .position(CGPoint(x: availableSize.width / 2.0, y: 10000.0))
                    )
                } else {
                    context.add(share
                        .position(CGPoint(x: originX, y: availableSize.height / 2.0))
                    )
                    originX += spacing
                }
                
                let quickLook = quickLook.update(
                    component: Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/OpenDocument",
                                tintColor: textColor
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
                    .position(CGPoint(x: originX, y: availableSize.height / 2.0))
                )
                size.width = originX + sideInset
            } else {
                var originX: CGFloat = sideInset
                
                let canGoBack = context.component.canGoBack
                let back = back.update(
                    component: ContextReferenceButtonComponent(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/Back",
                                tintColor: canGoBack ? textColor : textColor.withAlphaComponent(0.4)
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
                    .position(CGPoint(x: sideInset, y: availableSize.height / 2.0))
                )
                originX += spacing
                
                let canGoForward = context.component.canGoForward
                let forward = forward.update(
                    component: ContextReferenceButtonComponent(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/Forward",
                                tintColor: canGoForward ? textColor : textColor.withAlphaComponent(0.4)
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
                    .position(CGPoint(x: originX, y: availableSize.height / 2.0))
                )
                originX += spacing
                
                context.add(share
                    .position(CGPoint(x: originX, y: availableSize.height / 2.0))
                )
                originX += spacing
                
                let bookmark = bookmark.update(
                    component: Button(
                        content: AnyComponent(
                            BundleIconComponent(
                                name: "Instant View/Bookmark",
                                tintColor: textColor
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
                    .position(CGPoint(x: originX, y: availableSize.height / 2.0))
                )
                
                if context.component.canOpenIn {
                    originX += spacing
                    
                    let openIn = openIn.update(
                        component: Button(
                            content: AnyComponent(
                                BundleIconComponent(
                                    name: "Instant View/Browser",
                                    tintColor: textColor
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
                        .position(CGPoint(x: originX, y: availableSize.height / 2.0))
                    )
                }
                
                size.width = originX + sideInset
            }
            
            return size
        }
    }
}

final class SearchToolbarContentComponent: CombinedComponent {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let index: Int
    let count: Int
    let isEmpty: Bool
    let performAction: ActionSlot<BrowserScreen.Action>
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        index: Int,
        count: Int,
        isEmpty: Bool,
        performAction: ActionSlot<BrowserScreen.Action>
    ) {
        self.theme = theme
        self.strings = strings
        self.index = index
        self.count = count
        self.isEmpty = isEmpty
        self.performAction = performAction
    }
    
    static func ==(lhs: SearchToolbarContentComponent, rhs: SearchToolbarContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
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
            
            let sideInset: CGFloat = 60.0
            let buttonSize = CGSize(width: 50.0, height: availableSize.height)
                        
            let textColor = context.component.theme.rootController.navigationBar.primaryTextColor
            
            let down = down.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Chat/Input/Search/DownButton",
                            tintColor: textColor
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
                            tintColor: textColor
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
                    color: textColor
                ),
                availableSize: availableSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(text
                .position(CGPoint(x: availableSize.width - sideInset - down.size.width - up.size.width - text.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
            return CGSize(width: availableSize.width - 60.0, height: 48.0)
        }
    }
}
