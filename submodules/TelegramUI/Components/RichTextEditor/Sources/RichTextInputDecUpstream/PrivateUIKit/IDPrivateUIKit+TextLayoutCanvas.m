#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"

#import "IDPrivateUIKit.h"

#import <objc/message.h>
#import <objc/runtime.h>

/// The layout controller's container-to-canvas map, found BY NAME.
///
/// It used to be found by scanning for an ivar at offset **`0x50`**, and that is a promise about a
/// struct layout Apple never made. iOS 27 broke it: `_UITextLayoutControllerBase` gained
/// `_textOriginOverride` at `+0x10`, every later ivar moved down eight bytes, and `_textCanvasViews`
/// went `+0x50` -> `+0x58`. What sits at `+0x50` on 27 is `_invisibleRanges`, an `NSMutableSet` —
/// so the scan handed back a set, the contract check below correctly refused it, and the engine
/// could not register a canvas at all. That single constant is what made the hosted suites read
/// "Canvas map at _UITextKit2LayoutController +0x50 failed" on iOS 27.
///
/// A NAME is the thing the Objective-C runtime actually guarantees to carry, so it survives a
/// re-layout, and `class_getInstanceVariable` already walks the superclass chain. The offset is
/// still read — by `object_getIvar`, from the ivar the runtime resolved — which is the difference
/// between using reflection and hardcoding the answer reflection would have given.
///
/// **The contract checks stay, and they are the real guard.** A name can be renamed as easily as a
/// layout can shift; what makes either safe to discover is refusing anything that does not answer
/// `setObject:forKey:` and `objectForKey:`, which is what turns a silent wrong-object write into a
/// loud refusal at construction.
#define IDCanvasMapIvarName TGPN__textCanvasViews()

static NSMapTable *IDCanvasMap(id layoutController) {
    Ivar ivar = class_getInstanceVariable(object_getClass(layoutController),
                                          IDCanvasMapIvarName.UTF8String);
    id candidate = ivar == NULL ? nil : object_getIvar(layoutController, ivar);
    [IDPrivateUIKit requireObject:candidate
               respondsToSelector:@selector(setObject:forKey:)
                            stage:[NSString stringWithFormat:@"Canvas map at %@.%@",
                                     TGPN__UITextKit2LayoutController(), TGPN__textCanvasViews()]];
    [IDPrivateUIKit requireObject:candidate
               respondsToSelector:@selector(objectForKey:)
                            stage:[NSString stringWithFormat:@"Canvas map lookup at %@.%@",
                                     TGPN__UITextKit2LayoutController(), TGPN__textCanvasViews()]];
    return candidate;
}

void IDPrivateRegisterTextLayoutCanvas(id controller,
                                       NSTextContainer *container,
                                       UIView *canvas) {
    NSMapTable *map = IDCanvasMap(controller);
    [map setObject:canvas forKey:container];
    if ([map objectForKey:container] != canvas) {
        [IDPrivateUIKit requireObject:nil stage:@"Canvas registration identity read-back"];
    }
}

UIView *IDPrivateRegisteredTextLayoutCanvas(id controller, NSTextContainer *container) {
    return [IDCanvasMap(controller) objectForKey:container];
}

void IDPrivateSetContinuousSpellCheckingEnabled(id controller, BOOL enabled) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        controller, NSSelectorFromString(TGPN_setContinuousSpellCheckingEnabled_()), enabled);
}

BOOL IDPrivateContinuousSpellCheckingEnabled(id controller) {
    return ((BOOL (*)(id, SEL))objc_msgSend)(
        controller, NSSelectorFromString(TGPN_continuousSpellCheckingEnabled()));
}

id IDPrivateCanvasCustomRenderController(id context) {
    return ((id (*)(id, SEL))objc_msgSend)(
        context, NSSelectorFromString(TGPN_customRenderController()));
}

