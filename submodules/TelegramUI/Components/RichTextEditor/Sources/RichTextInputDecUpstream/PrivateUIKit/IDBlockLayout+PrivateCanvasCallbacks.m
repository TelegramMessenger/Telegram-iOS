#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockLayout.h"
#import "IDTextCanvasAttachmentLifecycle.h"

@protocol IDBlockLayoutCanvasHost <NSObject>
@optional
@property(nonatomic, strong, readonly, nullable) id customRenderController;
@property(nonatomic, strong, readonly) UIColor *textColor;
@property(nonatomic, readonly, getter=isEditable) BOOL editable;
@property(nonatomic, readonly, getter=isEditing) BOOL editing;
- (CGRect)_clipRectForFadedEdges;
- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentFrame;
- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views;
- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views;
- (void)_textKit2CanvasDidLayout;
- (void)_updateInteractionGeometry;
@end

@interface IDBlockLayout (CanvasHostAccess) <IDTextCanvasAttachmentLifecycleSink>
- (nullable id<IDBlockLayoutCanvasHost>)id_canvasHost;
- (NSTextLayoutManager *)id_blockLayoutManager;
- (CGPoint)id_textContainerOrigin;
@end

@implementation IDBlockLayout (PrivateCanvasCallbacks)

- (NSTextLayoutManager *)layoutManager {
    return [self id_blockLayoutManager];
}

- (CGPoint)textContainerOrigin {
    return [self id_textContainerOrigin];
}

- (id)customRenderController {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    return [host respondsToSelector:@selector(customRenderController)]
        ? host.customRenderController
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

- (CGRect)_clipRectForFadedEdges {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    return [host respondsToSelector:@selector(_clipRectForFadedEdges)]
        ? [host _clipRectForFadedEdges]
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

- (void)_textKit2CanvasDidLayout {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    if ([host respondsToSelector:@selector(_textKit2CanvasDidLayout)]) {
        [host _textKit2CanvasDidLayout];
    }
}

- (void)_updateInteractionGeometry {
    id<IDBlockLayoutCanvasHost> host = [self id_canvasHost];
    if ([host respondsToSelector:@selector(_updateInteractionGeometry)]) {
        [host _updateInteractionGeometry];
    }
}

@end

#endif
