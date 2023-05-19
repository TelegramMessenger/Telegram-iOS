#import <UIKit/UIKit.h>
#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

@class PGCameraShotMetadata;
@class PGRectangle;

@interface TGCameraCapturedPhoto : NSObject <TGMediaEditableItem, TGMediaSelectableItem>

@property (nonatomic, readonly) UIImage *existingImage;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) PGCameraShotMetadata *metadata;
@property (nonatomic, readonly) PGRectangle *rectangle;

- (instancetype)initWithImage:(UIImage *)image metadata:(PGCameraShotMetadata *)metadata;
- (instancetype)initWithExistingImage:(UIImage *)image;
- (instancetype)initWithExistingImage:(UIImage *)image identifier:(NSString *)identifier;

- (instancetype)initWithImage:(UIImage *)image rectangle:(PGRectangle *)rectangle;

- (void)_cleanUp;

@end
