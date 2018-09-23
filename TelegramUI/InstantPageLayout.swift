import Foundation
import TelegramCore
import Postbox
import Display

final class InstantPageLayout {
    let origin: CGPoint
    let contentSize: CGSize
    let items: [InstantPageItem]
    
    init(origin: CGPoint, contentSize: CGSize, items: [InstantPageItem]) {
        self.origin = origin
        self.contentSize = contentSize
        self.items = items
    }
    
    func flattenedItemsWithOrigin(_ origin: CGPoint) -> [InstantPageItem] {
        return self.items.map({ item in
            var item = item
            let itemFrame = item.frame.offsetBy(dx: origin.x, dy: origin.y)
            item.frame = itemFrame
            return item
        })
    }
}

private func setupStyleStack(_ stack: InstantPageTextStyleStack, theme: InstantPageTheme, category: InstantPageTextCategoryType, link: Bool) {
    let attributes = theme.textCategories.attributes(type: category, link: link)
    stack.push(.textColor(attributes.color))
    switch attributes.font.style {
        case .sans:
            stack.push(.fontSerif(false))
        case .serif:
            stack.push(.fontSerif(true))
    }
    stack.push(.fontSize(attributes.font.size))
    stack.push(.lineSpacingFactor(attributes.font.lineSpacingFactor))
    if attributes.underline {
        stack.push(.underline)
    }
}

