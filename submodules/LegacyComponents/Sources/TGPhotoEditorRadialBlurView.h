#import <UIKit/UIKit.h>

@interface TGPhotoEditorRadialBlurView : UIView

@property (nonatomic, copy) void (^valueChanged)(CGPoint centerPoint, CGFloat falloff, CGFloat size);

@property (nonatomic, readonly) bool isTracking;
@property (nonatomic, copy) void(^interactionEnded)(void);

@property (nonatomic, assign) CGSize actualAreaSize;

@property (nonatomic, assign) CGPoint centerPoint;
@property (nonatomic, assign) CGFloat falloff;
@property (nonatomic, assign) CGFloat size;

@end
