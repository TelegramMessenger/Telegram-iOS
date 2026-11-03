#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGModernGalleryComplexTransitionDescription : NSObject

@property (nonatomic, strong) UIImage *overlayImage;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) UIEdgeInsets insets;

@end

@protocol TGModernGalleryTransitionView <NSObject>

@required

- (UIImage *)transitionImage;

@optional

- (CGRect)transitionContentRect;

- (bool)hasComplexTransition;
- (TGModernGalleryComplexTransitionDescription *)complexTransitionDescription;

@end
