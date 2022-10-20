#import "PGPhotoProcessPass.h"

@class TGPhotoEditingContext;

@interface PGPhotoCustomFilterPass : PGPhotoProcessPass

@property (nonatomic, assign) CGFloat intensity;

- (instancetype)initWithShaderFile:(NSString *)shaderFile textureFiles:(NSArray *)textureFiles;
- (instancetype)initWithShaderFile:(NSString *)shaderFile textureFiles:(NSArray *)textureFiles optimized:(bool)optimized;
- (instancetype)initWithShaderString:(NSString *)shaderString textureImages:(NSArray *)textureImages;

@end
