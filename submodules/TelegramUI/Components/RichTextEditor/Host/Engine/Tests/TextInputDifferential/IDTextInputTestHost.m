#import "IDTextInputTestHost.h"

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDUIKitCapabilityResolver.h"

NSString *const IDTextInputTestHostErrorDomain =
    @"com.inputdec.tests.text-input-host";

@interface IDDifferentialStockTextView : UITextView
@property(nonatomic, strong) UIView *id_suppressedInputView;
@end

@implementation IDDifferentialStockTextView

- (UIView *)inputView {
    if (_id_suppressedInputView == nil) {
        _id_suppressedInputView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, 1, 0)];
    }
    return _id_suppressedInputView;
}

@end

@interface IDDifferentialBlockTextView : IDBlockTextView
@property(nonatomic, strong) UIView *id_suppressedInputView;
@end

@implementation IDDifferentialBlockTextView

- (UIView *)inputView {
    if (_id_suppressedInputView == nil) {
        _id_suppressedInputView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, 1, 0)];
    }
    return _id_suppressedInputView;
}

@end

@interface IDTextInputTestHost ()

@property(nonatomic, readwrite) IDTextInputHostKind kind;
@property(nonatomic, strong, readwrite) UIWindow *window;
@property(nonatomic, strong, readwrite) UIView<UITextInput> *input;
@property(nonatomic, strong, readwrite) NSTextStorage *observedTextStorage;
@property(nonatomic, readwrite) BOOL comparesAnnotations;
@property(nonatomic, weak) UIWindow *previousKeyWindow;

@end

@implementation IDTextInputTestHost

static NSError *IDTextInputHostError(NSString *description) {
    return [NSError errorWithDomain:IDTextInputTestHostErrorDomain
                               code:1
                           userInfo:@{
        NSLocalizedDescriptionKey: description,
    }];
}

+ (NSArray<NSAttributedString *> *)attributedBlocksFromCanonical:
    (NSString *)canonical
                                                           font:(UIFont *)font {
    NSMutableArray<NSAttributedString *> *blocks =
        [NSMutableArray array];
    NSDictionary *attributes = @{NSFontAttributeName: font};
    for (NSString *string in
         [canonical componentsSeparatedByString:@"\n"]) {
        [blocks addObject:[[NSAttributedString alloc]
            initWithString:string attributes:attributes]];
    }
    return blocks.copy;
}

+ (void)applyTraits:(NSDictionary<NSString *, id> *)traits
              input:(id)input {
    [input setAutocapitalizationType:
        [traits[@"autocapitalizationType"] integerValue]];
    [input setAutocorrectionType:
        [traits[@"autocorrectionType"] integerValue]];
    [input setSpellCheckingType:
        [traits[@"spellCheckingType"] integerValue]];
    [input setSmartQuotesType:
        [traits[@"smartQuotesType"] integerValue]];
    [input setSmartDashesType:
        [traits[@"smartDashesType"] integerValue]];
    [input setSmartInsertDeleteType:
        [traits[@"smartInsertDeleteType"] integerValue]];
    [input setInlinePredictionType:
        [traits[@"inlinePredictionType"] integerValue]];
    [input setKeyboardType:[traits[@"keyboardType"] integerValue]];
    [input setReturnKeyType:[traits[@"returnKeyType"] integerValue]];
    [input setSecureTextEntry:[traits[@"secureTextEntry"] boolValue]];
}