func layoutInstantPageBlock(webpage: TelegramMediaWebpage, block: InstantPageBlock, boundingWidth: CGFloat, horizontalInset: CGFloat, safeInset: CGFloat, isCover: Bool,  previousItems: [InstantPageItem], fillToWidthAndHeight: Bool, media: [MediaId: Media], mediaIndexCounter: inout Int, embedIndexCounter: inout Int, theme: InstantPageTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> InstantPageLayout {
    switch block {
        case let .cover(block):
            return layoutInstantPageBlock(webpage: webpage, block: block, boundingWidth: boundingWidth, horizontalInset: horizontalInset, safeInset: safeInset, isCover: true, previousItems:previousItems, fillToWidthAndHeight: fillToWidthAndHeight, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat)
        case let .title(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .header, link: false)
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .subtitle(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .subheader, link: false)
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .authorDate(author: author, date: date):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
            var text: RichText?
            if case .empty = author {
                if date != 0 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = localeWithStrings(strings)
                    dateFormatter.dateStyle = .long
                    dateFormatter.timeStyle = .none
                    let dateStringPlain = dateFormatter.string(from: Date(timeIntervalSince1970: Double(date)))
                    text = RichText.plain(dateStringPlain)
                }
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = localeWithStrings(strings)
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .none
                let dateStringPlain = dateFormatter.string(from: Date(timeIntervalSince1970: Double(date)))
                let dateText = RichText.plain(dateStringPlain)
                
                if date != 0 {
                    let formatString = strings.InstantPage_AuthorAndDateTitle("%1$@", "%2$@").0
                    let authorRange = formatString.range(of: "%1$@")!
                    let dateRange = formatString.range(of: "%2$@")!
                    
                    if authorRange.lowerBound < dateRange.lowerBound {
                        let byPart = String(formatString[formatString.startIndex ..< authorRange.lowerBound])
                        let middlePart = String(formatString[authorRange.upperBound ..< dateRange.lowerBound])
                        let endPart = String(formatString[dateRange.upperBound...])
                        
                        text = .concat([.plain(byPart), author, .plain(middlePart), dateText, .plain(endPart)])
                    } else {
                        let beforePart = String(formatString[formatString.startIndex ..< dateRange.lowerBound])
                        let middlePart = String(formatString[dateRange.upperBound ..< authorRange.lowerBound])
                        let endPart = String(formatString[authorRange.upperBound...])
                        
                        text = .concat([.plain(beforePart), dateText, .plain(middlePart), author, .plain(endPart)])
                    }
                } else {
                    text = author
                }
            }
            if let text = text {
                let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
                
                if let previousItem = previousItems.last as? InstantPageTextItem, previousItem.containsRTL {
                    item.alignment = .right
                }
                
                return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
            } else {
                return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
            }
        case let .header(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .header, link: false)
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .subheader(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .subheader, link: false)
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .paragraph(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .preformatted(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            let backgroundInset: CGFloat = 14.0
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - backgroundInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: backgroundInset)
            let backgroundItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: item.frame.size.height + backgroundInset * 2.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: item.frame.size.height + backgroundInset * 2.0)), shape: .rect, color: theme.codeBlockBackgroundColor)
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(width: boundingWidth, height: item.frame.size.height + backgroundInset * 2.0), items: [backgroundItem, item])
        case let .footer(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case .divider:
            let lineWidth = floor(boundingWidth / 2.0)
            let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - lineWidth) / 2.0), y: 0.0), size: CGSize(width: lineWidth, height: 1.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: 1.0)), shape: .rect, color: theme.textCategories.caption.color)
            return InstantPageLayout(origin: CGPoint(), contentSize: shapeItem.frame.size, items: [shapeItem])
        case let .list(contentItems, ordered):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var maxIndexWidth: CGFloat = 0.0
            var listItems: [InstantPageItem] = []
            var indexItems: [InstantPageItem] = []
            for i in 0 ..< contentItems.count {
                if ordered {
                    let styleStack = InstantPageTextStyleStack()
                    setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
                    let textItem = layoutTextItemWithString(attributedStringForRichText(.plain("\(i + 1)."), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                    if let line = textItem.lines.first {
                        maxIndexWidth = max(maxIndexWidth, line.frame.size.width)
                    }
                    indexItems.append(textItem)
                } else {
                    let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 6.0, height: 12.0)), shapeFrame: CGRect(origin: CGPoint(x: 0.0, y: 3.0), size: CGSize(width: 6.0, height: 6.0)), shape: .ellipse, color: theme.textCategories.paragraph.color)
                    indexItems.append(shapeItem)
                }
            }
            let indexSpacing: CGFloat = ordered ? 7.0 : 20.0
            for i in 0 ..< contentItems.count {
                if (i != 0) {
                    contentSize.height += 20.0
                }
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
                
                let textItem = layoutTextItemWithString(attributedStringForRichText(contentItems[i], styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - indexSpacing - maxIndexWidth)
                textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + indexSpacing + maxIndexWidth, dy:  contentSize.height)
                
                contentSize.height += textItem.frame.size.height
                let itemFrame = indexItems[i].frame.offsetBy(dx: horizontalInset, dy: textItem.frame.origin.y)
                indexItems[i].frame = itemFrame
                listItems.append(indexItems[i])
                listItems.append(textItem)
            }
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: listItems)
        case let .blockQuote(text, caption):
            let lineInset: CGFloat = 20.0
            let verticalInset: CGFloat = 4.0
            var contentSize = CGSize(width: boundingWidth, height: verticalInset)
            
            var items: [InstantPageItem] = []
            
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            styleStack.push(.italic)
            
            let textItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset)
            textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + lineInset, dy: contentSize.height)
            
            contentSize.height += textItem.frame.size.height
            items.append(textItem)
            
            if case .empty = caption {
            } else {
                contentSize.height += 14.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset)
                captionItem.frame = captionItem.frame.offsetBy(dx: horizontalInset + lineInset, dy: contentSize.height)
                
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
            contentSize.height += verticalInset
            
            let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: horizontalInset, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shapeFrame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shape: .roundLine, color: theme.textCategories.paragraph.color)
            
            items.append(shapeItem)
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .pullQuote(text, caption):
            let verticalInset: CGFloat = 4.0
            var contentSize = CGSize(width: boundingWidth, height: verticalInset)
            
            var items: [InstantPageItem] = []
            
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            styleStack.push(.italic)
            
            let textItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            textItem.frame = textItem.frame.offsetBy(dx: floor(boundingWidth - textItem.frame.size.width) / 2.0, dy: contentSize.height)
            textItem.alignment = .center
            
            contentSize.height += textItem.frame.size.height
            items.append(textItem)
            
            if case .empty = caption {
            } else {
                contentSize.height += 14.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                captionItem.alignment = .center
                
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
            contentSize.height += verticalInset
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .image(id, caption):
            if let image = media[id] as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions
                var filledSize = imageSize.aspectFitted(CGSize(width: boundingWidth - safeInset * 2.0, height: 1200.0))
                
                if fillToWidthAndHeight {
                    filledSize = CGSize(width: boundingWidth - safeInset * 2.0, height: boundingWidth - safeInset * 2.0)
                } else if isCover {
                    filledSize = imageSize.aspectFilled(CGSize(width: boundingWidth - safeInset * 2.0, height: 1.0))
                    if !filledSize.height.isZero {
                        filledSize = filledSize.cropped(CGSize(width: boundingWidth - safeInset * 2.0, height: floor((boundingWidth - safeInset * 2.0) * 3.0 / 5.0)))
                    }
                }
                
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                
                var contentSize = CGSize(width: boundingWidth - safeInset * 2.0, height: 0.0)
                var items: [InstantPageItem] = []
                
                let mediaItem = InstantPageImageItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), webPage: webpage, media: InstantPageMedia(index: mediaIndex, media: image, caption: caption.plainText), interactive: true, roundCorners: false, fit: false)
                
                items.append(mediaItem)
                contentSize.height += filledSize.height
                
                if case .empty = caption {
                } else {
                    contentSize.height += 10.0
                    
                    let styleStack = InstantPageTextStyleStack()
                    setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                    
                    let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                    captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                    captionItem.alignment = .center
                    
                    contentSize.height += captionItem.frame.size.height
                    items.append(captionItem)
                }
                
                return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
            } else {
                return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
            }
        case let .video(id, caption, autoplay, loop):
            if let file = media[id] as? TelegramMediaFile, let dimensions = file.dimensions {
                let imageSize = dimensions
                var filledSize = imageSize.aspectFitted(CGSize(width: boundingWidth - safeInset * 2.0, height: 1200.0))
                
                if fillToWidthAndHeight {
                    filledSize = CGSize(width: boundingWidth - safeInset * 2.0, height: boundingWidth - safeInset * 2.0)
                } else if isCover {
                    filledSize = imageSize.aspectFilled(CGSize(width: boundingWidth - safeInset * 2.0, height: 1.0))
                    if !filledSize.height.isZero {
                        filledSize = filledSize.cropped(CGSize(width: boundingWidth - safeInset * 2.0, height: floor((boundingWidth - safeInset * 2.0) * 3.0 / 5.0)))
                    }
                }
                
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                
                var contentSize = CGSize(width: boundingWidth - safeInset * 2.0, height: 0.0)
                var items: [InstantPageItem] = []
                
                if autoplay {
                    let mediaItem = InstantPagePlayableVideoItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), webPage: webpage, media: InstantPageMedia(index: mediaIndex, media: file, caption: caption.plainText), interactive: true)
                    
                    items.append(mediaItem)
                } else {
                    let mediaItem = InstantPageImageItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), webPage: webpage, media: InstantPageMedia(index: mediaIndex, media: file, caption: caption.plainText), interactive: true, roundCorners: false, fit: false)
                    
                    items.append(mediaItem)
                }
                contentSize.height += filledSize.height
                
                if case .empty = caption {
                } else {
                    contentSize.height += 10.0
                    
                    let styleStack = InstantPageTextStyleStack()
                    setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                    
                    let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                    captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                    captionItem.alignment = .center
                    
                    contentSize.height += captionItem.frame.size.height
                    items.append(captionItem)
                }
                
                return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
            } else {
                return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
            }
        case let .collage(items: innerItems, caption: caption):
            let spacing: CGFloat = 2.0
            let itemsPerRow = 3
            let itemSize = floor((boundingWidth - safeInset * 2.0 - spacing * max(0.0, CGFloat(itemsPerRow - 1))) / CGFloat(itemsPerRow))
            
            var items: [InstantPageItem] = []
            
            var nextItemOrigin = CGPoint(x: 0.0, y: 0.0)
            for subItem in innerItems {
                if nextItemOrigin.x + itemSize > boundingWidth {
                    nextItemOrigin.x = 0.0
                    nextItemOrigin.y += itemSize + spacing
                }
                let subLayout = layoutInstantPageBlock(webpage: webpage, block: subItem, boundingWidth: itemSize, horizontalInset: 0.0, safeInset: 0.0, isCover: false, previousItems: items, fillToWidthAndHeight: true, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat)
                items.append(contentsOf: subLayout.flattenedItemsWithOrigin(nextItemOrigin))
                nextItemOrigin.x += itemSize + spacing
            }
            
            var contentSize = CGSize(width: boundingWidth - safeInset * 2.0, height: nextItemOrigin.y + itemSize)
            
            if case .empty = caption {
            } else {
                contentSize.height += 10.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - safeInset * 2.0 - horizontalInset * 2.0)
                captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                captionItem.alignment = .center
                
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .postEmbed(url, webpageId, avatarId, author, date, blocks, caption):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            let lineInset: CGFloat = 20.0
            let verticalInset: CGFloat = 4.0
            let itemSpacing: CGFloat = 10.0
            var avatarInset: CGFloat = 0.0
            var avatarVerticalInset: CGFloat = 0.0
            
            contentSize.height += verticalInset
            
            var items: [InstantPageItem] = []
            
            if !author.isEmpty {
                let avatar: TelegramMediaImage? = avatarId.flatMap { media[$0] as? TelegramMediaImage }
                if let avatar = avatar {
                    let avatarItem = InstantPageImageItem(frame: CGRect(origin: CGPoint(x: horizontalInset + lineInset + 1.0, y: contentSize.height - 2.0), size: CGSize(width: 50.0, height: 50.0)), webPage: webpage, media: InstantPageMedia(index: -1, media: avatar, caption: ""), interactive: false, roundCorners: true, fit: false)
                    items.append(avatarItem)
                    
                    avatarInset += 62.0
                    avatarVerticalInset += 6.0
                    if date == 0 {
                        avatarVerticalInset += 11.0
                    }
                }
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
                styleStack.push(.bold)
                
                let textItem = layoutTextItemWithString(attributedStringForRichText(.plain(author), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset - avatarInset)
                textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + lineInset + avatarInset, dy: contentSize.height + avatarVerticalInset)
                items.append(textItem)
                
                contentSize.height += textItem.frame.size.height + avatarVerticalInset
            }
            if date != 0 {
                if items.count != 0 {
                    contentSize.height += itemSpacing
                }
                
                let dateString = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(date)), dateStyle: .long, timeStyle: .none)
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let textItem = layoutTextItemWithString(attributedStringForRichText(.plain(dateString), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset - avatarInset)
                textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + lineInset + avatarInset, dy: contentSize.height)
                items.append(textItem)
                
                contentSize.height += textItem.frame.size.height
            }
            
            if items.count != 0 {
                contentSize.height += itemSpacing
            }
            
            var previousBlock: InstantPageBlock?
            for subBlock in blocks {
                let subLayout = layoutInstantPageBlock(webpage: webpage, block: subBlock, boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset, horizontalInset: 0.0, safeInset: 0.0, isCover: false, previousItems: items, fillToWidthAndHeight: false, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat)
                
                let spacing = spacingBetweenBlocks(upper: previousBlock, lower: subBlock)
                let blockItems = subLayout.flattenedItemsWithOrigin(CGPoint(x: horizontalInset + lineInset, y: contentSize.height + spacing))
                items.append(contentsOf: blockItems)
                contentSize.height += subLayout.contentSize.height + spacing
                previousBlock = subBlock
            }
            
            contentSize.height += verticalInset
            
            items.append(InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: horizontalInset, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shapeFrame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shape: .roundLine, color: theme.textCategories.paragraph.color))
            
            if case .empty = caption {
            } else {
                contentSize.height += 14.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                captionItem.alignment = .center
                
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .slideshow(items: subItems, caption: caption):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            var itemMedias: [InstantPageMedia] = []
            
            for subBlock in subItems {
                switch subBlock {
                    case let .image(id, caption):
                        if let image = media[id] as? TelegramMediaImage, let imageSize = largestImageRepresentation(image.representations)?.dimensions {
                            let mediaIndex = mediaIndexCounter
                            mediaIndexCounter += 1
                            
                            let filledSize = imageSize.fitted(CGSize(width: boundingWidth, height: 1200.0))
                            contentSize.height = max(contentSize.height, filledSize.height)
                            
                            itemMedias.append(InstantPageMedia(index: mediaIndex, media: image, caption: caption.plainText))
                        }
                        break
                    default:
                        break
                }
            }
            
            items.append(InstantPageSlideshowItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height)), webPage: webpage, medias: itemMedias))
            
            if case .empty = caption {
            } else {
                contentSize.height += 14.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                captionItem.alignment = .center
                
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
        
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .webEmbed(url, html, dimensions, caption, stretchToWidth, allowScrolling, coverId):
            var embedBoundingWidth = boundingWidth - horizontalInset * 2.0
            if stretchToWidth {
                embedBoundingWidth = boundingWidth
            }
            let size: CGSize
            if dimensions.width.isLessThanOrEqualTo(0.0) {
                size = CGSize(width: embedBoundingWidth, height: dimensions.height)
            } else {
                size = dimensions.aspectFitted(CGSize(width: embedBoundingWidth, height: embedBoundingWidth))
            }
            
            var items: [InstantPageItem] = []
            
            let item = InstantPageWebEmbedItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - size.width) / 2.0), y: 0.0), size: size), url: url, html: html, enableScrolling: allowScrolling)
            items.append(item)
            
            var contentSize = item.frame.size
            
            if case .empty = caption {
            } else {
                contentSize.height += 10.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                captionItem.alignment = .center
                
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .channelBanner(peer):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            var rtl = false
            if let previousItem = previousItems.last as? InstantPageTextItem, previousItem.containsRTL {
                rtl = true
            }
            
            if let peer = peer {
                let item = InstantPagePeerReferenceItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: 40.0)), initialPeer: peer, rtl: rtl)
                items.append(item)
                contentSize.height += 40.0
            }
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .anchor(name):
            let item = InstantPageAnchorItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: 0.0)), anchor: name)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .audio(id: audioId, caption: caption):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            if let file = media[audioId] as? TelegramMediaFile {
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                let item = InstantPageAudioItem(frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: boundingWidth, height: 48.0)), media: InstantPageMedia(index: mediaIndex, media: file, caption: ""), webpage: webpage)
                
                contentSize.height += item.frame.size.height
                items.append(item)
                
                if case .empty = caption {
                } else {
                    contentSize.height += 10.0
                    
                    let styleStack = InstantPageTextStyleStack()
                    setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                    
                    let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                    captionItem.frame = captionItem.frame.offsetBy(dx: floor(boundingWidth - captionItem.frame.size.width) / 2.0, dy: contentSize.height)
                    captionItem.alignment = .center
                    
                    contentSize.height += captionItem.frame.size.height
                    items.append(captionItem)
                }
            }
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        default:
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
    }
}

