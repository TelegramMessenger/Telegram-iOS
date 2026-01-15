import Foundation
import UIKit
import ComponentFlow
import Display
import TelegramPresentationData
import MultilineTextComponent

public final class TableComponent: CombinedComponent {
    public class Item: Equatable {
        public enum TitleFont {
            case regular
            case bold
        }
        
        public let id: AnyHashable
        public let title: String?
        public let titleFont: TitleFont
        public let hasBackground: Bool
        public let component: AnyComponent<Empty>
        public let insets: UIEdgeInsets?

        public init<IdType: Hashable>(
            id: IdType,
            title: String?,
            titleFont: TitleFont = .regular,
            hasBackground: Bool = false,
            component: AnyComponent<Empty>,
            insets: UIEdgeInsets? = nil
        ) {
            self.id = AnyHashable(id)
            self.title = title
            self.titleFont = titleFont
            self.hasBackground = hasBackground
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
            if lhs.titleFont != rhs.titleFont {
                return false
            }
            if lhs.hasBackground != rhs.hasBackground {
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
    private let semiTransparent: Bool
    
    public init(theme: PresentationTheme, items: [Item], semiTransparent: Bool = false) {
        self.theme = theme
        self.items = items
        self.semiTransparent = semiTransparent
    }

    public static func ==(lhs: TableComponent, rhs: TableComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.semiTransparent != rhs.semiTransparent {
            return false
        }
        return true
    }
    
    public final class State: ComponentState {
        var cachedLastBackgroundImage: (UIImage, PresentationTheme)?
        var cachedLeftColumnImage: (UIImage, PresentationTheme)?
        var cachedBorderImage: (UIImage, PresentationTheme)?
    }
    
    public func makeState() -> State {
        return State()
    }

    public static var body: Body {
        let leftColumnBackground = Child(Image.self)
        let lastBackground = Child(Image.self)
        let verticalBorder = Child(Rectangle.self)
        let titleChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let valueChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let borderChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let outerBorder = Child(Image.self)

        return { context in
            let verticalPadding: CGFloat = 11.0
            let horizontalPadding: CGFloat = 12.0
            let borderWidth: CGFloat = 1.0
            
            let borderColor: UIColor
            let secondaryBackgroundColor: UIColor
            if context.component.semiTransparent {
                borderColor = context.component.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1)
                secondaryBackgroundColor = context.component.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.05)
            } else {
                let backgroundColor = context.component.theme.actionSheet.opaqueItemBackgroundColor
                borderColor = backgroundColor.mixedWith(context.component.theme.list.itemBlocksSeparatorColor, alpha: 0.6)
                secondaryBackgroundColor = context.component.theme.overallDarkAppearance ? context.component.theme.list.itemModalBlocksBackgroundColor : context.component.theme.list.itemInputField.backgroundColor
            }
            
            var leftColumnWidth: CGFloat = 0.0
            
            var updatedTitleChildren: [Int: _UpdatedChildComponent] = [:]
            var updatedValueChildren: [(_UpdatedChildComponent, UIEdgeInsets)] = []
            var updatedBorderChildren: [_UpdatedChildComponent] = []
            
            var i = 0
            for item in context.component.items {
                guard let title = item.title else {
                    i += 1
                    continue
                }
                let titleChild = titleChildren[item.id].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: title, font: item.titleFont == .bold ? Font.semibold(15.0) : Font.regular(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                    )),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                updatedTitleChildren[i] = titleChild
                
                if titleChild.size.width > leftColumnWidth {
                    leftColumnWidth = titleChild.size.width
                }
                i += 1
            }
            
            leftColumnWidth = max(100.0, leftColumnWidth + horizontalPadding * 2.0)
            let rightColumnWidth = context.availableSize.width - leftColumnWidth
            
            i = 0
            var rowHeights: [Int: CGFloat] = [:]
            var totalHeight: CGFloat = 0.0
            var innerTotalHeight: CGFloat = 0.0
            var innerTotalOffset: CGFloat = 0.0
            var hasRowBackground = false
            var rowBackgroundIsLast = false
            var hasStraightSide = false
            
            for item in context.component.items {
                let insets: UIEdgeInsets
                if let customInsets = item.insets {
                    insets = customInsets
                } else {
                    insets = UIEdgeInsets(top: 0.0, left: horizontalPadding, bottom: 0.0, right: horizontalPadding)
                }
                
                var titleHeight: CGFloat = 0.0
                if let titleChild = updatedTitleChildren[i] {
                    titleHeight = titleChild.size.height
                }
                
                let availableValueWidth: CGFloat
                if titleHeight > 0.0 {
                    availableValueWidth = rightColumnWidth
                } else {
                    availableValueWidth = context.availableSize.width
                }
                
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: availableValueWidth - insets.left - insets.right, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append((valueChild, insets))
               
                let rowHeight = max(40.0, max(titleHeight, valueChild.size.height) + verticalPadding * 2.0)
                rowHeights[i] = rowHeight
                totalHeight += rowHeight
                if titleHeight > 0.0 {
                    innerTotalHeight += rowHeight
                } else if i == 0 {
                    innerTotalOffset += rowHeight
                }
                
                if i < context.component.items.count - 1 {
                    let borderChild = borderChildren[item.id].update(
                        component: AnyComponent(Rectangle(color: borderColor)),
                        availableSize: CGSize(width: context.availableSize.width, height: borderWidth),
                        transition: context.transition
                    )
                    updatedBorderChildren.append(borderChild)
                }
                
                if item.hasBackground {
                    if i != 0 {
                        rowBackgroundIsLast = true
                    }
                    hasRowBackground = true
                }
                if item.title == nil {
                    if i != 0 {
                        rowBackgroundIsLast = true
                    }
                    hasStraightSide = true
                }
                
                i += 1
            }
            
            let borderRadius: CGFloat = 14.0
            
            if hasRowBackground {
                let lastBackgroundImage: UIImage
                if let (currentImage, theme) = context.state.cachedLastBackgroundImage, theme === context.component.theme {
                    lastBackgroundImage = currentImage
                } else {
                    lastBackgroundImage = generateImage(CGSize(width: borderRadius * 2.0 + 4.0, height: borderRadius * 2.0 + 4.0), rotatedContext: { size, context in
                        let bounds = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height + borderRadius))
                        context.clear(bounds)
                        
                        let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0).insetBy(dx: 0.0, dy: rowBackgroundIsLast ? -borderRadius * 2.0 : 0.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                        context.setFillColor(secondaryBackgroundColor.cgColor)
                        context.addPath(path)
                        context.fillPath()
                    })!.stretchableImage(withLeftCapWidth: Int(borderRadius), topCapHeight: Int(borderRadius))
                    context.state.cachedLastBackgroundImage = (lastBackgroundImage, context.component.theme)
                }
                
