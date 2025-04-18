#import "PGPhotoTool.h"
#import "PGPhotoBlurPass.h"

@interface PGBlurToolValue : NSObject <NSCopying>

@property (nonatomic, assign) PGBlurToolType type;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) CGFloat size;
@property (nonatomic, assign) CGFloat falloff;
@property (nonatomic, assign) CGFloat angle;

@property (nonatomic, assign) CGFloat intensity;
@property (nonatomic, assign) bool editingIntensity;

@end

@interface PGBlurTool : PGPhotoTool

@property (nonatomic, readonly) NSString *intensityEditingTitle;

@end
