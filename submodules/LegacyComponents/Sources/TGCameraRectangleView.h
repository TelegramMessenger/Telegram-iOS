#import <UIKit/UIKit.h>

@class TGCameraPreviewView;
@class PGRectangle;

@interface TGCameraRectangleView : UIView

@property (nonatomic, weak) TGCameraPreviewView *previewView;
@property (nonatomic, assign) bool enabled;

- (void)drawRectangle:(PGRectangle *)rectangle;

@end

