#import "GPUImageFilter.h"

#define PGShaderString(text) @ STRINGIZE2(text)

@interface PGPhotoProcessPassParameter : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) bool isConst;
@property (nonatomic, readonly) bool isUniform;
@property (nonatomic, readonly) bool isVarying;
@property (nonatomic, assign) NSInteger count;

- (void)setFloatValue:(CGFloat)floatValue;
- (void)setFloatArray:(NSArray *)floatArray;
- (void)setColorValue:(UIColor *)colorValue;

- (void)storeFilter:(GPUImageFilter *)filter uniformIndex:(GLint)uniformIndex;
- (NSString *)shaderString;

+ (instancetype)varyingWithName:(NSString *)name type:(NSString *)type;
+ (instancetype)parameterWithName:(NSString *)name type:(NSString *)type;
+ (instancetype)parameterWithName:(NSString *)name type:(NSString *)type count:(NSInteger)count;
+ (instancetype)constWithName:(NSString *)name type:(NSString *)type value:(NSString *)value;

@end

@interface PGPhotoProcessPass : NSObject
{
    GPUImageOutput <GPUImageInput> *_filter;
}

@property (nonatomic, readonly) GPUImageOutput <GPUImageInput> *filter;

- (void)updateParameters;
- (void)invalidate;

@end

extern NSString *const PGPhotoEnhanceColorSwapShaderString;
