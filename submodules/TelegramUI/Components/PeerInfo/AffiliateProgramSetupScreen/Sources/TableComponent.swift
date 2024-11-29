import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import MultilineTextComponent
import AlertComponent

final class TableComponent: CombinedComponent {
    class Item: Equatable {
        public let id: AnyHashable
        public let title: String
        public let component: AnyComponent<Empty>
        public let insets: UIEdgeInsets?

        public init<IdType: Hashable>(id: IdType, title: String, component: AnyComponent<Empty>, insets: UIEdgeInsets? = nil) {
            self.id = AnyHashable(id)
            self.title = title
            self.component = component
            self.insets = insets
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.component != rhs.component {
                return false
            }
            if lhs.insets != rhs.insets {
                return false
            }
            return true
        }
    }
    
    private let theme: PresentationTheme
    private let items: [Item]

    public init(theme: PresentationTheme, items: [Item]) {
        self.theme = theme
        self.items = items
    }

    public static func ==(lhs: TableComponent, rhs: TableComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedBorderImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }

    public static var body: Body {
        let leftColumnBackground = Child(Rectangle.self)
        let verticalBorder = Child(Rectangle.self)
        let titleChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let valueChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let borderChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let outerBorder = Child(Image.self)

        return { context in
            let verticalPadding: CGFloat = 11.0
            let horizontalPadding: CGFloat = 12.0
            let borderWidth: CGFloat = 1.0
            
            let backgroundColor = context.component.theme.actionSheet.opaqueItemBackgroundColor
            let borderColor = backgroundColor.mixedWith(context.component.theme.list.itemBlocksSeparatorColor, alpha: 0.6)
            
            var leftColumnWidth: CGFloat = 0.0
            
            var updatedTitleChildren: [_UpdatedChildComponent] = []
            var updatedValueChildren: [(_UpdatedChildComponent, UIEdgeInsets)] = []
            var updatedBorderChildren: [_UpdatedChildComponent] = []
            
            for item in context.component.items {
                let titleChild = titleChildren[item.id].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.title, font: Font.regular(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                    )),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                updatedTitleChildren.append(titleChild)
                
                if titleChild.size.width > leftColumnWidth {
                    leftColumnWidth = titleChild.size.width
                }
            }
            
            leftColumnWidth = max(100.0, leftColumnWidth + horizontalPadding * 2.0)
            let rightColumnWidth = context.availableSize.width - leftColumnWidth
            
            var i = 0
            var rowHeights: [Int: CGFloat] = [:]
            var totalHeight: CGFloat = 0.0
            
            for item in context.component.items {
                let titleChild = updatedTitleChildren[i]
                
                let insets: UIEdgeInsets
                if let customInsets = item.insets {
                    insets = customInsets
                } else {
                    insets = UIEdgeInsets(top: 0.0, left: horizontalPadding, bottom: 0.0, right: horizontalPadding)
                }
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: rightColumnWidth - insets.left - insets.right, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append((valueChild, insets))
                
                let rowHeight = max(40.0, max(titleChild.size.height, valueChild.size.height) + verticalPadding * 2.0)
                rowHeights[i] = rowHeight
                totalHeight += rowHeight
                
                if i < context.component.items.count - 1 {
                    let borderChild = borderChildren[item.id].update(
                        component: AnyComponent(Rectangle(color: borderColor)),
                        availableSize: CGSize(width: context.availableSize.width, height: borderWidth),
                        transition: context.transition
                    )
                    updatedBorderChildren.append(borderChild)
                }
                
                i += 1
            }
            
            let leftColumnBackground = leftColumnBackground.update(
                component: Rectangle(color: context.component.theme.list.itemInputField.backgroundColor),
                availableSize: CGSize(width: leftColumnWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                leftColumnBackground
                    .position(CGPoint(x: leftColumnWidth / 2.0, y: totalHeight / 2.0))
            )
            
            let borderImage: UIImage
            if let (currentImage, theme) = context.state.cachedBorderImage, theme === context.component.theme {
                borderImage = currentImage
            } else {
                let borderRadius: CGFloat = 5.0
                borderImage = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.setFillColor(backgroundColor.cgColor)
                    context.fill(bounds)
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setBlendMode(.clear)
                    context.addPath(path)
                    context.fillPath()
                    
                    context.setBlendMode(.normal)
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(borderWidth)
                    context.addPath(path)
                    context.strokePath()
                })!.stretchableImage(withLeftCapWidth: 5, topCapHeight: 5)
                context.state.cachedBorderImage = (borderImage, context.component.theme)
            }
            