func instantPageLayoutForWebPage(_ webPage: TelegramMediaWebpage, boundingWidth: CGFloat, safeInset: CGFloat, strings: PresentationStrings, theme: InstantPageTheme, dateTimeFormat: PresentationDateTimeFormat) -> InstantPageLayout {
    var maybeLoadedContent: TelegramMediaWebpageLoadedContent?
    if case let .Loaded(content) = webPage.content {
        maybeLoadedContent = content
    }
    
    guard let loadedContent = maybeLoadedContent, let instantPage = loadedContent.instantPage else {
        return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
    }
    
    let pageBlocks = instantPage.blocks
    var contentSize = CGSize(width: boundingWidth, height: 0.0)
    var items: [InstantPageItem] = []
    
    var media = instantPage.media
    if let image = loadedContent.image, let id = image.id {
        media[id] = image
    }
    
    var mediaIndexCounter: Int = 0
    var embedIndexCounter: Int = 0
    
    var previousBlock: InstantPageBlock?
    for block in pageBlocks {
        let blockLayout = layoutInstantPageBlock(webpage: webPage, block: block, boundingWidth: boundingWidth, horizontalInset: 17.0 + safeInset, safeInset: safeInset, isCover: false, previousItems: items, fillToWidthAndHeight: false, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat)
        let spacing = spacingBetweenBlocks(upper: previousBlock, lower: block)
        let blockItems = blockLayout.flattenedItemsWithOrigin(CGPoint(x: 0.0, y: contentSize.height + spacing))
        items.append(contentsOf: blockItems)
        if CGFloat(0.0).isLess(than: blockLayout.contentSize.height) {
            contentSize.height += blockLayout.contentSize.height + spacing
            previousBlock = block
        }
    }
    
    let closingSpacing = spacingBetweenBlocks(upper: previousBlock, lower: nil)
    contentSize.height += closingSpacing
    
    return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
}

