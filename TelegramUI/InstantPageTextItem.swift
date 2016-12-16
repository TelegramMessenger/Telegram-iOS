import Foundation
import TelegramCore

struct InstantPageTextUrlItem {
    let frame: CGRect
    let item: AnyObject
}

struct InstantPageTextStrikethroughItem {
    let frame: CGRect
}

final class InstantPageTextLine {
    let line: CTLine
    let frame: CGRect
    let urlItems: [InstantPageTextUrlItem]
    let strikethroughItems: [InstantPageTextStrikethroughItem]
    
    init(line: CTLine, frame: CGRect, urlItems: [InstantPageTextUrlItem], strikethroughItems: [InstantPageTextStrikethroughItem]) {
        self.line = line
        self.frame = frame
        self.urlItems = urlItems
        self.strikethroughItems = strikethroughItems
    }
}

final class InstantPageTextItem: InstantPageItem {
    let lines: [InstantPageTextLine]
    let hasLinks: Bool
    var frame: CGRect
    var alignment: NSTextAlignment = .left
    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = false
    
    init(frame: CGRect, lines: [InstantPageTextLine]) {
        self.frame = frame
        self.lines = lines
        var hasLinks = false
        for line in lines {
            if !line.urlItems.isEmpty {
                hasLinks = true
            }
        }
        self.hasLinks = hasLinks
    }
    
