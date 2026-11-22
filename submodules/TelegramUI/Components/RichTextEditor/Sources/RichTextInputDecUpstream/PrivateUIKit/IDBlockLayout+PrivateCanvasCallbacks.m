#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockLayout.h"
#import "IDTextCanvasAttachmentLifecycle.h"
#import "TGPrivateMethodAliases.h"
#import "TGPrivateRuntimeNames.h"


// The host answers the canvas callbacks under the same neutral `tgpn_` names they are compiled
// under here, so they are forwarded with a direct send; only UIKit uses the private names.
@protocol IDBlockLayoutCanvasHost <NSObject>
@optional
- (nullable id)tgpn_customRenderController;
- (CGRect)tgpn__clipRectForFadedEdges;
- (void)tgpn__textKit2CanvasDidLayout;
- (void)tgpn__updateInteractionGeometry;
@property(nonatomic, strong, readonly) UIColor *textColor;
@property(nonatomic, readonly, getter=isEditable) BOOL editable;
@property(nonatomic, readonly, getter=isEditing) BOOL editing;
- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentFrame;
- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views;
- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views;
@end

@interface IDBlockLayout (CanvasHostAccess) <IDTextCanvasAttachmentLifecycleSink>
- (nullable id<IDBlockLayoutCanvasHost>)id_canvasHost;
- (NSTextLayoutManager *)id_blockLayoutManager;
- (CGPoint)id_textContainerOrigin;
@end

FOUNDATION_EXTERN void IDBlockLayoutInstallPrivateCallbacks(Class cls);

@implementation IDBlockLayout (PrivateCanvasCallbacks)

- (NSTextLayoutManager *)layoutManager {
    return [self id_blockLayoutManager];
}

- (CGPoint)tgpn_textContainerOrigin {
    return [self id_textContainerOrigin];
}

- (id)tgpn_customRenderController {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    return [host respondsToSelector:@selector(tgpn_customRenderController)]
        ? [host tgpn_customRenderController]
        : nil;
}

- (UIColor *)textColor {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    return [host respondsToSelector:@selector(textColor)]
        ? host.textColor
        : UIColor.labelColor;
}

- (BOOL)isEditable {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    return [host respondsToSelector:@selector(isEditable)] && host.isEditable;
}

- (BOOL)isEditing {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    return [host respondsToSelector:@selector(isEditing)] && host.isEditing;
}

- (CGRect)tgpn__clipRectForFadedEdges {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    return [host respondsToSelector:@selector(tgpn__clipRectForFadedEdges)]
        ? [host tgpn__clipRectForFadedEdges]
        : CGRectNull;
}

- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentFrame {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    if ([host respondsToSelector:
        @selector(id_attachmentView:didLayoutInFragmentFrame:)]) {
        [host id_attachmentView:view didLayoutInFragmentFrame:fragmentFrame];
    }
}

- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    if ([host respondsToSelector:@selector(id_attachmentViewsDidEnterViewport:)]) {
        [host id_attachmentViewsDidEnterViewport:views];
    }
}

- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    if ([host respondsToSelector:@selector(id_attachmentViewsDidLeaveViewport:)]) {
        [host id_attachmentViewsDidLeaveViewport:views];
    }
}

- (void)tgpn__textKit2CanvasDidLayout {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    if ([host respondsToSelector:@selector(tgpn__textKit2CanvasDidLayout)]) {
        [host tgpn__textKit2CanvasDidLayout];
    }
}

- (void)tgpn__updateInteractionGeometry {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    if ([host respondsToSelector:@selector(tgpn__updateInteractionGeometry)]) {
        [host tgpn__updateInteractionGeometry];
    }
}

@end

void IDBlockLayoutInstallPrivateCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_textContainerOrigin, @selector(tgpn_textContainerOrigin) },
        { TGPN_customRenderController, @selector(tgpn_customRenderController) },
        { TGPN__clipRectForFadedEdges, @selector(tgpn__clipRectForFadedEdges) },
        { TGPN__textKit2CanvasDidLayout, @selector(tgpn__textKit2CanvasDidLayout) },
        { TGPN__updateInteractionGeometry, @selector(tgpn__updateInteractionGeometry) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

#endif