UIColor *IDPrivateCanvasTextColor(id context) {
    if (context == nil) {
        return UIColor.labelColor;
    }
    SEL selector = NSSelectorFromString(@"textColor");
    [IDPrivateUIKit requireObject:context
              respondsToSelector:selector
                           stage:@"Canvas context text-color contract"];
    id color = ((id (*)(id, SEL))objc_msgSend)(context, selector);
    if (![color isKindOfClass:UIColor.class]) {
        [IDPrivateUIKit requireObject:nil stage:@"Canvas context text-color result"];
    }
    return color;
}

CGPoint IDPrivateCanvasContextTextContainerOrigin(id context) {
    if (context == nil) {
        return CGPointZero;
    }
    SEL selector = NSSelectorFromString(TGPN_textContainerOrigin());
    [IDPrivateUIKit requireObject:context
              respondsToSelector:selector
                           stage:@"Canvas context text-container-origin contract"];
    return ((CGPoint (*)(id, SEL))objc_msgSend)(context, selector);
}

CGRect IDPrivateCanvasContextClipRectForFadedEdges(id context) {
    if (context == nil) {
        return CGRectNull;
    }
    SEL selector = NSSelectorFromString(TGPN__clipRectForFadedEdges());
    if (![context respondsToSelector:selector]) {
        return CGRectNull;
    }
    return ((CGRect (*)(id, SEL))objc_msgSend)(context, selector);
}

BOOL IDPrivateCanvasTextRangeIsEmpty(id textRange) {
    SEL selector = NSSelectorFromString(@"isEmpty");
    [IDPrivateUIKit requireObject:textRange
              respondsToSelector:selector
                           stage:@"Platform rendering-surface text-range contract"];
    return ((BOOL (*)(id, SEL))objc_msgSend)(textRange, selector);
}

NSRange IDPrivateCanvasNSRangeForTextKitRange(UIView *textView, id textRange) {
    SEL selector = NSSelectorFromString(TGPN__nsRangeForTextKitRanges_());
    [IDPrivateUIKit requireObject:textView
              respondsToSelector:selector
                           stage:@"Text emphasis TextKit-range conversion contract"];
    return ((NSRange (*)(id, SEL, id))objc_msgSend)(textView,
                                                    selector,
                                                    @[textRange]);
}

NSTextStorage *IDPrivateCanvasTextStorage(UIView *textView) {
    SEL selector = NSSelectorFromString(@"textStorage");
    [IDPrivateUIKit requireObject:textView
              respondsToSelector:selector
                           stage:@"Text emphasis storage contract"];
    id textStorage = ((id (*)(id, SEL))objc_msgSend)(textView, selector);
    if (![textStorage isKindOfClass:NSTextStorage.class]) {
        [IDPrivateUIKit requireObject:nil stage:@"Text emphasis storage result"];
    }
    return textStorage;
}

void IDPrivateCanvasSetEmphasisTextRange(UIView *emphasisView, id textRange) {
    SEL selector = NSSelectorFromString(@"setTextRange:");
    [IDPrivateUIKit requireObject:emphasisView
              respondsToSelector:selector
                           stage:@"Text emphasis range-update contract"];
    ((void (*)(id, SEL, id))objc_msgSend)(emphasisView, selector, textRange);
}

void IDPrivateCanvasSetEmphasisOrigin(UIView *emphasisView, CGPoint origin) {
    SEL selector = NSSelectorFromString(@"setOrigin:");
    [IDPrivateUIKit requireObject:emphasisView
              respondsToSelector:selector
                           stage:@"Text emphasis origin-update contract"];
    ((void (*)(id, SEL, CGPoint))objc_msgSend)(emphasisView, selector, origin);
}

