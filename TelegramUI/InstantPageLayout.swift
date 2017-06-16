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

func layoutInstantPageBlock(_ block: InstantPageBlock, boundingWidth: CGFloat, horizontalInset: CGFloat, isCover: Bool, fillToWidthAndHeight: Bool, media: [MediaId: Media], mediaIndexCounter: inout Int) -> InstantPageLayout {
    switch block {
        case let .cover(block):
            return layoutInstantPageBlock(block, boundingWidth: boundingWidth, horizontalInset: horizontalInset, isCover: true, fillToWidthAndHeight: fillToWidthAndHeight, media: media, mediaIndexCounter: &mediaIndexCounter)
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
            return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [backgroundItem, item])
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
                return InstantPageLayout(origin: CGPoint(), contentSize: item.frame.size, items: [item])
            } else {
                return InstantPageLayout(origin: CGPoint(), contentSize: CGSize(), items: [])
            }
        case let .image(id, caption):
            if let image = media[id] as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions
                let filledSize = imageSize.aspectFitted(CGSize(width: boundingWidth, height: 1200.0))
                let mediaIndex = mediaIndexCounter
                mediaIndexCounter += 1
                
                let mediaItem = InstantPageMediaItem(frame: CGRect(origin: CGPoint(x: floor((boundingWidth - filledSize.width) / 2.0), y: 0.0), size: filledSize), media: InstantPageMedia(index: mediaIndex, media: image, caption: nil), arguments: InstantPageMediaArguments.image(interactive: true, roundCorners: false, fit: false))
                return InstantPageLayout(origin: CGPoint(), contentSize: mediaItem.frame.size, items: [mediaItem])
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


/*
 
 if ([block isKindOfClass:[TGInstantPageBlockPhoto class]]) {
 TGInstantPageBlockPhoto *photoBlock = (TGInstantPageBlockPhoto *)block;
 TGImageMediaAttachment *imageMedia = images[@(photoBlock.photoId)];
 if (imageMedia != nil) {
 CGSize imageSize = CGSizeZero;
 if ([imageMedia.imageInfo imageUrlForLargestSize:&imageSize] != nil) {
 CGSize filledSize = TGFitSize(imageSize, CGSizeMake(boundingWidth, 1200.0));
 if (fillToWidthAndHeight) {
 filledSize = CGSizeMake(boundingWidth, boundingWidth);
 } else if (isCover) {
 filledSize = TGScaleToFill(imageSize, CGSizeMake(boundingWidth, 1.0f));
 if (filledSize.height > FLT_EPSILON) {
 filledSize = TGCropSize(filledSize, CGSizeMake(boundingWidth, CGFloor(boundingWidth * 3.0f / 5.0f)));
 }
 }
 
 NSMutableArray *items = [[NSMutableArray alloc] init];
 
 NSInteger mediaIndex = *mediaIndexCounter;
 (*mediaIndexCounter)++;
 
 CGSize contentSize = CGSizeMake(boundingWidth, 0.0f);
 TGImageMediaAttachment *mediaWithCaption = [imageMedia copy];
 mediaWithCaption.caption = richPlainText(photoBlock.caption);
 TGInstantPageMediaItem *mediaItem = [[TGInstantPageMediaItem alloc] initWithFrame:CGRectMake(CGFloor((boundingWidth - filledSize.width) / 2.0f), 0.0f, filledSize.width, filledSize.height) media:[[TGInstantPageMedia alloc] initWithIndex:mediaIndex media:mediaWithCaption] arguments:[[TGInstantPageImageMediaArguments alloc] initWithInteractive:true roundCorners:false fit:false]];
 [items addObject:mediaItem];
 contentSize.height += filledSize.height;
 
 if (photoBlock.caption != nil) {
 contentSize.height += 10.0f;
 TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
 [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:15.0]];
 [styleStack pushItem:[[TGInstantPageStyleTextColorItem alloc] initWithColor:UIColorRGB(0x79828B)]];
 TGInstantPageTextItem *captionItem = [self layoutTextItemWithString:[self attributedStringForRichText:photoBlock.caption styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset];
 if (filledSize.width >= boundingWidth - FLT_EPSILON) {
 captionItem.alignment = NSTextAlignmentCenter;
 captionItem.frame = CGRectOffset(captionItem.frame, horizontalInset, contentSize.height);
 } else {
 captionItem.alignment = NSTextAlignmentCenter;
 captionItem.frame = CGRectOffset(captionItem.frame, CGFloor((boundingWidth - captionItem.frame.size.width) / 2.0), contentSize.height);
 }
 contentSize.height += captionItem.frame.size.height;
 [items addObject:captionItem];
 }
 
 return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:contentSize items:items];
 }
 }
 }
 
 */








