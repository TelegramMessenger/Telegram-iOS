#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SSignal;
@class PGPhotoHistogram;

@protocol TGPhotoEditorToolView <NSObject>

@property (nonatomic, assign) CGSize actualAreaSize;

@property (nonatomic, copy) void(^valueChanged)(id newValue, bool animated);
@property (nonatomic, strong) id value;

@property (nonatomic, readonly) bool isTracking;
@property (nonatomic, copy) void(^interactionBegan)(void);
@property (nonatomic, copy) void(^interactionEnded)(void);

@property (nonatomic, assign) bool isLandscape;
@property (nonatomic, assign) CGFloat toolbarLandscapeSize;

- (bool)buttonPressed:(bool)cancelButton;

@optional
- (void)setHistogramSignal:(SSignal *)signal;

@end
