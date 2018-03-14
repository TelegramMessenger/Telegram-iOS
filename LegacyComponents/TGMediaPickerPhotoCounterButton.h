#import <UIKit/UIKit.h>
#import <LegacyComponents/TGModernButton.h>

@interface TGMediaPickerPhotoCounterButton : UIButton

@property (nonatomic, assign) bool internalHidden;

- (void)setSelectedCount:(NSInteger)count animated:(bool)animated;
- (void)setActiveNumber:(NSInteger)number animated:(bool)animated;
- (void)cancelledProcessingAnimated:(bool)animated completion:(void (^)(void))completion;

- (void)setInternalHidden:(bool)internalHidden animated:(bool)animated completion:(void (^)(void))completion;
- (void)setHidden:(bool)hidden animated:(bool)animated;
- (void)setHidden:(bool)hidden delay:(NSTimeInterval)delay animated:(bool)animated;
- (void)setSelected:(bool)selected animated:(bool)animated;

@end


@interface TGMediaPickerGroupButton : UIButton

- (void)setHidden:(bool)hidden animated:(bool)animated;
- (void)setInternalHidden:(bool)internalHidden animated:(bool)animated;

@end

@interface TGMediaPickerCameraButton : UIButton

- (void)setHidden:(bool)hidden animated:(bool)animated;
- (void)setInternalHidden:(bool)internalHidden animated:(bool)animated;

@end
