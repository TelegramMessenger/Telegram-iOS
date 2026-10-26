#import "IDDemoViewController.h"

#import "IDBlockLayout.h"
#import "IDBlockDocument.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDInlineTextFormatting.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+Testing.h"
#import "IDPrivateUIKit+RichTextLayout.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "IDRichTextAnchor.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextPosition.h"
#import "IDRichTextRange.h"
#import "IDSelectionCallbackReductionProbe.h"
#import "IDTextView.h"
#import "IDTextViewInternal.h"
#import "IDUIKitBehaviorKernel.h"
#import "IDUIKitCapabilityResolver.h"
#import <objc/message.h>

static UITextInputMode *IDDemoEnglishUSInputMode(void) {
    Class modeClass = NSClassFromString(@"UIKeyboardInputMode");
    SEL selector = NSSelectorFromString(@"keyboardInputModeWithIdentifier:");
    if ([modeClass respondsToSelector:selector]) {
        id (*send)(id, SEL, id) = (void *)objc_msgSend;
        UITextInputMode *mode = send(
            modeClass, selector, @"en_US@hw=Automatic");
        if ([mode.primaryLanguage isEqualToString:@"en-US"]) return mode;
    }
    return nil;
}

static void IDDemoForceEnglishUSInputMode(void) {
    UITextInputMode *mode = IDDemoEnglishUSInputMode();
    if (mode == nil) return;
    Class controllerClass =
        NSClassFromString(@"UIKeyboardInputModeController");
    SEL sharedSelector = NSSelectorFromString(@"sharedInputModeController");
    if (![controllerClass respondsToSelector:sharedSelector]) return;
    id (*sendShared)(id, SEL) = (void *)objc_msgSend;
    id controller = sendShared(controllerClass, sharedSelector);
    SEL preferenceSelector =
        NSSelectorFromString(@"setCurrentInputModeInPreference:");
    if ([controller respondsToSelector:preferenceSelector]) {
        void (*sendPreference)(id, SEL, id) = (void *)objc_msgSend;
        sendPreference(controller, preferenceSelector, mode);
    }
    SEL forceSelector = NSSelectorFromString(@"_setCurrentInputMode:force:");
    if ([controller respondsToSelector:forceSelector]) {
        void (*sendForced)(id, SEL, id, BOOL) = (void *)objc_msgSend;
        sendForced(controller, forceSelector, mode, YES);
    }
}

@interface IDDemoEnglishUSTextView : IDTextView
@end

@interface IDDemoEnglishUSBlockTextView : IDBlockTextView
@end

@implementation IDDemoEnglishUSBlockTextView

- (UITextInputMode *)textInputMode {
    UITextInputMode *forcedMode = IDDemoEnglishUSInputMode();
    return forcedMode != nil ? forcedMode : super.textInputMode;
}

@end

@implementation IDDemoEnglishUSTextView

- (UITextInputMode *)textInputMode {
    UITextInputMode *forcedMode = IDDemoEnglishUSInputMode();
    if (forcedMode != nil) return forcedMode;
    for (UITextInputMode *mode in UITextInputMode.activeInputModes) {
        if ([mode.primaryLanguage isEqualToString:@"en-US"]) return mode;
    }
    return super.textInputMode;
}

@end

static NSDictionary<NSString *, id> *IDCustomGeometryBoundary(
    IDBlockTextView *editor,
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
        @"role": @"custom",
        @"scenario": scenario ?: @"none",
        @"selection": selection,
    };
}

static void IDDemoInlinePredictionActionNotification(
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

static NSArray<NSDictionary<NSString *, NSNumber *> *> *IDDemoVisibleSelectionHandles(
    UIView *root) {
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *result = [NSMutableArray array];
    for (NSValue *value in IDPrivateVisibleSelectionHandleRects(root)) {
        CGRect rect = value.CGRectValue;
        [result addObject:@{@"x": @(rect.origin.x), @"y": @(rect.origin.y),
                            @"width": @(rect.size.width), @"height": @(rect.size.height)}];
    }
    return result.copy;
}

static NSString *const IDDemoAttachmentUTI = @"com.inputdec.demo.attachment";

static IDInlineTextTraits IDDemoSemanticInlineTraits(
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    IDInlineTextTraits traits = 0;
    if ([attributes[IDInlineTextBoldAttributeName] boolValue])
        traits |= IDInlineTextTraitBold;
    if ([attributes[IDInlineTextItalicAttributeName] boolValue])
        traits |= IDInlineTextTraitItalic;
    if ([attributes[IDInlineTextUnderlineAttributeName] boolValue])
        traits |= IDInlineTextTraitUnderline;
    if ([attributes[IDInlineTextStrikethroughAttributeName] boolValue])
        traits |= IDInlineTextTraitStrikethrough;
    return traits;
}

static NSArray<NSString *> *IDDemoInlineTraitNames(
    IDInlineTextTraits traits) {
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    if ((traits & IDInlineTextTraitBold) != 0)
        [names addObject:@"bold"];
    if ((traits & IDInlineTextTraitItalic) != 0)
        [names addObject:@"italic"];
    if ((traits & IDInlineTextTraitUnderline) != 0)
        [names addObject:@"underline"];
    if ((traits & IDInlineTextTraitStrikethrough) != 0)
        [names addObject:@"strikethrough"];
    return names.copy;
}

static NSString *IDDemoInlineTraitStateName(
    IDInlineTextTraitState state) {
    switch (state) {
        case IDInlineTextTraitStateOn:
            return @"on";
        case IDInlineTextTraitStateMixed:
            return @"mixed";
        case IDInlineTextTraitStateOff:
            return @"off";
    }
}

static NSArray<NSDictionary<NSString *, id> *> *IDDemoInlineRuns(
    NSAttributedString *block) {
    NSMutableArray<NSDictionary<NSString *, id> *> *runs =
        [NSMutableArray array];
    NSUInteger location = 0;
    while (location < block.length) {
        NSRange effectiveRange = NSMakeRange(0, 0);
        NSDictionary<NSAttributedStringKey, id> *attributes =
            [block attributesAtIndex:location
               longestEffectiveRange:&effectiveRange
                             inRange:NSMakeRange(location,
                                                 block.length - location)];
        NSArray<NSString *> *traits =
            IDDemoInlineTraitNames(IDDemoSemanticInlineTraits(attributes));
        NSDictionary<NSString *, id> *last = runs.lastObject;
        NSRange lastRange = last == nil
            ? NSMakeRange(NSNotFound, 0)
            : NSMakeRange([last[@"range"][@"location"] unsignedIntegerValue],
                          [last[@"range"][@"length"] unsignedIntegerValue]);
        if (last != nil && NSMaxRange(lastRange) == effectiveRange.location &&
            [last[@"traits"] isEqual:traits]) {
            runs[runs.count - 1] = @{
                @"range": @{
                    @"location": @(lastRange.location),
                    @"length": @(lastRange.length + effectiveRange.length),
                },
                @"traits": traits,
            };
        } else {
            [runs addObject:@{
                @"range": @{
                    @"location": @(effectiveRange.location),
                    @"length": @(effectiveRange.length),
                },
                @"traits": traits,
            }];
        }
        location = NSMaxRange(effectiveRange);
    }
    return runs.copy;
}

@interface IDTextView (IDDemoContinuousSpelling)
- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled;
@end

@interface IDDemoStatusView : UIView
@property(nonatomic, copy) NSString *statusValue;
@property(nonatomic, copy) NSString *(^statusValueProvider)(void);
@end

@implementation IDDemoStatusView

- (void)setStatusValue:(NSString *)statusValue {
    if ((_statusValue == statusValue) || [_statusValue isEqualToString:statusValue]) {
        return;
    }
    _statusValue = [statusValue copy];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self);
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityValue {
    return self.statusValueProvider != nil ? self.statusValueProvider() : self.statusValue;
}

@end

@interface IDDemoAttachmentView : UIView
@property(nonatomic, weak) IDTextView *editor;
@end

@implementation IDDemoAttachmentView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.isAccessibilityElement = YES;
        self.accessibilityIdentifier = @"attachment-provider";
        self.accessibilityLabel = @"Text attachment provider";
        self.backgroundColor = UIColor.systemBlueColor;
        self.layer.cornerRadius = 3;
    }
    return self;
}

- (NSString *)accessibilityValue {
    IDTextView *editor = self.editor;
    if (editor == nil || self.superview == nil) {
        return @"document-frame=unavailable";
    }
    CGRect frame = [self convertRect:self.bounds toView:editor.id_canvasView];
    frame.origin.x += CGRectGetMinX(editor.id_canvasView.frame);
    frame.origin.y += CGRectGetMinY(editor.id_canvasView.frame);
    return [NSString stringWithFormat:
        @"document-frame={{%.3f,%.3f},{%.3f,%.3f}}",
        frame.origin.x, frame.origin.y, frame.size.width, frame.size.height];
}

@end

@interface IDDemoAttachment : NSTextAttachment
@property(nonatomic, weak) IDTextView *editor;
@property(nonatomic, strong) IDDemoAttachmentView *providedView;
@end

@interface IDDemoAttachmentProvider : NSTextAttachmentViewProvider
@end

@implementation IDDemoAttachmentProvider

- (BOOL)tracksTextAttachmentViewBounds {
    return YES;
}

- (void)loadView {
    IDDemoAttachment *attachment = (IDDemoAttachment *)self.textAttachment;
    attachment.providedView.editor = attachment.editor;
    self.view = attachment.providedView;
}

- (CGRect)attachmentBoundsForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                                location:(id<NSTextLocation>)location
                           textContainer:(NSTextContainer *)textContainer
                    proposedLineFragment:(CGRect)proposedLineFragment
                                position:(CGPoint)position {
    return CGRectMake(0, -2, 36, 20);
}

@end

@implementation IDDemoAttachment

- (instancetype)initWithEditor:(IDTextView *)editor {
    [NSTextAttachment registerTextAttachmentViewProviderClass:IDDemoAttachmentProvider.class
                                                  forFileType:IDDemoAttachmentUTI];
    self = [super initWithData:[@"InputDec UI attachment"
        dataUsingEncoding:NSUTF8StringEncoding]
                       ofType:IDDemoAttachmentUTI];
    if (self != nil) {
        self.fileType = IDDemoAttachmentUTI;
        self.allowsTextAttachmentView = YES;
        _editor = editor;
        _providedView = [[IDDemoAttachmentView alloc] initWithFrame:CGRectZero];
        _providedView.editor = editor;
    }
    return self;
}

@end

static NSString *const IDSampleText =
    @"A completely custom iOS 26 text view.\n\n"
     "Tap between characters, double-tap a word, or triple-tap this paragraph. "
     "Drag the caret and selection handles to explore cursor navigation and the loupe.\n\n"
     "Try a misspeled word for autocorrection and predictions. Hold the space bar for "
     "the floating cursor, dictate another sentence, and scroll through the longer text.\n\n"
     "Selection remains available when editing is disabled. The controls above can reset "
     "this sample, toggle editing and selection independently, dismiss the keyboard, and "
     "show the current private UIKit compatibility report.\n\n"
     "Cursor navigation\n"
     "Tap near the start, middle, and end of this paragraph. Use the arrow keys with a "
     "hardware keyboard, then hold the software keyboard space bar and move slowly to "
     "exercise the floating cursor across wrapped lines.\n\n"
     "Word and paragraph selection\n"
     "Double-tap individual words such as constellation, punctuation, and multilingual. "
     "Triple-tap this paragraph, drag both selection handles, and compare how the selection "
     "adapts when it crosses line fragments and paragraph separators.\n\n"
     "Loupe exploration\n"
     "Press and hold between these characters, then drag upward and sideways. The native "
     "interaction assistant owns the loupe gesture and keeps the magnified insertion point "
     "aligned with the TextKit 2 layout geometry.\n\n"
     "Autocorrection and prediction\n"
     "Type teh quik brown fox and accept or reject the suggested correction. Continue the "
     "sentence from the prediction bar, insert an emoji, and verify that composed character "
     "sequences remain intact while the caret moves.\n\n"
     "Dictation and marked text\n"
     "Dictate a short sentence here. If another keyboard is installed, enter marked text and "
     "move its internal selection before committing the composition. The controller remains "
     "the owner of marked ranges and input-delegate notifications.\n\n"
     "Scrolling and visibility\n"
     "Move the insertion point to this paragraph and type several lines. The editor should "
     "scroll the active range above the keyboard and preserve its content inset rather than "
     "jumping the caret underneath the bottom edge.\n\n"
     "Editing commands\n"
     "Select this sentence, copy it, paste it below, then undo and redo. Try Cut while editing "
     "is enabled and confirm that Copy remains available after Editable is switched Off.\n\n"
     "Selection-only mode\n"
     "Disable editing without disabling selection. Taps should still activate selection "
     "gestures, while the software keyboard stays dismissed and typed input cannot mutate "
     "the controller-owned string.\n\n"
     "Selectable lifecycle\n"
     "Turn Selectable Off and On repeatedly. Gesture installation should clear and restore "
     "the native recognizers without duplication, while editability remains an independent "
     "state reported by the control above.\n\n"
     "Long-document navigation\n"
     "Scroll toward the beginning, page through the middle, and return to this location. "
     "Selection rectangles, the caret, and the loupe should all remain in the editor's "
     "coordinate system as contentOffset changes.\n\n"
     "Accessibility\n"
     "The editor exposes its complete plain-text value on every query. The control titles "
     "wrap and reflow at accessibility sizes, and their labels and On or Off values continue "
     "to announce stable state to assistive technologies.\n\n"
     "International text\n"
     "Move across café, Ελληνικά, العربية, 日本語, and 👩🏽‍💻 without splitting a composed "
     "sequence. Select across scripts and paragraph direction changes to inspect tokenizer "
     "and affinity behavior at visual line boundaries.\n\n"
     "Final exploration notes\n"
     "Add observations here while comparing the custom implementation with UIKit behavior. "
     "This intentionally long corpus produces meaningful vertical overflow on phones and "
     "tablets so scrolling, caret visibility, and selection navigation remain easy to test.";

