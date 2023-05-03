import Foundation
import UIKit
import Display
import ComponentFlow
import BlurredBackgroundComponent
import BundleIconComponent
import TelegramPresentationData

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
                    .appear(Transition.Appear({ _, view, transition in
                        transition.animatePosition(view: view, from: CGPoint(x: 0.0, y: size.height), to: .zero, additive: true)
                    }))
                    .disappear(Transition.Disappear({ view, transition, completion in
                        transition.animatePosition(view: view, from: .zero, to: CGPoint(x: 0.0, y: size.height), additive: true, completion: { _ in
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
    let textColor: UIColor
    let canGoBack: Bool
    let canGoForward: Bool
    let performAction: ActionSlot<BrowserScreen.Action>
    
    init(
        textColor: UIColor,
        canGoBack: Bool,
        canGoForward: Bool,
        performAction: ActionSlot<BrowserScreen.Action>
    ) {
        self.textColor = textColor
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.performAction = performAction
    }
    
    static func ==(lhs: NavigationToolbarContentComponent, rhs: NavigationToolbarContentComponent) -> Bool {
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.canGoBack != rhs.canGoBack {
            return false
        }
        if lhs.canGoForward != rhs.canGoForward {
            return false
        }
        return true
    }
    
    static var body: Body {
        let back = Child(Button.self)
        let forward = Child(Button.self)
        let share = Child(Button.self)
        let openIn = Child(Button.self)
        
        return { context in
            let availableSize = context.availableSize
            let performAction = context.component.performAction
            
            let sideInset: CGFloat = 5.0
            let buttonSize = CGSize(width: 50.0, height: availableSize.height)
            let spacing = (availableSize.width - buttonSize.width * 4.0 - sideInset * 2.0) / 3.0
            
            let back = back.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Instant View/Back",
                            tintColor: context.component.textColor
                        )
                    ),
                    isEnabled: context.component.canGoBack,
                    action: {
                        performAction.invoke(.navigateBack)
                    }
                ).minSize(buttonSize),
                availableSize: buttonSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(back
                .position(CGPoint(x: sideInset + back.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
            let forward = forward.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Instant View/Forward",
                            tintColor: context.component.textColor
                        )
                    ),
                    isEnabled: context.component.canGoForward,
                    action: {
                        performAction.invoke(.navigateForward)
                    }
                ).minSize(buttonSize),
                availableSize: buttonSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(forward
                .position(CGPoint(x: sideInset + back.size.width + spacing + forward.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
            let share = share.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Chat List/NavigationShare",
                            tintColor: context.component.textColor
                        )
                    ),
                    action: {
                        performAction.invoke(.share)
                    }
                ).minSize(buttonSize),
                availableSize: buttonSize,
                transition: .easeInOut(duration: 0.2)
            )
            context.add(share
                .position(CGPoint(x: sideInset + back.size.width + spacing + forward.size.width + spacing + share.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
            let openIn = openIn.update(
                component: Button(
                    content: AnyComponent(
                        BundleIconComponent(
                            name: "Chat/Context Menu/Browser",
                            tintColor: context.component.textColor
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
                .position(CGPoint(x: sideInset + back.size.width + spacing + forward.size.width + spacing + share.size.width + spacing + openIn.size.width / 2.0, y: availableSize.height / 2.0))
            )
            
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