void IDPrivateCanvasPrepareCustomRenderer(id controller, CGFloat contentsScale) {
    [IDPrivateUIKit requireObject:controller
              respondsToSelector:NSSelectorFromString(TGPN_beginLayout())
                           stage:@"Custom renderer begin-layout contract"];
    [IDPrivateUIKit requireObject:controller
              respondsToSelector:NSSelectorFromString(TGPN_didLayoutFragment_())
                           stage:@"Custom renderer fragment-layout contract"];
    [IDPrivateUIKit requireObject:controller
              respondsToSelector:NSSelectorFromString(TGPN_endLayoutWithConsumer_())
                           stage:@"Custom renderer end-layout contract"];
    SEL setContentsScale = NSSelectorFromString(@"setContentsScale:");
    if ([controller respondsToSelector:setContentsScale]) {
        ((void (*)(id, SEL, CGFloat))objc_msgSend)(controller,
                                                   setContentsScale,
                                                   contentsScale);
    }
}

void IDPrivateCanvasCustomRendererBeginLayout(id controller) {
    ((void (*)(id, SEL))objc_msgSend)(controller, NSSelectorFromString(TGPN_beginLayout()));
}

void IDPrivateCanvasCustomRendererPreLayoutNotify(id controller) {
    SEL selector = NSSelectorFromString(TGPN_preLayoutNotify());
    if ([controller respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, selector);
    }
}

void IDPrivateCanvasCustomRendererDidLayoutFragment(id controller,
                                                     NSTextLayoutFragment *fragment) {
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, NSSelectorFromString(TGPN_didLayoutFragment_()), fragment);
}

void IDPrivateCanvasCustomRendererEndLayout(id controller,
                                            IDPrivateCanvasSurfaceConsumer consumer) {
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, NSSelectorFromString(TGPN_endLayoutWithConsumer_()), consumer);
}

UIView *IDPrivateCanvasRequireCustomEndConsumerHost(UIView *surface,
                                                    Class expectedHostClass) {
    if (surface == nil || ![surface isKindOfClass:expectedHostClass]) {
        NSString *actualClass = surface == nil
            ? @"<nil>"
            : NSStringFromClass(surface.class);
        NSString *stage = [NSString stringWithFormat:
            @"Custom renderer end-consumer stage requires an exact keyed %@; found %@",
            NSStringFromClass(expectedHostClass),
            actualClass];
        [IDPrivateUIKit requireObject:nil stage:stage];
    }
    return surface;
}

CALayer *IDPrivateCanvasCustomSurfaceLayer(id surface) {
    [IDPrivateUIKit requireObject:surface
              respondsToSelector:NSSelectorFromString(@"layer")
                           stage:@"Custom renderer surface-layer contract"];
    id layer = ((id (*)(id, SEL))objc_msgSend)(surface, NSSelectorFromString(@"layer"));
    if (![layer isKindOfClass:CALayer.class]) {
        [IDPrivateUIKit requireObject:nil stage:@"Custom renderer surface layer result"];
    }
    return layer;
}

void IDPrivateCanvasCustomRendererPostLayoutNotify(id controller) {
    SEL selector = NSSelectorFromString(TGPN_postLayoutNotify());
    if ([controller respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, selector);
    }
}

void IDPrivateCanvasSetNeedsDisplay(id customRenderController) {
    SEL selector = NSSelectorFromString(@"setNeedsDisplay");
    [IDPrivateUIKit requireObject:customRenderController
              respondsToSelector:selector
                           stage:@"Custom renderer display invalidation contract"];
    ((void (*)(id, SEL))objc_msgSend)(customRenderController, selector);
}

BOOL IDPrivateCanvasCanInvalidateTemporaryAttributes(id customRenderController) {
    return [customRenderController respondsToSelector:
        NSSelectorFromString(TGPN_invalidateTemporaryAttributesInRange_())];
}

NSArray *IDPrivateTextKit2Ranges(id rangeAdapter) {
    if ([rangeAdapter isKindOfClass:NSTextRange.class]) {
        return @[rangeAdapter];
    }
    [IDPrivateUIKit requireObject:rangeAdapter
              respondsToSelector:NSSelectorFromString(TGPN_textKit2Ranges())
                           stage:@"Temporary-attribute TextKit 2 range adapter"];
    id ranges = ((id (*)(id, SEL))objc_msgSend)(
        rangeAdapter, NSSelectorFromString(TGPN_textKit2Ranges()));
    if (![ranges isKindOfClass:NSArray.class]) {
        [IDPrivateUIKit requireObject:nil stage:@"Temporary-attribute TextKit 2 ranges result"];
    }
    return ranges;
}