@interface IDSelectableDiagnosticLabel : UILabel
@end

@implementation IDSelectableDiagnosticLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        UILongPressGestureRecognizer *copyGesture =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                          action:@selector(copyReport:)];
        [self addGestureRecognizer:copyGesture];
        __weak IDSelectableDiagnosticLabel *weakSelf = self;
        self.accessibilityCustomActions = @[
            [[UIAccessibilityCustomAction alloc] initWithName:@"Copy report"
                                                actionHandler:^BOOL(UIAccessibilityCustomAction *action) {
                IDSelectableDiagnosticLabel *label = weakSelf;
                if (label == nil) return NO;
                [label copy:action];
                return YES;
            }],
        ];
    }
    return self;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)copy:(id)sender {
    UIPasteboard.generalPasteboard.string = self.text;
}

- (BOOL)copyReport:(id)sender {
    if ([sender isKindOfClass:UILongPressGestureRecognizer.class] &&
        [(UILongPressGestureRecognizer *)sender state] != UIGestureRecognizerStateBegan) {
        return NO;
    }
    [self copy:sender];
    return YES;
}

@end

@interface IDDemoViewController () <IDTextViewDelegate>
@property(nonatomic, strong) IDTextView *editor;
@property(nonatomic, strong) IDBlockTextView *blockEditor;
@property(nonatomic, strong) UIView *editorHostView;
@property(nonatomic, strong) UIButton *editorModeButton;
@property(nonatomic, strong) UIButton *editableButton;
@property(nonatomic, strong) UIButton *selectableButton;
@property(nonatomic, strong) UIStackView *primaryControls;
@property(nonatomic, strong) UIStackView *secondaryControls;
@property(nonatomic, strong) UIStackView *inlineFormattingControls;
@property(nonatomic, copy) NSArray<UIButton *> *inlineFormattingButtons;
@property(nonatomic, strong) IDDemoStatusView *inlineFormattingStatusView;
@property(nonatomic, copy) NSString *constructionCompatibilityFailure;
@property(nonatomic, copy) NSString *uiScenario;
@property(nonatomic, copy) NSString *blockUIScenario;
@property(nonatomic) IDUIKitBehaviorBackend behaviorBackend;
@property(nonatomic, strong) IDDemoStatusView *selectionStatusView;
@property(nonatomic, strong) IDDemoStatusView *spellingStatusView;
@property(nonatomic, strong) IDDemoStatusView *blockStatusView;
@property(nonatomic, strong) IDDemoStatusView *behaviorStatusView;
@property(nonatomic, strong) IDDemoStatusView *touchSelectionStatusView;
@property(nonatomic, strong) IDDemoStatusView *floatingCursorStatusView;
@property(nonatomic, strong) IDSelectionCallbackReductionProbe *selectionCallbackReductionProbe;
@property(nonatomic, strong) IDDemoStatusView *selectionCallbackReductionStatusView;
@property(nonatomic, strong) UIButton *selectionCallbackReductionRefreshButton;
@property(nonatomic, strong) IDPrivateFloatingLifecycleWeakReferences *floatingTruthReferences;
@property(nonatomic, copy) NSArray<IDDemoStatusView *> *floatingTruthStatusViews;
@property(nonatomic, copy) NSString *floatingTruthTerminalEvent;
@property(nonatomic, copy) NSString *floatingTruthActionEvent;
@property(nonatomic, strong) IDDemoAttachment *demoAttachment;
@property(nonatomic) NSUInteger autocorrectionBaselineDocumentRevision;
@property(nonatomic) NSUInteger inlinePredictionBaselineDocumentRevision;
@property(nonatomic) NSUInteger imeBaselineDocumentRevision;
@end

@implementation IDDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"InputDec";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.uiScenario = [self id_requestedUIScenario];
    self.blockUIScenario = [self id_requestedBlockUIScenario];
    self.behaviorBackend = [self id_requestedBehaviorBackend];

    if (self.behaviorBackend == IDUIKitBehaviorBackendReference &&
        ![self id_isPrivateUIKitCompatible]) {
        [self showFatalCompatibilityReport];
        return;
    }

    if (![self buildCompatibleDemo]) {
        return;
    }
    if (self.blockUIScenario.length > 0) {
        [self id_configureBlockUIScenario];
    } else {
        [self id_configureUIScenarioIfNeeded];
    }
    __weak IDDemoViewController *weakSelf = self;
    [self registerForTraitChanges:@[UITraitPreferredContentSizeCategory.class]
                     withHandler:^(__kindof id<UITraitEnvironment> environment,
                                   UITraitCollection *previousCollection) {
        [weakSelf updateControlLayoutForCurrentTraits];
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateControlLayoutForCurrentTraits];
    [self id_scheduleUIStatusUpdate];
}

- (NSString *)id_requestedUIScenario {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [arguments indexOfObject:@"--id-ui-scenario"];
    if (index == NSNotFound || index + 1 >= arguments.count) {
        return nil;
    }
    NSString *scenario = arguments[index + 1];
    NSSet<NSString *> *supported = [NSSet setWithArray:@[
        @"caret", @"selection", @"spelling", @"attachment",
    ]];
    return [supported containsObject:scenario] ? scenario : nil;
}

- (BOOL)id_selectionCallbackReducedSurfaceRequested {
    return [NSProcessInfo.processInfo.arguments
        containsObject:@"--id-selection-callback-reduced-surface"];
}

- (void)id_installSelectionCallbackReductionProbeIfNeeded {
    if (![self id_selectionCallbackReducedSurfaceRequested] || self.blockEditor == nil) {
        return;
    }

    IDSelectionCallbackReductionProbe *probe =
        [[IDSelectionCallbackReductionProbe alloc]
            initWithEditor:self.blockEditor];
    IDDemoStatusView *status = [[IDDemoStatusView alloc]
        initWithFrame:CGRectMake(0, 0, 2, 2)];
    status.accessibilityIdentifier = @"selection-callback-reduced-surface-status";
    status.accessibilityLabel = @"selection-callback-reduced-surface-status";
    status.backgroundColor = UIColor.clearColor;
    __weak IDSelectionCallbackReductionProbe *weakProbe = probe;
    status.statusValueProvider = ^NSString *{
        return [weakProbe serializedSnapshot] ?: @"{}";
    };
    [self.view insertSubview:status atIndex:0];

    UIButton *refresh = [self buttonWithTitle:@"Refresh Selection Callback Status"
                                   identifier:@"selection-callback-reduced-surface-refresh"
                                       action:@selector(id_refreshSelectionCallbackReductionStatus:)];
    refresh.frame = CGRectMake(16, 190, 220, 32);
    [self.view addSubview:refresh];

    self.selectionCallbackReductionProbe = probe;
    self.selectionCallbackReductionStatusView = status;
    self.selectionCallbackReductionRefreshButton = refresh;

    NSMutableArray *elements =
        [self.view.accessibilityElements mutableCopy] ?: [NSMutableArray array];
    [elements insertObject:status atIndex:0];
    [elements insertObject:refresh atIndex:1];
    self.view.accessibilityElements = elements;
}

- (void)id_refreshSelectionCallbackReductionStatus:(id)sender {
    (void)sender;
    self.selectionCallbackReductionStatusView.statusValue =
        [self.selectionCallbackReductionProbe serializedSnapshot];
    [self.selectionCallbackReductionStatusView setNeedsLayout];
}

- (NSString *)id_requestedBlockUIScenario {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [arguments indexOfObject:@"--id-block-ui-scenario"];
    if (index == NSNotFound || index + 1 >= arguments.count) {
        return nil;
    }
    NSString *scenario = arguments[index + 1];
    NSSet<NSString *> *supported = [NSSet setWithArray:@[
        @"caret", @"selection", @"boundary", @"spelling",
        @"touch-ltr", @"touch-boundary", @"touch-bidi", @"touch-autoscroll",
        @"floating-ltr", @"floating-boundary", @"floating-bidi", @"floating-scroll",
        @"autocorrection-interior", @"autocorrection-before-boundary",
        @"autocorrection-after-boundary",
        @"inline-prediction-interior", @"inline-prediction-before-boundary",
        @"inline-prediction-after-boundary",
        @"inline-formatting",
        @"inline-formatting-keyboard",
        @"navigation-horizontal",
        @"navigation-vertical",
        @"navigation-selection",
        @"geometry-authority",
        @"geometry-large-selection",
    ]];
    return [supported containsObject:scenario] ||
        [scenario hasPrefix:@"ime-"] ? scenario : nil;
}

- (IDUIKitBehaviorBackend)id_requestedBehaviorBackend {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index =
        [arguments indexOfObject:@"-InputDecBehaviorBackend"];
    if (index != NSNotFound && index + 1 < arguments.count &&
        [arguments[index + 1] isEqualToString:@"minimal"]) {
        return IDUIKitBehaviorBackendMinimalKernel;
    }
    return IDUIKitBehaviorBackendReference;
}

- (BOOL)id_isPrivateUIKitCompatible {
    return IDPrivateUIKit.isCompatible;
}

- (NSString *)id_privateUIKitCompatibilityReport {
    return IDPrivateUIKit.compatibilityReport;
}

- (UIButton *)buttonWithTitle:(NSString *)title
                   identifier:(NSString *)identifier
                       action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.accessibilityLabel = title;
    button.accessibilityIdentifier = identifier;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIStackView *)buttonRow:(NSArray<UIView *> *)buttons {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentFill;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 8;
    return row;
}

- (UIButton *)inlineFormattingButtonWithTitle:(NSString *)title
                                         label:(NSString *)label
                                    identifier:(NSString *)identifier
                                         trait:(IDInlineTextTraits)trait {
    UIButton *button = [self buttonWithTitle:title
                                  identifier:identifier
                                      action:@selector(toggleInlineFormatting:)];
    button.accessibilityLabel = label;
    button.accessibilityValue = @"Off";
    button.tag = (NSInteger)trait;
    return button;
}

