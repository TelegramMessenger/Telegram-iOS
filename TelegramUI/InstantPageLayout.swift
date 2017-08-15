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
            item.frame = item.frame.offsetBy(dx: origin.x, dy: origin.y)
            return item
        })
    }
}

func layoutInstantPageBlock(_ block: InstantPageBlock, boundingWidth: CGFloat, horizontalInset: CGFloat, isCover: Bool,  previousItems: [InstantPageItem], fillToWidthAndHeight: Bool, media: [MediaId: Media], mediaIndexCounter: inout Int, embedIndexCounter: inout Int, theme: InstantPageTheme) -> InstantPageLayout {
    switch block {
        case let .cover(block):
            return layoutInstantPageBlock(block, boundingWidth: boundingWidth, horizontalInset: horizontalInset, isCover: true, previousItems:previousItems, fillToWidthAndHeight: fillToWidthAndHeight, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, theme: theme)
        case let .title(text):
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(28.0))
            styleStack.push(.fontSerif(true))
            styleStack.push(.lineSpacingFactor(0.685))
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .subtitle(text):
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(17.0))
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .authorDate(author: author, date: date):
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(15.0))
            styleStack.push(.textColor(UIColor(rgb: 0x79828b)))
            var text: RichText?
            if case .empty = author {
                if date != 0 {
                    let dateStringPlain = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(date)), dateStyle: .long, timeStyle: .none)
                    text = RichText.plain(dateStringPlain)
                }
            } else {
                let dateStringPlain = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(date)), dateStyle: .long, timeStyle: .none)
                let dateText = RichText.plain(dateStringPlain)
                
                if date != 0 {
                    let formatString = NSLocalizedString("InstantPage.AuthorAndDateTitle", comment: "")
                    let authorRange = formatString.range(of: "%1$@")!
                    let dateRange = formatString.range(of: "%2$@")!
                    
                    if authorRange.lowerBound < dateRange.lowerBound {
                        let byPart = formatString.substring(to: authorRange.lowerBound)
                        let middlePart = formatString.substring(with: authorRange.upperBound ..< dateRange.lowerBound)
                        let endPart = formatString.substring(from: dateRange.upperBound)
                        
                        text = .concat([.plain(byPart), author, .plain(middlePart), dateText, .plain(endPart)])
                    } else {
                        let beforePart = formatString.substring(to: dateRange.lowerBound)
                        let middlePart = formatString.substring(with: dateRange.upperBound ..< authorRange.lowerBound)
                        let endPart = formatString.substring(from: authorRange.upperBound)
                        
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
            styleStack.push(.fontSize(24.0))
            styleStack.push(.fontSerif(true))
            styleStack.push(.lineSpacingFactor(0.685))
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .subheader(text):
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(19.0))
            styleStack.push(.fontSerif(true))
            styleStack.push(.lineSpacingFactor(0.685))
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .paragraph(text):
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(17.0))
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case let .preformatted(text):
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(16.0))
            styleStack.push(.fontFixed(true))
            styleStack.push(.lineSpacingFactor(0.685))
            let backgroundInset: CGFloat = 14.0
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - backgroundInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: backgroundInset)
            let backgroundItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: item.frame.size.height + backgroundInset * 2.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: boundingWidth, height: item.frame.size.height + backgroundInset * 2.0)), shape: .rect, color: UIColor(rgb: 0xF5F8FC))
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(width: boundingWidth, height: item.frame.size.height + backgroundInset * 2.0), items: [backgroundItem, item])
        case let .footer(text):
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(15.0))
            let item = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
            item.frame = item.frame.offsetBy(dx: horizontalInset, dy: 0.0)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        case .divider:
            let lineWidth = floor(boundingWidth / 2.0)
            let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - lineWidth) / 2.0), y: 0.0), size: CGSize(width: lineWidth, height: 1.0)), shapeFrame: CGRect(origin: CGPoint(), size: CGSize(width: lineWidth, height: 1.0)), shape: .rect, color: UIColor(rgb: 0x79828b))
            return InstantPageLayout(origin: CGPoint(), contentSize: shapeItem.frame.size, items: [shapeItem])
        case let .list(contentItems, ordered):
            var contentSize = CGSize(width: boundingWidth, height: 0.0)
            var maxIndexWidth: CGFloat = 0.0
            var listItems: [InstantPageItem] = []
            var indexItems: [InstantPageItem] = []
            for i in 0 ..< contentItems.count {
                if ordered {
                    let styleStack = InstantPageTextStyleStack()
                    styleStack.push(.fontSize(17.0))
                    let textItem = layoutTextItemWithString(attributedStringForRichText(.plain("\(i + 1)."), styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0)
                    if let line = textItem.lines.first {
                        maxIndexWidth = max(maxIndexWidth, line.frame.size.width)
                    }
                    indexItems.append(textItem)
                } else {
                    let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 6.0, height: 12.0)), shapeFrame: CGRect(origin: CGPoint(x: 0.0, y: 3.0), size: CGSize(width: 6.0, height: 6.0)), shape: .ellipse, color: UIColor.black)
                    indexItems.append(shapeItem)
                }
            }
            let indexSpacing: CGFloat = ordered ? 7.0 : 20.0
            for i in 0 ..< contentItems.count {
                if (i != 0) {
                    contentSize.height += 20.0
                }
                let styleStack = InstantPageTextStyleStack()
                styleStack.push(.fontSize(17.0))
                
                let textItem = layoutTextItemWithString(attributedStringForRichText(contentItems[i], styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - indexSpacing - maxIndexWidth)
                textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + indexSpacing + maxIndexWidth, dy:  contentSize.height)
                
                contentSize.height += textItem.frame.size.height
                indexItems[i].frame = indexItems[i].frame.offsetBy(dx: horizontalInset, dy: textItem.frame.origin.y)
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
            styleStack.push(.fontSize(17.0))
            styleStack.push(.fontSerif(true))
            styleStack.push(.italic)
            
            let textItem = layoutTextItemWithString(attributedStringForRichText(text, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset)
            textItem.frame = textItem.frame.offsetBy(dx: horizontalInset + lineInset, dy: contentSize.height)
            
            contentSize.height += textItem.frame.size.height
            items.append(textItem)
            
            if case .empty = caption {
            } else {
                contentSize.height += 14.0
                
                let styleStack = InstantPageTextStyleStack()
                styleStack.push(.fontSize(15.0))
                
                let captionItem = layoutTextItemWithString(attributedStringForRichText(caption, styleStack: styleStack), boundingWidth: boundingWidth - horizontalInset * 2.0 - lineInset)
                captionItem.frame = captionItem.frame.offsetBy(dx: horizontalInset + lineInset, dy: contentSize.height)
                
                contentSize.height += captionItem.frame.size.height
                items.append(captionItem)
            }
            contentSize.height += verticalInset
            
            let shapeItem = InstantPageShapeItem(frame: CGRect(origin: CGPoint(x: horizontalInset, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shapeFrame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 3.0, height: contentSize.height)), shape: .roundLine, color: UIColor.black)
            
            items.append(shapeItem)
            
            return InstantPageLayout(origin: CGPoint(), contentSize: contentSize, items: items)
        case let .pullQuote(text, caption):
            let verticalInset: CGFloat = 4.0
            var contentSize = CGSize(width: boundingWidth, height: verticalInset)
            
            var items: [InstantPageItem] = []
            
            let styleStack = InstantPageTextStyleStack()
            styleStack.push(.fontSize(17.0))
            styleStack.push(.fontSerif(true))
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
                styleStack.push(.fontSize(15.0))
                
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
                var filledSize = imageSize.aspectFitted(CGSize(width: boundingWidth, height: 1200.0))
                
                if fillToWidthAndHeight {
                    filledSize = CGSize(width: boundingWidth, height: boundingWidth)
                } else if isCover {
                    filledSize = imageSize.aspectFilled(CGSize(width: boundingWidth, height: 1.0))
                    if !filledSize.height.isZero {
                        filledSize = filledSize.cropped(CGSize(width: boundingWidth, height: floor(boundingWidth * 3.0 / 5.0)))
                    }
                }
                
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                
                var contentSize = CGSize(width: boundingWidth, height: 0.0)
                var items: [InstantPageItem] = []
                
                let mediaItem = InstantPageMediaItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), media: InstantPageMedia(index: mediaIndex, media: image, caption: caption.plainText), arguments: InstantPageMediaArguments.image(interactive: true, roundCorners: false, fit: false))
                
                items.append(mediaItem)
                contentSize.height += filledSize.height
                
                if case .empty = caption {
                } else {
                    contentSize.height += 10.0
                    
                    let styleStack = InstantPageTextStyleStack()
                    styleStack.push(.fontSize(15.0))
                    
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
            let item = InstantPageWebEmbedItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - size.width) / 2.0), y: 0.0), size: size), url: url, html: html, enableScrolling: allowScrolling)
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
        default:
            return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
    }
}

func instantPageLayoutForWebPage(_ webPage: TelegramMediaWebpage, boundingWidth: CGFloat) -> InstantPageLayout {
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
    let theme = InstantPageTheme()
    
    var previousBlock: InstantPageBlock?
    for block in pageBlocks {
        let blockLayout = layoutInstantPageBlock(block, boundingWidth: boundingWidth, horizontalInset: 17.0, isCover: false, previousItems: items, fillToWidthAndHeight: false, media: media, mediaIndexCounter: &mediaIndexCounter, embedIndexCounter: &embedIndexCounter, theme: theme)
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