void IDPrivateCanvasInvalidateTemporaryAttributes(id customRenderController, id textKit2Range) {
    ((void (*)(id, SEL, id))objc_msgSend)(
        customRenderController,
        NSSelectorFromString(TGPN_invalidateTemporaryAttributesInRange_()),
        textKit2Range);
}

void IDPrivateCanvasSetHostsLayoutEngine(UIView *view, BOOL hostsLayoutEngine) {
    if (view == nil) {
        return;
    }
    SEL selector = NSSelectorFromString(TGPN__setHostsLayoutEngine_());
    [IDPrivateUIKit requireObject:view
              respondsToSelector:selector
                           stage:@"Layout-engine hosting view contract"];
    ((void (*)(id, SEL, BOOL))objc_msgSend)(view, selector, hostsLayoutEngine);
}

CGRect IDPrivateCanvasParagraphAnchoredBounds(NSTextLayoutFragment *fragment,
                                               id attachment) {
    SEL selector = NSSelectorFromString(TGPN_boundsForTextParagraphAnchoredAttachment_());
    [IDPrivateUIKit requireObject:fragment
              respondsToSelector:selector
                           stage:@"Paragraph-anchored attachment bounds contract"];
    return ((CGRect (*)(id, SEL, id))objc_msgSend)(fragment, selector, attachment);
}

id IDPrivateCanvasParagraphAnchoredProvider(NSTextLayoutFragment *fragment,
                                            id attachment) {
    SEL selector =
        NSSelectorFromString(TGPN_textAttachmentViewProviderForTextParagraphAnchoredAttachment_());
    [IDPrivateUIKit requireObject:fragment
              respondsToSelector:selector
                           stage:@"Paragraph-anchored attachment provider contract"];
    return ((id (*)(id, SEL, id))objc_msgSend)(fragment, selector, attachment);
}

UIView *IDPrivateCanvasAttachmentProviderView(id provider) {
    if (provider == nil) {
        return nil;
    }
    SEL selector = NSSelectorFromString(@"view");
    [IDPrivateUIKit requireObject:provider
              respondsToSelector:selector
                           stage:@"Paragraph-anchored attachment provider view contract"];
    id view = ((id (*)(id, SEL))objc_msgSend)(provider, selector);
    if (view != nil && ![view isKindOfClass:UIView.class]) {
        [IDPrivateUIKit requireObject:nil
                               stage:@"Paragraph-anchored attachment provider view result"];
    }
    return view;
}

void IDPrivateCanvasDrawParagraphAnchoredAttachment(NSTextLayoutFragment *fragment,
                                                     id attachment,
                                                     CGRect bounds,
                                                     CGContextRef context) {
    SEL selector = NSSelectorFromString(TGPN_drawTextParagraphAnchoredAttachment_bounds_context_());
    [IDPrivateUIKit requireObject:fragment
              respondsToSelector:selector
                           stage:@"Paragraph-anchored attachment drawing contract"];
    ((void (*)(id, SEL, id, CGRect, CGContextRef))objc_msgSend)(fragment,
                                                                selector,
                                                                attachment,
                                                                bounds,
                                                                context);
}

BOOL IDPrivateCanvasInstallPlatformSurfaceUpdaterIfAvailable(
    NSTextViewportLayoutController *controller,
    IDPrivateCanvasPlatformSurfaceUpdater updater) {
    SEL getter = NSSelectorFromString(TGPN__platformRenderingSurfaceUpdater());
    SEL setter = NSSelectorFromString(TGPN_set_platformRenderingSurfaceUpdater_());
    BOOL hasGetter = [controller respondsToSelector:getter];
    BOOL hasSetter = [controller respondsToSelector:setter];
    if (!hasGetter && !hasSetter) {
        return NO;
    }
    if (hasGetter != hasSetter) {
        [IDPrivateUIKit requireObject:nil
                               stage:@"Platform rendering-surface updater getter/setter contract"];
    }
    id existing = ((id (*)(id, SEL))objc_msgSend)(controller, getter);
    if (existing == nil) {
        ((void (*)(id, SEL, id))objc_msgSend)(controller, setter, updater);
    }
    return YES;
}