            let outerBorder = outerBorder.update(
                component: Image(image: borderImage),
                availableSize: CGSize(width: context.availableSize.width, height: totalHeight),
                transition: context.transition
            )
            context.add(outerBorder
                .position(CGPoint(x: context.availableSize.width / 2.0, y: totalHeight / 2.0))
            )
            
            let verticalBorder = verticalBorder.update(
                component: Rectangle(color: borderColor),
                availableSize: CGSize(width: borderWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                verticalBorder
                    .position(CGPoint(x: leftColumnWidth - borderWidth / 2.0, y: totalHeight / 2.0))
            )
            
            i = 0
            var originY: CGFloat = 0.0
            for (titleChild, (valueChild, valueInsets)) in zip(updatedTitleChildren, updatedValueChildren) {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                let valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + valueInsets.left, y: originY + verticalPadding), size: valueChild.size)
                
                context.add(titleChild
                    .position(titleFrame.center)
                )
                
                context.add(valueChild
                    .position(valueFrame.center)
                )
                
                if i < updatedBorderChildren.count {
                    let borderChild = updatedBorderChildren[i]
                    context.add(borderChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + rowHeight - borderWidth / 2.0))
                    )
                }
                
                originY += rowHeight
                i += 1
            }
            
            return CGSize(width: context.availableSize.width, height: totalHeight)
        }
    }
}

private final class TableAlertContentComponet: CombinedComponent {
    let theme: PresentationTheme
    let title: String
    let text: String
    let table: TableComponent
    
    init(theme: PresentationTheme, title: String, text: String, table: TableComponent) {
        self.theme = theme
        self.title = title
        self.text = text
        self.table = table
    }
    
    static func ==(lhs: TableAlertContentComponet, rhs: TableAlertContentComponet) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.table != rhs.table {
            return false
        }
        return true
    }
    
    public static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        
        return { context in
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: context.component.title, font: Font.semibold(16.0), textColor: context.component.theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: .immediate
            )
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: context.component.text, font: Font.regular(13.0), textColor: context.component.theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: .immediate
            )
            let table = table.update(
                component: context.component.table,
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: .immediate
            )
            
            var size = CGSize(width: 0.0, height: 0.0)
            
            size.width = max(size.width, title.size.width)
            size.width = max(size.width, text.size.width)
            size.width = max(size.width, table.size.width)
            
            size.height += title.size.height
            size.height += 5.0
            size.height += text.size.height
            size.height += 14.0
            size.height += table.size.height
            size.height -= 3.0
            
            var contentHeight: CGFloat = 0.0
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - title.size.width) * 0.5), y: contentHeight), size: title.size)
            contentHeight += title.size.height + 5.0
            let textFrame = CGRect(origin: CGPoint(x: floor((size.width - text.size.width) * 0.5), y: contentHeight), size: text.size)
            contentHeight += text.size.height + 14.0
            let tableFrame = CGRect(origin: CGPoint(x: floor((size.width - table.size.width) * 0.5), y: contentHeight), size: table.size)
            contentHeight += table.size.height
            
            context.add(title
                .position(titleFrame.center)
            )
            context.add(text
                .position(textFrame.center)
            )
            context.add(table
                .position(tableFrame.center)
            )
            
            return size
        }
    }
}

func tableAlert(theme: PresentationTheme, title: String, text: String, table: TableComponent, actions: [ComponentAlertAction]) -> ViewController {
    return componentAlertController(
        theme: AlertControllerTheme(presentationTheme: theme, fontSize: .regular),
        content: AnyComponent(TableAlertContentComponet(
            theme: theme,
            title: title,
            text: text,
            table: table
        )),
        actions: actions,
        actionLayout: .horizontal
    )
}
