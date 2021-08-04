import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import MosaicLayout

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
    stack.push(.markerColor(theme.markerColor))
    stack.push(.linkColor(theme.linkColor))
    stack.push(.linkMarkerColor(theme.linkHighlightColor))
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

func layoutInstantPageBlock(webpage: TelegramMediaWebpage, rtl: Bool, block: InstantPageBlock, boundingWidth: CGFloat, horizontalInset: CGFloat, safeInset: CGFloat, isCover: Bool, previousItems: [InstantPageItem], fillToSize: CGSize?, media: [MediaId: Media], mediaIndexCounter: inout Int, embedIndexCounter: inout Int, detailsIndexCounter: inout Int, theme: InstantPageTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, webEmbedHeights: [Int : CGFloat] = [:], excludeCaptions: Bool) -> InstantPageLayout {
   
    let layoutCaption: (InstantPageCaption, CGSize) -> ([InstantPageItem], CGSize) = { caption, contentSize in
        var items: [InstantPageItem] = []
        var offset = contentSize.height
        var contentSize = CGSize()
        var rtl = rtl
        if case .empty = caption.text {
        } else {
            contentSize.height += 14.0
            offset += 14.0
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
            let (textItem, captionItems, captionContentSize) = layoutTextItemWithString(attributedStringForRichText(caption.text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint(x: horizontalInset, y: offset), media: media, webpage: webpage)
            contentSize.height += captionContentSize.height
            offset += captionContentSize.height
            items.append(contentsOf: captionItems)
            
            rtl = textItem?.containsRTL ?? rtl
        }
        
        if case .empty = caption.credit {
        } else {
            if case .empty = caption.text {
                contentSize.height += 14.0
                offset += 14.0
            } else {
                contentSize.height += 10.0
                offset += 10.0
            }
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .credit, link: false)
            let (_, captionItems, captionContentSize) = layoutTextItemWithString(attributedStringForRichText(caption.credit, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, alignment: rtl ? .right : .natural, offset: CGPoint(x: horizontalInset, y: offset), media: media, webpage: webpage)
            contentSize.height += captionContentSize.height
            offset += captionContentSize.height
            items.append(contentsOf: captionItems)
        }
        if contentSize.height > 0.0 && isCover {
            contentSize.height += 14.0
        }
        return (items, contentSize)
    }
    
    let stringForDate: (Int32) -> String = { date in
        let dateFormatter = DateFormatter()
        dateFormatter.locale = localeWithStrings(strings)
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: Date(timeIntervalSince1970: Double(date)))
    }
    
    switch block {
        case let .cover(block):
            return layoutInstantPageBlock(webpage: webpage, rtl: rtl, block: block, boundingWidth: boundingWidth, horizontalInset: horizontalInset, safeInset: safeInset, isCover: true, previousItems:previousItems, fillToSize: fillToSize, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, detailsIndexCounter: &detailsIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, webEmbedHeights: webEmbedHeights, excludeCaptions: false)
        case let .title(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .header, link: false)
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .subtitle(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .subheader, link: false)
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .authorDate(author: author, date: date):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
            var text: RichText?
            if case .empty = author {
                if date != 0 {
                    text = .plain(stringForDate(date))
                }
            } else {
                if date != 0 {
                    let dateText = RichText.plain(stringForDate(date))
                    let formatString = strings.InstantPage_AuthorAndDateTitle("%1$@", "%2$@").string
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
                var previousItemHasRTL = false
                if let previousItem = previousItems.last as? InstantPageTextItem, previousItem.containsRTL {
                    previousItemHasRTL = true
                }
                let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, alignment: rtl || previousItemHasRTL ? .right : .natural, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
                return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
            } else {
                return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
            }
        case let .kicker(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .kicker, link: false)
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .header(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .header, link: false)
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .subheader(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .subheader, link: false)
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .paragraph(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, horizontalInset: horizontalInset, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .preformatted(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            let backgroundInset: CGFloat = 14.0
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - backgroundInset * 2.0, offset: CGPoint(x: 17.0, y: backgroundInset), media: media, webpage: webpage, opaqueBackground: true)
            let backgroundItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height + backgroundInset * 2.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height + backgroundInset * 2.0)), shape: .rect, color: theme.codeBlockBackgroundColor)
            var allItems: [InstantPageItem] = [backgroundItem]
            allItems.append(contentsOf: items)
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(width: boundingWidth, height: contentSize.height + backgroundInset * 2.0), items: allItems)
        case let .footer(text):
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
            let (_, items, contentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint(x: horizontalInset, y: 0.0), media: media, webpage: webpage)
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case .divider:
            let lineWidth = floor(boundingWidth / 2.0)
            let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - lineWidth) / 2.0), y: 0.0), size: CGSize(width: lineWidth, height: 1.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: 1.0)), shape: .rect, color: theme.textCategories.caption.color)
            return InstantPageLayout(origin: CGPoint(), contentSize: shapeItem.frame.size, items: [shapeItem])
        case let .list(contentItems, ordered):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var maxIndexWidth: CGFloat = 0.0
            var listItems: [InstantPageItem] = []
            var indexItems: [InstantPageItem] = []
            
            var hasNums = false
            if ordered {
                for item in contentItems {
                    if let num = item.num, !num.isEmpty {
                        hasNums = true
                        break
                    }
                }
            }
            
            for i in 0 ..< contentItems.count {
                let item = contentItems[i]
                if ordered {
                    let styleStack = InstantPageTextStyleStack()
                    setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
                    let value: String
                    if hasNums {
                        if let num = item.num {
                            value = "\(num)."
                        } else {
                            value = " "
                        }
                    } else {
                        value = "\(i + 1)."
                    }
                    let (textItem, _, _) = layoutTextItemWithString(attributedStringForRichText(.plain(value), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, offset: CGPoint())
                    if let textItem = textItem, let line = textItem.lines.first {
                        textItem.selectable = false
                        maxIndexWidth = max(maxIndexWidth, line.frame.width)
                        indexItems.append(textItem)
                    }
                } else {
                    let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 6.0, height: 12.0)), shapeFrame: CGRect(origin: CGPoint(x: 0.0, y: 3.0), size: CGSize(width: 6.0, height: 6.0)), shape: .ellipse, color: theme.textCategories.paragraph.color)
                    indexItems.append(shapeItem)
                }
            }
            let indexSpacing: CGFloat = ordered ? 12.0 : 20.0
            for (i, item) in contentItems.enumerated() {
                if (i != 0) {
                    contentSize.height += 18.0
                }
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
                
                var effectiveItem = item
                if case let .blocks(blocks, num) = effectiveItem, blocks.isEmpty {
                    effectiveItem = .text(.plain(" "), num)
                }
                switch effectiveItem {
                    case let .text(text, _):
                        let (textItem, textItems, textItemSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - indexSpacing - maxIndexWidth, offset: CGPoint(x: horizontalInset + indexSpacing + maxIndexWidth, y: contentSize.height), media: media, webpage: webpage)

                        contentSize.height += textItemSize.height
                        let indexItem = indexItems[i]
                        var itemFrame = indexItem.frame
                        
                        var lineMidY: CGFloat = 0.0
                        if let textItem = textItem {
                            if let line = textItem.lines.first {
                                lineMidY = textItem.frame.minY + line.frame.midY
                            } else {
                                lineMidY = textItem.frame.midY
                            }
                        }
                        
                        if let textIndexItem = indexItem as? InstantPageTextItem, let line = textIndexItem.lines.first {
                            itemFrame = itemFrame.offsetBy(dx: horizontalInset + maxIndexWidth - line.frame.width, dy: floorToScreenPixels(lineMidY - (itemFrame.height / 2.0)))
                        } else {
                            itemFrame = itemFrame.offsetBy(dx: horizontalInset, dy: floorToScreenPixels(lineMidY - itemFrame.height / 2.0))
                        }
                        indexItems[i].frame = itemFrame
                        listItems.append(indexItems[i])
                        listItems.append(contentsOf: textItems)
                    case let .blocks(blocks, _):
                        var previousBlock: InstantPageBlock?
                        var originY: CGFloat = contentSize.height
                        for subBlock in blocks {
                            let subLayout = layoutInstantPageBlock(webpage: webpage, rtl: rtl, block: subBlock, boundingWidth: boundingWidth - horizontalInset * 2.0 - indexSpacing - maxIndexWidth, horizontalInset: 0.0, safeInset: 0.0, isCover: false, previousItems: listItems, fillToSize: nil, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, detailsIndexCounter: &detailsIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, webEmbedHeights: webEmbedHeights, excludeCaptions: false)
                            
                            let spacing: CGFloat = previousBlock != nil && subLayout.contentSize.height > 0.0 ? spacingBetweenBlocks(upper: previousBlock, lower: subBlock) : 0.0
                            let blockItems = subLayout.flattenedItemsWithOrigin(CGPoint(x: horizontalInset + indexSpacing + maxIndexWidth, y: contentSize.height + spacing))
                            if previousBlock == nil {
                                originY += spacing
                            }
                            listItems.append(contentsOf: blockItems)
                            contentSize.height += subLayout.contentSize.height + spacing
                            previousBlock = subBlock
                        }
                        let indexItem = indexItems[i]
                        var indexItemFrame = indexItem.frame
                        if let textIndexItem = indexItem as? InstantPageTextItem, let line = textIndexItem.lines.first {
                            indexItemFrame = indexItemFrame.offsetBy(dx: horizontalInset + maxIndexWidth - line.frame.width, dy: originY)
                        } else {
                            indexItemFrame = indexItemFrame.offsetBy(dx: horizontalInset, dy: originY)
                        }
                        indexItems[i].frame = indexItemFrame
                        listItems.append(indexItems[i])
                        break
                    
                    default:
                        break
                }
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
            
            let (_, textItems, textContentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset, offset: CGPoint(x: horizontalInset + lineInset, y: contentSize.height), media: media, webpage: webpage)
            
            contentSize.height += textContentSize.height
            items.append(contentsOf: textItems)
            
            if case .empty = caption {
            } else {
                contentSize.height += 14.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let (_, captionItems, captionContentSize) = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset, offset: CGPoint(x: horizontalInset + lineInset, y: contentSize.height), media: media, webpage: webpage)
                
                contentSize.height += captionContentSize.height
                items.append(contentsOf: captionItems)
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
            
            let (_, textItems, textContentSize) = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, alignment: .center, offset: CGPoint(x: 0.0, y: contentSize.height), media: media, webpage: webpage)
            for var item in textItems {
                item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            }
            
            contentSize.height += textContentSize.height
            items.append(contentsOf: textItems)
            
            if case .empty = caption {
            } else {
                contentSize.height += 14.0
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let (_, captionItems, captionContentSize) = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0, alignment: .center, offset: CGPoint(x: 0.0, y: contentSize.height), media: media, webpage: webpage)
                for var item in textItems {
                    item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
                }
                
                contentSize.height += captionContentSize.height
                items.append(contentsOf: captionItems)
            }
            contentSize.height += verticalInset
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .image(id, caption, url, webpageId):
            if let image = media[id] as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions
                var filledSize = imageSize.cgSize.aspectFitted(CGSize(width: boundingWidth - safeInset * 2.0, height: 1200.0))
                
                if let size = fillToSize {
                    filledSize = size
                } else if isCover {
                    filledSize = imageSize.cgSize.aspectFilled(CGSize(width: boundingWidth - safeInset * 2.0, height: 1.0))
                    if !filledSize.height.isZero {
                        filledSize = filledSize.cropped(CGSize(width: boundingWidth - safeInset * 2.0, height: floor((boundingWidth - safeInset * 2.0) * 3.0 / 5.0)))
                    }
                }
                
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                
                var contentSize = CGSize(width: boundingWidth - safeInset * 2.0, height: 0.0)
                var items: [InstantPageItem] = []
                
                var mediaUrl: InstantPageUrlItem?
                if let url = url {
                    mediaUrl = InstantPageUrlItem(url: url, webpageId: webpageId)
                }
                
                let mediaItem = InstantPageImageItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), webPage: webpage, media: InstantPageMedia(index: mediaIndex, media: image, url: mediaUrl, caption: caption.text, credit: caption.credit), interactive: true, roundCorners: false, fit: false)
                
                items.append(mediaItem)
                contentSize.height += filledSize.height
                
                if !excludeCaptions {
                    let (captionItems, captionSize) = layoutCaption(caption, contentSize)
                    items.append(contentsOf: captionItems)
                    contentSize.height += captionSize.height
                }
                
                return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
            } else {
                return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
            }
        case let .video(id, caption, autoplay, _):
            if let file = media[id] as? TelegramMediaFile, let dimensions = file.dimensions {
                let imageSize = dimensions
                var filledSize = imageSize.cgSize.aspectFitted(CGSize(width: boundingWidth - safeInset * 2.0, height: 1200.0))
                
                if let size = fillToSize {
                    filledSize = size
                } else if isCover {
                    filledSize = imageSize.cgSize.aspectFilled(CGSize(width: boundingWidth - safeInset * 2.0, height: 1.0))
                    if !filledSize.height.isZero {
                        filledSize = filledSize.cropped(CGSize(width: boundingWidth - safeInset * 2.0, height: floor((boundingWidth - safeInset * 2.0) * 3.0 / 5.0)))
                    }
                }
                
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                
                var contentSize = CGSize(width: boundingWidth - safeInset * 2.0, height: 0.0)
                var items: [InstantPageItem] = []
                
                if autoplay {
                    let mediaItem = InstantPagePlayableVideoItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), webPage: webpage, media: InstantPageMedia(index: mediaIndex, media: file, url: nil, caption: caption.text, credit: caption.credit), interactive: true)
                    
                    items.append(mediaItem)
                } else {
                    let mediaItem = InstantPageImageItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), webPage: webpage, media: InstantPageMedia(index: mediaIndex, media: file, url: nil, caption: caption.text, credit: caption.credit), interactive: true, roundCorners: false, fit: false)
                    
                    items.append(mediaItem)
                }
                contentSize.height += filledSize.height
                
                if !excludeCaptions {
                    let (captionItems, captionSize) = layoutCaption(caption, contentSize)
                    items.append(contentsOf: captionItems)
                    contentSize.height += captionSize.height
                }
                
                return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
            } else {
                return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
            }
        case let .collage(innerItems, caption):
            var items: [InstantPageItem] = []
            var itemSizes: [CGSize] = []
            for subItem in innerItems {
                var size = CGSize()
                switch subItem {
                    case let .image(id, _, _, _):
                        if let image = media[id] as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                            size = largest.dimensions.cgSize
                        }
                    case let .video(id, _, _, _):
                        if let file = media[id] as? TelegramMediaFile, let dimensions = file.dimensions {
                            size = dimensions.cgSize
                        }
                    default:
                        break
                }
                itemSizes.append(size)
            }
            let (mosaicLayout, mosaicSize) = chatMessageBubbleMosaicLayout(maxSize: CGSize(width: boundingWidth, height: boundingWidth), itemSizes: itemSizes)
            
            var i = 0
            for subItem in innerItems {
                let frame = mosaicLayout[i].0
                let subLayout = layoutInstantPageBlock(webpage: webpage, rtl: rtl, block: subItem, boundingWidth: frame.width, horizontalInset: 0.0, safeInset: 0.0, isCover: false, previousItems: items, fillToSize: frame.size, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, detailsIndexCounter: &detailsIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, webEmbedHeights: webEmbedHeights, excludeCaptions: true)
                items.append(contentsOf: subLayout.flattenedItemsWithOrigin(frame.origin))
                i += 1
            }
            
            var contentSize = CGSize(width: boundingWidth - safeInset * 2.0, height: mosaicSize.height)
            
            let (captionItems, captionSize) = layoutCaption(caption, contentSize)
            items.append(contentsOf: captionItems)
            contentSize.height += captionSize.height
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .postEmbed(_, _, avatarId, author, date, blocks, caption):
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
                    let avatarItem = InstantPageImageItem(frame: CGRect(origin: CGPoint(x: horizontalInset + lineInset + 1.0, y: contentSize.height - 2.0), size: CGSize(width: 50.0, height: 50.0)), webPage: webpage, media: InstantPageMedia(index: -1, media: avatar, url: nil, caption: nil, credit: nil), interactive: false, roundCorners: true, fit: false)
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
                
                let (_, textItems, textContentSize) = layoutTextItemWithString(attributedStringForRichText(.plain(author), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset - avatarInset, offset: CGPoint(x: horizontalInset + lineInset + avatarInset, y: contentSize.height + avatarVerticalInset), media: media, webpage: webpage)
                items.append(contentsOf: textItems)
                
                contentSize.height += textContentSize.height + avatarVerticalInset
            }
            if date != 0 {
                if items.count != 0 {
                    contentSize.height += itemSpacing
                }
                
                let dateString = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(date)), dateStyle: .long, timeStyle: .none)
                
                let styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
                
                let (_, textItems, textContentSize) = layoutTextItemWithString(attributedStringForRichText(.plain(dateString), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset - avatarInset, offset: CGPoint(x: horizontalInset + lineInset + avatarInset, y: contentSize.height), media: media, webpage: webpage)
                items.append(contentsOf: textItems)
                
                contentSize.height += textContentSize.height
            }
            
            if items.count != 0 {
                contentSize.height += itemSpacing
            }
            
            var previousBlock: InstantPageBlock?
            for subBlock in blocks {
                let subLayout = layoutInstantPageBlock(webpage: webpage, rtl: rtl, block: subBlock, boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset, horizontalInset: 0.0, safeInset: 0.0, isCover: false, previousItems: items, fillToSize: nil, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, detailsIndexCounter: &detailsIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, webEmbedHeights: webEmbedHeights, excludeCaptions: false)
                
                let spacing = spacingBetweenBlocks(upper: previousBlock, lower: subBlock)
                let blockItems = subLayout.flattenedItemsWithOrigin(CGPoint(x: horizontalInset + lineInset, y: contentSize.height + spacing))
                items.append(contentsOf: blockItems)
                contentSize.height += subLayout.contentSize.height + spacing
                previousBlock = subBlock
            }
            
            contentSize.height += verticalInset
            
            items.append(InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: horizontalInset, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shapeFrame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shape: .roundLine, color: theme.textCategories.paragraph.color))
            
            let (captionItems, captionSize) = layoutCaption(caption, contentSize)
            items.append(contentsOf: captionItems)
            contentSize.height += captionSize.height
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .slideshow(items: subItems, caption: caption):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            var itemMedias: [InstantPageMedia] = []
            
            for subBlock in subItems {
                switch subBlock {
                    case let .image(id, caption, url, webpageId):
                        if let image = media[id] as? TelegramMediaImage, let imageSize = largestImageRepresentation(image.representations)?.dimensions {
                            let mediaIndex = mediaIndexCounter
                            mediaIndexCounter += 1
                            
                            let filledSize = imageSize.cgSize.fitted(CGSize(width: boundingWidth, height: 1200.0))
                            contentSize.height = max(contentSize.height, filledSize.height)
                            
                            var mediaUrl: InstantPageUrlItem?
                            if let url = url {
                                mediaUrl = InstantPageUrlItem(url: url, webpageId: webpageId)
                            }
                            itemMedias.append(InstantPageMedia(index: mediaIndex, media: image, url: mediaUrl, caption: caption.text, credit: caption.credit))
                        }
                        break
                    default:
                        break
                }
            }
            
            items.append(InstantPageSlideshowItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: contentSize.height)), webPage: webpage, medias: itemMedias))
            
            let (captionItems, captionSize) = layoutCaption(caption, contentSize)
            items.append(contentsOf: captionItems)
            contentSize.height += captionSize.height
        
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .webEmbed(url, html, dimensions, caption, stretchToWidth, allowScrolling, coverId):
            var embedBoundingWidth = boundingWidth - horizontalInset * 2.0
            if stretchToWidth {
                embedBoundingWidth = boundingWidth
            }
            
            let embedIndex = embedIndexCounter
            embedIndexCounter += 1
            
            let size: CGSize
            if let dimensions = dimensions {
                if dimensions.width <= 0 {
                    size = CGSize(width: embedBoundingWidth, height: dimensions.cgSize.height)
                } else {
                    size = dimensions.cgSize.aspectFitted(CGSize(width: embedBoundingWidth, height: embedBoundingWidth))
                }
            } else {
                if let height = webEmbedHeights[embedIndex] {
                    size = CGSize(width: embedBoundingWidth, height: CGFloat(height))
                } else {
                    size = CGSize(width: embedBoundingWidth, height: 44.0)
                }
            }
            
            var items: [InstantPageItem] = []
            var contentSize: CGSize
            let frame = CGRect(origin: CGPoint(x: floor((boundingWidth - size.width) / 2.0), y: 0.0), size: size)
            let item: InstantPageItem
            if let url = url, let coverId = coverId, let image = media[coverId] as? TelegramMediaImage {
                let loadedContent = TelegramMediaWebpageLoadedContent(url: url, displayUrl: url, hash: 0, type: "video", websiteName: nil, title: nil, text: nil, embedUrl: url, embedType: "video", embedSize: PixelDimensions(size), duration: nil, author: nil, image: image, file: nil, attributes: [], instantPage: nil)
                let content = TelegramMediaWebpageContent.Loaded(loadedContent)
                
                item = InstantPageImageItem(frame: frame, webPage: webpage, media: InstantPageMedia(index: embedIndex, media: TelegramMediaWebpage(webpageId: MediaId(namespace: Namespaces.Media.LocalWebpage, id: -1), content: content), url: nil, caption: nil, credit: nil), attributes: [], interactive: true, roundCorners: false, fit: false)

            } else {
                item = InstantPageWebEmbedItem(frame: frame, url: url, html: html, enableScrolling: allowScrolling)
            }
            items.append(item)
            contentSize = item.frame.size
            
            let (captionItems, captionSize) = layoutCaption(caption, contentSize)
            items.append(contentsOf: captionItems)
            contentSize.height += captionSize.height
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .channelBanner(peer):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            var offset: CGFloat = 0.0
            
            var previousItemHasRTL = false
            if let previousItem = previousItems.last as? InstantPageTextItem {
                if previousItem.containsRTL {
                    previousItemHasRTL = true
                }
                var minY = previousItem.frame.minY
                if let firstItem = previousItems.first {
                    minY = firstItem.frame.maxY
                }
                offset = minY - previousItem.frame.maxY
            }
            if !offset.isZero {
                offset -= 40.0 + 14.0
            }
            
            if let peer = peer {
                let item = InstantPagePeerReferenceItem(frame: CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize(width: boundingWidth, height: 40.0)), initialPeer: peer, safeInset: safeInset, transparent: !offset.isZero, rtl: rtl || previousItemHasRTL)
                items.append(item)
                if offset.isZero {
                    contentSize.height += 40.0
                }
            }
            return InstantPageLayout(origin: CGPoint(x: 0.0, y: offset), contentSize: contentSize, items: items)
        case let .anchor(name):
            let item = InstantPageAnchorItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: 0.0)), anchor: name)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .audio(audioId, caption):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            if let file = media[audioId] as? TelegramMediaFile {
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                let item = InstantPageAudioItem(frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: boundingWidth, height: 48.0)), media: InstantPageMedia(index: mediaIndex, media: file, url: nil, caption: nil, credit: nil), webpage: webpage)
                
                contentSize.height += item.frame.height
                items.append(item)
                
                let (captionItems, captionSize) = layoutCaption(caption, contentSize)
                items.append(contentsOf: captionItems)
                contentSize.height += captionSize.height
            }
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .table(title, rows, bordered, striped):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            var styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .caption, link: false)
            let backgroundInset: CGFloat = 0.0
            let (_, textItems, textContentSize) = layoutTextItemWithString(attributedStringForRichText(title, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - backgroundInset * 2.0, alignment: .center, offset: CGPoint(), media: media, webpage: webpage)
            for var item in textItems {
                item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            }
            items.append(contentsOf: textItems)
            contentSize.height += textContentSize.height + 10.0
            
            styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .table, link: false)
            let tableBoundingWidth = boundingWidth - horizontalInset * 2.0
            let tableItem = layoutTableItem(rtl: rtl, rows: rows, styleStack: styleStack, theme: theme, bordered: bordered, striped: striped, boundingWidth: tableBoundingWidth, horizontalInset: horizontalInset, media: media, webpage: webpage)
            tableItem.frame = tableItem.frame.offsetBy(dx: 0.0, dy: contentSize.height)
            
            contentSize.height += tableItem.frame.height
            items.append(tableItem)
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .details(title, blocks, expanded):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var subitems: [InstantPageItem] = []
            
            let detailsIndex = detailsIndexCounter
            detailsIndexCounter += 1
            
            var subDetailsIndex = 0
            
            var previousBlock: InstantPageBlock?
            for subBlock in blocks {
                let subLayout = layoutInstantPageBlock(webpage: webpage, rtl: rtl, block: subBlock, boundingWidth: boundingWidth, horizontalInset: horizontalInset, safeInset: safeInset, isCover: false, previousItems: subitems, fillToSize: nil, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, detailsIndexCounter: &subDetailsIndex, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, webEmbedHeights: webEmbedHeights, excludeCaptions: false)
                
                let spacing = spacingBetweenBlocks(upper: previousBlock, lower: subBlock)
                let blockItems = subLayout.flattenedItemsWithOrigin(CGPoint(x: 0.0, y: contentSize.height + spacing))
                subitems.append(contentsOf: blockItems)
                contentSize.height += subLayout.contentSize.height + spacing
                previousBlock = subBlock
            }
            
            if !blocks.isEmpty {
                let closingSpacing = spacingBetweenBlocks(upper: previousBlock, lower: nil)
                contentSize.height += closingSpacing
            }
            
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            styleStack.push(.lineSpacingFactor(0.685))
            let detailsItem = layoutDetailsItem(theme: theme, title: attributedStringForRichText(title, styleStack: styleStack), boundingWidth: boundingWidth, items: subitems, contentSize: contentSize, safeInset: safeInset, rtl: rtl, initiallyExpanded: expanded, index: detailsIndex)
            return InstantPageLayout(origin: CGPoint(), contentSize: detailsItem.frame.size, items: [detailsItem])
        
        case let .relatedArticles(title, articles):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var items: [InstantPageItem] = []
            
            let styleStack = InstantPageTextStyleStack()
            setupStyleStack(styleStack, theme: theme, category: .paragraph, link: false)
            styleStack.push(.bold)
            let backgroundInset: CGFloat = 14.0
            let (_, textItems, textContentSize) = layoutTextItemWithString(attributedStringForRichText(title, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - backgroundInset * 2.0, offset: CGPoint(x: horizontalInset, y: backgroundInset), media: media, webpage: webpage, opaqueBackground: true)
            let backgroundItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: textContentSize.height + backgroundInset * 2.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: textContentSize.height + backgroundInset * 2.0)), shape: .rect, color: theme.panelBackgroundColor)
            items.append(backgroundItem)
            items.append(contentsOf: textItems)
            contentSize.height += backgroundItem.frame.height
            
            for (i, article) in articles.enumerated() {
                var cover: TelegramMediaImage?
                if let coverId = article.photoId {
                    cover = media[coverId] as? TelegramMediaImage
                }
                
                var styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .article, link: false)
                let title = attributedStringForRichText(.plain(article.title ?? ""), styleStack: styleStack)
                
                styleStack = InstantPageTextStyleStack()
                setupStyleStack(styleStack, theme: theme, category: .caption, link: false)

                var subtext: String?
                if article.author != nil || article.date != nil {
                    if let author = article.author {
                        if let date = article.date {
                            subtext = strings.InstantPage_RelatedArticleAuthorAndDateTitle(author, stringForDate(date)).string
                        } else {
                            subtext = author
                        }
                    } else if let date = article.date {
                        subtext = stringForDate(date)
                    }
                } else {
                    subtext = article.description
                }
                let description = attributedStringForRichText(.plain(subtext ?? ""), styleStack: styleStack)
                
                let item = layoutArticleItem(theme: theme, webPage: webpage, title: title, description: description, cover: cover, url: article.url, webpageId: article.webpageId, boundingWidth: boundingWidth, rtl: rtl)
                item.frame = item.frame.offsetBy(dx: 0.0, dy: contentSize.height)
                contentSize.height += item.frame.height
                items.append(item)
                
                let inset: CGFloat = i == articles.count - 1 ? 0.0 : 17.0
                let lineSize = CGSize(width: boundingWidth - inset, height: UIScreenPixel)
                let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: rtl || item.rtl ? 0.0 : inset, y: contentSize.height - lineSize.height), size: lineSize), shapeFrame: CGRect(origin: CGPoint(), size: lineSize), shape: .rect, color: theme.controlColor)
                items.append(shapeItem)
            }
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .map(latitude, longitude, zoom, dimensions, caption):
            let imageSize = dimensions
            var filledSize = imageSize.cgSize.aspectFitted(CGSize(width: boundingWidth - safeInset * 2.0, height: 1200.0))
            
            if let size = fillToSize {
                filledSize = size
            } else if isCover {
                filledSize = imageSize.cgSize.aspectFilled(CGSize(width: boundingWidth - safeInset * 2.0, height: 1.0))
                if !filledSize.height.isZero {
                    filledSize = filledSize.cropped(CGSize(width: boundingWidth - safeInset * 2.0, height: floor((boundingWidth - safeInset * 2.0) * 3.0 / 5.0)))
                }
            }
            
            let map = TelegramMediaMap(latitude: latitude, longitude: longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
            let attributes: [InstantPageImageAttribute] = [InstantPageMapAttribute(zoom: zoom, dimensions: dimensions.cgSize)]
            
            var contentSize = CGSize(width: boundingWidth - safeInset * 2.0, height: 0.0)
            var items: [InstantPageItem] = []
            let mediaItem = InstantPageImageItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), webPage: webpage, media: InstantPageMedia(index: -1, media: map, url: nil, caption: caption.text, credit: caption.credit), attributes: attributes, interactive: true, roundCorners: false, fit: false)
            
            items.append(mediaItem)
            contentSize.height += filledSize.height
            
            let (captionItems, captionSize) = layoutCaption(caption, contentSize)
            items.append(contentsOf: captionItems)
            contentSize.height += captionSize.height
        
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        default:
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
    }
}

