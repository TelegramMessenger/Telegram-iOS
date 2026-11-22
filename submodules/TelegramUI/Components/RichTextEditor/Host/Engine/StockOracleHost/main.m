@import UIKit;

#import "IDPrivateUIKit.h"
#import <QuartzCore/QuartzCore.h>

@interface IDStockEnglishUSTextView : UITextView
@end

@implementation IDStockEnglishUSTextView

- (UITextInputMode *)textInputMode {
    for (UITextInputMode *mode in UITextInputMode.activeInputModes) {
        if ([mode.primaryLanguage isEqualToString:@"en-US"]) return mode;
    }
    return super.textInputMode;
}

@end

static NSDictionary<NSString *, id> *IDStockGeometryBoundary(
    UITextView *editor,
    NSDictionary<NSString *, NSNumber *> *selection,
    NSString *scenario) {
    UITextPosition *extent = editor.selectedTextRange.end ?:
        editor.beginningOfDocument;
    NSWritingDirection writingDirection = extent == nil
        ? NSWritingDirectionNatural
        : [editor baseWritingDirectionForPosition:extent
                                       inDirection:UITextStorageDirectionForward];
    return @{
        @"affinity": @(editor.selectionAffinity),
        @"baseWritingDirection": @(writingDirection),
        @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier ?: @"",
        @"firstResponder": @(editor.isFirstResponder),
        @"launchArguments": NSProcessInfo.processInfo.arguments ?: @[],
        @"localeIdentifier": NSLocale.currentLocale.localeIdentifier ?: @"",
        @"primaryLanguage": editor.textInputMode.primaryLanguage ?: @"",
        @"role": @"stock",
        @"scenario": scenario ?: @"none",
        @"selection": selection,
    };
}

static void IDStockInlinePredictionActionNotification(
    CFNotificationCenterRef center, void *observer, CFStringRef name,
    const void *object, CFDictionaryRef userInfo) {
    (void)center;
    (void)observer;
    (void)object;
    (void)userInfo;
    if (!CFEqual(name, CFSTR("com.inputdec.inline-prediction.dismiss"))) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL forwarded =
            IDPrivateDismissInlineTextCompletionForUITesting();
        NSCAssert(forwarded,
                  @"UIKit inline-prediction action ABI is unavailable");
    });
}

