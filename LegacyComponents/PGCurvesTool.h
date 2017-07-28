#import "PGPhotoTool.h"

typedef enum
{
    PGCurvesTypeLuminance,
    PGCurvesTypeRed,
    PGCurvesTypeGreen,
    PGCurvesTypeBlue
} PGCurvesType;

@interface PGCurvesValue : NSObject <NSCopying>

@property (nonatomic, assign) CGFloat blacksLevel;
@property (nonatomic, assign) CGFloat shadowsLevel;
@property (nonatomic, assign) CGFloat midtonesLevel;
@property (nonatomic, assign) CGFloat highlightsLevel;
@property (nonatomic, assign) CGFloat whitesLevel;

- (NSArray *)interpolateCurve;

+ (instancetype)defaultValue;

@end

@interface PGCurvesToolValue : NSObject <NSCopying, PGCustomToolValue>

@property (nonatomic, strong) PGCurvesValue *luminanceCurve;
@property (nonatomic, strong) PGCurvesValue *redCurve;
@property (nonatomic, strong) PGCurvesValue *greenCurve;
@property (nonatomic, strong) PGCurvesValue *blueCurve;

@property (nonatomic, assign) PGCurvesType activeType;

@end

@interface PGCurvesTool : PGPhotoTool

@end