func instantPageLayoutForWebPage(_ webPage: TelegramMediaWebpage, boundingWidth: CGFloat, safeInset: CGFloat, strings: PresentationStrings, theme: InstantPageTheme, dateTimeFormat: PresentationDateTimeFormat, webEmbedHeights: [Int : CGFloat] = [:]) -> InstantPageLayout {
    var maybeLoadedContent: TelegramMediaWebpageLoadedContent?
    if case let .Loaded(content) = webPage.content {
        maybeLoadedContent = content
    }
    
    guard let loadedContent = maybeLoadedContent, let instantPage = loadedContent.instantPage else {
        return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
    }
    
    let rtl = instantPage.rtl
    let pageBlocks = instantPage.blocks
    var contentSize = CGSize(width: boundingWidth, height: 0.0)
    var items: [InstantPageItem] = []
    
    var media = instantPage.media
    if let image = loadedContent.image, let id = image.id {
        media[id] = image
    }
    if let video = loadedContent.file, let id = video.id {
        media[id] = video
    }
    
    var mediaIndexCounter: Int = 0
    var embedIndexCounter: Int = 0
    var detailsIndexCounter: Int = 0
    
    var previousBlock: InstantPageBlock?
    for block in pageBlocks {
        let blockLayout = layoutInstantPageBlock(webpage: webPage, rtl: rtl, block: block, boundingWidth: boundingWidth, horizontalInset: 17.0 + safeInset, safeInset: safeInset, isCover: false, previousItems: items, fillToSize: nil, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, detailsIndexCounter: &detailsIndexCounter, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, webEmbedHeights: webEmbedHeights, excludeCaptions: false)
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
    
    let feedbackItem = InstantPageFeedbackItem(frame: CGRect(x: 0.0, y: contentSize.height, width: boundingWidth, height: 40.0), webPage: webPage)
    contentSize.height += feedbackItem.frame.height
    items.append(feedbackItem)
    
    return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
}