static NSString *IDStockText(void) {
    NSString *scenario = NSProcessInfo.processInfo.environment[@"IDStockTouchScenario"];
    if ([scenario hasPrefix:@"ime-"]) {
        return @"Alpha middle omega\nSecond block remains unchanged.";
    }
    if ([scenario isEqualToString:@"inline-prediction-interior"]) {
        return @"Earlier sentence.  \nLater block stays.";
    }
    if ([scenario isEqualToString:@"inline-prediction-before-boundary"]) {
        return @"Earlier sentence. \nLater block stays.";
    }
    if ([scenario isEqualToString:@"inline-prediction-after-boundary"]) {
        return @"Earlier sentence.\n \nLater block stays.";
    }
    if ([scenario isEqualToString:@"autocorrection-interior"]) {
        return @"A quiet  lantern waits.\nSecond block stays unchanged.";
    }
    if ([scenario isEqualToString:@"autocorrection-before-boundary"]) {
        return @"A quiet \nlantern waits.";
    }
    if ([scenario isEqualToString:@"autocorrection-after-boundary"]) {
        return @"A quiet scene.\n lantern waits.";
    }
    if ([scenario isEqualToString:@"inline-formatting-keyboard"]) {
        return @"";
    }
    if ([scenario isEqualToString:@"navigation-horizontal"]) {
        return @"abc אבג\nA👨‍👩‍👧‍👦B\n\n\ntail";
    }
    if ([scenario isEqualToString:@"navigation-vertical"]) {
        return @"abcdefghijklmno\nxy\nabcdefghijklmno";
    }
    if ([scenario isEqualToString:@"navigation-selection"]) {
        return @"alpha\n\nbeta\ngamma";
    }
    if ([scenario isEqualToString:@"geometry-authority"]) {
        return @"alpha beta wrapped words\n\nאבגדה six mixed text\nA👨‍👩‍👧‍👦B composed tail\nfinal block";
    }
    if ([scenario isEqualToString:@"geometry-large-selection"]) {
        NSMutableArray<NSString *> *blocks = [NSMutableArray array];
        for (NSUInteger index = 0; index < 120; index += 1) {
            [blocks addObject:[NSString stringWithFormat:@"block %03lu",
                (unsigned long)index]];
        }
        return [blocks componentsJoinedByString:@"\n"];
    }
    if ([scenario isEqualToString:@"floating-ltr"] ||
        [scenario isEqualToString:@"floating-scroll"]) {
        NSMutableArray<NSString *> *lines = [@[
            @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
            @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
            @"Third paragraph provides a stable lower destination without leaving the viewport.",
        ] mutableCopy];
        if ([scenario isEqualToString:@"floating-scroll"]) {
            for (NSUInteger index = 0; index < 30; index += 1) {
                [lines addObject:[NSString stringWithFormat:
                    @"Floating cursor block %02lu carries enough words to wrap.",
                    (unsigned long)index]];
            }
        }
        return [lines componentsJoinedByString:@"\n"];
    }
    if ([scenario isEqualToString:@"floating-boundary"]) {
        return [@[
            @"alpha beta omega",
            @"delta epsilon zeta",
            @"eta theta iota",
        ] componentsJoinedByString:@"\n"];
    }
    if ([scenario isEqualToString:@"floating-bidi"]) {
        return [@[
            @"left alpha אבגדה right omega",
            @"second שלום mixed tail",
            @"third paragraph final",
        ] componentsJoinedByString:@"\n"];
    }
    if ([scenario isEqualToString:@"touch-boundary"]) {
        return @"Boundary alpha omega\nBoundary beta gamma";
    }
    if ([scenario isEqualToString:@"touch-bidi"]) {
        return @"English prefix\nאבגדה mixed suffix";
    }
    NSMutableArray<NSString *> *lines = [@[
        @"First wrapped paragraph contains constellation and punctuation for precise taps.",
        @"Second wrapped paragraph provides selection handles across independent blocks.",
        @"Third wrapped paragraph keeps the viewport tall enough for controlled scrolling.",
    ] mutableCopy];
    if ([scenario isEqualToString:@"touch-autoscroll"]) {
        for (NSUInteger index = 0; index < 30; index += 1) {
            [lines addObject:[NSString stringWithFormat:
                @"Autoscroll block %02lu carries enough words to wrap.",
                (unsigned long)index]];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}

static NSArray<NSString *> *IDStockInlineTraitNames(
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    UIFont *font = attributes[NSFontAttributeName];
    UIFontDescriptorSymbolicTraits fontTraits =
        [font isKindOfClass:UIFont.class]
            ? font.fontDescriptor.symbolicTraits : 0;
    if ((fontTraits & UIFontDescriptorTraitBold) != 0)
        [result addObject:@"bold"];
    if ((fontTraits & UIFontDescriptorTraitItalic) != 0)
        [result addObject:@"italic"];
    if ([attributes[NSUnderlineStyleAttributeName] integerValue] != 0)
        [result addObject:@"underline"];
    if ([attributes[NSStrikethroughStyleAttributeName] integerValue] != 0)
        [result addObject:@"strikethrough"];
    return result.copy;
}

static NSArray<NSDictionary<NSString *, id> *> *IDStockInlineRuns(
    NSTextStorage *storage) {
    NSMutableArray<NSDictionary<NSString *, id> *> *result =
        [NSMutableArray array];
    NSUInteger location = 0;
    while (location < storage.length) {
        NSRange effectiveRange = NSMakeRange(0, 0);
        NSDictionary<NSAttributedStringKey, id> *attributes =
            [storage attributesAtIndex:location
                 longestEffectiveRange:&effectiveRange
                               inRange:NSMakeRange(
                                   location, storage.length - location)];
        NSArray<NSString *> *traits =
            [storage.string characterAtIndex:location] == '\n'
                ? @[] : IDStockInlineTraitNames(attributes);
        NSDictionary<NSString *, id> *last = result.lastObject;
        NSRange lastRange = last == nil
            ? NSMakeRange(NSNotFound, 0)
            : NSMakeRange(
                [last[@"range"][@"location"] unsignedIntegerValue],
                [last[@"range"][@"length"] unsignedIntegerValue]);
        if (last != nil && NSMaxRange(lastRange) == effectiveRange.location &&
            [last[@"traits"] isEqual:traits]) {
            result[result.count - 1] = @{
                @"range": @{
                    @"location": @(lastRange.location),
                    @"length": @(lastRange.length + effectiveRange.length),
                },
                @"traits": traits,
            };
        } else {
            [result addObject:@{
                @"range": @{
                    @"location": @(effectiveRange.location),
                    @"length": @(effectiveRange.length),
                },
                @"traits": traits,
            }];
        }
        location = NSMaxRange(effectiveRange);
    }
    return result.copy;
}

@interface IDStockAutocorrectionObserver : NSObject <UITextViewDelegate>
@property(nonatomic) NSUInteger documentRevision;
@property(nonatomic) NSUInteger textEpoch;
@property(nonatomic) NSUInteger selectionEpoch;
@property(nonatomic) NSUInteger checkingEpoch;
@property(nonatomic, strong) NSMutableArray<NSString *> *mutationTrace;
@end

@implementation IDStockAutocorrectionObserver

- (instancetype)init {
    self = [super init];
    if (self != nil) _mutationTrace = [NSMutableArray array];
    return self;
}

- (void)textViewDidChange:(UITextView *)textView {
    (void)textView;
    self.documentRevision += 1;
    self.textEpoch += 1;
    self.checkingEpoch += 1;
    [self.mutationTrace addObject:@"textDidChange"];
    IDRecordAutocorrectionTraceForUITesting(@"textDidChange");
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    (void)textView;
    self.selectionEpoch += 1;
    [self.mutationTrace addObject:@"selectionDidChange"];
    IDRecordAutocorrectionTraceForUITesting(@"selectionDidChange");
}

@end

static NSDictionary<NSString *, NSNumber *> *IDStockIMERange(NSRange range) {
    return @{@"location": @(range.location), @"length": @(range.length)};
}

static NSDictionary<NSString *, NSNumber *> *IDStockIMEGeometry(CGRect frame) {
    if (CGRectIsNull(frame) || CGRectIsInfinite(frame) ||
        !isfinite(frame.origin.x) || !isfinite(frame.origin.y) ||
        !isfinite(frame.size.width) || !isfinite(frame.size.height)) {
        frame = CGRectZero;
    }
    return @{
        @"x": @(frame.origin.x), @"y": @(frame.origin.y),
        @"width": @(MAX(frame.size.width, 0.0)),
        @"height": @(MAX(frame.size.height, 0.0)),
    };
}

static NSDictionary<NSString *, id> *IDStockIMEStatus(
    UITextView *editor, IDStockAutocorrectionObserver *observer) {
    NSDictionary<NSString *, NSString *> *environment =
        NSProcessInfo.processInfo.environment;
    NSString *scenario = environment[@"IDStockTouchScenario"] ?: @"";
    NSString *language = environment[@"IDIMELanguage"] ?: @"";
    NSString *locationName = environment[@"IDIMELocation"] ?: @"";
    NSString *decision = environment[@"IDIMEDecision"] ?: @"";

    UITextRange *selectedTextRange = editor.selectedTextRange;
    NSInteger selectionLocation = selectedTextRange == nil ? NSNotFound :
        [editor offsetFromPosition:editor.beginningOfDocument
                       toPosition:selectedTextRange.start];
    NSInteger selectionLength = selectedTextRange == nil ? 0 :
        [editor offsetFromPosition:selectedTextRange.start
                       toPosition:selectedTextRange.end];
    NSRange selection = selectionLocation < 0 || selectionLength < 0
        ? NSMakeRange(0, 0)
        : NSMakeRange((NSUInteger)selectionLocation,
                      (NSUInteger)selectionLength);

    UITextRange *markedTextRange = editor.markedTextRange;
    NSInteger markedLocation = markedTextRange == nil ? NSNotFound :
        [editor offsetFromPosition:editor.beginningOfDocument
                       toPosition:markedTextRange.start];
    NSInteger markedLength = markedTextRange == nil ? 0 :
        [editor offsetFromPosition:markedTextRange.start
                       toPosition:markedTextRange.end];
    NSRange markedRange =
        markedTextRange == nil || markedLocation < 0 || markedLength < 0
        ? NSMakeRange(NSNotFound, 0)
        : NSMakeRange((NSUInteger)markedLocation, (NSUInteger)markedLength);
    NSString *markedText = @"";
    if (markedRange.location != NSNotFound &&
        NSMaxRange(markedRange) <= editor.text.length) {
        markedText = [editor.text substringWithRange:markedRange];
    }
    NSRange markedSelection = NSMakeRange(NSNotFound, 0);
    if (markedRange.location != NSNotFound &&
        selection.location >= markedRange.location &&
        NSMaxRange(selection) <= NSMaxRange(markedRange)) {
        markedSelection = NSMakeRange(
            selection.location - markedRange.location, selection.length);
    }

    NSMutableOrderedSet<NSString *> *markedAttributeKeys =
        [NSMutableOrderedSet orderedSet];
    NSMutableArray<NSDictionary<NSString *, id> *> *temporaryDescriptors =
        [NSMutableArray array];
    if (markedRange.location != NSNotFound && markedRange.length > 0 &&
        NSMaxRange(markedRange) <= editor.attributedText.length) {
        NSDictionary<NSAttributedStringKey, id> *attributes =
            [editor.attributedText attributesAtIndex:markedRange.location
                                      effectiveRange:NULL];
        NSArray<NSString *> *keys =
            [[attributes.allKeys valueForKey:@"description"]
                sortedArrayUsingSelector:@selector(compare:)];
        [markedAttributeKeys addObjectsFromArray:keys];
        NSMutableArray<NSString *> *descriptions =
            [NSMutableArray arrayWithCapacity:keys.count];
        for (NSString *key in keys) {
            id value = attributes[key];
            [descriptions addObject:[value description] ?: @""];
        }
        if (keys.count > 0) {
            [temporaryDescriptors addObject:@{
                @"range": IDStockIMERange(markedRange),
                @"attributeKeys": keys,
                @"valueDescriptions": descriptions.copy,
            }];
        }
    }

    CGRect compositionFrame = CGRectZero;
    if (markedTextRange != nil) {
        compositionFrame = [editor firstRectForRange:markedTextRange];
        compositionFrame = [editor convertRect:compositionFrame toView:nil];
    }
    NSArray<NSString *> *blocks =
        [editor.text componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *blockIdentifiers =
        [NSMutableArray arrayWithCapacity:blocks.count];
    NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
    NSUInteger runningLocation = 0;
    for (NSUInteger index = 0; index < blocks.count; index += 1) {
        [blockIdentifiers addObject:[NSString stringWithFormat:
            @"stock-block-%lu", (unsigned long)index]];
        runningLocation += [blocks[index] length];
        if (index + 1 < blocks.count) {
            [newlines addObject:@(runningLocation)];
            runningLocation += 1;
        }
    }
    NSArray *enabledIdentifiers =
        [NSUserDefaults.standardUserDefaults arrayForKey:@"AppleKeyboards"];
    if (![enabledIdentifiers isKindOfClass:NSArray.class] ||
        enabledIdentifiers.count == 0) {
        enabledIdentifiers = @[@"unavailable"];
    }
    NSString *primaryLanguage = editor.textInputMode.primaryLanguage ?: @"";
    return @{
        @"schema": @1,
        @"scenario": scenario,
        @"language": language,
        @"location": locationName,
        @"decision": decision,
        @"canonical": editor.text ?: @"",
        @"blocks": blocks,
        @"blockIdentifiers": blockIdentifiers.copy,
        @"anchorIdentities": @[@"stock-selection-anchor"],
        @"selection": IDStockIMERange(selection),
        @"affinity": editor.selectionAffinity ==
            UITextStorageDirectionBackward ? @"backward" : @"forward",
        @"markedRange": IDStockIMERange(markedRange),
        @"markedText": markedText,
        @"markedSelection": IDStockIMERange(markedSelection),
        @"markedAttributeKeys": markedAttributeKeys.array,
        @"structuralNewlineLocations": newlines.copy,
        @"checkingRanges": @[],
        @"temporaryRenderingDescriptors": temporaryDescriptors.copy,
        @"candidateDescriptor": @{
            @"visible": @NO, @"actionable": @NO, @"labels": @[],
            @"selectedLabel": @"", @"geometry": IDStockIMEGeometry(CGRectZero),
        },
        @"keyboardState": @{
            @"visible": @(editor.isFirstResponder),
            @"primaryLanguage": primaryLanguage,
            @"enabledInputModeIdentifiers": enabledIdentifiers,
        },
        @"compositionGeometry": IDStockIMEGeometry(compositionFrame),
        @"mutationTrace": observer.mutationTrace.copy ?: @[],
        @"eventTrace": IDCopyAutocorrectionTraceForUITesting(),
        @"coordinateSpaceIdentity": @"screen",
        @"documentRevision": @(observer.documentRevision),
        @"textEpoch": @(observer.textEpoch),
        @"selectionEpoch": @(observer.selectionEpoch),
        @"checkingEpoch": @(observer.checkingEpoch),
        @"layoutEpoch": @(observer.textEpoch + observer.selectionEpoch),
        @"firstResponder": @(editor.isFirstResponder),
    };
}

static NSDictionary<NSString *, id> *IDStockInlinePredictionObservation(
    UITextView *editor, NSRange markedRange) {
    NSString *displayText = @"";
    NSString *identity = @"";
    CGRect geometry = CGRectZero;
    // iOS 26.5's active path is UIKeyboard's marked-text presentation path.
    // Observe the public UITextInput state that UIKit actually publishes;
    // do not infer a candidate by searching private view classes.
    if (markedRange.location != NSNotFound &&
        NSMaxRange(markedRange) <= editor.text.length) {
        displayText = [editor.text substringWithRange:markedRange];
        identity = @"marked-text";
        UITextPosition *start = [editor positionFromPosition:
            editor.beginningOfDocument offset:(NSInteger)markedRange.location];
        UITextPosition *end = [editor positionFromPosition:start
            offset:(NSInteger)markedRange.length];
        if (start != nil && end != nil) {
            UITextRange *range = [editor textRangeFromPosition:start
                                                    toPosition:end];
            geometry = [editor firstRectForRange:range];
        }
    }
    NSRange range = markedRange.location == NSNotFound
        ? NSMakeRange(editor.selectedRange.location, 0) : markedRange;
    return @{
        @"descriptor": @{
            @"present": @((BOOL)(displayText.length > 0)),
            @"displayText": displayText,
            @"accessibilityIdentity": identity,
            @"range": @{
                @"location": @(range.location), @"length": @(range.length),
            },
            @"renderingAttributeKeys": @[],
        },
        @"temporaryRenderingDescriptors": @[],
        @"geometry": @{
            @"x": @(geometry.origin.x), @"y": @(geometry.origin.y),
            @"width": @(geometry.size.width), @"height": @(geometry.size.height),
        },
    };
}

@interface IDStockStatusView : UIView
@property(nonatomic, weak) UITextView *editor;
@property(nonatomic, weak) IDStockAutocorrectionObserver *autocorrectionObserver;
@property(nonatomic, copy) NSString *lastValue;
@property(nonatomic, strong) IDPrivateFloatingLifecycleWeakReferences *references;
@end

@implementation IDStockStatusView

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityValue {
    UITextView *editor = self.editor;
    if (editor == nil) return self.lastValue ?: @"{}";
    [self.references refreshWithEditor:editor];
    [editor layoutIfNeeded];
    UITextRange *selectedRange = editor.selectedTextRange;
    NSInteger location = selectedRange == nil ? NSNotFound :
        [editor offsetFromPosition:editor.beginningOfDocument
                       toPosition:selectedRange.start];
    NSInteger length = selectedRange == nil ? 0 :
        [editor offsetFromPosition:selectedRange.start toPosition:selectedRange.end];
    NSRange selection = location < 0 || length < 0
        ? NSMakeRange(0, 0)
        : NSMakeRange((NSUInteger)location, (NSUInteger)length);
    NSDictionary<NSString *, id> *lifecycle =
        IDPrivateCopyStockFloatingLifecycleStateForUITesting(editor);
    NSInteger startAffinity = [lifecycle[@"startAffinity"] integerValue];
    NSInteger endAffinity = [lifecycle[@"endAffinity"] integerValue];

    CGRect caret = CGRectZero;
    NSMutableArray<NSDictionary<NSString *, id> *> *selectionRects =
        [NSMutableArray array];
    if (selection.length == 0 && selectedRange != nil) {
        caret = [editor caretRectForPosition:selectedRange.end];
    } else if (selectedRange != nil) {
        for (UITextSelectionRect *rect in [editor selectionRectsForRange:selectedRange]) {
            CGRect frame = rect.rect;
            if (CGRectIsNull(frame) || CGRectIsInfinite(frame) ||
                !isfinite(frame.origin.x) || !isfinite(frame.origin.y) ||
                !isfinite(frame.size.width) || !isfinite(frame.size.height)) {
                continue;
            }
            [selectionRects addObject:@{
                @"containsEnd": @(rect.containsEnd),
                @"containsStart": @(rect.containsStart),
                @"direction": @(rect.writingDirection),
                @"height": @(frame.size.height), @"width": @(frame.size.width),
                @"x": @(frame.origin.x), @"y": @(frame.origin.y),
            }];
        }
        if ([NSProcessInfo.processInfo.environment[@"IDStockTouchScenario"]
                isEqualToString:@"touch-autoscroll"] && selectionRects.count > 2) {
            NSIndexSet *endpointIndexes = [selectionRects indexesOfObjectsPassingTest:
                ^BOOL(NSDictionary<NSString *, id> *rect, NSUInteger index, BOOL *stop) {
                    (void)index;
                    (void)stop;
                    return [rect[@"containsStart"] boolValue] ||
                        [rect[@"containsEnd"] boolValue];
                }];
            selectionRects = [[selectionRects objectsAtIndexes:endpointIndexes] mutableCopy];
        }
    }
    if (CGRectIsNull(caret) || CGRectIsInfinite(caret) ||
        !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
        !isfinite(caret.size.width) || !isfinite(caret.size.height)) {
        caret = CGRectZero;
    }
    UIEdgeInsets insets = editor.adjustedContentInset;
    CGRect visible = CGRectMake(editor.contentOffset.x + insets.left,
                                editor.contentOffset.y + insets.top,
                                MAX(CGRectGetWidth(editor.bounds) - insets.left - insets.right, 0),
                                MAX(CGRectGetHeight(editor.bounds) - insets.top - insets.bottom, 0));
    NSString *scenario = NSProcessInfo.processInfo.environment[@"IDStockTouchScenario"];
    if ([scenario hasPrefix:@"geometry-"]) {
        NSString *selectionText = selectedRange == nil
            ? @"" : ([editor textInRange:selectedRange] ?: @"");
        NSMutableArray<NSDictionary<NSString *, id> *> *geometrySelectionRects =
            [NSMutableArray array];
        if (selection.length > 0 && selectedRange != nil) {
            for (UITextSelectionRect *selectionRect in
                    [editor selectionRectsForRange:selectedRange]) {
                CGRect rect = selectionRect.rect;
                if (CGRectIsNull(rect) || CGRectIsInfinite(rect) ||
                    !isfinite(rect.origin.x) || !isfinite(rect.origin.y) ||
                    !isfinite(rect.size.width) || !isfinite(rect.size.height)) {
                    continue;
                }
                [geometrySelectionRects addObject:@{
                    @"containsEnd": @(selectionRect.containsEnd),
                    @"containsStart": @(selectionRect.containsStart),
                    @"height": @(rect.size.height),
                    @"vertical": @(selectionRect.isVertical),
                    @"width": @(rect.size.width),
                    @"writingDirection": @(selectionRect.writingDirection),
                    @"x": @(rect.origin.x),
                    @"y": @(rect.origin.y),
                }];
            }
        }
        NSDictionary<NSString *, NSNumber *> *selectionStatus = @{
            @"length": @(selection.length), @"location": @(selection.location),
        };
        NSMutableDictionary<NSString *, id> *geometryStatus = [@{
            @"blockCount": @([editor.text componentsSeparatedByString:@"\n"].count),
            @"boundary": IDStockGeometryBoundary(
                editor, selectionStatus, scenario),
            @"canonical": editor.text ?: @"",
            @"caret": @{
                @"height": @(caret.size.height), @"width": @(caret.size.width),
                @"x": @(caret.origin.x), @"y": @(caret.origin.y),
            },
            @"contentOffset": @{
                @"x": @(editor.contentOffset.x), @"y": @(editor.contentOffset.y),
            },
            @"firstResponder": @(editor.isFirstResponder),
            @"scenario": [@"stock-" stringByAppendingString:scenario],
            @"selection": selectionStatus,
            @"selectionRects": geometrySelectionRects.copy,
            @"state": selection.length == 0 ? @"caret" : @"selection",
            @"visible": @{
                @"height": @(visible.size.height), @"width": @(visible.size.width),
                @"x": @(visible.origin.x), @"y": @(visible.origin.y),
            },
        } mutableCopy];
        if ([scenario isEqualToString:@"geometry-large-selection"]) {
            geometryStatus[@"canonicalLength"] = @(editor.text.length);
            geometryStatus[@"selectionTextLength"] = @(selectionText.length);
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:geometryStatus
            options:NSJSONWritingSortedKeys error:nil];
        self.lastValue = data == nil ? @"{}" : [[NSString alloc]
            initWithData:data encoding:NSUTF8StringEncoding];
        return self.lastValue;
    }
    if ([scenario isEqualToString:@"inline-formatting-keyboard"]) {
        UITextRange *markedTextRange = editor.markedTextRange;
        NSInteger markedLocation = markedTextRange == nil ? NSNotFound :
            [editor offsetFromPosition:editor.beginningOfDocument
                            toPosition:markedTextRange.start];
        NSInteger markedLength = markedTextRange == nil ? 0 :
            [editor offsetFromPosition:markedTextRange.start
                            toPosition:markedTextRange.end];
        NSDictionary<NSString *, id> *formattingStatus = @{
            @"canonical": editor.text ?: @"",
            @"selection": @{
                @"location": @(selection.location),
                @"length": @(selection.length),
            },
            @"markedRange": @{
                @"location": @(markedTextRange == nil
                    ? NSNotFound : (NSUInteger)MAX(markedLocation, 0)),
                @"length": @((NSUInteger)MAX(markedLength, 0)),
            },
            @"typingInlineTraits":
                IDStockInlineTraitNames(editor.typingAttributes),
            @"inlineRuns": IDStockInlineRuns(editor.textStorage),
            @"canUndo": @(editor.undoManager.canUndo),
        };
        NSData *data = [NSJSONSerialization
            dataWithJSONObject:formattingStatus
                       options:NSJSONWritingSortedKeys
                         error:nil];
        NSString *value = data == nil ? @"{}" :
            [[NSString alloc] initWithData:data
                                 encoding:NSUTF8StringEncoding];
        self.lastValue = value;
        return value;
    }
    if ([scenario hasPrefix:@"ime-"]) {
        NSDictionary<NSString *, id> *imeStatus =
            IDStockIMEStatus(editor, self.autocorrectionObserver);
        NSData *data = [NSJSONSerialization
            dataWithJSONObject:imeStatus
                       options:NSJSONWritingSortedKeys
                         error:nil];
        NSString *value = data == nil ? @"{}" :
            [[NSString alloc] initWithData:data
                                 encoding:NSUTF8StringEncoding];
        self.lastValue = value;
        return value;
    }
    if ([scenario hasPrefix:@"inline-prediction-"]) {
        UITextRange *markedTextRange = editor.markedTextRange;
        NSInteger markedLocation = markedTextRange == nil ? NSNotFound :
            [editor offsetFromPosition:editor.beginningOfDocument
                            toPosition:markedTextRange.start];
        NSInteger markedLength = markedTextRange == nil ? 0 :
            [editor offsetFromPosition:markedTextRange.start
                            toPosition:markedTextRange.end];
        NSRange markedRange = NSMakeRange(
            (NSUInteger)MAX(markedLocation, 0), (NSUInteger)MAX(markedLength, 0));
        if (markedTextRange == nil) markedRange = NSMakeRange(NSNotFound, 0);
        NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
        [editor.text enumerateSubstringsInRange:NSMakeRange(0, editor.text.length)
            options:NSStringEnumerationByComposedCharacterSequences
            usingBlock:^(NSString *substring, NSRange substringRange,
                         NSRange enclosingRange, BOOL *stop) {
                (void)enclosingRange;
                (void)stop;
                if ([substring isEqualToString:@"\n"]) {
                    [newlines addObject:@(substringRange.location)];
                }
            }];
        NSDictionary<NSString *, id> *prediction =
            IDStockInlinePredictionObservation(editor, markedRange);
        NSString *language = editor.textInputMode.primaryLanguage ?: @"";
        IDStockAutocorrectionObserver *observer = self.autocorrectionObserver;
        NSDictionary *inlinePredictionStatus = @{
            @"schema": @1,
            @"scenario": scenario,
            @"canonical": editor.text ?: @"",
            @"blocks": [editor.text componentsSeparatedByString:@"\n"],
            @"selection": @{
                @"location": @(selection.location), @"length": @(selection.length),
            },
            @"affinity": @"forward",
            @"markedRange": @{
                @"location": @(markedRange.location), @"length": @(markedRange.length),
            },
            @"structuralNewlineLocations": newlines.copy,
            @"checkingRanges": @[],
            @"predictionDescriptor": prediction[@"descriptor"],
            @"temporaryRenderingDescriptors":
                prediction[@"temporaryRenderingDescriptors"],
            @"mutationTrace": observer.mutationTrace.copy ?: @[],
            @"eventTrace": IDCopyAutocorrectionTraceForUITesting(),
            @"keyboardState": @{
                @"visible": @(editor.isFirstResponder),
                @"locale": language,
                @"inlinePredictionEnabled":
                    @((BOOL)(editor.inlinePredictionType ==
                        UITextInlinePredictionTypeYes)),
            },
            @"predictionGeometry": prediction[@"geometry"],
            @"coordinateSpaceIdentity": @"stock-text-view",
            @"documentRevision": @(observer.documentRevision),
            @"textEpoch": @(observer.textEpoch),
            @"selectionEpoch": @(observer.selectionEpoch),
            @"checkingEpoch": @(observer.checkingEpoch),
            @"firstResponder": @(editor.isFirstResponder),
        };
        NSData *data = [NSJSONSerialization
            dataWithJSONObject:inlinePredictionStatus
                        options:NSJSONWritingSortedKeys error:nil];
        NSString *value = data == nil ? @"{}" :
            [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        self.lastValue = value;
        return value;
    }
    if ([scenario hasPrefix:@"autocorrection-"]) {
        UITextRange *markedTextRange = editor.markedTextRange;
        NSInteger markedLocation = markedTextRange == nil ? NSNotFound :
            [editor offsetFromPosition:editor.beginningOfDocument
                            toPosition:markedTextRange.start];
        NSInteger markedLength = markedTextRange == nil ? 0 :
            [editor offsetFromPosition:markedTextRange.start
                            toPosition:markedTextRange.end];
        NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
        [editor.text enumerateSubstringsInRange:NSMakeRange(0, editor.text.length)
            options:NSStringEnumerationByComposedCharacterSequences
            usingBlock:^(NSString *substring, NSRange substringRange,
                         NSRange enclosingRange, BOOL *stop) {
                (void)enclosingRange;
                (void)stop;
                if ([substring isEqualToString:@"\n"])
                    [newlines addObject:@(substringRange.location)];
            }];
        CGRect correctionRect = selectedRange == nil ? CGRectZero :
            [editor caretRectForPosition:selectedRange.end];
        NSString *language = editor.textInputMode.primaryLanguage ?: @"";
        IDStockAutocorrectionObserver *observer = self.autocorrectionObserver;
        NSDictionary *autocorrectionStatus = @{
            @"schema": @1,
            @"scenario": scenario,
            @"canonical": editor.text ?: @"",
            @"blocks": [editor.text componentsSeparatedByString:@"\n"],
            @"selection": @{@"location": @(selection.location),
                              @"length": @(selection.length)},
            @"affinity": @"forward",
            @"markedRange": @{@"location": @(markedLocation),
                                @"length": @(MAX(markedLength, 0))},
            @"structuralNewlineLocations": newlines.copy,
            @"checkingRanges": @[],
            @"candidateDescriptor": @{
                @"candidate": @"", @"original": @"", @"actionable": @NO,
            },
            @"mutationTrace": observer.mutationTrace.copy ?: @[],
            @"eventTrace": IDCopyAutocorrectionTraceForUITesting(),
            @"keyboardState": @{
                @"visible": @(editor.isFirstResponder), @"locale": language,
                @"learnedOriginal": @([UITextChecker hasLearnedWord:@"adress"]),
            },
            @"correctionGeometry": @{
                @"x": @(correctionRect.origin.x), @"y": @(correctionRect.origin.y),
                @"width": @(correctionRect.size.width),
                @"height": @(correctionRect.size.height),
            },
            @"coordinateSpaceIdentity": @"stock-text-view",
            @"documentRevision": @(observer.documentRevision),
            @"textEpoch": @(observer.textEpoch),
            @"selectionEpoch": @(observer.selectionEpoch),
            @"checkingEpoch": @(observer.checkingEpoch),
            @"firstResponder": @(editor.isFirstResponder),
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:autocorrectionStatus
            options:NSJSONWritingSortedKeys error:nil];
        NSString *value = data == nil ? @"{}" :
            [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        self.lastValue = value;
        return value;
    }
    if ([scenario hasPrefix:@"floating-"]) {
        NSMutableDictionary *trace =
            [IDPrivateCopyTextAutoscrollTraceForUITesting(editor) mutableCopy];
        [trace addEntriesFromDictionary:lifecycle];
        NSDictionary *floatingStatus = @{
            @"blockCount": @([editor.text componentsSeparatedByString:@"\n"].count),
            @"canonical": editor.text ?: @"",
            @"caret": @{@"height": @(caret.size.height), @"width": @(caret.size.width),
                         @"x": @(caret.origin.x), @"y": @(caret.origin.y)},
            @"containerCreations":
                @(IDPrivateFloatingContainerCreationCountForUITesting(editor)),
            @"containerStable": lifecycle[@"containerStable"],
            @"contentOffset": @{@"x": @(editor.contentOffset.x), @"y": @(editor.contentOffset.y)},
            @"firstResponder": @(editor.isFirstResponder),
            @"presentationUpdates": lifecycle[@"presentationUpdates"],
            @"scenario": scenario,
            @"selection": @{@"length": @(selection.length), @"location": @(selection.location)},
            @"startAffinity": @(startAffinity),
            @"endAffinity": @(endAffinity),
            @"visible": @{@"height": @(visible.size.height), @"width": @(visible.size.width),
                          @"x": @(visible.origin.x), @"y": @(visible.origin.y)},
            @"cursorCallback": IDPrivateCopyStockCursorTraceForUITesting(editor)
                ?: NSNull.null,
            @"autoscrollTrace": trace.copy,
            @"interactionHostTopology": @{},
            @"lifecycle": lifecycle,
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:floatingStatus options:0 error:nil];
        NSString *value = data == nil ? @"{}" : [[NSString alloc] initWithData:data
                                                                        encoding:NSUTF8StringEncoding];
        self.lastValue = value;
        return value;
    }
    NSMutableDictionary *status = [@{
        @"backend": @"stock",
        @"blockCount": @([editor.text componentsSeparatedByString:@"\n"].count),
        @"canonical": editor.text ?: @"",
        @"caret": @{
            @"height": @(caret.size.height), @"width": @(caret.size.width),
            @"x": @(caret.origin.x), @"y": @(caret.origin.y),
        },
        @"containerCreations":
            @(IDPrivateFloatingContainerCreationCountForUITesting(editor)),
        @"containerStable": lifecycle[@"containerStable"],
        @"selectionContainerIdentity": lifecycle[@"containerToken"],
        @"contentOffset": @{
            @"x": @(editor.contentOffset.x), @"y": @(editor.contentOffset.y),
        },
        @"presentationUpdates": lifecycle[@"presentationUpdates"],
        @"scenario": [@"stock-" stringByAppendingString:
            NSProcessInfo.processInfo.environment[@"IDStockTouchScenario"] ?: @"touch-ltr"],
        @"selection": @{
            @"length": @(selection.length), @"location": @(selection.location),
        },
        @"selectionRects": selectionRects.copy,
        @"state": selection.length == 0 ? @"caret" : @"selection",
        @"visible": @{
            @"height": @(visible.size.height), @"width": @(visible.size.width),
            @"x": @(visible.origin.x), @"y": @(visible.origin.y),
        },
    } mutableCopy];
    if ([NSProcessInfo.processInfo.environment[@"IDStockTouchScenario"]
            isEqualToString:@"touch-autoscroll"]) {
        NSDictionary *trace = IDPrivateCopyTextAutoscrollTraceForUITesting(editor);
        NSDictionary *lastPoint = trace[@"assistantPoint"] ?: @{@"x": @0, @"y": @0};
        status[@"autoscroll"] = @{
            @"active": lifecycle[@"autoscrollActive"],
            @"cancelCount": trace[@"cancelCount"] ?: @0,
            @"lastPoint": lastPoint,
            @"startCount": trace[@"startCount"] ?: @0,
        };
        status[@"visibleHandles"] =
            IDPrivateCopyStockVisibleSelectionHandlesForUITesting(editor);
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:status options:0 error:nil];
    NSString *value = data == nil ? @"{}" : [[NSString alloc] initWithData:data
                                                                    encoding:NSUTF8StringEncoding];
    self.lastValue = value;
    return value;
}

@end

@interface IDStockReleaseStatusView : UIView
@property(nonatomic, strong) IDPrivateFloatingLifecycleWeakReferences *references;
@end

@implementation IDStockReleaseStatusView
- (BOOL)isAccessibilityElement { return YES; }
- (NSString *)accessibilityValue {
    NSDictionary *state = [self.references copyAtomicFloatingSnapshot] ?: @{};
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}
@end

@interface IDStockTerminalStatusView : IDStockReleaseStatusView
@end

@implementation IDStockTerminalStatusView
- (NSString *)accessibilityValue {
    NSDictionary *state = [self.references copyTerminalSnapshot] ?: @{};
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}
@end

@interface IDStockStoredReleaseStatusView : IDStockReleaseStatusView
@property(nonatomic, copy) NSString *phase;
@end

@implementation IDStockStoredReleaseStatusView
- (NSString *)accessibilityValue {
    NSDictionary *state = [self.references copyReleaseSnapshotForPhase:self.phase] ?: @{};
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}
@end

@interface IDStockOracleAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UITextView *editor;
@property(nonatomic, strong) UITextField *releaseResponder;
@property(nonatomic, strong) IDStockAutocorrectionObserver *autocorrectionObserver;
@end

@implementation IDStockOracleAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)options {
    (void)application;
    (void)options;
    CGRect editorFrame = CGRectFromString(NSProcessInfo.processInfo.environment[@"IDStockEditorFrame"]);
    if (CGRectIsEmpty(editorFrame) || CGRectIsNull(editorFrame) || CGRectIsInfinite(editorFrame)) {
        editorFrame = CGRectMake(16, 198, 370, 360);
    }
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.systemBackgroundColor;

    NSString *scenario = NSProcessInfo.processInfo.environment[@"IDStockTouchScenario"];
    BOOL isAutocorrectionScenario = [scenario hasPrefix:@"autocorrection-"];
    BOOL isInlinePredictionScenario =
        [scenario hasPrefix:@"inline-prediction-"];
    BOOL isFormattingKeyboardScenario =
        [scenario isEqualToString:@"inline-formatting-keyboard"];
    BOOL isIMEScenario = [scenario hasPrefix:@"ime-"];
    BOOL forceEnglishUSInputMode = [NSProcessInfo.processInfo.environment[
        @"IDForceEnglishUSInputMode"] isEqualToString:@"1"];
    if (isInlinePredictionScenario || isFormattingKeyboardScenario) {
        CFNotificationCenterRef center =
            CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(
            center, NULL, IDStockInlinePredictionActionNotification,
            CFSTR("com.inputdec.inline-prediction.dismiss"), NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    BOOL needsInstrumentation = [scenario isEqualToString:@"touch-autoscroll"] ||
        [scenario hasPrefix:@"floating-"];
    Class editorClass = (isAutocorrectionScenario ||
                         isInlinePredictionScenario ||
                         forceEnglishUSInputMode)
        ? IDStockEnglishUSTextView.class : UITextView.class;
    UITextView *editor = needsInstrumentation
        ? (UITextView *)IDPrivateNewStockOracleTextView(editorClass, editorFrame)
        : [[editorClass alloc] initWithFrame:editorFrame];
    if (isAutocorrectionScenario || isInlinePredictionScenario ||
        forceEnglishUSInputMode) {
        editor.keyboardType = UIKeyboardTypeASCIICapable;
    }
    self.editor = editor;
    editor.accessibilityIdentifier = @"stock-text-view";
    editor.accessibilityLabel = @"Stock text editor";
    BOOL hidesEditorFromAccessibility = [NSProcessInfo.processInfo.environment[
        @"IDStockHideEditorFromAccessibility"] isEqualToString:@"1"];
    if (hidesEditorFromAccessibility) {
        editor.accessibilityIdentifier = nil;
        editor.accessibilityLabel = nil;
        editor.isAccessibilityElement = NO;
        editor.accessibilityElementsHidden = YES;
    }
    editor.font = [UIFont systemFontOfSize:20.0];
    editor.textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    editor.textContainer.lineFragmentPadding = 5.0;
    editor.text = IDStockText();
    if (isFormattingKeyboardScenario) {
        UIFontDescriptor *descriptor = [editor.font.fontDescriptor
            fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
        UIFont *boldFont = [UIFont
            fontWithDescriptor:descriptor
                          size:editor.font.pointSize];
        editor.typingAttributes = @{
            NSFontAttributeName: boldFont,
            NSForegroundColorAttributeName: UIColor.blackColor,
        };
        editor.selectedRange = NSMakeRange(0, 0);
    }
    if (isIMEScenario) {
        NSString *location =
            NSProcessInfo.processInfo.environment[@"IDIMELocation"];
        NSRange boundary = [editor.text rangeOfString:@"\n"];
        NSUInteger selectionLocation = 6;
        if ([location isEqualToString:@"before-boundary"]) {
            selectionLocation = boundary.location;
        } else if ([location isEqualToString:@"after-boundary"]) {
            selectionLocation = NSMaxRange(boundary);
        }
        editor.selectedRange = NSMakeRange(selectionLocation, 0);
    } else if (isInlinePredictionScenario ||
               isFormattingKeyboardScenario) {
        NSUInteger selectionLocation = 0;
        if (isInlinePredictionScenario) {
            NSRange location = [scenario isEqualToString:
                @"inline-prediction-interior"]
                ? [editor.text rangeOfString:@"  \n"]
                : [editor.text rangeOfString:@"\n"];
            selectionLocation = location.location;
            if ([scenario isEqualToString:@"inline-prediction-interior"]) {
                selectionLocation += 1;
            } else if ([scenario isEqualToString:
                @"inline-prediction-after-boundary"]) {
                selectionLocation += 1;
            }
        }
        editor.selectedRange = NSMakeRange(selectionLocation, 0);
    } else if (isAutocorrectionScenario) {
        editor.selectedRange = NSMakeRange(
            [scenario isEqualToString:@"autocorrection-after-boundary"] ? 15 : 8, 0);
    } else if ([scenario isEqualToString:@"navigation-horizontal"] ||
               [scenario isEqualToString:@"navigation-selection"]) {
        editor.selectedRange = NSMakeRange(3, 0);
    } else if ([scenario isEqualToString:@"navigation-vertical"]) {
        editor.selectedRange = NSMakeRange(12, 0);
    } else if ([scenario isEqualToString:@"geometry-authority"]) {
        NSString *requestedLocation = NSProcessInfo.processInfo.environment[
            @"IDGeometrySelectionLocation"];
        NSUInteger location = requestedLocation == nil
            ? 3 : requestedLocation.integerValue;
        NSUInteger length = [NSProcessInfo.processInfo.environment[
            @"IDGeometrySelectionLength"] integerValue];
        editor.selectedRange = NSMakeRange(location, length);
    } else if ([scenario isEqualToString:@"geometry-large-selection"]) {
        editor.selectedRange = NSMakeRange(0, 0);
    } else if ([scenario isEqualToString:@"touch-autoscroll"]) {
        editor.selectedRange = NSMakeRange(0, 0);
    } else if ([scenario isEqualToString:@"floating-ltr"] ||
               [scenario isEqualToString:@"floating-scroll"]) {
        editor.selectedRange = NSMakeRange(
            [scenario isEqualToString:@"floating-scroll"]
                ? ([NSProcessInfo.processInfo.environment[@"IDFloatingScrollSelection"]
                    isEqualToString:@"1"] ? 900 :
                   ([NSProcessInfo.processInfo.environment[@"IDFloatingScrollEdge"]
                    isEqualToString:@"lower"] ? 1600 : 891))
                : 46, 0);
    } else if ([scenario isEqualToString:@"floating-boundary"]) {
        editor.selectedRange = NSMakeRange(50, 0);
    } else if ([scenario isEqualToString:@"floating-bidi"]) {
        editor.selectedRange = NSMakeRange(16, 0);
    }
    editor.backgroundColor = UIColor.whiteColor;
    editor.textColor = UIColor.blackColor;
    editor.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    editor.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    if (isIMEScenario) {
        editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        editor.autocorrectionType = UITextAutocorrectionTypeYes;
        editor.smartQuotesType = UITextSmartQuotesTypeNo;
        editor.smartDashesType = UITextSmartDashesTypeNo;
        editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        editor.inlinePredictionType = UITextInlinePredictionTypeNo;
        editor.spellCheckingType = UITextSpellCheckingTypeYes;
        IDInstallAutocorrectionTraceForUITesting();
        IDStockAutocorrectionObserver *observer =
            [IDStockAutocorrectionObserver new];
        self.autocorrectionObserver = observer;
        editor.delegate = observer;
    } else if (isInlinePredictionScenario ||
               isFormattingKeyboardScenario) {
        if (isFormattingKeyboardScenario) {
            NSString *original = NSProcessInfo.processInfo.environment[
                @"IDInlineFormattingOriginal"];
            if (original.length > 0) {
                [UITextChecker unlearnWord:original];
            }
        }
        editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        editor.autocorrectionType = UITextAutocorrectionTypeYes;
        editor.smartQuotesType = UITextSmartQuotesTypeNo;
        editor.smartDashesType = UITextSmartDashesTypeNo;
        editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        editor.inlinePredictionType = UITextInlinePredictionTypeYes;
        editor.spellCheckingType = UITextSpellCheckingTypeYes;
        IDInstallAutocorrectionTraceForUITesting();
        IDStockAutocorrectionObserver *observer =
            [IDStockAutocorrectionObserver new];
        self.autocorrectionObserver = observer;
        editor.delegate = observer;
    } else if (isAutocorrectionScenario) {
        // Keep the stock oracle independent from earlier rejected/abandoned
        // rows. This resets only the fixture word before the baseline; UIKit
        // still owns candidate generation and every decision thereafter.
        [UITextChecker unlearnWord:@"adress"];
        editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        editor.autocorrectionType = UITextAutocorrectionTypeYes;
        editor.smartQuotesType = UITextSmartQuotesTypeNo;
        editor.smartDashesType = UITextSmartDashesTypeNo;
        editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        editor.inlinePredictionType = UITextInlinePredictionTypeNo;
        editor.spellCheckingType = UITextSpellCheckingTypeYes;
        IDInstallAutocorrectionTraceForUITesting();
        IDStockAutocorrectionObserver *observer = [IDStockAutocorrectionObserver new];
        self.autocorrectionObserver = observer;
        editor.delegate = observer;
    } else if (![scenario hasPrefix:@"floating-"]) {
        editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        editor.autocorrectionType = UITextAutocorrectionTypeNo;
        editor.smartQuotesType = UITextSmartQuotesTypeNo;
        editor.smartDashesType = UITextSmartDashesTypeNo;
        editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        editor.inlinePredictionType = UITextInlinePredictionTypeNo;
        editor.spellCheckingType = UITextSpellCheckingTypeNo;
    }
    editor.layer.borderColor = UIColor.separatorColor.CGColor;
    editor.layer.borderWidth = 0.5;
    editor.layer.cornerRadius = 10;
    UIView *editorHost = [[UIView alloc] initWithFrame:editorFrame];
    editor.frame = editorHost.bounds;
    [editorHost addSubview:editor];
    [controller.view addSubview:editorHost];
    UIButton *imeResignButton = nil;
    UIButton *imeUndoButton = nil;
    if (isIMEScenario) {
        UIButton *resignButton = [UIButton buttonWithType:UIButtonTypeSystem];
        resignButton.frame = CGRectMake(16, 150, 150, 36);
        [resignButton setTitle:@"Resign IME Editor"
                      forState:UIControlStateNormal];
        resignButton.accessibilityIdentifier = @"ime-resign";
        resignButton.accessibilityLabel = @"Resign IME Editor";
        resignButton.isAccessibilityElement = YES;
        __weak UITextView *weakIMEEditor = editor;
        [resignButton addAction:[UIAction actionWithHandler:
            ^(__unused UIAction *action) {
                [weakIMEEditor resignFirstResponder];
            }]
              forControlEvents:UIControlEventTouchUpInside];
        [controller.view addSubview:resignButton];
        imeResignButton = resignButton;

        UIButton *undoButton = [UIButton buttonWithType:UIButtonTypeSystem];
        undoButton.frame = CGRectMake(180, 150, 120, 36);
        [undoButton setTitle:@"Undo IME Edit"
                    forState:UIControlStateNormal];
        undoButton.accessibilityIdentifier = @"ime-undo";
        undoButton.accessibilityLabel = @"Undo IME Edit";
        undoButton.isAccessibilityElement = YES;
        [undoButton addAction:[UIAction actionWithHandler:
            ^(__unused UIAction *action) {
                [weakIMEEditor.undoManager undo];
            }]
            forControlEvents:UIControlEventTouchUpInside];
        [controller.view addSubview:undoButton];
        imeUndoButton = undoButton;
    }
    if ([scenario hasPrefix:@"floating-"]) {
        IDPrivateInstallStockCursorTraceForUITesting(editor);
    }

    IDStockStatusView *status = [[IDStockStatusView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
    NSString *statusIdentifier = isInlinePredictionScenario
        ? @"inline-prediction-status"
        : isAutocorrectionScenario ? @"autocorrection-status"
        : isIMEScenario ? @"ime-composition-status" :
        ([scenario hasPrefix:@"floating-"] ? @"floating-status" :
         ([scenario hasPrefix:@"geometry-"] ? @"geometry-status" : @"touch-status"));
    if (isFormattingKeyboardScenario) {
        statusIdentifier = @"inline-formatting-keyboard-status";
    }
    status.accessibilityIdentifier = statusIdentifier;
    status.accessibilityLabel = statusIdentifier;
    status.editor = editor;
    status.autocorrectionObserver = self.autocorrectionObserver;
    status.references = [[IDPrivateFloatingLifecycleWeakReferences alloc]
        initWithEditor:editor];
    [controller.view addSubview:status];
    UIButton *geometrySelectAllButton = nil;
    if ([scenario isEqualToString:@"geometry-large-selection"]) {
        geometrySelectAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
        geometrySelectAllButton.frame = CGRectMake(16, 150, 160, 36);
        [geometrySelectAllButton setTitle:@"Select All Document"
                                 forState:UIControlStateNormal];
        geometrySelectAllButton.accessibilityIdentifier = @"geometry-select-all";
        geometrySelectAllButton.accessibilityLabel = @"Select All Document";
        __weak UITextView *weakGeometryEditor = editor;
        __weak IDStockStatusView *weakGeometryStatus = status;
        [geometrySelectAllButton addAction:[UIAction actionWithHandler:
            ^(__unused UIAction *action) {
                [weakGeometryEditor selectAll:nil];
                UIAccessibilityPostNotification(
                    UIAccessibilityLayoutChangedNotification, weakGeometryStatus);
            }]
            forControlEvents:UIControlEventTouchUpInside];
        [controller.view addSubview:geometrySelectAllButton];
    }
    IDStockReleaseStatusView *releaseStatus = [IDStockReleaseStatusView new];
    releaseStatus.accessibilityIdentifier = @"floating-release-status";
    releaseStatus.accessibilityLabel = @"floating-release-status";
    releaseStatus.references = status.references;
    [controller.view addSubview:releaseStatus];
    IDStockTerminalStatusView *terminalStatus = [IDStockTerminalStatusView new];
    terminalStatus.accessibilityIdentifier = @"floating-terminal-status";
    terminalStatus.accessibilityLabel = @"floating-terminal-status";
    terminalStatus.references = status.references;
    [controller.view addSubview:terminalStatus];
    IDStockStoredReleaseStatusView *(^storedStatus)(NSString *, NSString *) =
        ^IDStockStoredReleaseStatusView *(NSString *identifier, NSString *phase) {
            IDStockStoredReleaseStatusView *value = [IDStockStoredReleaseStatusView new];
            value.accessibilityIdentifier = identifier;
            value.accessibilityLabel = identifier;
            value.references = status.references;
            value.phase = phase;
            [controller.view addSubview:value];
            return value;
        };
    IDStockStoredReleaseStatusView *immediateReleaseStatus = storedStatus(
        @"floating-release-immediate-status", @"immediate");
    IDStockStoredReleaseStatusView *heldReleaseStatus = storedStatus(
        @"floating-release-held-status", @"held");
    IDStockStoredReleaseStatusView *exactReleaseStatus = storedStatus(
        @"floating-release-exact-status", @"exact-release-500ms");
    IDStockStoredReleaseStatusView *postLiftReleaseStatus = storedStatus(
        @"floating-release-post-lift-status", @"post-keyboard-lift-500ms");
    if ([scenario hasPrefix:@"floating-"]) {
        UITextField *releaseResponder = [[UITextField alloc]
            initWithFrame:CGRectMake(1, 1, 2, 2)];
        releaseResponder.accessibilityElementsHidden = YES;
        self.releaseResponder = releaseResponder;
        [controller.view addSubview:releaseResponder];
        __weak typeof(self) weakSelf = self;
        __weak UITextView *weakEditor = editor;
        __weak UIView *weakEditorHost = editorHost;
        __weak UIView *weakRootView = controller.view;
        __block void (^rearmTruthObservers)(void) = nil;
        UIButton *(^button)(NSString *, CGRect, void (^)(void)) =
            ^UIButton *(NSString *title, CGRect frame, void (^action)(void)) {
                UIButton *value = [UIButton buttonWithType:UIButtonTypeSystem];
                value.frame = frame;
                [value setTitle:title forState:UIControlStateNormal];
                value.accessibilityIdentifier = [@"floating-" stringByAppendingString:
                    [[title lowercaseString] stringByReplacingOccurrencesOfString:@" "
                                                                        withString:@"-"]];
                [value addAction:[UIAction actionWithHandler:^(__unused UIAction *ignored) {
                    action();
                }] forControlEvents:UIControlEventTouchUpInside];
                [controller.view addSubview:value];
                return value;
            };
        UIButton *editableButton = button(@"Editable: On", CGRectMake(130, 120, 134, 32), ^{
            IDPrivateTestingRequestEditableOff(weakEditor);
        });
        editableButton.accessibilityIdentifier = @"floating-editable-off";
        UIButton *selectableButton = button(@"Selectable: On", CGRectMake(250, 120, 134, 32), ^{
            IDPrivateTestingRequestSelectableOff(weakEditor);
        });
        selectableButton.accessibilityIdentifier = @"floating-selectable-off";
        UIButton *selectableOnButton = button(@"Selectable: Rebuild",
            CGRectMake(250, 84, 134, 32), ^{
                weakEditor.selectable = YES;
                weakEditor.editable = YES;
                if (rearmTruthObservers != nil) rearmTruthObservers();
                [weakEditor becomeFirstResponder];
            });
        selectableOnButton.accessibilityIdentifier = @"floating-selectable-on";
        UIButton *resignButton = button(@"Resign", CGRectMake(20, 153, 120, 36), ^{
            IDPrivateTestingRequestResponderLoss(weakEditor);
        });
        resignButton.accessibilityIdentifier = @"floating-resign";
        UIButton *dismissButton = button(@"Keyboard Dismiss", CGRectMake(145, 153, 150, 36), ^{
            IDPrivateTestingRequestKeyboardDismissal(weakEditor);
        });
        dismissButton.accessibilityIdentifier = @"floating-keyboard-dismiss";
        UIButton *detachButton = button(@"Window Detach", CGRectMake(20, 190, 140, 36), ^{
            IDPrivateTestingRequestWindowDetach(weakEditor);
        });
        detachButton.accessibilityIdentifier = @"floating-window-detach";
        void (^releaseEditor)(NSString *, NSUInteger, CFTimeInterval, CFTimeInterval) =
        ^(NSString *terminalEvent, NSUInteger observedTerminalCount,
          CFTimeInterval terminalEpoch, CFTimeInterval liftTargetEpoch) {
            UITextView *strongEditor = weakEditor;
            if (strongEditor == nil) return;
            (void)status.accessibilityValue;
            [status.references refreshWithEditor:strongEditor];
            NSDictionary *lifecycle =
                IDPrivateCopyStockFloatingLifecycleStateForUITesting(strongEditor);
            NSString *countKey = [terminalEvent stringByAppendingString:@"Count"];
            NSUInteger terminalCount = [lifecycle[countKey] unsignedIntegerValue];
            if (observedTerminalCount != 0) terminalCount = observedTerminalCount;
            if (terminalCount == 0) return;
            [status.references markReleaseAttemptAfterTerminalEvent:terminalEvent
                                                               count:terminalCount
                                                       terminalEpoch:terminalEpoch
                                                     liftTargetEpoch:liftTargetEpoch];
            [status.references scheduleReleaseSnapshots];
            UIView *rootView = weakRootView;
            UITextField *handoff = weakSelf.releaseResponder;
            [handoff becomeFirstResponder];
            NSLog(@"IDReleaseDelegateOwnership %@",
                IDPrivateCopyKeyboardInputDelegateOwnershipForUITesting(
                    strongEditor, handoff));
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakEditorHost removeFromSuperview];
                NSMutableArray *elements = [rootView.accessibilityElements mutableCopy];
                [elements removeObjectIdenticalTo:strongEditor];
                rootView.accessibilityElements = elements;
                status.editor = nil;
                weakSelf.editor = nil;
                UIViewController *releasedController = [UIViewController new];
                releasedController.view.backgroundColor = UIColor.systemBackgroundColor;
                [releasedController.view addSubview:status];
                [releasedController.view addSubview:releaseStatus];
                [releasedController.view addSubview:terminalStatus];
                [releasedController.view addSubview:immediateReleaseStatus];
                [releasedController.view addSubview:heldReleaseStatus];
                [releasedController.view addSubview:exactReleaseStatus];
                [releasedController.view addSubview:postLiftReleaseStatus];
                [releasedController.view addSubview:handoff];
                releasedController.view.accessibilityElements =
                    @[status, releaseStatus, terminalStatus, heldReleaseStatus,
                      immediateReleaseStatus,
                      exactReleaseStatus, postLiftReleaseStatus];
                UIWindow *oldWindow = weakSelf.window;
                UIWindow *releasedWindow = [[UIWindow alloc] initWithFrame:oldWindow.bounds];
                releasedWindow.rootViewController = releasedController;
                weakSelf.window = releasedWindow;
                [releasedWindow makeKeyAndVisible];
                [handoff becomeFirstResponder];
                NSLog(@"IDReleaseDelegateOwnershipAfterWindow %@",
                    IDPrivateCopyKeyboardInputDelegateOwnershipForUITesting(
                        strongEditor, handoff));
                oldWindow.rootViewController = nil;
                oldWindow.hidden = YES;
                [status.references recordImmediateReleaseSnapshot];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [handoff resignFirstResponder];
                });
            });
        };
        UIButton *releaseButton = button(@"Release Editor", CGRectMake(165, 190, 140, 36), ^{
            NSDictionary *lifecycle =
                IDPrivateCopyStockFloatingLifecycleStateForUITesting(weakEditor);
            NSString *event = [lifecycle[@"normalEndCount"] unsignedIntegerValue] > 0
                ? @"normalEnd" : @"responderLoss";
            CFTimeInterval now = CACurrentMediaTime();
            releaseEditor(event, [lifecycle[[event stringByAppendingString:@"Count"]]
                unsignedIntegerValue], now, now);
        });
        releaseButton.accessibilityIdentifier = @"floating-release-editor";
        NSString *releaseMode = NSProcessInfo.processInfo.environment[@"IDStockReleaseAttempt"];
        NSString *truthTerminalEvent =
            NSProcessInfo.processInfo.environment[@"IDStockTruthTerminalEvent"];
        NSString *truthActionEvent =
            NSProcessInfo.processInfo.environment[@"IDStockTruthActionEvent"];
        if ([releaseMode isEqualToString:@"after-normal"] ||
            [releaseMode isEqualToString:@"after-interruption"]) {
            NSString *event = [releaseMode isEqualToString:@"after-normal"]
                ? @"normalEnd" : @"responderLoss";
            if (truthActionEvent.length > 0) {
                IDPrivateSetFloatingLifecycleActionObserverForUITesting(
                    editor, truthActionEvent,
                    ^(NSString *observedEvent, NSUInteger count,
                      CFTimeInterval actionEpoch) {
                        (void)observedEvent;
                        (void)count;
                        [status.references markActionObservationAtEpoch:actionEpoch
                            liftDelay:1.55];
                    });
            }
            __weak UITextView *observerEditor = editor;
            IDPrivateSetFloatingLifecycleTerminalObserverForUITesting(
                editor, event, ^(NSString *observedEvent, NSUInteger count,
                                 CFTimeInterval terminalEpoch) {
                    (void)observerEditor;
                    NSTimeInterval liftDelta = [releaseMode isEqualToString:@"after-normal"]
                        ? 0.0 : 1.55;
                    releaseEditor(observedEvent, count, terminalEpoch,
                                  terminalEpoch + liftDelta);
            });
            [status.references beginHeldSnapshotPollingForTerminalEvent:event];
        } else if (truthTerminalEvent.length > 0) {
            rearmTruthObservers = ^{
                UITextView *strongEditor = weakEditor;
                if (strongEditor == nil) return;
                IDPrivateFloatingLifecycleWeakReferences *references =
                    [[IDPrivateFloatingLifecycleWeakReferences alloc]
                        initWithEditor:strongEditor];
                status.references = references;
                releaseStatus.references = references;
                terminalStatus.references = references;
                heldReleaseStatus.references = references;
                immediateReleaseStatus.references = references;
                exactReleaseStatus.references = references;
                postLiftReleaseStatus.references = references;
                [references beginHeldSnapshotPollingForTerminalEvent:truthTerminalEvent];
                if (truthActionEvent.length > 0) {
                    IDPrivateSetFloatingLifecycleActionObserverForUITesting(
                        strongEditor, truthActionEvent,
                        ^(NSString *observedEvent, NSUInteger count,
                          CFTimeInterval actionEpoch) {
                            (void)observedEvent;
                            (void)count;
                            [references markActionObservationAtEpoch:actionEpoch
                                liftDelay:1.55];
                        });
                }
                IDPrivateSetFloatingLifecycleTerminalObserverForUITesting(
                    strongEditor, truthTerminalEvent,
                    ^(NSString *observedEvent, NSUInteger count,
                      CFTimeInterval terminalEpoch) {
                        CFTimeInterval liftTarget = terminalEpoch +
                            ([observedEvent isEqualToString:@"normalEnd"] ? 0.0 : 1.55);
                        [references markTerminalObservationForEvent:observedEvent
                            count:count terminalEpoch:terminalEpoch
                            liftTargetEpoch:liftTarget];
                        [references scheduleReleaseSnapshots];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [references recordImmediateReleaseSnapshot];
                        });
                    });
            };
            rearmTruthObservers();
        }
        NSMutableArray *accessibilityElements = [@[
            status, releaseStatus, terminalStatus, heldReleaseStatus,
            immediateReleaseStatus, exactReleaseStatus,
            postLiftReleaseStatus, editableButton, selectableButton, resignButton,
            selectableOnButton, dismissButton, detachButton, releaseButton,
        ] mutableCopy];
        if (!hidesEditorFromAccessibility) [accessibilityElements addObject:editor];
        controller.view.accessibilityElements = accessibilityElements;
    } else if (isIMEScenario) {
        controller.view.accessibilityElements =
            @[status, imeResignButton, imeUndoButton, editor];
    } else if (geometrySelectAllButton != nil) {
        controller.view.accessibilityElements =
            @[status, geometrySelectAllButton, editor];
    } else {
        controller.view.accessibilityElements = @[status, editor];
    }

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    [editor becomeFirstResponder];
    if (isAutocorrectionScenario || isInlinePredictionScenario) {
        [editor reloadInputViews];
        dispatch_async(dispatch_get_main_queue(), ^{
            [editor reloadInputViews];
        });
    }
    if ([scenario isEqualToString:@"floating-scroll"]) {
        __weak UITextView *weakEditor = editor;
        dispatch_async(dispatch_get_main_queue(), ^{
            UITextView *editor = weakEditor;
            if (editor == nil) return;
            [controller.view layoutIfNeeded];
            [editor layoutIfNeeded];
            NSString *edge = NSProcessInfo.processInfo.environment[@"IDFloatingScrollEdge"];
            CGRect caret = [editor caretRectForPosition:editor.selectedTextRange.end];
            CGFloat viewportY = [edge isEqualToString:@"upper"]
                ? 45.0
                : CGRectGetHeight(editor.bounds) - 45.0;
            CGFloat offsetY = MAX(CGRectGetMidY(caret) - viewportY, 0.0);
            [editor setContentOffset:CGPointMake(0, offsetY) animated:NO];
            [editor layoutIfNeeded];
        });
    }
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass(IDStockOracleAppDelegate.class));
    }
}