- (void)installInlineFormattingControls {
    self.inlineFormattingButtons = @[
        [self inlineFormattingButtonWithTitle:@"B"
                                        label:@"Bold"
                                   identifier:@"inline-format-bold"
                                        trait:IDInlineTextTraitBold],
        [self inlineFormattingButtonWithTitle:@"I"
                                        label:@"Italic"
                                   identifier:@"inline-format-italic"
                                        trait:IDInlineTextTraitItalic],
        [self inlineFormattingButtonWithTitle:@"U"
                                        label:@"Underline"
                                   identifier:@"inline-format-underline"
                                        trait:IDInlineTextTraitUnderline],
        [self inlineFormattingButtonWithTitle:@"S"
                                        label:@"Strikethrough"
                                   identifier:@"inline-format-strikethrough"
                                        trait:IDInlineTextTraitStrikethrough],
    ];
    self.inlineFormattingControls =
        [self buttonRow:self.inlineFormattingButtons];
    self.inlineFormattingControls.accessibilityIdentifier =
        @"inline-format-controls";
    self.inlineFormattingControls.hidden = YES;

    IDDemoStatusView *status =
        [[IDDemoStatusView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
    status.accessibilityIdentifier = @"inline-format-diagnostics";
    status.accessibilityLabel = @"inline-format-diagnostics";
    status.backgroundColor = UIColor.clearColor;
    __weak IDDemoViewController *weakSelf = self;
    status.statusValueProvider = ^NSString *{
        return [weakSelf id_blockStatusValue];
    };
    self.inlineFormattingStatusView = status;
    [self.view insertSubview:status atIndex:0];
}

- (IDTextView *)id_newEditor {
    if ([NSProcessInfo.processInfo.environment[
            @"IDForceEnglishUSInputMode"] isEqualToString:@"1"]) {
        IDTextView *editor =
            [[IDDemoEnglishUSTextView alloc] initWithFrame:CGRectZero];
        editor.keyboardType = UIKeyboardTypeASCIICapable;
        return editor;
    }
    return [[IDTextView alloc] initWithFrame:CGRectZero];
}

- (BOOL)buildCompatibleDemo {
    UIButton *reset = [self buttonWithTitle:@"Reset"
                                 identifier:@"reset-button"
                                     action:@selector(reset:)];
    self.editableButton = [self buttonWithTitle:@"Editable"
                                      identifier:@"editable-toggle"
                                          action:@selector(toggleEditable:)];
    self.selectableButton = [self buttonWithTitle:@"Selectable"
                                        identifier:@"selectable-toggle"
                                            action:@selector(toggleSelectable:)];
    UIButton *dismiss = [self buttonWithTitle:@"Dismiss"
                                    identifier:@"dismiss-button"
                                        action:@selector(dismissKeyboard:)];
    UIButton *diagnostics = [self buttonWithTitle:@"Diagnostics"
                                        identifier:@"diagnostics-button"
                                            action:@selector(showDiagnostics:)];
    self.editorModeButton = [self buttonWithTitle:@"Multi-Block Experiment"
                                        identifier:@"editor-mode-toggle"
                                            action:@selector(toggleEditorMode:)];
    [self installInlineFormattingControls];

    self.primaryControls = [self buttonRow:@[
        reset,
        self.editableButton,
        self.selectableButton,
    ]];
    self.primaryControls.accessibilityIdentifier = @"primary-controls";
    self.secondaryControls = [self buttonRow:@[dismiss, diagnostics, self.editorModeButton]];
    self.secondaryControls.accessibilityIdentifier = @"secondary-controls";
    UIStackView *controls = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.primaryControls,
        self.secondaryControls,
        self.inlineFormattingControls,
    ]];
    controls.axis = UILayoutConstraintAxisVertical;
    controls.spacing = 6;
    controls.translatesAutoresizingMaskIntoConstraints = NO;

    UIScrollView *controlsScrollView = [UIScrollView new];
    controlsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    controlsScrollView.directionalLockEnabled = YES;
    controlsScrollView.showsHorizontalScrollIndicator = NO;
    controlsScrollView.accessibilityIdentifier = @"controls-scroll-view";
    [controlsScrollView addSubview:controls];

    UIView *initialEditor = nil;
    @try {
        if (self.blockUIScenario.length > 0) {
            IDBlockTextView *blockEditor = [self id_newBlockEditorForScenario:self.blockUIScenario];
            [IDPrivateUIKit requireObject:blockEditor stage:@"IDBlockTextView construction"];
            self.blockEditor = blockEditor;
            initialEditor = blockEditor;
        } else {
            IDTextView *editor = [self id_newEditor];
            [IDPrivateUIKit requireObject:editor stage:@"IDTextView construction"];
            editor.translatesAutoresizingMaskIntoConstraints = NO;
            editor.accessibilityIdentifier = @"custom-text-view";
            editor.accessibilityLabel = @"Custom text editor";
            editor.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
            editor.text = IDSampleText;
            editor.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            editor.layer.borderColor = UIColor.separatorColor.CGColor;
            editor.layer.borderWidth = 0.5;
            editor.layer.cornerRadius = 10;
            self.editor = editor;
            initialEditor = editor;
        }
    } @catch (NSException *exception) {
        if (![exception.name isEqualToString:NSInternalInconsistencyException]) {
            @throw;
        }
        self.constructionCompatibilityFailure = [NSString stringWithFormat:
            @"Private editor construction failed.\n%@",
            exception.reason ?: exception.description];
        [self showFatalCompatibilityReport];
        return NO;
    }
    [self updateInlineFormattingFeedback];
    [self updateToggleFeedback];
    [self updateControlLayoutForCurrentTraits];

    UIView *editorHost = [UIView new];
    editorHost.translatesAutoresizingMaskIntoConstraints = NO;
    editorHost.accessibilityIdentifier = @"editor-host";
    self.editorHostView = editorHost;
    [editorHost addSubview:initialEditor];
    [self.view addSubview:controlsScrollView];
    [self.view addSubview:editorHost];
    UILayoutGuide *margins = self.view.layoutMarginsGuide;
    NSLayoutConstraint *controlsFitHeight =
        [controlsScrollView.heightAnchor constraintEqualToAnchor:controls.heightAnchor];
    controlsFitHeight.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *editorHostBottom =
        [editorHost.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor
                                                 constant:-8];
    NSMutableArray<NSLayoutConstraint *> *layoutConstraints = [@[
        [controlsScrollView.topAnchor
            constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                           constant:8],
        [controlsScrollView.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [controlsScrollView.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [controlsScrollView.heightAnchor
            constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor
                                    multiplier:0.45],
        controlsFitHeight,
        [controls.topAnchor
            constraintEqualToAnchor:controlsScrollView.contentLayoutGuide.topAnchor],
        [controls.leadingAnchor
            constraintEqualToAnchor:controlsScrollView.contentLayoutGuide.leadingAnchor],
        [controls.trailingAnchor
            constraintEqualToAnchor:controlsScrollView.contentLayoutGuide.trailingAnchor],
        [controls.bottomAnchor
            constraintEqualToAnchor:controlsScrollView.contentLayoutGuide.bottomAnchor],
        [controls.widthAnchor
            constraintEqualToAnchor:controlsScrollView.frameLayoutGuide.widthAnchor],
        [editorHost.topAnchor constraintEqualToAnchor:controlsScrollView.bottomAnchor constant:8],
        [editorHost.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [editorHost.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        editorHostBottom,
        [initialEditor.topAnchor constraintEqualToAnchor:editorHost.topAnchor],
        [initialEditor.leadingAnchor constraintEqualToAnchor:editorHost.leadingAnchor],
        [initialEditor.trailingAnchor constraintEqualToAnchor:editorHost.trailingAnchor],
        [initialEditor.bottomAnchor constraintEqualToAnchor:editorHost.bottomAnchor],
    ] mutableCopy];
    if ([self.blockUIScenario isEqualToString:@"touch-autoscroll"] ||
        [self.blockUIScenario isEqualToString:@"floating-scroll"]) {
        editorHostBottom.active = NO;
        [layoutConstraints removeObject:editorHostBottom];
        [layoutConstraints addObject:
            [editorHost.bottomAnchor constraintLessThanOrEqualToAnchor:
                self.view.keyboardLayoutGuide.topAnchor constant:-8]];
        [layoutConstraints addObject:
            [editorHost.heightAnchor constraintEqualToConstant:360.0]];
    }
    [NSLayoutConstraint activateConstraints:layoutConstraints];
    return YES;
}

- (NSArray<NSAttributedString *> *)id_blockDemoBlocksForScenario:(NSString *)scenario {
    NSArray<NSString *> *strings = nil;
    if ([scenario isEqualToString:@"inline-prediction-interior"]) {
        strings = @[@"Earlier sentence.  ", @"Later block stays."];
    } else if ([scenario isEqualToString:
                   @"inline-prediction-before-boundary"]) {
        strings = @[@"Earlier sentence. ", @"Later block stays."];
    } else if ([scenario isEqualToString:
                   @"inline-prediction-after-boundary"]) {
        strings = @[@"Earlier sentence.", @" ", @"Later block stays."];
    } else if ([scenario isEqualToString:@"autocorrection-interior"]) {
        strings = @[
            @"A quiet  lantern waits.", @"Second block stays unchanged.",
        ];
    } else if ([scenario isEqualToString:@"autocorrection-before-boundary"]) {
        strings = @[@"A quiet ", @"lantern waits."];
    } else if ([scenario isEqualToString:@"autocorrection-after-boundary"]) {
        strings = @[@"A quiet scene.", @" lantern waits."];
    } else if ([scenario hasPrefix:@"ime-"]) {
        strings = @[
            @"Alpha middle omega",
            @"Second block remains unchanged.",
        ];
    } else if ([scenario isEqualToString:@"floating-ltr"] ||
        [scenario isEqualToString:@"floating-scroll"]) {
        strings = @[
            @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
            @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
            @"Third paragraph provides a stable lower destination without leaving the viewport.",
        ];
    } else if ([scenario isEqualToString:@"floating-boundary"]) {
        strings = @[
            @"alpha beta omega",
            @"delta epsilon zeta",
            @"eta theta iota",
        ];
    } else if ([scenario isEqualToString:@"floating-bidi"]) {
        strings = @[
            @"left alpha אבגדה right omega",
            @"second שלום mixed tail",
            @"third paragraph final",
        ];
    } else if ([scenario isEqualToString:@"touch-ltr"] ||
        [scenario isEqualToString:@"touch-autoscroll"]) {
        strings = @[
            @"First wrapped paragraph contains constellation and punctuation for precise taps.",
            @"Second wrapped paragraph provides selection handles across independent blocks.",
            @"Third wrapped paragraph keeps the viewport tall enough for controlled scrolling.",
        ];
    } else if ([scenario isEqualToString:@"touch-boundary"]) {
        strings = @[@"Boundary alpha omega", @"Boundary beta gamma"];
    } else if ([scenario isEqualToString:@"touch-bidi"]) {
        strings = @[@"English prefix", @"אבגדה mixed suffix"];
    } else if ([scenario isEqualToString:@"inline-formatting"]) {
        strings = @[@"Alpha", @"Beta"];
    } else if ([scenario isEqualToString:@"inline-formatting-keyboard"]) {
        strings = @[@""];
    } else if ([scenario isEqualToString:@"navigation-horizontal"]) {
        strings = @[@"abc אבג", @"A👨‍👩‍👧‍👦B", @"", @"", @"tail"];
    } else if ([scenario isEqualToString:@"navigation-vertical"]) {
        strings = @[@"abcdefghijklmno", @"xy", @"abcdefghijklmno"];
    } else if ([scenario isEqualToString:@"navigation-selection"]) {
        strings = @[@"alpha", @"", @"beta", @"gamma"];
    } else if ([scenario isEqualToString:@"geometry-authority"]) {
        strings = @[
            @"alpha beta wrapped words",
            @"",
            @"אבגדה six mixed text",
            @"A👨‍👩‍👧‍👦B composed tail",
            @"final block",
        ];
    } else if ([scenario isEqualToString:@"geometry-large-selection"]) {
        NSMutableArray<NSString *> *large = [NSMutableArray array];
        for (NSUInteger index = 0; index < 120; index += 1) {
            [large addObject:[NSString stringWithFormat:@"block %03lu",
                (unsigned long)index]];
        }
        strings = large.copy;
    } else if ([scenario isEqualToString:@"caret"] || [scenario isEqualToString:@"spelling"]) {
        strings = @[@""];
    } else if ([scenario isEqualToString:@"selection"] ||
               [scenario isEqualToString:@"boundary"]) {
        strings = @[@"alpha", @"beta"];
    } else {
        strings = @[
            @"Multi-block editing keeps this paragraph in its own TextKit 2 graph.",
            @"Return splits blocks; backward-delete at this boundary merges them again.",
        ];
    }
    NSMutableArray<NSString *> *fixtureStrings = [strings mutableCopy];
    if ([scenario isEqualToString:@"touch-autoscroll"]) {
        for (NSUInteger index = 0; index < 30; index += 1) {
            [fixtureStrings addObject:[NSString stringWithFormat:
                @"Autoscroll block %02lu carries enough words to wrap.",
                (unsigned long)index]];
        }
    } else if ([scenario isEqualToString:@"floating-scroll"]) {
        for (NSUInteger index = 0; index < 30; index += 1) {
            [fixtureStrings addObject:[NSString stringWithFormat:
                @"Floating cursor block %02lu carries enough words to wrap.",
                (unsigned long)index]];
        }
    }
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    UIFont *font = ([scenario hasPrefix:@"floating-"] ||
                    [scenario hasPrefix:@"navigation-"] ||
                    [scenario hasPrefix:@"geometry-"])
        ? [UIFont systemFontOfSize:20.0]
        : [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: UIColor.labelColor,
    };
    for (NSString *string in fixtureStrings) {
        NSMutableAttributedString *block = [[NSMutableAttributedString alloc]
            initWithString:string attributes:attributes];
        if ([scenario isEqualToString:@"inline-formatting"] &&
            blocks.count == 0 && block.length > 0) {
            [block addAttribute:IDInlineTextBoldAttributeName
                          value:@YES
                          range:NSMakeRange(0, block.length)];
        }
        [blocks addObject:block.copy];
    }
    return blocks.copy;
}

- (IDBlockTextView *)id_newBlockEditorForScenario:(NSString *)scenario {
    Class editorClass = [NSProcessInfo.processInfo.environment[
            @"IDForceEnglishUSInputMode"] isEqualToString:@"1"]
        ? IDDemoEnglishUSBlockTextView.class : IDBlockTextView.class;
    IDBlockTextView *editor = [[editorClass alloc]
        initWithFrame:CGRectZero
      attributedBlocks:[self id_blockDemoBlocksForScenario:scenario]
       behaviorBackend:self.behaviorBackend
               resolver:[IDUIKitCapabilityResolver systemResolver]
  requestedCapabilities:
      IDUIKitBehaviorCapabilityInputController |
      IDUIKitBehaviorCapabilityIncomingCallbacks |
      IDUIKitBehaviorCapabilityTypingAttributes |
      IDUIKitBehaviorCapabilityInteraction |
      IDUIKitBehaviorCapabilityFloatingCursor |
      IDUIKitBehaviorCapabilityAutoscroll |
      IDUIKitBehaviorCapabilityChecking |
      IDUIKitBehaviorCapabilityPrediction |
      IDUIKitBehaviorCapabilityPaste |
      IDUIKitBehaviorCapabilityDictation
selectionPresentationBackendFactory:
        [IDBlockTextView
            id_defaultSelectionPresentationBackendFactory]];
    if ([NSProcessInfo.processInfo.environment[
            @"IDForceEnglishUSInputMode"] isEqualToString:@"1"]) {
        editor.keyboardType = UIKeyboardTypeASCIICapable;
    }
    editor.translatesAutoresizingMaskIntoConstraints = NO;
    editor.accessibilityIdentifier = @"block-text-view";
    editor.accessibilityLabel = @"Multi-block text editor";
    editor.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
    editor.font = [UIFont systemFontOfSize:scenario.length > 0 ? 20 : 17];
    editor.layer.borderColor = UIColor.separatorColor.CGColor;
    editor.layer.borderWidth = 0.5;
    editor.layer.cornerRadius = 10;
    __weak IDDemoViewController *weakSelf = self;
    editor.inlineTextTraitStateDidChangeHandler = ^{
        [weakSelf updateInlineFormattingFeedback];
    };
    return editor;
}

- (void)id_installEditorView:(UIView *)editorView {
    for (UIView *subview in self.editorHostView.subviews.copy) {
        [subview removeFromSuperview];
    }
    [self.editorHostView addSubview:editorView];
    [NSLayoutConstraint activateConstraints:@[
        [editorView.topAnchor constraintEqualToAnchor:self.editorHostView.topAnchor],
        [editorView.leadingAnchor constraintEqualToAnchor:self.editorHostView.leadingAnchor],
        [editorView.trailingAnchor constraintEqualToAnchor:self.editorHostView.trailingAnchor],
        [editorView.bottomAnchor constraintEqualToAnchor:self.editorHostView.bottomAnchor],
    ]];
}

- (void)toggleEditorMode:(id)sender {
    if (self.blockEditor == nil) {
        [self.editor resignFirstResponder];
        [self.editor removeFromSuperview];
        self.editor = nil;
        self.blockEditor = [self id_newBlockEditorForScenario:nil];
        [self id_installEditorView:self.blockEditor];
        [self.editorModeButton setTitle:@"Flat Oracle" forState:UIControlStateNormal];
        self.editorModeButton.accessibilityLabel = @"Flat Oracle";
    } else {
        [self.blockEditor resignFirstResponder];
        [self.blockEditor id_tearDownEditorGraph];
        [self.blockEditor removeFromSuperview];
        self.blockEditor = nil;
        IDTextView *editor = [self id_newEditor];
        editor.translatesAutoresizingMaskIntoConstraints = NO;
        editor.accessibilityIdentifier = @"custom-text-view";
        editor.accessibilityLabel = @"Custom text editor";
        editor.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
        editor.text = IDSampleText;
        editor.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        editor.layer.borderColor = UIColor.separatorColor.CGColor;
        editor.layer.borderWidth = 0.5;
        editor.layer.cornerRadius = 10;
        self.editor = editor;
        [self id_installEditorView:editor];
        [self.editorModeButton setTitle:@"Multi-Block Experiment" forState:UIControlStateNormal];
        self.editorModeButton.accessibilityLabel = @"Multi-Block Experiment";
    }
    [self updateInlineFormattingFeedback];
    [self updateToggleFeedback];
}

- (void)showFatalCompatibilityReport {
    UILabel *report = [IDSelectableDiagnosticLabel new];
    report.translatesAutoresizingMaskIntoConstraints = NO;
    report.numberOfLines = 0;
    report.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    report.adjustsFontForContentSizeCategory = YES;
    report.textColor = UIColor.labelColor;
    report.text = self.constructionCompatibilityFailure ?:
        [self id_privateUIKitCompatibilityReport];
    report.userInteractionEnabled = YES;
    report.tag = 2601;
    report.accessibilityIdentifier = @"fatal-compatibility-report";
    report.accessibilityTraits |= UIAccessibilityTraitStaticText;
    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.accessibilityIdentifier = @"fatal-compatibility-scroll";
    [scrollView addSubview:report];
    [self.view addSubview:scrollView];
    UILayoutGuide *margins = self.view.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [report.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor
                                         constant:16],
        [report.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [report.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [report.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor
                                            constant:-16],
        [report.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],
    ]];
}

- (void)updateToggleFeedback {
    BOOL editable = self.blockEditor != nil ? self.blockEditor.isEditable : self.editor.isEditable;
    BOOL selectable = self.blockEditor != nil ? self.blockEditor.isSelectable : self.editor.isSelectable;
    NSString *editableState = editable ? @"On" : @"Off";
    NSString *selectableState = selectable ? @"On" : @"Off";
    [self.editableButton setTitle:[NSString stringWithFormat:@"Editable: %@", editableState]
                         forState:UIControlStateNormal];
    [self.selectableButton setTitle:[NSString stringWithFormat:@"Selectable: %@", selectableState]
                           forState:UIControlStateNormal];
    self.editableButton.accessibilityValue = editableState;
    self.selectableButton.accessibilityValue = selectableState;
}

- (void)updateControlLayoutForCurrentTraits {
    BOOL accessibility = UIContentSizeCategoryIsAccessibilityCategory(
        self.traitCollection.preferredContentSizeCategory);
    UILayoutConstraintAxis axis = accessibility
        ? UILayoutConstraintAxisVertical
        : UILayoutConstraintAxisHorizontal;
    self.primaryControls.axis = axis;
    self.secondaryControls.axis = axis;
    self.inlineFormattingControls.axis = axis;
}

- (NSString *)inlineFormattingValueForState:
    (IDInlineTextTraitState)state {
    switch (state) {
        case IDInlineTextTraitStateOn:
            return @"On";
        case IDInlineTextTraitStateMixed:
            return @"Mixed";
        case IDInlineTextTraitStateOff:
            return @"Off";
    }
}

- (void)updateInlineFormattingFeedback {
    IDBlockTextView *editor = self.blockEditor;
    BOOL showsFormattingControls =
        editor != nil &&
        (self.blockUIScenario.length == 0 ||
         [self.blockUIScenario hasPrefix:@"inline-formatting"]);
    self.inlineFormattingControls.hidden = !showsFormattingControls;
    for (UIButton *button in self.inlineFormattingButtons) {
        NSString *value = editor == nil
            ? @"Off"
            : [self inlineFormattingValueForState:
                [editor stateForInlineTextTrait:
                    (IDInlineTextTraits)button.tag]];
        button.accessibilityValue = value;
        [button setTitle:[NSString stringWithFormat:@"%@: %@",
            [button.currentTitle componentsSeparatedByString:@":"].firstObject,
            value]
                forState:UIControlStateNormal];
    }
}

- (void)toggleInlineFormatting:(UIButton *)sender {
    [self.blockEditor toggleInlineTextTrait:(IDInlineTextTraits)sender.tag];
    [self updateInlineFormattingFeedback];
}

- (void)reset:(id)sender {
    if (self.blockEditor != nil) {
        self.blockEditor.text =
            @"Multi-block editing keeps this paragraph in its own TextKit 2 graph.\n"
             "Return splits blocks; backward-delete at this boundary merges them again.";
        UITextPosition *start = self.blockEditor.beginningOfDocument;
        self.blockEditor.selectedTextRange =
            [self.blockEditor textRangeFromPosition:start toPosition:start];
        return;
    }
    self.editor.text = IDSampleText;
    self.editor.selectedTextRange = [self.editor textRangeFromPosition:self.editor.beginningOfDocument
                                                             toPosition:self.editor.beginningOfDocument];
}

- (void)toggleEditable:(id)sender {
    if (self.blockEditor != nil) {
        self.blockEditor.editable = !self.blockEditor.isEditable;
        if (!self.blockEditor.isEditable) [self.blockEditor resignFirstResponder];
        IDPrivateResetInteractionHostTopologyBaselineForUITesting(
            self.blockEditor, self.blockEditor.id_blockStack, nil);
        [self updateToggleFeedback];
        return;
    }
    self.editor.editable = !self.editor.isEditable;
    if (!self.editor.isEditable) {
        [self.editor resignFirstResponder];
    }
    [self updateToggleFeedback];
}

- (void)toggleSelectable:(id)sender {
    if (self.blockEditor != nil) {
        self.blockEditor.selectable = !self.blockEditor.isSelectable;
        IDPrivateResetInteractionHostTopologyBaselineForUITesting(
            self.blockEditor, self.blockEditor.id_blockStack, nil);
        [self updateToggleFeedback];
        return;
    }
    self.editor.selectable = !self.editor.isSelectable;
    [self updateToggleFeedback];
}

- (void)dismissKeyboard:(id)sender {
    UIResponder *editor = self.blockEditor != nil ? self.blockEditor : self.editor;
    [editor resignFirstResponder];
}

- (void)showDiagnostics:(id)sender {
    NSString *report = [self id_privateUIKitCompatibilityReport];
    NSString *backend = self.behaviorBackend ==
        IDUIKitBehaviorBackendMinimalKernel ? @"minimal" : @"reference";
    NSDictionary *behavior = self.blockEditor.id_behaviorReport == nil
        ? @{
            @"backend": backend,
            @"capabilities": @[],
        }
        : @{
            @"backend": backend,
            @"report":
                [self.blockEditor.id_behaviorReport normalizedDictionary],
        };
    NSData *behaviorData = [NSJSONSerialization
        dataWithJSONObject:behavior
                   options:NSJSONWritingSortedKeys
                     error:nil];
    NSString *behaviorDescription = behaviorData == nil
        ? @"{}"
        : [[NSString alloc] initWithData:behaviorData
                                encoding:NSUTF8StringEncoding];
    report = [NSString stringWithFormat:
        @"Behavior backend: %@\n%@\n\n%@",
        backend, behaviorDescription, report];
    NSString *title =
        self.behaviorBackend == IDUIKitBehaviorBackendMinimalKernel ||
        [self id_isPrivateUIKitCompatible]
            ? @"Behavior capabilities"
            : @"Compatibility failure";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:report
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.view.accessibilityIdentifier = @"compatibility-report";
    [alert addAction:[UIAlertAction actionWithTitle:@"Done"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)id_configureUIScenarioIfNeeded {
    if (self.uiScenario.length == 0) {
        return;
    }

    self.editor.delegate = self;
    self.editor.font = [UIFont systemFontOfSize:20];
    self.editor.textColor = UIColor.blackColor;
    self.editor.backgroundColor = UIColor.whiteColor;
    self.editor.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.editor.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.editor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.editor.smartQuotesType = UITextSmartQuotesTypeNo;
    self.editor.smartDashesType = UITextSmartDashesTypeNo;
    self.editor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    self.editor.inlinePredictionType = UITextInlinePredictionTypeNo;

    if ([self.uiScenario isEqualToString:@"caret"]) {
        self.editor.spellCheckingType = UITextSpellCheckingTypeNo;
        self.editor.text = @"";
        [self id_installStatusViewWithIdentifier:@"selection-status"];
    } else if ([self.uiScenario isEqualToString:@"selection"]) {
        self.editor.spellCheckingType = UITextSpellCheckingTypeNo;
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        for (NSUInteger index = 0; index < 42; index++) {
            [lines addObject:[NSString stringWithFormat:
                @"Selection line %02lu carries several words across the viewport.",
                (unsigned long)index]];
        }
        self.editor.text = [lines componentsJoinedByString:@"\n"];
        [self id_installStatusViewWithIdentifier:@"selection-status"];
    } else if ([self.uiScenario isEqualToString:@"spelling"]) {
        self.editor.spellCheckingType = UITextSpellCheckingTypeYes;
        self.editor.text = @"";
        [self.editor setContinuousSpellCheckingEnabled:YES];
        [self id_installStatusViewWithIdentifier:@"spelling-status"];
    } else if ([self.uiScenario isEqualToString:@"attachment"]) {
        self.editor.spellCheckingType = UITextSpellCheckingTypeNo;
        [self id_installStatusViewWithIdentifier:@"selection-status"];
        [self id_installAttachmentScenario];
    }

    UITextPosition *start = self.editor.beginningOfDocument;
    self.editor.selectedTextRange = [self.editor textRangeFromPosition:start toPosition:start];
    [self.editor setNeedsLayout];
    [self.editor layoutIfNeeded];
    [self id_scheduleUIStatusUpdate];
}

- (void)id_configureBlockUIScenario {
    self.blockEditor.backgroundColor = UIColor.whiteColor;
    self.blockEditor.textColor = UIColor.blackColor;
    self.blockEditor.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.blockEditor.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    BOOL isFloatingScenario = [self.blockUIScenario hasPrefix:@"floating-"];
    BOOL isAutocorrectionScenario =
        [self.blockUIScenario hasPrefix:@"autocorrection-"];
    BOOL isInlinePredictionScenario =
        [self.blockUIScenario hasPrefix:@"inline-prediction-"];
    BOOL isFormattingKeyboardScenario =
        [self.blockUIScenario isEqualToString:
            @"inline-formatting-keyboard"];
    BOOL isIMEScenario = [self.blockUIScenario hasPrefix:@"ime-"];
    BOOL isGeometryScenario = [self.blockUIScenario hasPrefix:@"geometry-"];
    if (isIMEScenario) {
        self.blockEditor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.blockEditor.autocorrectionType = UITextAutocorrectionTypeYes;
        self.blockEditor.smartQuotesType = UITextSmartQuotesTypeNo;
        self.blockEditor.smartDashesType = UITextSmartDashesTypeNo;
        self.blockEditor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        self.blockEditor.inlinePredictionType = UITextInlinePredictionTypeNo;
        self.blockEditor.spellCheckingType = UITextSpellCheckingTypeYes;
    } else if (isInlinePredictionScenario ||
               isFormattingKeyboardScenario) {
        CFNotificationCenterRef center =
            CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(
            center, NULL, IDDemoInlinePredictionActionNotification,
            CFSTR("com.inputdec.inline-prediction.dismiss"), NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        self.blockEditor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.blockEditor.autocorrectionType = UITextAutocorrectionTypeYes;
        self.blockEditor.smartQuotesType = UITextSmartQuotesTypeNo;
        self.blockEditor.smartDashesType = UITextSmartDashesTypeNo;
        self.blockEditor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        self.blockEditor.inlinePredictionType = UITextInlinePredictionTypeYes;
        self.blockEditor.spellCheckingType = UITextSpellCheckingTypeYes;
        if (isFormattingKeyboardScenario) {
            NSString *original = NSProcessInfo.processInfo.environment[
                @"IDInlineFormattingOriginal"];
            if (original.length > 0) {
                [UITextChecker unlearnWord:original];
            }
        }
    } else if (isAutocorrectionScenario) {
        NSString *original = NSProcessInfo.processInfo.environment[
            @"IDAutocorrectionOriginal"];
        NSAssert(original.length > 0,
                 @"Autocorrection scenarios require a test-supplied original token");
        [UITextChecker unlearnWord:original];
        self.blockEditor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.blockEditor.autocorrectionType = UITextAutocorrectionTypeYes;
        self.blockEditor.smartQuotesType = UITextSmartQuotesTypeNo;
        self.blockEditor.smartDashesType = UITextSmartDashesTypeNo;
        self.blockEditor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        self.blockEditor.inlinePredictionType = UITextInlinePredictionTypeNo;
        self.blockEditor.spellCheckingType = UITextSpellCheckingTypeYes;
    } else if (!isFloatingScenario) {
        self.blockEditor.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.blockEditor.autocorrectionType = UITextAutocorrectionTypeNo;
        self.blockEditor.smartQuotesType = UITextSmartQuotesTypeNo;
        self.blockEditor.smartDashesType = UITextSmartDashesTypeNo;
        self.blockEditor.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        self.blockEditor.inlinePredictionType = UITextInlinePredictionTypeNo;
        self.blockEditor.spellCheckingType = [self.blockUIScenario isEqualToString:@"spelling"]
            ? UITextSpellCheckingTypeYes
            : UITextSpellCheckingTypeNo;
    }
    [self.editorModeButton setTitle:@"Flat Oracle" forState:UIControlStateNormal];
    self.editorModeButton.accessibilityLabel = @"Flat Oracle";

    UITextPosition *selectionStart = self.blockEditor.beginningOfDocument;
    if (isIMEScenario) {
        NSString *location =
            NSProcessInfo.processInfo.environment[@"IDIMELocation"] ?: @"";
        NSUInteger offset = 6;
        if ([location isEqualToString:@"before-boundary"]) {
            offset = [self.blockEditor.text rangeOfString:@"\n"].location;
        } else if ([location isEqualToString:@"after-boundary"]) {
            offset = NSMaxRange([self.blockEditor.text rangeOfString:@"\n"]);
        }
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument
                           offset:(NSInteger)offset];
    } else if (isInlinePredictionScenario) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument
                           offset:18];
    } else if (isAutocorrectionScenario) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument
                           offset:[self.blockUIScenario
                                isEqualToString:@"autocorrection-after-boundary"]
                                ? 15 : 8];
    } else if ([self.blockUIScenario isEqualToString:@"boundary"]) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument offset:6];
    } else if ([self.blockUIScenario isEqualToString:@"selection"]) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument offset:3];
    } else if ([self.blockUIScenario isEqualToString:@"navigation-horizontal"] ||
               [self.blockUIScenario isEqualToString:@"navigation-selection"]) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument offset:3];
    } else if ([self.blockUIScenario isEqualToString:@"navigation-vertical"]) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument offset:12];
    } else if ([self.blockUIScenario isEqualToString:@"geometry-authority"]) {
        NSString *requestedLocation = NSProcessInfo.processInfo.environment[
            @"IDGeometrySelectionLocation"];
        NSUInteger location = requestedLocation == nil
            ? 3 : requestedLocation.integerValue;
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument
                           offset:(NSInteger)location];
    } else if ([self.blockUIScenario isEqualToString:@"floating-ltr"] ||
               [self.blockUIScenario isEqualToString:@"floating-scroll"]) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument
                           offset:[self.blockUIScenario isEqualToString:@"floating-scroll"]
                                ? ([NSProcessInfo.processInfo.environment[@"IDFloatingScrollSelection"]
                                    isEqualToString:@"1"] ? 900 :
                                   ([NSProcessInfo.processInfo.environment[@"IDFloatingScrollEdge"]
                                    isEqualToString:@"lower"] ? 1600 : 891))
                                : 46];
    } else if ([self.blockUIScenario isEqualToString:@"floating-boundary"]) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument offset:50];
    } else if ([self.blockUIScenario isEqualToString:@"floating-bidi"]) {
        selectionStart = [self.blockEditor
            positionFromPosition:self.blockEditor.beginningOfDocument offset:16];
    }
    UITextPosition *selectionEnd = selectionStart;
    if ([self.blockUIScenario isEqualToString:@"geometry-authority"]) {
        NSUInteger length = [NSProcessInfo.processInfo.environment[
            @"IDGeometrySelectionLength"] integerValue];
        selectionEnd = [self.blockEditor
            positionFromPosition:selectionStart offset:(NSInteger)length];
    }
    if ([self.blockUIScenario isEqualToString:@"inline-formatting"]) {
        selectionEnd = self.blockEditor.endOfDocument;
    }
    self.blockEditor.selectedTextRange =
        [self.blockEditor textRangeFromPosition:selectionStart
                                    toPosition:selectionEnd];
    if (isFormattingKeyboardScenario) {
        [self.blockEditor toggleInlineTextTrait:IDInlineTextTraitBold];
    }
    [self updateInlineFormattingFeedback];
    if (isIMEScenario) {
        IDInstallAutocorrectionTraceForUITesting();
        self.imeBaselineDocumentRevision =
            self.blockEditor.id_document.documentRevision;
    } else if (isAutocorrectionScenario) {
        IDInstallAutocorrectionTraceForUITesting();
        self.autocorrectionBaselineDocumentRevision =
            self.blockEditor.id_document.documentRevision;
    } else if (isInlinePredictionScenario) {
        IDInstallAutocorrectionTraceForUITesting();
        self.inlinePredictionBaselineDocumentRevision =
            self.blockEditor.id_document.documentRevision;
    }
    if ([self.blockUIScenario isEqualToString:@"spelling"]) {
        IDPrivateSetContinuousSpellCheckingEnabled(self.blockEditor.id_inputController, YES);
    }

    IDDemoStatusView *status = [[IDDemoStatusView alloc]
        initWithFrame:CGRectMake(0, 0, 2, 2)];
    NSString *statusIdentifier = isInlinePredictionScenario
        ? @"inline-prediction-status"
        : isAutocorrectionScenario ? @"autocorrection-status"
        : isIMEScenario ? @"ime-composition-status"
        : isGeometryScenario ? @"geometry-status" : @"block-status";
    if (isFormattingKeyboardScenario) {
        statusIdentifier = @"inline-formatting-keyboard-status";
    }
    status.accessibilityIdentifier = statusIdentifier;
    status.accessibilityLabel = statusIdentifier;
    status.backgroundColor = UIColor.clearColor;
    __weak IDDemoViewController *weakSelf = self;
    status.statusValueProvider = ^NSString *{
        return isInlinePredictionScenario
            ? [weakSelf id_inlinePredictionStatusValue]
            : isAutocorrectionScenario
                ? [weakSelf id_autocorrectionStatusValue]
                : isIMEScenario
                    ? [weakSelf id_imeCompositionStatusValue]
                : isFormattingKeyboardScenario
                    ? [weakSelf id_inlineFormattingKeyboardStatusValue]
                : isGeometryScenario
                    ? [weakSelf id_geometryStatusValue]
                : [weakSelf id_blockStatusValue];
    };
    self.blockStatusView = status;
    [self.view insertSubview:status atIndex:0];
    IDDemoStatusView *behaviorStatus = [[IDDemoStatusView alloc]
        initWithFrame:CGRectMake(0, 0, 2, 2)];
    behaviorStatus.accessibilityIdentifier =
        @"behavior-capability-status";
    behaviorStatus.accessibilityLabel =
        @"behavior-capability-status";
    behaviorStatus.statusValueProvider = ^NSString *{
        IDDemoViewController *self = weakSelf;
        NSString *backend =
            self.behaviorBackend ==
                IDUIKitBehaviorBackendMinimalKernel
                ? @"minimal" : @"reference";
        NSDictionary *payload = @{
            @"backend": backend,
            @"report": self.blockEditor.id_behaviorReport == nil
                ? NSNull.null
                : [self.blockEditor.id_behaviorReport
                    normalizedDictionary],
        };
        NSData *data = [NSJSONSerialization
            dataWithJSONObject:payload
                       options:NSJSONWritingSortedKeys
                         error:nil];
        return data == nil
            ? @"{}"
            : [[NSString alloc] initWithData:data
                                    encoding:NSUTF8StringEncoding];
    };
    self.behaviorStatusView = behaviorStatus;
    [self.view insertSubview:behaviorStatus atIndex:0];
    UIButton *geometrySelectAllButton = nil;
    if ([self.blockUIScenario isEqualToString:@"geometry-large-selection"]) {
        geometrySelectAllButton = [self buttonWithTitle:@"Select All Document"
                                             identifier:@"geometry-select-all"
                                                 action:@selector(id_selectAllGeometryDocument:)];
        geometrySelectAllButton.frame = CGRectMake(16, 150, 160, 36);
        [self.view addSubview:geometrySelectAllButton];
    }
    BOOL isTouchScenario = [self.blockUIScenario hasPrefix:@"touch-"];
    if (isFloatingScenario) {
        IDPrivateInstallRichCursorTraceForUITesting(
            self.blockEditor.id_richLayoutController);
        IDDemoStatusView *floatingStatus = [[IDDemoStatusView alloc]
            initWithFrame:CGRectMake(0, 0, 2, 2)];
        floatingStatus.accessibilityIdentifier = @"floating-status";
        floatingStatus.accessibilityLabel = @"floating-status";
        floatingStatus.backgroundColor = UIColor.clearColor;
        floatingStatus.statusValueProvider = ^NSString *{
            return [weakSelf id_floatingCursorStatusValue];
        };
        self.floatingCursorStatusView = floatingStatus;
        [self.view insertSubview:floatingStatus atIndex:0];
        NSString *truthTerminalEvent =
            NSProcessInfo.processInfo.environment[@"IDFloatingTruthTerminalEvent"];
        NSString *truthActionEvent =
            NSProcessInfo.processInfo.environment[@"IDFloatingTruthActionEvent"];
        self.floatingTruthTerminalEvent = truthTerminalEvent;
        self.floatingTruthActionEvent = truthActionEvent;
        NSMutableArray<IDDemoStatusView *> *truthStatusViews = [NSMutableArray array];
        if (truthTerminalEvent.length > 0) {
            NSDictionary<NSString *, NSString *> *phaseIdentifiers = @{
                @"held": @"floating-release-held-status",
                @"terminal": @"floating-terminal-status",
                @"immediate": @"floating-release-immediate-status",
                @"exact-release-500ms": @"floating-release-exact-status",
                @"post-keyboard-lift-500ms": @"floating-release-post-lift-status",
            };
            [phaseIdentifiers enumerateKeysAndObjectsUsingBlock:
                ^(NSString *phase, NSString *identifier, BOOL *stop) {
                (void)stop;
                IDDemoStatusView *phaseStatus = [[IDDemoStatusView alloc]
                    initWithFrame:CGRectMake(0, 0, 2, 2)];
                phaseStatus.accessibilityIdentifier = identifier;
                phaseStatus.accessibilityLabel = identifier;
                phaseStatus.statusValueProvider = ^NSString *{
                    IDPrivateFloatingLifecycleWeakReferences *references =
                        weakSelf.floatingTruthReferences;
                    NSDictionary *snapshot = [phase isEqualToString:@"terminal"]
                        ? [references copyTerminalSnapshot]
                        : [references copyReleaseSnapshotForPhase:phase];
                    if (snapshot == nil) return @"{}";
                    NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot
                        options:NSJSONWritingSortedKeys error:nil];
                    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
                        encoding:NSUTF8StringEncoding];
                };
                [self.view insertSubview:phaseStatus atIndex:0];
                [truthStatusViews addObject:phaseStatus];
            }];
            self.floatingTruthStatusViews = truthStatusViews.copy;
            [self id_armFloatingTruthObservers];
        }
        UIButton *editableOff = [self buttonWithTitle:@"Editable: On"
                                           identifier:@"floating-editable-off"
                                               action:@selector(id_disableFloatingEditable:)];
        editableOff.frame = CGRectMake(130, 120, 134, 32);
        [self.view addSubview:editableOff];
        UIButton *selectableOff = [self buttonWithTitle:@"Selectable: On"
                                             identifier:@"floating-selectable-off"
                                                 action:@selector(id_disableFloatingSelectable:)];
        selectableOff.frame = CGRectMake(250, 120, 134, 32);
        [self.view addSubview:selectableOff];
        UIButton *resign = [self buttonWithTitle:@"Resign"
                                      identifier:@"floating-resign"
                                          action:@selector(id_resignFloatingEditor:)];
        resign.frame = CGRectMake(20, 153, 120, 36);
        [self.view addSubview:resign];
        UIButton *keyboardDismiss = [self buttonWithTitle:@"Keyboard Dismiss"
                                                identifier:@"floating-keyboard-dismiss"
                                                    action:@selector(id_dismissFloatingKeyboard:)];
        keyboardDismiss.frame = CGRectMake(145, 153, 150, 36);
        [self.view addSubview:keyboardDismiss];
        UIButton *selectableOn = [self buttonWithTitle:@"Selectable: Rebuild"
                                            identifier:@"floating-selectable-on"
                                                action:@selector(id_enableFloatingSelectable:)];
        selectableOn.frame = CGRectMake(300, 153, 84, 36);
        [self.view addSubview:selectableOn];
        NSMutableArray *floatingElements = [@[
            behaviorStatus, status, floatingStatus, editableOff, selectableOff, resign,
            keyboardDismiss, selectableOn, self.blockEditor,
        ] mutableCopy];
        [floatingElements addObjectsFromArray:truthStatusViews];
        self.view.accessibilityElements = floatingElements;
    } else if (isIMEScenario) {
        UIButton *resign = [self buttonWithTitle:@"Resign IME Editor"
                                      identifier:@"ime-resign"
                                          action:@selector(id_resignIMEEditor:)];
        resign.frame = CGRectMake(16, 150, 150, 36);
        [self.view addSubview:resign];
        UIButton *undo = [self buttonWithTitle:@"Undo IME Edit"
                                    identifier:@"ime-undo"
                                        action:@selector(id_undoIMEEdit:)];
        undo.frame = CGRectMake(180, 150, 120, 36);
        [self.view addSubview:undo];
        self.view.accessibilityElements =
            @[behaviorStatus, status, resign, undo, self.blockEditor];
    } else if (isTouchScenario) {
        IDDemoStatusView *touchStatus = [[IDDemoStatusView alloc]
            initWithFrame:CGRectMake(0, 0, 2, 2)];
        touchStatus.accessibilityIdentifier = @"touch-status";
        touchStatus.accessibilityLabel = @"touch-status";
        touchStatus.backgroundColor = UIColor.clearColor;
        touchStatus.statusValueProvider = ^NSString *{
            return [weakSelf id_touchSelectionStatusValue];
        };
        self.touchSelectionStatusView = touchStatus;
        [self.view insertSubview:touchStatus atIndex:0];
        self.view.accessibilityElements =
            @[behaviorStatus, status, touchStatus, self.editableButton,
              self.selectableButton, self.blockEditor];
    } else if ([self.blockUIScenario isEqualToString:@"inline-formatting"] ||
               isFormattingKeyboardScenario) {
        NSMutableArray *elements =
            [NSMutableArray arrayWithObjects:
                behaviorStatus,
                isFormattingKeyboardScenario
                    ? status : self.inlineFormattingStatusView,
                nil];
        if (!isFormattingKeyboardScenario) {
            [elements addObjectsFromArray:self.inlineFormattingButtons];
        }
        [elements addObject:self.blockEditor];
        self.view.accessibilityElements = elements;
    } else if (geometrySelectAllButton != nil) {
        self.view.accessibilityElements =
            @[behaviorStatus, status, geometrySelectAllButton, self.blockEditor];
    } else {
        self.view.accessibilityElements =
            @[behaviorStatus, status, self.blockEditor];
    }
    [self id_installSelectionCallbackReductionProbeIfNeeded];
    [self.blockEditor setNeedsLayout];
    [self.view layoutIfNeeded];
    [self.blockEditor layoutIfNeeded];
    if ([NSProcessInfo.processInfo.environment[
            @"IDForceEnglishUSInputMode"] isEqualToString:@"1"]) {
        IDDemoForceEnglishUSInputMode();
    }
    [self.blockEditor becomeFirstResponder];
    if ([NSProcessInfo.processInfo.environment[
            @"IDForceEnglishUSInputMode"] isEqualToString:@"1"]) {
        IDDemoForceEnglishUSInputMode();
        [self.blockEditor reloadInputViews];
        dispatch_async(dispatch_get_main_queue(), ^{
            IDDemoForceEnglishUSInputMode();
            [self.blockEditor reloadInputViews];
        });
    }
    if ([self.blockUIScenario isEqualToString:@"floating-scroll"]) {
        __weak IDDemoViewController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            IDDemoViewController *self = weakSelf;
            IDBlockTextView *editor = self.blockEditor;
            if (editor == nil) return;
            [self.view layoutIfNeeded];
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
}