/*+ (TGInstantPageLayout *)makeLayoutForWebPage:(TGWebPageMediaAttachment *)webPage boundingWidth:(CGFloat)boundingWidth {
    
    NSInteger mediaIndexCounter = 0;
    
    TGInstantPageBlock *previousBlock = nil;
    for (TGInstantPageBlock *block in pageBlocks) {
        TGInstantPageLayout *blockLayout = [self layoutBlock:block boundingWidth:boundingWidth horizontalInset:17.0f isCover:false fillToWidthAndHeight:false images:images videos:webPage.instantPage.videos mediaIndexCounter:&mediaIndexCounter];
        CGFloat spacing = spacingBetweenBlocks(previousBlock, block);
        NSArray *blockItems = [blockLayout flattenedItemsWithOrigin:CGPointMake(0.0f, contentSize.height + spacing)];
        [items addObjectsFromArray:blockItems];
        contentSize.height += blockLayout.contentSize.height + spacing;
        previousBlock = block;
    }
    CGFloat closingSpacing = spacingBetweenBlocks(previousBlock, nil);
    contentSize.height += closingSpacing;
    
    {
        CGFloat height = CGCeil([TGInstantPageFooterButtonView heightForWidth:boundingWidth]);
        
        TGInstantPageFooterButtonItem *item = [[TGInstantPageFooterButtonItem alloc] initWithFrame:CGRectMake(0.0f, contentSize.height, boundingWidth, height)];
        [items addObject:item];
        contentSize.height += item.frame.size.height;
    }
    
    return [[TGInstantPageLayout alloc] initWithOrigin:CGPointZero contentSize:contentSize items:items];
}*/


