#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, JNWValueType) {
	JNWValueTypeNumber,
	JNWValueTypePoint,
	JNWValueTypeSize,
	JNWValueTypeRect,
	JNWValueTypeAffineTransform,
	JNWValueTypeTransform3D,
	JNWValueTypeUnknown
};

@interface NSValue (JNWAdditions)

- (CGRect)jnw_rectValue;
- (CGSize)jnw_sizeValue;
- (CGPoint)jnw_pointValue;
- (CGAffineTransform)jnw_affineTransformValue;

+ (NSValue *)jnw_valueWithRect:(CGRect)rect;
+ (NSValue *)jnw_valueWithSize:(CGSize)size;
+ (NSValue *)jnw_valueWithPoint:(CGPoint)point;
+ (NSValue *)jnw_valueWithAffineTransform:(CGAffineTransform)transform;

- (JNWValueType)jnw_type;

@end