- (void)id_resignIMEEditor:(id)sender {
    (void)sender;
    [self.blockEditor resignFirstResponder];
}

- (void)id_selectAllGeometryDocument:(id)sender {
    [self.blockEditor selectAll:sender];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification,
                                    self.blockStatusView);
}

- (void)id_undoIMEEdit:(id)sender {
    (void)sender;
    [self.blockEditor.undoManager undo];
}

- (void)id_resignFloatingEditor:(id)sender {
    (void)sender;
    IDPrivateTestingRequestResponderLoss(self.blockEditor);
}

- (void)id_dismissFloatingKeyboard:(id)sender {
    (void)sender;
    IDPrivateTestingRequestKeyboardDismissal(self.blockEditor);
}

- (void)id_disableFloatingEditable:(id)sender {
    (void)sender;
    IDPrivateTestingRequestEditableOff(self.blockEditor);
}

- (void)id_armFloatingTruthObservers {
    NSString *terminalEvent = self.floatingTruthTerminalEvent;
    if (terminalEvent.length == 0) return;
    NSString *actionEvent = self.floatingTruthActionEvent;
    IDPrivateFloatingLifecycleWeakReferences *references =
        [[IDPrivateFloatingLifecycleWeakReferences alloc]
            initWithEditor:self.blockEditor
            layoutController:self.blockEditor.id_richLayoutController];
    self.floatingTruthReferences = references;
    [references beginHeldSnapshotPollingForTerminalEvent:terminalEvent];
    if (actionEvent.length > 0) {
        IDPrivateSetFloatingLifecycleActionObserverForUITesting(
            self.blockEditor, actionEvent,
            ^(NSString *observedEvent, NSUInteger count, CFTimeInterval actionEpoch) {
                (void)observedEvent;
                (void)count;
                [references markActionObservationAtEpoch:actionEpoch liftDelay:1.55];
            });
    }
    IDPrivateSetFloatingLifecycleTerminalObserverForUITesting(
        self.blockEditor, terminalEvent,
        ^(NSString *observedEvent, NSUInteger count, CFTimeInterval terminalEpoch) {
            CFTimeInterval liftTarget = terminalEpoch +
                ([observedEvent isEqualToString:@"normalEnd"] ? 0.0 : 1.55);
            [references markTerminalObservationForEvent:observedEvent count:count
                terminalEpoch:terminalEpoch liftTargetEpoch:liftTarget];
            [references scheduleReleaseSnapshots];
            dispatch_async(dispatch_get_main_queue(), ^{
                [references recordImmediateReleaseSnapshot];
            });
        });
}

