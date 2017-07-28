#import "PGPhotoEditorItem.h"
#import "PGPhotoProcessPass.h"

@class PGPhotoToolComposer;

typedef enum
{
    PGPhotoToolTypePass,
    PGPhotoToolTypeShader
} PGPhotoToolType;

@protocol PGCustomToolValue <NSObject>

- (id<PGCustomToolValue>)cleanValue;

@end

@interface PGPhotoTool : NSObject <PGPhotoEditorItem>
{
    PGPhotoProcessPass *_pass;
    
    NSString *_identifier;
    PGPhotoToolType _type;
    NSInteger _order;
    
    NSArray *_parameters;
    NSArray *_constants;
    
    CGFloat _minimumValue;
    CGFloat _maximumValue;
    CGFloat _defaultValue;
}

@property (nonatomic, readonly) PGPhotoToolType type;
@property (nonatomic, readonly) NSInteger order;
@property (nonatomic, readonly) UIImage *image;

@property (nonatomic, readonly) bool isHidden;

@property (nonatomic, readonly) NSString *shaderString;
@property (nonatomic, readonly) NSString *ancillaryShaderString;
@property (nonatomic, readonly) PGPhotoProcessPass *pass;

@property (nonatomic, readonly) bool isSimple;

@property (nonatomic, weak) PGPhotoToolComposer *toolComposer;

- (void)invalidate;

- (NSString *)stringValue;
- (NSString *)stringValue:(bool)includeZero;

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id newValue, bool animated))changeBlock explicit:(bool)explicit nameWidth:(CGFloat)nameWidth;
- (UIView <TGPhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id))changeBlock explicit:(bool)explicit;

@end