BOOL IDPrivateCanvasClearPlatformSurfaceUpdaterIfAvailable(
    NSTextViewportLayoutController *controller) {
    SEL getter = NSSelectorFromString(TGPN__platformRenderingSurfaceUpdater());
    SEL setter = NSSelectorFromString(TGPN_set_platformRenderingSurfaceUpdater_());
    BOOL hasGetter = [controller respondsToSelector:getter];
    BOOL hasSetter = [controller respondsToSelector:setter];
    if (!hasGetter && !hasSetter) {
        return NO;
    }
    if (hasGetter != hasSetter) {
        [IDPrivateUIKit requireObject:nil
                               stage:@"Platform rendering-surface updater getter/setter contract"];
    }
    ((void (*)(id, SEL, id))objc_msgSend)(controller, setter, nil);
    return YES;
}

void IDPrivateCanvasNotifyContextDidLayout(id context) {
    if (context == nil) {
        return;
    }
    SEL selector = NSSelectorFromString(TGPN__textKit2CanvasDidLayout());
    [IDPrivateUIKit requireObject:context
              respondsToSelector:selector
                           stage:@"Canvas post-layout context callback"];
    ((void (*)(id, SEL))objc_msgSend)(context, selector);
}

void IDPrivateCanvasUpdateContextInteractionGeometry(id context) {
    if (context == nil) {
        return;
    }
    SEL selector = NSSelectorFromString(TGPN__updateInteractionGeometry());
    [IDPrivateUIKit requireObject:context
              respondsToSelector:selector
                           stage:@"Canvas post-layout interaction geometry callback"];
    ((void (*)(id, SEL))objc_msgSend)(context, selector);
}

BOOL IDPrivateCanvasContextIsEditing(id context) {
    if (context == nil) {
        return NO;
    }
    SEL selector = NSSelectorFromString(@"isEditing");
    if (![context respondsToSelector:selector]) {
        return NO;
    }
    return ((BOOL (*)(id, SEL))objc_msgSend)(context, selector);
}

BOOL IDPrivateCanvasContextIsEditable(id context) {
    if (context == nil) {
        return NO;
    }
    SEL selector = NSSelectorFromString(@"isEditable");
    [IDPrivateUIKit requireObject:context
              respondsToSelector:selector
                           stage:@"Canvas context editable-state contract"];
    return ((BOOL (*)(id, SEL))objc_msgSend)(context, selector);
}

BOOL IDPrivateCanvasSupportsAnchoredTextAttachments(id textContentManager) {
    if (textContentManager == nil) {
        return NO;
    }
    SEL selector = NSSelectorFromString(TGPN_supportsAnchoredTextAttachments());
    [IDPrivateUIKit requireObject:textContentManager
              respondsToSelector:selector
                           stage:@"Anchored-attachment content-manager contract"];
    return ((BOOL (*)(id, SEL))objc_msgSend)(textContentManager, selector);
}

NSArray *IDPrivateCanvasAnchoredTextAttachments(NSTextLayoutFragment *fragment) {
    SEL selector = NSSelectorFromString(TGPN_anchoredTextAttachments());
    [IDPrivateUIKit requireObject:fragment
              respondsToSelector:selector
                           stage:@"Anchored-attachment fragment enumeration contract"];
    id attachments = ((id (*)(id, SEL))objc_msgSend)(fragment, selector);
    if (![attachments isKindOfClass:NSArray.class]) {
        [IDPrivateUIKit requireObject:nil
                               stage:@"Anchored-attachment fragment enumeration result"];
    }
    return attachments;
}

#endif