- (void)id_disableFloatingSelectable:(id)sender {
    (void)sender;
    IDPrivateTestingRequestSelectableOff(self.blockEditor);
}

- (void)id_enableFloatingSelectable:(id)sender {
    (void)sender;
    self.blockEditor.selectable = YES;
    self.blockEditor.editable = YES;
    [self id_armFloatingTruthObservers];
    [self.blockEditor becomeFirstResponder];
}

- (NSString *)id_floatingCursorStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) return @"{}";
    [editor layoutIfNeeded];
    UITextRange *selectedRange = editor.selectedTextRange;
    NSRange selection = [editor id_NSRangeForTextRange:selectedRange];
    if (selection.location == NSNotFound) selection = NSMakeRange(0, 0);
    NSInteger startAffinity = selectedRange == nil ? UITextStorageDirectionForward :
        [editor.id_richLayoutController id_affinityForPosition:selectedRange.start];
    NSInteger endAffinity = selectedRange == nil ? UITextStorageDirectionForward :
        [editor.id_richLayoutController id_affinityForPosition:selectedRange.end];
    CGRect caret = selection.length == 0 && selectedRange != nil
        ? [editor caretRectForPosition:selectedRange.end] : CGRectZero;
    if (CGRectIsNull(caret) || CGRectIsInfinite(caret) ||
        !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
        !isfinite(caret.size.width) || !isfinite(caret.size.height)) caret = CGRectZero;
    UIEdgeInsets insets = editor.adjustedContentInset;
    CGRect visible = CGRectMake(editor.contentOffset.x + insets.left,
                                editor.contentOffset.y + insets.top,
                                MAX(CGRectGetWidth(editor.bounds) - insets.left - insets.right, 0),
                                MAX(CGRectGetHeight(editor.bounds) - insets.top - insets.bottom, 0));
    NSDictionary<NSString *, id> *lifecycle =
        IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting(
            editor, editor.id_richLayoutController);
    NSDictionary *status = @{
        @"blockCount": @(editor.attributedBlocks.count),
        @"canonical": editor.text ?: @"",
        @"caret": @{@"height": @(caret.size.height), @"width": @(caret.size.width),
                     @"x": @(caret.origin.x), @"y": @(caret.origin.y)},
        @"containerCreations":
            @(IDPrivateFloatingContainerCreationCountForUITesting(editor)),
        @"containerStable": lifecycle[@"containerStable"],
        @"contentOffset": @{@"x": @(editor.contentOffset.x), @"y": @(editor.contentOffset.y)},
        @"firstResponder": @(editor.isFirstResponder),
        @"presentationUpdates": lifecycle[@"presentationUpdates"],
        @"scenario": self.blockUIScenario ?: @"none",
        @"selection": @{@"length": @(selection.length), @"location": @(selection.location)},
        @"startAffinity": @(startAffinity),
        @"endAffinity": @(endAffinity),
        @"visible": @{@"height": @(visible.size.height), @"width": @(visible.size.width),
                      @"x": @(visible.origin.x), @"y": @(visible.origin.y)},
        @"cursorCallback": IDPrivateCopyRichCursorTraceForUITesting(
            editor.id_richLayoutController)
            ?: NSNull.null,
        @"autoscrollTrace": IDPrivateCopyTextAutoscrollTraceForUITesting(editor),
        @"interactionHostTopology":
            IDPrivateCopyInteractionHostTopologyForUITesting(
                editor, editor.id_blockStack, nil),
        @"lifecycle": lifecycle,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:status
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
}