                let lastRowHeight: CGFloat
                let position: CGFloat
                if !rowBackgroundIsLast {
                    lastRowHeight = rowHeights[0] ?? 0
                    position = lastRowHeight / 2.0
                } else {
                    lastRowHeight = rowHeights[i - 1] ?? 0
                    position = totalHeight - lastRowHeight / 2.0
                }
                let lastBackground = lastBackground.update(
                    component: Image(image: lastBackgroundImage),
                    availableSize: CGSize(width: context.availableSize.width, height: lastRowHeight),
                    transition: context.transition
                )
                
                context.add(
                    lastBackground
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: position))
                )
            }
            
            let leftColumnImage: UIImage
            if let (currentImage, theme) = context.state.cachedLeftColumnImage, theme === context.component.theme {
                leftColumnImage = currentImage
            } else {
                leftColumnImage = generateImage(CGSize(width: borderRadius * 2.0 + 4.0, height: borderRadius * 2.0 + 4.0), rotatedContext: { size, context in
                    var bounds = CGRect(origin: .zero, size: CGSize(width: size.width + borderRadius, height: size.height))
                    context.clear(bounds)
                    
                    var offset: CGFloat = 0.0
                    if hasStraightSide {
                        offset = rowBackgroundIsLast ? 0.0 : -borderRadius
                        
                        bounds.origin.y += offset
                        bounds.size.height += borderRadius
                    }
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setFillColor(secondaryBackgroundColor.cgColor)
                    context.addPath(path)
                    context.fillPath()
                })!.stretchableImage(withLeftCapWidth: Int(borderRadius), topCapHeight: Int(borderRadius))
                context.state.cachedLeftColumnImage = (leftColumnImage, context.component.theme)
            }
            
            let leftColumnBackground = leftColumnBackground.update(
                component: Image(image: leftColumnImage),
                availableSize: CGSize(width: leftColumnWidth, height: innerTotalHeight),
                transition: context.transition
            )
            context.add(leftColumnBackground
                .position(CGPoint(x: leftColumnWidth / 2.0, y: innerTotalOffset + innerTotalHeight / 2.0))
            )
            
            let borderImage: UIImage
            if let (currentImage, theme) = context.state.cachedBorderImage, theme === context.component.theme {
                borderImage = currentImage
            } else {
                borderImage = generateImage(CGSize(width: borderRadius * 2.0 + 4.0, height: borderRadius * 2.0 + 4.0), rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.clear(bounds)
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setBlendMode(.clear)
                    context.addPath(path)
                    context.fillPath()
                    
                    context.setBlendMode(.normal)
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(borderWidth)
                    context.addPath(path)
                    context.strokePath()
                })!.stretchableImage(withLeftCapWidth: Int(borderRadius), topCapHeight: Int(borderRadius))
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
                availableSize: CGSize(width: borderWidth, height: innerTotalHeight),
                transition: context.transition
            )
            context.add(
                verticalBorder
                    .position(CGPoint(x: leftColumnWidth - borderWidth / 2.0, y: innerTotalOffset + innerTotalHeight / 2.0))
            )
            
            i = 0
            var originY: CGFloat = 0.0
            for (valueChild, valueInsets) in updatedValueChildren {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let valueFrame: CGRect
                if let titleChild = updatedTitleChildren[i] {
                    let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                    context.add(titleChild
                        .position(titleFrame.center)
                    )
                    valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + valueInsets.left, y: originY + verticalPadding), size: valueChild.size)
                } else {
                    if hasRowBackground && rowBackgroundIsLast {
                        valueFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - valueChild.size.width) / 2.0), y: originY + verticalPadding), size: valueChild.size)
                    } else {
                        valueFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: valueChild.size)
                    }
                }
                
                context.add(valueChild
                    .position(valueFrame.center)
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                
                if i < updatedBorderChildren.count {
                    let borderChild = updatedBorderChildren[i]
                    context.add(borderChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + rowHeight - borderWidth / 2.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                }
                
                originY += rowHeight
                i += 1
            }
            
            return CGSize(width: context.availableSize.width, height: totalHeight)
        }
    }
}
