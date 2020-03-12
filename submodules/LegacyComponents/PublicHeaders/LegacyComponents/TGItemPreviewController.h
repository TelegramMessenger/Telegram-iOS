#import <UIKit/UIKit.h>

#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGOverlayController.h>

@class TGItemPreviewView;

@interface TGItemPreviewController : TGOverlayController

@property (nonatomic, copy) void (^onDismiss)(void);

@property (nonatomic, copy) CGPoint (^sourcePointForItem)(id item);
@property (nonatomic, readonly) TGItemPreviewView *previewView;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context parentController:(TGViewController *)parentController previewView:(TGItemPreviewView *)previewView;
- (void)dismiss;
- (void)dismissImmediately;

@end