- (NSString *)id_touchSelectionStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) return @"{}";
    [editor layoutIfNeeded];
    UITextRange *selectedRange = editor.selectedTextRange;
    NSRange selection = [editor id_NSRangeForTextRange:selectedRange];
    if (selection.location == NSNotFound) selection = NSMakeRange(0, 0);

    CGRect caret = CGRectZero;
    NSMutableArray<NSDictionary<NSString *, id> *> *selectionRects =
        [NSMutableArray array];
    if (selection.length == 0 && selectedRange != nil) {
        caret = [editor caretRectForPosition:selectedRange.end];
        if (CGRectIsNull(caret) || CGRectIsInfinite(caret) ||
            !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
            !isfinite(caret.size.width) || !isfinite(caret.size.height)) {
            caret = CGRectZero;
        }
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
                @"height": @(frame.size.height),
                @"width": @(frame.size.width),
                @"x": @(frame.origin.x),
                @"y": @(frame.origin.y),
            }];
        }
        if ([self.blockUIScenario isEqualToString:@"touch-autoscroll"] &&
            selectionRects.count > 2) {
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

    UIEdgeInsets insets = editor.adjustedContentInset;
    CGRect visible = CGRectMake(editor.contentOffset.x + insets.left,
                                editor.contentOffset.y + insets.top,
                                MAX(CGRectGetWidth(editor.bounds) - insets.left - insets.right, 0),
                                MAX(CGRectGetHeight(editor.bounds) - insets.top - insets.bottom, 0));
    id<IDSelectionPresentationBackend> presentationBackend =
        editor.id_selectionPresentationBackend;
    UIView *firstContainer = [presentationBackend id_selectionContainerView];
    UIView *secondContainer = [presentationBackend id_selectionContainerView];
    BOOL containerStable = firstContainer != nil && firstContainer == secondContainer &&
        firstContainer.superview == editor;
    NSString *backend =
        editor.id_behaviorBackend ==
            IDUIKitBehaviorBackendMinimalKernel
            ? @"minimal"
            : @"reference";
    NSMutableDictionary<NSString *, id> *autoscroll =
        [IDPrivateCopyTextAutoscrollTraceForUITesting(editor)
            mutableCopy];
    if (editor.id_behaviorBackend ==
        IDUIKitBehaviorBackendMinimalKernel) {
        IDVerticalAutoscroll *session =
            editor.id_verticalAutoscroll;
        autoscroll[@"tickCount"] = @(session.count);
        autoscroll[@"direction"] = @(session.directions);
        autoscroll[@"active"] = @(session.isActive);
    } else if (editor.id_textAutoscroll != nil) {
        NSDictionary *snapshot =
            IDPrivateTestingCopyUIKitAutoscrollSnapshot(
                editor.id_textAutoscroll);
        autoscroll[@"tickCount"] = snapshot[@"count"];
        autoscroll[@"direction"] = snapshot[@"directions"];
        autoscroll[@"active"] = snapshot[@"active"];
    } else {
        autoscroll[@"tickCount"] = @0;
        autoscroll[@"direction"] = @0;
        autoscroll[@"active"] = @NO;
    }
    autoscroll[@"backend"] = backend;
    NSMutableDictionary *status = [@{
        @"autoscroll": autoscroll.copy,
        @"backend": backend,
        @"blockCount": @(editor.attributedBlocks.count),
        @"canonical": editor.text ?: @"",
        @"caret": @{
            @"height": @(caret.size.height),
            @"width": @(caret.size.width),
            @"x": @(caret.origin.x),
            @"y": @(caret.origin.y),
        },
        @"containerCreations": @(presentationBackend.selectionContainerCreationCount),
        @"selectionContainerIdentity": firstContainer == nil
            ? @"nil"
            : [NSString stringWithFormat:@"%p", firstContainer],
        @"containerStable": @(containerStable),
        @"interactionHostTopology":
            IDPrivateCopyInteractionHostTopologyForUITesting(
                editor, editor.id_blockStack, nil),
        @"contentOffset": @{
            @"x": @(editor.contentOffset.x),
            @"y": @(editor.contentOffset.y),
        },
        @"presentationUpdates": @(presentationBackend.presentationUpdateCount),
        @"scenario": self.blockUIScenario ?: @"none",
        @"selection": @{
            @"length": @(selection.length),
            @"location": @(selection.location),
        },
        @"selectionRects": selectionRects.copy,
        @"state": selection.length == 0 ? @"caret" : @"selection",
        @"visible": @{
            @"height": @(visible.size.height),
            @"width": @(visible.size.width),
            @"x": @(visible.origin.x),
            @"y": @(visible.origin.y),
        },
    } mutableCopy];
    if ([self.blockUIScenario isEqualToString:@"touch-autoscroll"]) {
        status[@"visibleHandles"] = IDDemoVisibleSelectionHandles(editor);
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:status
                                                   options:NSJSONWritingSortedKeys
                                                     error:&error];
    NSAssert(data != nil, @"Touch selection status JSON serialization failed: %@", error);
    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding];
}