    func drawInTile(context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        context.translateBy(x: self.frame.minX, y: self.frame.minY)
        
        let clipRect = context.boundingBoxOfClipPath
        
        let upperOriginBound = clipRect.minY - 10.0
        let lowerOriginBound = clipRect.maxY + 10.0
        let boundsWidth = self.frame.size.width
        
        for line in self.lines {
            let lineFrame = line.frame
            if lineFrame.maxY < upperOriginBound || lineFrame.minY > lowerOriginBound {
                continue
            }
            
            var lineOrigin = lineFrame.origin
            if self.alignment == .center {
                lineOrigin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            }
            
            context.textPosition = CGPoint(x: lineOrigin.x, y: lineOrigin.y + lineFrame.size.height)
            CTLineDraw(line.line, context)
            
            if !line.strikethroughItems.isEmpty {
                for item in line.strikethroughItems {
                    context.fill(CGRect(x: item.frame.minX, y: item.frame.minY + floor((lineFrame.size.height / 2.0) + 1.0), width: item.frame.size.width, height: 1.0))
                }
            }
        }
        
        context.restoreGState()
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func node(account: Account) -> InstantPageNode? {
        return nil
    }
    
    func matchesNode(_ node: InstantPageNode) -> Bool {
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}

/*


static TGInstantPageLinkSelectionView *selectionViewFromFrames(NSArray<NSValue *> *frames, CGPoint origin, id urlItem) {
    CGRect frame = CGRectMake(0.0f, 0.0f, 0.0f, 0.0f);
    bool first = true;
    for (NSValue *rectValue in frames) {
        CGRect rect = [rectValue CGRectValue];
        if (first) {
            first = false;
            frame = rect;
        } else {
            frame = CGRectUnion(rect, frame);
        }
    }
    NSMutableArray *adjustedFrames = [[NSMutableArray alloc] init];
    for (NSValue *rectValue in frames) {
        CGRect rect = [rectValue CGRectValue];
        rect.origin.x -= frame.origin.x;
        rect.origin.y -= frame.origin.y;
        [adjustedFrames addObject:[NSValue valueWithCGRect:rect]];
    }
    return [[TGInstantPageLinkSelectionView alloc] initWithFrame:CGRectOffset(frame, origin.x, origin.y) rects:adjustedFrames urlItem:urlItem];
    }
    
    - (NSArray<TGInstantPageLinkSelectionView *> *)linkSelectionViews {
        if (_hasLinks) {
            NSMutableArray<TGInstantPageLinkSelectionView *> *views = [[NSMutableArray alloc] init];
            NSMutableArray<NSValue *> *currentLinkFrames = [[NSMutableArray alloc] init];
            id currentUrlItem = nil;
            for (TGInstantPageTextLine *line in _lines) {
                if (line.urlItems != nil) {
                    for (TGInstantPageTextUrlItem *urlItem in line.urlItems) {
                        if (currentUrlItem == urlItem.item) {
                        } else {
                            if (currentLinkFrames.count != 0) {
                                [views addObject:selectionViewFromFrames(currentLinkFrames, self.frame.origin, currentUrlItem)];
                            }
                            [currentLinkFrames removeAllObjects];
                            currentUrlItem = urlItem.item;
                        }
                        CGPoint lineOrigin = line.frame.origin;
                        if (_alignment == NSTextAlignmentCenter) {
                            lineOrigin.x = CGFloor((self.frame.size.width - line.frame.size.width) / 2.0f);
                        }
                        [currentLinkFrames addObject:[NSValue valueWithCGRect:CGRectOffset(urlItem.frame, lineOrigin.x, 0.0)]];
                    }
                } else if (currentUrlItem != nil) {
                    if (currentLinkFrames.count != 0) {
                        [views addObject:selectionViewFromFrames(currentLinkFrames, self.frame.origin, currentUrlItem)];
                    }
                    [currentLinkFrames removeAllObjects];
                    currentUrlItem = nil;
                }
            }
            if (currentLinkFrames.count != 0 && currentUrlItem != nil) {
                [views addObject:selectionViewFromFrames(currentLinkFrames, self.frame.origin, currentUrlItem)];
            }
            return views;
        }
        return nil;
}

@end*/

func attributedStringForRichText(_ text: RichText, styleStack: InstantPageTextStyleStack) -> NSAttributedString {
    switch text {
        case .empty:
            return NSAttributedString(string: "", attributes: styleStack.textAttributes())
        case let .plain(string):
            return NSAttributedString(string: string, attributes: styleStack.textAttributes())
        case let .bold(text):
            styleStack.push(.bold)
            let result = attributedStringForRichText(text, styleStack: styleStack)
            styleStack.pop()
            return result
        case let .italic(text):
            styleStack.push(.italic)
            let result = attributedStringForRichText(text, styleStack: styleStack)
            styleStack.pop()
            return result
        case let .underline(text):
            styleStack.push(.underline)
            let result = attributedStringForRichText(text, styleStack: styleStack)
            styleStack.pop()
            return result
        case let .strikethrough(text):
            styleStack.push(.strikethrough)
            let result = attributedStringForRichText(text, styleStack: styleStack)
            styleStack.pop()
            return result
        case let .fixed(text):
            styleStack.push(.fontFixed(true))
            let result = attributedStringForRichText(text, styleStack: styleStack)
            styleStack.pop()
            return result
        case let .url(text, url, _):
            styleStack.push(.textColor(UIColor(0x007BE8)))
            let result = attributedStringForRichText(text, styleStack: styleStack)
            styleStack.pop()
            styleStack.pop()
            return result
        case let .email(text, _):
            styleStack.push(.bold)
            styleStack.push(.textColor(UIColor(0x007BE8)))
            let result = attributedStringForRichText(text, styleStack: styleStack)
            styleStack.pop()
            styleStack.pop()
            return result
        case let .concat(texts):
            let string = NSMutableAttributedString()
            for text in texts {
                let substring = attributedStringForRichText(text, styleStack: styleStack)
                string.append(substring)
            }
            return string
    }
}

func layoutTextItemWithString(_ string: NSAttributedString, boundingWidth: CGFloat) -> InstantPageTextItem {
    if string.length == 0 {
        return InstantPageTextItem(frame: CGRect(), lines: [])
    }
    
    var lines: [InstantPageTextLine] = []
    guard let font = string.attribute(NSFontAttributeName, at: 0, effectiveRange: nil) as? UIFont else {
        return InstantPageTextItem(frame: CGRect(), lines: [])
    }
    
    var lineSpacingFactor: CGFloat = 1.12
    if let lineSpacingFactorAttribute = string.attribute(InstantPageLineSpacingFactorAttribute, at: 0, effectiveRange: nil) {
        lineSpacingFactor = CGFloat((lineSpacingFactorAttribute as! NSNumber).floatValue)
    }
    
    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let fontAscent = font.ascender
    let fontDescent = font.descender
    
    let fontLineHeight = floor(fontAscent + fontDescent)
    let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
    
    var lastIndex: CFIndex = 0
    var currentLineOrigin = CGPoint()
    
    while true {
        let currentMaxWidth = boundingWidth - currentLineOrigin.x
        let currentLineInset: CGFloat = 0.0
        let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastIndex, Double(currentMaxWidth))
        
        if lineCharacterCount > 0 {
            let line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0)
            
            if line != nil {
                let trailingWhitespace = CGFloat(CTLineGetTrailingWhitespaceWidth(line))
                let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil) + Double(currentLineInset))
                
                var urlItems: [InstantPageTextUrlItem] = []
                var strikethroughItems: [InstantPageTextStrikethroughItem] = []
                
                string.enumerateAttribute(NSStrikethroughStyleAttributeName, in: NSMakeRange(lastIndex, lineCharacterCount), options: [], using: { item, range, _ in
                    if let item = item {
                        let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                        let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                        
                        strikethroughItems.append(InstantPageTextStrikethroughItem(frame: CGRect(x: currentLineOrigin.x + lowerX, y: currentLineOrigin.y, width: upperX - lowerX, height: fontLineHeight)))
                    }
                })
                
                /*__block NSMutableArray<TGInstantPageTextUrlItem *> *urlItems = nil;
                [string enumerateAttribute:(NSString *)TGUrlAttribute inRange:NSMakeRange(lastIndex, lineCharacterCount) options:0 usingBlock:^(id item, NSRange range, __unused BOOL *stop) {
                    if (item != nil) {
                    if (urlItems == nil) {
                    urlItems = [[NSMutableArray alloc] init];
                    }
                    CGFloat lowerX = CGFloor(CTLineGetOffsetForStringIndex(line, range.location, NULL));
                    CGFloat upperX = CGCeil(CTLineGetOffsetForStringIndex(line, range.location + range.length, NULL));
                    [urlItems addObject:[[TGInstantPageTextUrlItem alloc] initWithFrame:CGRectMake(currentLineOrigin.x + lowerX, currentLineOrigin.y, upperX - lowerX, fontLineHeight) item:item]];
                    }
                    }];*/
                
                let textLine = InstantPageTextLine(line: line, frame: CGRect(x: currentLineOrigin.x, y: currentLineOrigin.y, width: lineWidth, height: fontLineHeight), urlItems: urlItems, strikethroughItems: strikethroughItems)
                
                lines.append(textLine)
                
                var rightAligned = false
                
                /*let glyphRuns = CTLineGetGlyphRuns(line)
                if CFArrayGetCount(glyphRuns) != 0 {
                    if (CTRunGetStatus(CFArrayGetValueAtIndex(glyphRuns, 0) as! CTRun).rawValue & CTRunStatus.rightToLeft.rawValue) != 0 {
                        rightAligned = true
                    }
                }*/
                
                //hadRTL |= rightAligned;
                
                currentLineOrigin.x = 0.0;
                currentLineOrigin.y += fontLineHeight + fontLineSpacing
                
                lastIndex += lineCharacterCount
            } else {
                break;
            }
        } else {
            break;
        }
    }
    
    var height: CGFloat = 0.0
    if !lines.isEmpty {
        height = lines.last!.frame.maxY
    }
    
    return InstantPageTextItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: height), lines: lines)
}
