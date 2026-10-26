#import "IDSelectionCallbackReductionProbe.h"

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDBlockStackCanvasView.h"
#import "IDSelectionPresentation.h"
#import "IDPrivateUIKit+Testing.h"

#import <objc/runtime.h>
#import <stdlib.h>

static BOOL IDProbeClassLocallyImplementsSelector(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index += 1) {
        if (method_getName(methods[index]) == selector) {
            found = YES;
            break;
        }
    }
    free(methods);
    return found;
}

static NSString *IDProbeBlockUIScenario(void) {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [arguments indexOfObject:@"--id-block-ui-scenario"];
    if (index == NSNotFound || index + 1 >= arguments.count) return @"none";
    NSString *scenario = arguments[index + 1];
    return scenario.length == 0 ? @"none" : scenario;
}

@interface IDSelectionCallbackReductionProbe ()
@property(nonatomic, weak) IDBlockTextView *editor;
@end

@implementation IDSelectionCallbackReductionProbe

- (instancetype)initWithEditor:(IDBlockTextView *)editor {
    self = [super init];
    if (self == nil) return nil;
    _editor = editor;
    return self;
}

- (NSDictionary<NSString *, id> *)snapshot {
    IDBlockTextView *editor = self.editor;
    NSArray<NSString *> *selectorNames = @[
        @"selectionContainerView",
        @"_selectionContainerViewAboveText",
        @"_existingSelectionContainerView",
        @"_placeSelectionContainerView",
        @"_updateInteractionGeometry",
    ];
    NSMutableDictionary<NSString *, NSNumber *> *responds =
        [NSMutableDictionary dictionaryWithCapacity:selectorNames.count];
    for (NSString *name in selectorNames) {
        responds[name] = @([editor respondsToSelector:NSSelectorFromString(name)]);
    }

    id<IDSelectionPresentationBackend> backend =
        editor.id_selectionPresentationBackend;
    UIView *firstContainer = [backend id_selectionContainerView];
    UIView *secondContainer = [backend id_selectionContainerView];
    UIView *existingContainer = backend.existingSelectionContainerView;
    UIView *superview = existingContainer.superview;
    NSString *superviewRole = @"none";
    if (superview == editor.id_blockStack) {
        superviewRole = @"blockStack";
    } else if (superview == editor) {
        superviewRole = @"textInputView";
    } else if (superview != nil) {
        superviewRole = @"editor";
    }

    SEL editingSelector = NSSelectorFromString(@"isEditing");
    Class editorClass = editor.class;
    Class directSuperclass = class_getSuperclass(editorClass);
    BOOL localProvider = IDProbeClassLocallyImplementsSelector(
        editorClass, editingSelector);
    IMP resolvedImplementation = class_getMethodImplementation(
        editorClass, editingSelector);
    IMP inheritedImplementation = class_getMethodImplementation(
        directSuperclass, editingSelector);

    NSString *visualSelectorName =
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:";
    SEL visualSelector = NSSelectorFromString(visualSelectorName);
    BOOL visualLocalProvider = IDProbeClassLocallyImplementsSelector(
        editorClass, visualSelector);
    BOOL visualResponds = [editor respondsToSelector:visualSelector];
    IMP visualResolvedImplementation = visualResponds
        ? class_getMethodImplementation(editorClass, visualSelector)
        : NULL;
    IMP visualInheritedImplementation = class_getMethodImplementation(
        directSuperclass, visualSelector);
    BOOL visualResolvedMatchesDirectSuperclass = visualResponds &&
        visualResolvedImplementation == visualInheritedImplementation;
    NSString *visualResolvedOwner = visualLocalProvider
        ? @"IDBlockTextView"
        : (visualResolvedMatchesDirectSuperclass ? @"directSuperclass" : @"none");
    BOOL richControllerLocalProvider = IDProbeClassLocallyImplementsSelector(
        object_getClass(editor.id_richLayoutController), visualSelector);

    SEL internalControllerSelector =
        NSSelectorFromString(@"_internalTextLayoutController");
    BOOL internalLocalProvider = IDProbeClassLocallyImplementsSelector(
        editorClass, internalControllerSelector);
    BOOL internalResponds = class_getInstanceMethod(
        editorClass, internalControllerSelector) != NULL;
    IMP internalResolvedImplementation = internalResponds
        ? class_getMethodImplementation(editorClass, internalControllerSelector)
        : NULL;
    IMP internalInheritedImplementation = class_getMethodImplementation(
        directSuperclass, internalControllerSelector);
    BOOL internalResolvedMatchesDirectSuperclass = internalResponds &&
        internalResolvedImplementation == internalInheritedImplementation;
    BOOL textLayoutControllerLocalProvider =
        IDProbeClassLocallyImplementsSelector(
            editorClass, NSSelectorFromString(@"textLayoutController"));

    UITextRange *selection = editor.selectedTextRange;
    NSInteger selectionLocation = 0;
    NSInteger selectionLength = 0;
    if (selection != nil) {
        selectionLocation = [editor offsetFromPosition:editor.beginningOfDocument
                                            toPosition:selection.start];
        selectionLength = [editor offsetFromPosition:selection.start
                                           toPosition:selection.end];
    }
    NSString *phase = editor.isFirstResponder
        ? @"focused"
        : (editor.window != nil ? @"attached" : @"detached");

    return @{
        @"schema": @5,
        @"responds": responds.copy,
        @"container": @{
            @"created": @(backend.selectionContainerCreationCount),
            @"stable": @(firstContainer != nil &&
                           firstContainer == secondContainer &&
                           firstContainer == existingContainer),
            @"superviewRole": superviewRole,
        },
        @"editingLookup": @{
            @"selector": @"isEditing",
            @"localProvider": @(localProvider),
            @"responds": @([editor respondsToSelector:editingSelector]),
            @"resolvedMatchesDirectSuperclass":
                @(resolvedImplementation == inheritedImplementation),
            @"resolvedOwner": localProvider
                ? @"IDBlockTextView"
                : @"directSuperclass",
        },
        @"visualSelectionLookup": @{
            @"selector": visualSelectorName,
            @"localProvider": @(visualLocalProvider),
            @"responds": @(visualResponds),
            @"resolvedMatchesDirectSuperclass":
                @(visualResolvedMatchesDirectSuperclass),
            @"resolvedOwner": visualResolvedOwner,
            @"richControllerLocalProvider": @(richControllerLocalProvider),
        },
        @"internalControllerLookup": @{
            @"selector": @"_internalTextLayoutController",
            @"localProvider": @(internalLocalProvider),
            @"responds": @(internalResponds),
            @"resolvedMatchesDirectSuperclass":
                @(internalResolvedMatchesDirectSuperclass),
            @"resolvedOwner": internalLocalProvider
                ? @"IDBlockTextView"
                : (internalResponds ? @"directSuperclass" : @"none"),
            @"textLayoutControllerLocalProvider":
                @(textLayoutControllerLocalProvider),
        },
        @"editorState": @{
            @"firstResponder": @(editor.isFirstResponder),
            @"editable": @(editor.isEditable),
            @"selectable": @(editor.isSelectable),
            @"selectionLocation": @(selectionLocation),
            @"selectionLength": @(selectionLength),
            @"scenario": IDProbeBlockUIScenario(),
            @"phase": phase,
        },
    };
}

- (NSString *)serializedSnapshot {
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.snapshot
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    if (data == nil) return @"{}";
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