/*+
 else if ([block isKindOfClass:[TGInstantPageBlockFooter class]]) {
        TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
        [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:15.0]];
        [styleStack pushItem:[[TGInstantPageStyleTextColorItem alloc] initWithColor:UIColorRGB(0x79828B)]];
        TGInstantPageTextItem *item = [self layoutTextItemWithString:[self attributedStringForRichText:((TGInstantPageBlockFooter *)block).text styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset];
        item.frame = CGRectOffset(item.frame, horizontalInset, 0.0f);
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:item.frame.size items:@[item]];
        
    } else if ([block isKindOfClass:[TGInstantPageBlockDivider class]]) {
        CGFloat lineWidth = CGFloor(boundingWidth / 2.0f);
        TGInstantPageShapeItem *shapeItem = [[TGInstantPageShapeItem alloc] initWithFrame:CGRectMake(CGFloor((boundingWidth - lineWidth) / 2.0f), 0.0f, lineWidth, 1.0f) shapeFrame:CGRectMake(0.0f, 0.0f, lineWidth, 1.0f) shape:TGInstantPageShapeRect color:UIColorRGBA(0x79828B, 0.4f)];
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:shapeItem.frame.size items:@[shapeItem]];
    } else if ([block isKindOfClass:[TGInstantPageBlockList class]]) {
        TGInstantPageBlockList *listBlock = (TGInstantPageBlockList *)block;
        CGSize contentSize = CGSizeMake(boundingWidth, 0.0f);
        CGFloat maxIndexWidth = 0.0f;
        NSMutableArray<id<TGInstantPageLayoutItem>> *listItems = [[NSMutableArray alloc] init];
        NSMutableArray<id<TGInstantPageLayoutItem>> *indexItems = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < listBlock.items.count; i++) {
            if (listBlock.ordered) {
                TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
                [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:17.0]];
                
                TGInstantPageTextItem *textItem = [self layoutTextItemWithString:[self attributedStringForRichText:[[TGRichTextPlain alloc] initWithText:[NSString stringWithFormat:@"%d.", (int)i + 1]] styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset];
                maxIndexWidth = MAX(textItem->_lines.firstObject.frame.size.width, maxIndexWidth);
                [indexItems addObject:textItem];
            } else {
                TGInstantPageShapeItem *shapeItem = [[TGInstantPageShapeItem alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 6.0f, 12.0f) shapeFrame:CGRectMake(0.0f, 3.0f, 6.0f, 6.0f) shape:TGInstantPageShapeEllipse color:[UIColor blackColor]];
                [indexItems addObject:shapeItem];
            }
        }
        NSInteger index = -1;
        CGFloat indexSpacing = listBlock.ordered ? 7.0f : 20.0f;
        for (TGRichText *text in listBlock.items) {
            index++;
            if (index != 0) {
                contentSize.height += 20.0f;
            }
            TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
            [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:17.0]];
            TGInstantPageTextItem *textItem = [self layoutTextItemWithString:[self attributedStringForRichText:text styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset - indexSpacing - maxIndexWidth];
            textItem.frame = CGRectOffset(textItem.frame, horizontalInset + indexSpacing + maxIndexWidth, contentSize.height);
            
            contentSize.height += textItem.frame.size.height;
            id<TGInstantPageLayoutItem> indexItem = indexItems[index];
            indexItem.frame = CGRectOffset(indexItem.frame, horizontalInset, textItem.frame.origin.y);
            [listItems addObject:indexItem];
            [listItems addObject:textItem];
        }
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:contentSize items:listItems];
    } else if ([block isKindOfClass:[TGInstantPageBlockBlockQuote class]]) {
        TGInstantPageBlockBlockQuote *quoteBlock = (TGInstantPageBlockBlockQuote *)block;
        CGFloat lineInset = 20.0f;
        CGFloat verticalInset = 4.0f;
        CGSize contentSize = CGSizeMake(boundingWidth, verticalInset);
        
        NSMutableArray<id<TGInstantPageLayoutItem>> *items = [[NSMutableArray alloc] init];
        
        {
            TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
            [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:17.0]];
            [styleStack pushItem:[[TGInstantPageStyleFontSerifItem alloc] initWithSerif:true]];
            [styleStack pushItem:[[TGInstantPageStyleItalicItem alloc] init]];
            
            TGInstantPageTextItem *textItem = [self layoutTextItemWithString:[self attributedStringForRichText:quoteBlock.text styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset - lineInset];
            textItem.frame = CGRectOffset(textItem.frame, horizontalInset + lineInset, contentSize.height);
            
            contentSize.height += textItem.frame.size.height;
            [items addObject:textItem];
        }
        if (quoteBlock.caption != nil) {
            contentSize.height += 14.0f;
            {
                TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
                [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:15.0]];
                [styleStack pushItem:[[TGInstantPageStyleTextColorItem alloc] initWithColor:UIColorRGB(0x79828B)]];
                
                TGInstantPageTextItem *captionItem = [self layoutTextItemWithString:[self attributedStringForRichText:quoteBlock.caption styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset - lineInset];
                captionItem.frame = CGRectOffset(captionItem.frame, horizontalInset + lineInset, contentSize.height);
                
                contentSize.height += captionItem.frame.size.height;
                [items addObject:captionItem];
            }
        }
        contentSize.height += verticalInset;
        [items addObject:[[TGInstantPageShapeItem alloc] initWithFrame:CGRectMake(horizontalInset, 0.0f, 3.0f, contentSize.height) shapeFrame:CGRectMake(0.0f, 0.0f, 3.0f, contentSize.height) shape:TGInstantPageShapeRoundLine color:[UIColor blackColor]]];
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:contentSize items:items];
    } else if ([block isKindOfClass:[TGInstantPageBlockPullQuote class]]) {
        TGInstantPageBlockPullQuote *quoteBlock = (TGInstantPageBlockPullQuote *)block;
        CGFloat verticalInset = 4.0f;
        CGSize contentSize = CGSizeMake(boundingWidth, verticalInset);
        
        NSMutableArray<id<TGInstantPageLayoutItem>> *items = [[NSMutableArray alloc] init];
        
        {
            TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
            [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:17.0]];
            [styleStack pushItem:[[TGInstantPageStyleFontSerifItem alloc] initWithSerif:true]];
            [styleStack pushItem:[[TGInstantPageStyleItalicItem alloc] init]];
            
            TGInstantPageTextItem *textItem = [self layoutTextItemWithString:[self attributedStringForRichText:quoteBlock.text styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset];
            textItem.frame = CGRectOffset(textItem.frame, CGFloor((boundingWidth - textItem.frame.size.width) / 2.0), contentSize.height);
            textItem.alignment = NSTextAlignmentCenter;
            
            contentSize.height += textItem.frame.size.height;
            [items addObject:textItem];
        }
        contentSize.height += 14.0f;
        {
            TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
            [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:15.0]];
            [styleStack pushItem:[[TGInstantPageStyleTextColorItem alloc] initWithColor:UIColorRGB(0x79828B)]];
            
            TGInstantPageTextItem *captionItem = [self layoutTextItemWithString:[self attributedStringForRichText:quoteBlock.caption styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset];
            captionItem.frame = CGRectOffset(captionItem.frame, CGFloor((boundingWidth - captionItem.frame.size.width) / 2.0), contentSize.height);
            captionItem.alignment = NSTextAlignmentCenter;
            
            contentSize.height += captionItem.frame.size.height;
            [items addObject:captionItem];
        }
        contentSize.height += verticalInset;
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:contentSize items:items];
    } else  else if ([block isKindOfClass:[TGInstantPageBlockVideo class]]) {
        TGInstantPageBlockVideo *videoBlock = (TGInstantPageBlockVideo *)block;
        TGVideoMediaAttachment *videoMedia = videos[@(videoBlock.videoId)];
        if (videoMedia != nil) {
            CGSize imageSize = [videoMedia dimensions];
            if (imageSize.width > FLT_EPSILON && imageSize.height > FLT_EPSILON) {
                CGSize filledSize = TGFitSize(imageSize, CGSizeMake(boundingWidth, 1200.0));
                if (fillToWidthAndHeight) {
                    filledSize = CGSizeMake(boundingWidth, boundingWidth);
                } else if (isCover) {
                    filledSize = TGScaleToFill(imageSize, CGSizeMake(boundingWidth, 1.0f));
                    if (filledSize.height > FLT_EPSILON) {
                        filledSize = TGCropSize(filledSize, CGSizeMake(boundingWidth, CGFloor(boundingWidth * 3.0f / 5.0f)));
                    }
                }
                
                NSMutableArray *items = [[NSMutableArray alloc] init];
                
                NSInteger mediaIndex = *mediaIndexCounter;
                (*mediaIndexCounter)++;
                
                CGSize contentSize = CGSizeMake(boundingWidth, 0.0f);
                TGVideoMediaAttachment *videoWithCaption = [videoMedia copy];
                videoWithCaption.caption = richPlainText(videoBlock.caption);
                videoWithCaption.loopVideo = videoBlock.loop;
                TGInstantPageMediaItem *mediaItem = [[TGInstantPageMediaItem alloc] initWithFrame:CGRectMake(CGFloor((boundingWidth - filledSize.width) / 2.0f), 0.0f, filledSize.width, filledSize.height) media:[[TGInstantPageMedia alloc] initWithIndex:mediaIndex media:videoWithCaption] arguments:[[TGInstantPageVideoMediaArguments alloc] initWithInteractive:true autoplay:videoBlock.autoplay || videoBlock.loop]];
                [items addObject:mediaItem];
                contentSize.height += filledSize.height;
                
                if (videoBlock.caption != nil) {
                    contentSize.height += 10.0f;
                    TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
                    [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:15.0]];
                    [styleStack pushItem:[[TGInstantPageStyleTextColorItem alloc] initWithColor:UIColorRGB(0x79828B)]];
                    TGInstantPageTextItem *captionItem = [self layoutTextItemWithString:[self attributedStringForRichText:videoBlock.caption styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset];
                    if (filledSize.width >= boundingWidth - FLT_EPSILON) {
                        captionItem.alignment = NSTextAlignmentCenter;
                        captionItem.frame = CGRectOffset(captionItem.frame, horizontalInset, contentSize.height);
                    } else {
                        captionItem.alignment = NSTextAlignmentCenter;
                        captionItem.frame = CGRectOffset(captionItem.frame, CGFloor((boundingWidth - captionItem.frame.size.width) / 2.0), contentSize.height);
                    }
                    contentSize.height += captionItem.frame.size.height;
                    [items addObject:captionItem];
                }
                
                return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:contentSize items:items];
            }
        }
    } else  else if ([block isKindOfClass:[TGInstantPageBlockSlideshow class]]) {
        TGInstantPageBlockSlideshow *slideshowBlock = (TGInstantPageBlockSlideshow *)block;
        NSMutableArray<TGInstantPageMedia *> *medias = [[NSMutableArray alloc] init];
        CGSize contentSize = CGSizeMake(boundingWidth, 0.0f);
        for (TGInstantPageBlock *subBlock in slideshowBlock.items) {
            if ([subBlock isKindOfClass:[TGInstantPageBlockPhoto class]]) {
                TGInstantPageBlockPhoto *photoBlock = (TGInstantPageBlockPhoto *)subBlock;
                TGImageMediaAttachment *imageMedia = images[@(photoBlock.photoId)];
                if (imageMedia != nil) {
                    CGSize imageSize = CGSizeZero;
                    if ([imageMedia.imageInfo imageUrlForLargestSize:&imageSize] != nil) {
                        TGImageMediaAttachment *mediaWithCaption = [imageMedia copy];
                        mediaWithCaption.caption = richPlainText(photoBlock.caption);
                        NSInteger mediaIndex = *mediaIndexCounter;
                        (*mediaIndexCounter)++;
                        
                        CGSize filledSize = TGFitSize(imageSize, CGSizeMake(boundingWidth, 1200.0f));
                        contentSize.height = MAX(contentSize.height, filledSize.height);
                        [medias addObject:[[TGInstantPageMedia alloc] initWithIndex:mediaIndex media:imageMedia]];
                    }
                }
            }
        }
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:contentSize items:@[[[TGInstantPageSlideshowItem alloc] initWithFrame:CGRectMake(0.0f, 0.0f, boundingWidth, contentSize.height) medias:medias]]];
    } else if ([block isKindOfClass:[TGInstantPageBlockCollage class]]) {
        TGInstantPageBlockCollage *collageBlock = (TGInstantPageBlockCollage *)block;
        CGFloat spacing = 2.0f;
        int itemsPerRow = 3;
        CGFloat itemSize = (boundingWidth - spacing * MAX(0, itemsPerRow - 1)) / itemsPerRow;
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        
        CGPoint nextItemOrigin = CGPointMake(0.0f, 0.0f);
        for (TGInstantPageBlock *subBlock in collageBlock.items) {
            if (nextItemOrigin.x + itemSize > boundingWidth) {
                nextItemOrigin.x = 0.0f;
                nextItemOrigin.y += itemSize + spacing;
            }
            TGInstantPageLayout *subLayout = [self layoutBlock:subBlock boundingWidth:itemSize horizontalInset:0.0f isCover:false fillToWidthAndHeight:true images:images videos:videos mediaIndexCounter:mediaIndexCounter];
            [items addObjectsFromArray:[subLayout flattenedItemsWithOrigin:nextItemOrigin]];
            nextItemOrigin.x += itemSize + spacing;
        }
        
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:CGSizeMake(boundingWidth, nextItemOrigin.y + itemSize) items:items];
    } else if ([block isKindOfClass:[TGInstantPageBlockEmbedPost class]]) {
        TGInstantPageBlockEmbedPost *postBlock = (TGInstantPageBlockEmbedPost *)block;
        
        CGSize contentSize = CGSizeMake(boundingWidth, 0.0f);
        CGFloat lineInset = 20.0f;
        CGFloat verticalInset = 4.0f;
        CGFloat itemSpacing = 10.0f;
        CGFloat avatarInset = 0.0f;
        CGFloat avatarVerticalInset = 0.0f;
        
        contentSize.height += verticalInset;
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        
        if (postBlock.author.length != 0) {
            TGImageMediaAttachment *avatar = postBlock.authorPhotoId == 0 ? nil : images[@(postBlock.authorPhotoId)];
            if (avatar != nil) {
                TGInstantPageMediaItem *avatarItem = [[TGInstantPageMediaItem alloc] initWithFrame:CGRectMake(horizontalInset + lineInset + 1.0f, contentSize.height - 2.0f, 50.0f, 50.0f) media:[[TGInstantPageMedia alloc] initWithIndex:-1 media:avatar] arguments:[[TGInstantPageImageMediaArguments alloc] initWithInteractive:false roundCorners:true fit:false]];
                [items addObject:avatarItem];
                avatarInset += 62.0f;
                avatarVerticalInset += 6.0f;
                if (postBlock.date == 0) {
                    avatarVerticalInset += 11.0f;
                }
            }
            
            TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
            [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:17.0]];
            [styleStack pushItem:[[TGInstantPageStyleBoldItem alloc] init]];
            
            TGInstantPageTextItem *textItem = [self layoutTextItemWithString:[self attributedStringForRichText:[[TGRichTextPlain alloc] initWithText:postBlock.author] styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset - lineInset - avatarInset];
            textItem.frame = CGRectOffset(textItem.frame, horizontalInset + lineInset + avatarInset, contentSize.height + avatarVerticalInset);
            
            contentSize.height += textItem.frame.size.height + avatarVerticalInset;
            [items addObject:textItem];
        }
        if (postBlock.date != 0) {
            if (items.count != 0) {
                contentSize.height += itemSpacing;
            }
            NSString *dateString = [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:postBlock.date] dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
            
            TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
            [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:15.0]];
            [styleStack pushItem:[[TGInstantPageStyleTextColorItem alloc] initWithColor:UIColorRGB(0x838C96)]];
            TGInstantPageTextItem *textItem = [self layoutTextItemWithString:[self attributedStringForRichText:[[TGRichTextPlain alloc] initWithText:dateString] styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset - lineInset - avatarInset];
            textItem.frame = CGRectOffset(textItem.frame, horizontalInset + lineInset + avatarInset, contentSize.height);
            contentSize.height += textItem.frame.size.height;
            if (textItem != nil) {
                [items addObject:textItem];
            }
        }
        
        if (true) {
            if (items.count != 0) {
                contentSize.height += itemSpacing;
            }
            
            TGInstantPageBlock *previousBlock = nil;
            for (TGInstantPageBlock *subBlock in postBlock.blocks) {
                TGInstantPageLayout *subLayout = [self layoutBlock:subBlock boundingWidth:boundingWidth - horizontalInset - horizontalInset - lineInset horizontalInset:0.0f isCover:false fillToWidthAndHeight:false images:images videos:videos mediaIndexCounter:mediaIndexCounter];
                CGFloat spacing = spacingBetweenBlocks(previousBlock, subBlock);
                NSArray *blockItems = [subLayout flattenedItemsWithOrigin:CGPointMake(horizontalInset + lineInset, contentSize.height + spacing)];
                [items addObjectsFromArray:blockItems];
                contentSize.height += subLayout.contentSize.height + spacing;
                previousBlock = subBlock;
            }
        }
        
        contentSize.height += verticalInset;
        
        [items addObject:[[TGInstantPageShapeItem alloc] initWithFrame:CGRectMake(horizontalInset, 0.0f, 3.0f, contentSize.height) shapeFrame:CGRectMake(0.0f, 0.0f, 3.0f, contentSize.height) shape:TGInstantPageShapeRoundLine color:[UIColor blackColor]]];
        
        TGRichText *postCaption = postBlock.caption;
        
        if (postCaption != nil) {
            contentSize.height += 14.0f;
            TGInstantPageStyleStack *styleStack = [[TGInstantPageStyleStack alloc] init];
            [styleStack pushItem:[[TGInstantPageStyleFontSizeItem alloc] initWithSize:15.0]];
            [styleStack pushItem:[[TGInstantPageStyleTextColorItem alloc] initWithColor:UIColorRGB(0x79828B)]];
            TGInstantPageTextItem *captionItem = [self layoutTextItemWithString:[self attributedStringForRichText:postCaption styleStack:styleStack] boundingWidth:boundingWidth - horizontalInset - horizontalInset];
            captionItem.frame = CGRectOffset(captionItem.frame, horizontalInset, contentSize.height);
            contentSize.height += captionItem.frame.size.height;
            [items addObject:captionItem];
        }
        
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:contentSize items:items];
    } else if ([block isKindOfClass:[TGInstantPageBlockAnchor class]]) {
        TGInstantPageBlockAnchor *anchorBlock = (TGInstantPageBlockAnchor *)block;
        return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:CGSizeMake(0.0f, 0.0f) items:@[[[TGInstantPageAnchorItem alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f) anchor:anchorBlock.name]]];
    }
    
    return [[TGInstantPageLayout alloc] initWithOrigin:CGPointMake(0.0f, 0.0f) contentSize:CGSizeMake(0.0f, 0.0f) items:@[]];
}*/

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
    
    var previousBlock: InstantPageBlock?
    for block in pageBlocks {
        let blockLayout = layoutInstantPageBlock(block, boundingWidth: boundingWidth, horizontalInset: 17.0, isCover: false, fillToWidthAndHeight: false, media: media, mediaIndexCounter: &mediaIndexCounter)
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