- (NSString *)id_imeCompositionStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) return @"{}";
    [editor layoutIfNeeded];

    NSRange selection = [editor id_NSRangeForTextRange:editor.selectedTextRange];
    if (selection.location == NSNotFound) selection = NSMakeRange(0, 0);
    UITextRange *markedTextRange = editor.markedTextRange;
    NSRange markedRange = markedTextRange == nil
        ? NSMakeRange(NSNotFound, 0)
        : [editor id_NSRangeForTextRange:markedTextRange];
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

    NSMutableArray<NSString *> *blocks = [NSMutableArray array];
    NSMutableArray<NSString *> *blockIdentifiers = [NSMutableArray array];
    NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
    NSUInteger cursor = 0;
    for (IDBlock *block in editor.id_document.blocks) {
        [blocks addObject:block.attributedText.string ?: @""];
        [blockIdentifiers addObject:block.identifier.UUIDString ?: @""];
        cursor += block.attributedText.length;
        if (block != editor.id_document.blocks.lastObject) {
            [newlines addObject:@(cursor)];
            cursor += 1;
        }
    }

    NSMutableArray<NSString *> *anchorIdentities = [NSMutableArray array];
    IDRichTextRange *richSelection =
        [editor.selectedTextRange isKindOfClass:IDRichTextRange.class]
            ? (IDRichTextRange *)editor.selectedTextRange : nil;
    if (richSelection != nil) {
        IDRichTextAnchor *start = richSelection.start.anchor;
        [anchorIdentities addObject:start.blockIdentifier.UUIDString ?: @""];
        if (![richSelection.start isEqual:richSelection.end]) {
            IDRichTextAnchor *end = richSelection.end.anchor;
            if (![end.blockIdentifier isEqual:start.blockIdentifier]) {
                [anchorIdentities addObject:
                    end.blockIdentifier.UUIDString ?: @""];
            }
        }
    }

    NSMutableOrderedSet<NSString *> *markedAttributeKeys =
        [NSMutableOrderedSet orderedSet];
    NSMutableArray<NSDictionary<NSString *, id> *> *temporaryDescriptors =
        [NSMutableArray array];
    if (markedTextRange != nil && markedRange.length > 0) {
        NSAttributedString *persistent =
            [editor.id_richLayoutController
                id_attributedTextInRange:markedTextRange];
        NSAttributedString *temporary =
            [editor.id_richLayoutController
                id_annotatedSubstringForRange:markedTextRange];
        NSMutableDictionary<NSAttributedStringKey, id> *attributes =
            [NSMutableDictionary dictionary];
        if (persistent.length > 0) {
            [attributes addEntriesFromDictionary:
                [persistent attributesAtIndex:0 effectiveRange:NULL]];
        }
        if (temporary.length > 0) {
            [attributes addEntriesFromDictionary:
                [temporary attributesAtIndex:0 effectiveRange:NULL]];
        }
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
                @"range": @{
                    @"location": @(markedRange.location),
                    @"length": @(markedRange.length),
                },
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
    if (CGRectIsNull(compositionFrame) ||
        CGRectIsInfinite(compositionFrame) ||
        !isfinite(compositionFrame.origin.x) ||
        !isfinite(compositionFrame.origin.y) ||
        !isfinite(compositionFrame.size.width) ||
        !isfinite(compositionFrame.size.height)) {
        compositionFrame = CGRectZero;
    }

    NSArray<NSString *> *trace = IDCopyAutocorrectionTraceForUITesting();
    NSUInteger textEpoch = 0;
    NSUInteger selectionEpoch = 0;
    for (NSString *event in trace) {
        textEpoch += [event isEqualToString:@"textDidChange"];
        selectionEpoch += [event isEqualToString:@"selectionDidChange"];
    }
    NSUInteger revision = editor.id_document.documentRevision;
    NSUInteger baseline = self.imeBaselineDocumentRevision;
    NSArray *enabledIdentifiers =
        [NSUserDefaults.standardUserDefaults arrayForKey:@"AppleKeyboards"];
    if (![enabledIdentifiers isKindOfClass:NSArray.class] ||
        enabledIdentifiers.count == 0) {
        enabledIdentifiers = @[@"unavailable"];
    }
    NSString *affinity = editor.selectionAffinity ==
        UITextStorageDirectionBackward ? @"backward" : @"forward";
    NSDictionary<NSString *, NSString *> *environment =
        NSProcessInfo.processInfo.environment;
    NSDictionary *status = @{
        @"schema": @1,
        @"scenario": self.blockUIScenario ?: @"ime-unknown",
        @"language": environment[@"IDIMELanguage"] ?: @"",
        @"location": environment[@"IDIMELocation"] ?: @"",
        @"decision": environment[@"IDIMEDecision"] ?: @"",
        @"canonical": editor.text ?: @"",
        @"blocks": blocks.copy,
        @"blockIdentifiers": blockIdentifiers.copy,
        @"anchorIdentities": anchorIdentities.copy,
        @"selection": @{
            @"location": @(selection.location), @"length": @(selection.length),
        },
        @"affinity": affinity,
        @"markedRange": @{
            @"location": @(markedRange.location),
            @"length": @(markedRange.length),
        },
        @"markedText": markedText,
        @"markedSelection": @{
            @"location": @(markedSelection.location),
            @"length": @(markedSelection.length),
        },
        @"markedAttributeKeys": markedAttributeKeys.array,
        @"structuralNewlineLocations": newlines.copy,
        @"checkingRanges": @[],
        @"temporaryRenderingDescriptors": temporaryDescriptors.copy,
        @"candidateDescriptor": @{
            @"visible": @NO, @"actionable": @NO, @"labels": @[],
            @"selectedLabel": @"",
            @"geometry": @{
                @"x": @0, @"y": @0, @"width": @0, @"height": @0,
            },
        },
        @"keyboardState": @{
            @"visible": @(editor.isFirstResponder),
            @"primaryLanguage": editor.textInputMode.primaryLanguage ?: @"",
            @"enabledInputModeIdentifiers": enabledIdentifiers,
        },
        @"compositionGeometry": @{
            @"x": @(compositionFrame.origin.x),
            @"y": @(compositionFrame.origin.y),
            @"width": @(MAX(compositionFrame.size.width, 0.0)),
            @"height": @(MAX(compositionFrame.size.height, 0.0)),
        },
        @"mutationTrace": trace,
        @"eventTrace": trace,
        @"coordinateSpaceIdentity": @"screen",
        @"documentRevision": @(revision >= baseline ? revision - baseline : 0),
        @"textEpoch": @(textEpoch),
        @"selectionEpoch": @(selectionEpoch),
        @"checkingEpoch": @(textEpoch),
        @"layoutEpoch": @(textEpoch + selectionEpoch),
        @"firstResponder": @(editor.isFirstResponder),
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:status
        options:NSJSONWritingSortedKeys error:nil];
    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
        encoding:NSUTF8StringEncoding];
}

- (NSString *)id_autocorrectionStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) return @"{}";
    NSRange selection = [editor id_NSRangeForTextRange:editor.selectedTextRange];
    UITextRange *markedTextRange = editor.markedTextRange;
    NSRange marked = markedTextRange == nil
        ? NSMakeRange(NSNotFound, 0)
        : [editor id_NSRangeForTextRange:markedTextRange];
    NSMutableArray<NSString *> *blocks = [NSMutableArray array];
    NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
    __block NSUInteger cursor = 0;
    [editor.attributedBlocks enumerateObjectsUsingBlock:
        ^(NSAttributedString *block, NSUInteger index, BOOL *stop) {
            (void)stop;
            [blocks addObject:block.string ?: @""];
            cursor += block.length;
            if (index + 1 < editor.attributedBlocks.count) {
                [newlines addObject:@(cursor)];
                cursor += 1;
            }
        }];
    NSArray<NSString *> *trace = IDCopyAutocorrectionTraceForUITesting();
    NSUInteger textEpoch = 0;
    NSUInteger selectionEpoch = 0;
    for (NSString *event in trace) {
        textEpoch += [event isEqualToString:@"textDidChange"];
        selectionEpoch += [event isEqualToString:@"selectionDidChange"];
    }
    CGRect correctionRect = editor.selectedTextRange == nil ? CGRectZero
        : [editor caretRectForPosition:editor.selectedTextRange.end];
    NSUInteger revision = editor.id_document.documentRevision;
    NSUInteger baseline = self.autocorrectionBaselineDocumentRevision;
    NSDictionary *status = @{
        @"schema": @1,
        @"scenario": self.blockUIScenario ?: @"autocorrection-interior",
        @"canonical": editor.text ?: @"",
        @"blocks": blocks.copy,
        @"selection": @{@"location": @(selection.location),
                           @"length": @(selection.length)},
        @"affinity": @"forward",
        @"markedRange": @{@"location": @(marked.location),
                             @"length": @(marked.length)},
        @"structuralNewlineLocations": newlines.copy,
        @"checkingRanges": @[],
        @"candidateDescriptor": @{
            @"candidate": @"", @"original": @"", @"actionable": @NO,
        },
        @"mutationTrace": trace,
        @"eventTrace": trace,
        @"keyboardState": @{
            @"visible": @(editor.isFirstResponder),
            @"locale": editor.textInputMode.primaryLanguage ?: @"",
            @"learnedOriginal": @([UITextChecker hasLearnedWord:
                NSProcessInfo.processInfo.environment[@"IDAutocorrectionOriginal"] ?: @""]),
        },
        @"correctionGeometry": @{
            @"x": @(correctionRect.origin.x), @"y": @(correctionRect.origin.y),
            @"width": @(correctionRect.size.width),
            @"height": @(correctionRect.size.height),
        },
        @"coordinateSpaceIdentity": @"block-text-view",
        @"documentRevision": @(revision >= baseline ? revision - baseline : 0),
        @"textEpoch": @(textEpoch),
        @"selectionEpoch": @(selectionEpoch),
        @"checkingEpoch": @(textEpoch),
        @"firstResponder": @(editor.isFirstResponder),
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:status
        options:NSJSONWritingSortedKeys error:nil];
    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
        encoding:NSUTF8StringEncoding];
}

- (NSString *)id_inlinePredictionStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) return @"{}";
    [editor layoutIfNeeded];
    NSRange selection = [editor id_NSRangeForTextRange:editor.selectedTextRange];
    UITextRange *markedTextRange = editor.markedTextRange;
    NSRange marked = markedTextRange == nil
        ? NSMakeRange(NSNotFound, 0)
        : [editor id_NSRangeForTextRange:markedTextRange];
    NSMutableArray<NSString *> *blocks = [NSMutableArray array];
    NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
    __block NSUInteger cursor = 0;
    [editor.attributedBlocks enumerateObjectsUsingBlock:
        ^(NSAttributedString *block, NSUInteger index, BOOL *stop) {
            (void)stop;
            [blocks addObject:block.string ?: @""];
            cursor += block.length;
            if (index + 1 < editor.attributedBlocks.count) {
                [newlines addObject:@(cursor)];
                cursor += 1;
            }
        }];
    NSArray<NSString *> *trace = IDCopyAutocorrectionTraceForUITesting();
    NSUInteger textEpoch = 0;
    NSUInteger selectionEpoch = 0;
    for (NSString *event in trace) {
        textEpoch += [event isEqualToString:@"textDidChange"];
        selectionEpoch += [event isEqualToString:@"selectionDidChange"];
    }
    NSString *displayText = @"";
    CGRect geometry = CGRectZero;
    if (marked.location != NSNotFound && NSMaxRange(marked) <= editor.text.length) {
        displayText = [editor.text substringWithRange:marked];
        geometry = [editor firstRectForRange:markedTextRange];
    }
    NSRange descriptorRange = marked.location == NSNotFound
        ? NSMakeRange(selection.location, 0) : marked;
    NSUInteger revision = editor.id_document.documentRevision;
    NSUInteger baseline = self.inlinePredictionBaselineDocumentRevision;
    NSDictionary *status = @{
        @"schema": @1,
        @"scenario": self.blockUIScenario ?: @"inline-prediction-interior",
        @"canonical": editor.text ?: @"",
        @"blocks": blocks.copy,
        @"selection": @{
            @"location": @(selection.location), @"length": @(selection.length),
        },
        @"affinity": @"forward",
        @"markedRange": @{
            @"location": @(marked.location), @"length": @(marked.length),
        },
        @"structuralNewlineLocations": newlines.copy,
        @"checkingRanges": @[],
        @"predictionDescriptor": @{
            @"present": @((BOOL)(displayText.length > 0)),
            @"displayText": displayText,
            @"accessibilityIdentity":
                displayText.length > 0 ? @"marked-text" : @"",
            @"range": @{
                @"location": @(descriptorRange.location),
                @"length": @(descriptorRange.length),
            },
            @"renderingAttributeKeys": @[],
        },
        @"temporaryRenderingDescriptors": @[],
        @"mutationTrace": trace,
        @"eventTrace": trace,
        @"keyboardState": @{
            @"visible": @(editor.isFirstResponder),
            @"locale": editor.textInputMode.primaryLanguage ?: @"",
            @"inlinePredictionEnabled":
                @((BOOL)(editor.inlinePredictionType ==
                    UITextInlinePredictionTypeYes)),
        },
        @"predictionGeometry": @{
            @"x": @(geometry.origin.x), @"y": @(geometry.origin.y),
            @"width": @(geometry.size.width), @"height": @(geometry.size.height),
        },
        @"coordinateSpaceIdentity": @"block-text-view",
        @"documentRevision": @(revision >= baseline ? revision - baseline : 0),
        @"textEpoch": @(textEpoch),
        @"selectionEpoch": @(selectionEpoch),
        @"checkingEpoch": @(textEpoch),
        @"firstResponder": @(editor.isFirstResponder),
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:status
        options:NSJSONWritingSortedKeys error:nil];
    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
        encoding:NSUTF8StringEncoding];
}