+ (nullable instancetype)hostWithKind:(IDTextInputHostKind)kind
                             scenario:(IDTextInputScenario *)scenario
                                error:(NSError **)error {
    if (error != NULL) *error = nil;
    if (scenario == nil ||
        (kind != IDTextInputHostKindStock &&
         kind != IDTextInputHostKindReference &&
         kind != IDTextInputHostKindMinimal)) {
        if (error != NULL) {
            *error = IDTextInputHostError(
                @"Host kind or scenario is invalid.");
        }
        return nil;
    }

    IDTextInputTestHost *host = [IDTextInputTestHost new];
    host.kind = kind;
    host.comparesAnnotations =
        [scenario.comparisonFields containsObject:@"annotationRanges"];
    UIFont *font = [UIFont systemFontOfSize:17.0];
    CGRect editorFrame = CGRectMake(35, 120, 320, 480);
    UIEdgeInsets textInsets = UIEdgeInsetsMake(11, 9, 13, 9);

    if (kind == IDTextInputHostKindStock) {
        IDDifferentialStockTextView *stock =
            [[IDDifferentialStockTextView alloc]
                initWithFrame:editorFrame];
        stock.font = font;
        stock.text = scenario.initialText;
        stock.textContainerInset = textInsets;
        stock.contentInsetAdjustmentBehavior =
            UIScrollViewContentInsetAdjustmentNever;
        host.input = stock;
        host.observedTextStorage = stock.textStorage;
    } else {
        IDUIKitBehaviorBackend backend =
            kind == IDTextInputHostKindReference
                ? IDUIKitBehaviorBackendReference
                : IDUIKitBehaviorBackendMinimalKernel;
        IDUIKitBehaviorCapabilities capabilities =
            IDUIKitBehaviorCapabilityIncomingCallbacks |
            IDUIKitBehaviorCapabilityTypingAttributes |
            IDUIKitBehaviorCapabilityInteraction |
            IDUIKitBehaviorCapabilityFloatingCursor;
        IDDifferentialBlockTextView *custom =
            [[IDDifferentialBlockTextView alloc]
                initWithFrame:editorFrame
              attributedBlocks:
                  [self attributedBlocksFromCanonical:scenario.initialText
                                                 font:font]
               behaviorBackend:backend
                       resolver:[IDUIKitCapabilityResolver systemResolver]
          requestedCapabilities:capabilities
        selectionPresentationBackendFactory:
            [IDDifferentialBlockTextView
                id_defaultSelectionPresentationBackendFactory]];
        custom.font = font;
        custom.textContainerInset = textInsets;
        custom.contentInsetAdjustmentBehavior =
            UIScrollViewContentInsetAdjustmentNever;
        host.input = custom;
        host.observedTextStorage = custom.id_textStorageAdapter;
    }
    host.input.backgroundColor = UIColor.whiteColor;
    [(id)host.input setTextColor:UIColor.blackColor];
    [self applyTraits:scenario.initialTraits input:host.input];

    UIWindowScene *scene = nil;
    for (UIScene *candidate in
         UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class]) {
            scene = (UIWindowScene *)candidate;
            break;
        }
    }
    UIWindow *window = scene != nil
        ? [[UIWindow alloc] initWithWindowScene:scene]
        : [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    window.frame = CGRectMake(0, 0, 390, 844);
    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.whiteColor;
    window.rootViewController = controller;
    [controller.view addSubview:host.input];
    host.previousKeyWindow = scene.keyWindow;
    host.window = window;
    if (scenario.family == IDTextInputScenarioFamilyInlineFormatting) {
        window.hidden = YES;
    } else {
        [window makeKeyAndVisible];
    }
    [controller.view layoutIfNeeded];
    [host.input setNeedsLayout];
    [host.input layoutIfNeeded];

    UITextPosition *start = [host.input
        positionFromPosition:host.input.beginningOfDocument
                       offset:(NSInteger)scenario.initialSelection.location];
    UITextPosition *end = [host.input
        positionFromPosition:start
                       offset:(NSInteger)scenario.initialSelection.length];
    UITextRange *selection = start != nil && end != nil
        ? [host.input textRangeFromPosition:start toPosition:end] : nil;
    if (selection == nil) {
        if (error != NULL) {
            *error = IDTextInputHostError(
                @"Initial selection cannot be represented by the host.");
        }
        window.hidden = YES;
        return nil;
    }
    host.input.selectedTextRange = selection;
    [host.input layoutIfNeeded];
    return host;
}

- (void)dealloc {
    [self.input resignFirstResponder];
    [self.input removeFromSuperview];
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    [self.previousKeyWindow makeKeyWindow];
}

@end