- (NSString *)id_geometryStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) return @"{}";
    [editor layoutIfNeeded];
    UITextRange *selectedRange = editor.selectedTextRange;
    NSRange selection = [editor id_NSRangeForTextRange:selectedRange];
    if (selection.location == NSNotFound) selection = NSMakeRange(0, 0);
    CGRect caret = selection.length == 0 && selectedRange != nil
        ? [editor caretRectForPosition:selectedRange.end] : CGRectZero;
    if (CGRectIsNull(caret) || CGRectIsInfinite(caret) ||
        !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
        !isfinite(caret.size.width) || !isfinite(caret.size.height)) {
        caret = CGRectZero;
    }
    UIEdgeInsets insets = editor.adjustedContentInset;
    CGRect visible = CGRectMake(
        editor.contentOffset.x + insets.left,
        editor.contentOffset.y + insets.top,
        MAX(CGRectGetWidth(editor.bounds) - insets.left - insets.right, 0),
        MAX(CGRectGetHeight(editor.bounds) - insets.top - insets.bottom, 0));
    NSString *selectionText = selectedRange == nil
        ? @"" : ([editor textInRange:selectedRange] ?: @"");
    NSMutableArray<NSDictionary<NSString *, id> *> *selectionRects =
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
            [selectionRects addObject:@{
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
    NSMutableDictionary<NSString *, id> *status = [@{
        @"blockCount": @(editor.attributedBlocks.count),
        @"boundary": IDCustomGeometryBoundary(
            editor, selectionStatus, self.blockUIScenario),
        @"canonical": editor.text ?: @"",
        @"caret": @{
            @"height": @(caret.size.height), @"width": @(caret.size.width),
            @"x": @(caret.origin.x), @"y": @(caret.origin.y),
        },
        @"contentOffset": @{
            @"x": @(editor.contentOffset.x), @"y": @(editor.contentOffset.y),
        },
        @"firstResponder": @(editor.isFirstResponder),
        @"scenario": self.blockUIScenario ?: @"none",
        @"selection": selectionStatus,
        @"selectionRects": selectionRects.copy,
        @"state": selection.length == 0 ? @"caret" : @"selection",
        @"visible": @{
            @"height": @(visible.size.height), @"width": @(visible.size.width),
            @"x": @(visible.origin.x), @"y": @(visible.origin.y),
        },
    } mutableCopy];
    if ([self.blockUIScenario isEqualToString:@"geometry-large-selection"]) {
        status[@"canonicalLength"] = @(editor.text.length);
        status[@"selectionTextLength"] = @(selectionText.length);
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:status
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
                                                        encoding:NSUTF8StringEncoding];
}

- (NSString *)id_blockStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) {
        return @"{\"blockCount\":0,\"blockOrigins\":[],\"canonical\":\"\","
                "\"caret\":{\"height\":0,\"width\":0,\"x\":0,\"y\":0},"
                "\"scenario\":\"none\",\"selection\":{\"length\":0,\"location\":0},"
                "\"spelling\":\"none\",\"spellingGeometryRequests\":0,"
                "\"state\":\"unavailable\",\"visible\":false}";
    }
    [editor layoutIfNeeded];
    NSRange range = [editor id_NSRangeForTextRange:editor.selectedTextRange];
    if (range.location == NSNotFound) range = NSMakeRange(0, 0);
    CGRect caret = editor.selectedTextRange != nil
        ? [editor caretRectForPosition:editor.selectedTextRange.end]
        : CGRectZero;
    if (CGRectIsNull(caret) || CGRectIsInfinite(caret) ||
        !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
        !isfinite(caret.size.width) || !isfinite(caret.size.height)) {
        caret = CGRectZero;
    }
    UIEdgeInsets insets = editor.adjustedContentInset;
    CGRect visibleRect = CGRectMake(editor.contentOffset.x + insets.left,
                                    editor.contentOffset.y + insets.top,
                                    MAX(CGRectGetWidth(editor.bounds) - insets.left - insets.right, 0),
                                    MAX(CGRectGetHeight(editor.bounds) - insets.top - insets.bottom, 0));
    BOOL visible = CGRectContainsRect(CGRectInset(visibleRect, -1, -1), caret);

    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *origins = [NSMutableArray array];
    for (IDBlockLayout *layout in editor.id_blockStack.blockLayouts) {
        CGPoint origin = [editor.id_blockStack
            documentOriginForBlockIdentifier:layout.blockIdentifier];
        if (!isfinite(origin.x) || !isfinite(origin.y)) origin = CGPointZero;
        [origins addObject:@{@"x": @(origin.x), @"y": @(origin.y)}];
    }

    __block NSString *spelling = @"none";
    UITextRange *documentRange = [editor textRangeFromPosition:editor.beginningOfDocument
                                                   toPosition:editor.endOfDocument];
    if (documentRange != nil) {
        NSAttributedString *annotated =
            [editor.id_richLayoutController id_annotatedSubstringForRange:documentRange];
        [annotated enumerateAttribute:@"NSTextAlternativesDisplayStyle"
                              inRange:NSMakeRange(0, annotated.length)
                              options:0
                           usingBlock:^(id value, NSRange annotatedRange, BOOL *stop) {
            if (value != nil) {
                spelling = [value description];
                *stop = YES;
            }
        }];
    }
    NSString *state = @"ready";
    if ([self.blockUIScenario isEqualToString:@"selection"]) {
        state = range.length == 0 ? @"seeded-caret" : @"public-selection";
    } else if ([self.blockUIScenario isEqualToString:@"boundary"]) {
        state = editor.attributedBlocks.count == 1 ? @"merged" : @"seeded-boundary";
    } else if ([self.blockUIScenario isEqualToString:@"caret"]) {
        state = editor.text.length == 0 ? @"seeded-caret" : @"edited";
    } else if ([self.blockUIScenario isEqualToString:@"spelling"]) {
        state = ![spelling isEqualToString:@"none"]
            ? @"annotated"
            : (editor.text.length == 0 ? @"seeded-caret" : @"checking");
    }
    NSMutableArray<NSDictionary<NSString *, id> *> *inlineBlocks =
        [NSMutableArray array];
    [editor.attributedBlocks enumerateObjectsUsingBlock:
        ^(NSAttributedString *block, NSUInteger index, BOOL *stop) {
            (void)stop;
            [inlineBlocks addObject:@{
                @"index": @(index),
                @"runs": IDDemoInlineRuns(block),
            }];
        }];
    NSDictionary<NSString *, id> *inlineFormatting = @{
        @"effectiveTypingTraits":
            IDDemoInlineTraitNames(editor.effectiveInlineTextTraits),
        @"states": @{
            @"bold": IDDemoInlineTraitStateName(
                [editor stateForInlineTextTrait:IDInlineTextTraitBold]),
            @"italic": IDDemoInlineTraitStateName(
                [editor stateForInlineTextTrait:IDInlineTextTraitItalic]),
            @"underline": IDDemoInlineTraitStateName(
                [editor stateForInlineTextTrait:IDInlineTextTraitUnderline]),
            @"strikethrough": IDDemoInlineTraitStateName(
                [editor stateForInlineTextTrait:
                    IDInlineTextTraitStrikethrough]),
        },
        @"blocks": inlineBlocks.copy,
    };
    NSDictionary *status = @{
        @"blockCount": @(editor.attributedBlocks.count),
        @"blockOrigins": origins.copy,
        @"canonical": editor.text ?: @"",
        @"caret": @{
            @"height": @(caret.size.height),
            @"width": @(caret.size.width),
            @"x": @(caret.origin.x),
            @"y": @(caret.origin.y),
        },
        @"scenario": self.blockUIScenario ?: @"normal",
        @"inlineFormatting": inlineFormatting,
        @"selection": @{
            @"length": @(range.length),
            @"location": @(range.location),
        },
        @"spelling": spelling,
        @"spellingGeometryRequests":
            @(editor.id_richLayoutController.id_boundingRectForCharacterRangeCallCount),
        @"state": state,
        @"visible": @(visible),
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:status
                                                   options:NSJSONWritingSortedKeys
                                                     error:&error];
    NSAssert(data != nil, @"Block status JSON serialization failed: %@", error);
    return data == nil ? @"{}" : [[NSString alloc] initWithData:data
                                                        encoding:NSUTF8StringEncoding];
}

- (NSString *)id_inlineFormattingKeyboardStatusValue {
    IDBlockTextView *editor = self.blockEditor;
    if (editor == nil) return @"{}";
    NSRange selection =
        [editor id_NSRangeForTextRange:editor.selectedTextRange];
    if (selection.location == NSNotFound) {
        selection = NSMakeRange(0, 0);
    }
    UITextRange *markedTextRange = editor.markedTextRange;
    NSRange marked = markedTextRange == nil
        ? NSMakeRange(NSNotFound, 0)
        : [editor id_NSRangeForTextRange:markedTextRange];
    NSMutableArray<NSDictionary<NSString *, id> *> *runs =
        [NSMutableArray array];
    __block NSUInteger location = 0;
    [editor.attributedBlocks enumerateObjectsUsingBlock:
        ^(NSAttributedString *block, NSUInteger index, BOOL *stop) {
            (void)stop;
            for (NSDictionary<NSString *, id> *run in
                 IDDemoInlineRuns(block)) {
                NSDictionary *range = run[@"range"];
                [runs addObject:@{
                    @"range": @{
                        @"location":
                            @(location +
                              [range[@"location"] unsignedIntegerValue]),
                        @"length": range[@"length"],
                    },
                    @"traits": run[@"traits"],
                }];
            }
            location += block.length;
            if (index + 1 < editor.attributedBlocks.count) {
                [runs addObject:@{
                    @"range": @{
                        @"location": @(location), @"length": @1,
                    },
                    @"traits": @[],
                }];
                location += 1;
            }
        }];
    NSDictionary<NSString *, id> *status = @{
        @"canonical": editor.text ?: @"",
        @"selection": @{
            @"location": @(selection.location),
            @"length": @(selection.length),
        },
        @"markedRange": @{
            @"location": @(marked.location),
            @"length": @(marked.length),
        },
        @"typingInlineTraits":
            IDDemoInlineTraitNames(editor.effectiveInlineTextTraits),
        @"inlineRuns": runs.copy,
        @"canUndo": @(editor.undoManager.canUndo),
    };
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:status
                   options:NSJSONWritingSortedKeys
                     error:nil];
    return data == nil ? @"{}" :
        [[NSString alloc] initWithData:data
                             encoding:NSUTF8StringEncoding];
}

- (void)id_installStatusViewWithIdentifier:(NSString *)identifier {
    IDDemoStatusView *status = [[IDDemoStatusView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
    status.accessibilityIdentifier = identifier;
    status.accessibilityLabel = identifier;
    status.backgroundColor = UIColor.clearColor;
    [self.view insertSubview:status atIndex:0];
    if ([identifier isEqualToString:@"selection-status"]) {
        self.selectionStatusView = status;
        __weak IDDemoViewController *weakSelf = self;
        status.statusValueProvider = ^NSString *{
            return [weakSelf id_selectionStatusValue];
        };
    } else {
        self.spellingStatusView = status;
        __weak IDTextView *weakEditor = self.editor;
        status.statusValueProvider = ^NSString *{
            IDTextView *editor = weakEditor;
            if (editor == nil) return @"text=;length=0;annotation=none";
            __block NSString *annotation = @"none";
            NSTextRange *documentRange = editor.id_textContentStorage.documentRange;
            if (documentRange.location != nil) {
                [editor.id_textLayoutManager
                    enumerateRenderingAttributesFromLocation:documentRange.location
                                                      reverse:NO
                                                   usingBlock:^BOOL(
                                                       NSTextLayoutManager *layoutManager,
                                                       NSDictionary *attributes,
                                                       NSTextRange *range) {
                    id style = attributes[@"NSTextAlternativesDisplayStyle"];
                    if (style != nil) {
                        annotation = [style description];
                        return NO;
                    }
                    return YES;
                }];
            }
            return [NSString stringWithFormat:@"text=%@;length=%lu;annotation=%@",
                                              editor.text,
                                              (unsigned long)editor.text.length,
                                              annotation];
        };
    }
}

- (NSString *)id_selectionStatusValue {
    IDTextView *editor = self.editor;
    if (editor == nil) {
        return @"range={0,0};caret={{0.000,0.000},{0.000,0.000}};"
                "visible={{0.000,0.000},{0.000,0.000}};offset={0.000,0.000}";
    }
    [editor layoutIfNeeded];
    UITextRange *selection = editor.selectedTextRange;
    NSRange range = [editor id_NSRangeForTextRange:selection];
    if (range.location == NSNotFound) range = NSMakeRange(0, 0);
    CGRect caret = selection != nil ? [editor caretRectForPosition:selection.end] : CGRectZero;
    if (CGRectIsNull(caret) || CGRectIsInfinite(caret)) caret = CGRectZero;
    UIEdgeInsets insets = editor.adjustedContentInset;
    CGRect visible = CGRectMake(editor.contentOffset.x + insets.left,
                                editor.contentOffset.y + insets.top,
                                MAX(CGRectGetWidth(editor.bounds) - insets.left - insets.right, 0),
                                MAX(CGRectGetHeight(editor.bounds) - insets.top - insets.bottom, 0));
    return [NSString stringWithFormat:
        @"range={%lu,%lu};caret={{%.3f,%.3f},{%.3f,%.3f}};"
         "visible={{%.3f,%.3f},{%.3f,%.3f}};offset={%.3f,%.3f}",
        (unsigned long)range.location,
        (unsigned long)range.length,
        caret.origin.x, caret.origin.y, caret.size.width, caret.size.height,
        visible.origin.x, visible.origin.y, visible.size.width, visible.size.height,
        editor.contentOffset.x, editor.contentOffset.y];
}

- (void)id_installAttachmentScenario {
    IDDemoAttachment *attachment = [[IDDemoAttachment alloc] initWithEditor:self.editor];
    self.demoAttachment = attachment;
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"Attachment viewport regression\nprovider: "];
    [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:@" real view\n"]];
    for (NSUInteger index = 0; index < 48; index++) {
        [text appendAttributedString:[[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:
                @"Attachment scroll line %02lu keeps the document overflowing.\n",
                (unsigned long)index]]];
    }
    [self.editor.id_textContentStorage performEditingTransactionUsingBlock:^{
        [self.editor.id_textContentStorage.textStorage setAttributedString:text];
    }];
    [self.editor id_applyUniformAttributes];
    [self.editor setNeedsLayout];
}

- (void)id_scheduleUIStatusUpdate {
    if (self.uiScenario.length == 0) {
        return;
    }
    __weak IDDemoViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf id_updateUIStatus];
    });
}

- (void)id_updateUIStatus {
    IDTextView *editor = self.editor;
    if (editor == nil) return;
    [editor layoutIfNeeded];

    if (self.selectionStatusView != nil) {
        self.selectionStatusView.statusValue = [self id_selectionStatusValue];
    }
    if (self.spellingStatusView != nil) {
        self.spellingStatusView.statusValue = [NSString stringWithFormat:
            @"text=%@;length=%lu", editor.text, (unsigned long)editor.text.length];
    }
    NSMutableArray *accessibilityElements = [NSMutableArray array];
    if (self.selectionStatusView != nil) {
        [accessibilityElements addObject:self.selectionStatusView];
    }
    if (self.spellingStatusView != nil) {
        [accessibilityElements addObject:self.spellingStatusView];
    }
    [accessibilityElements addObject:editor];
    IDDemoAttachmentView *attachmentView = self.demoAttachment.providedView;
    if (attachmentView.superview != nil && !attachmentView.hidden) {
        [accessibilityElements addObject:attachmentView];
    }
    self.view.accessibilityElements = accessibilityElements;
}

- (void)textViewDidChange:(IDTextView *)textView {
    [self id_scheduleUIStatusUpdate];
}

- (void)textViewDidBeginEditing:(IDTextView *)textView {
    if ([self.uiScenario isEqualToString:@"spelling"]) {
        [textView setContinuousSpellCheckingEnabled:YES];
    }
    [self id_scheduleUIStatusUpdate];
}

- (void)textViewDidChangeSelection:(IDTextView *)textView {
    [self id_scheduleUIStatusUpdate];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self id_scheduleUIStatusUpdate];
}

@end
