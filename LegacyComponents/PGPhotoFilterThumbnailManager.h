#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PGPhotoEditor;
@class PGPhotoFilter;

@interface PGPhotoFilterThumbnailManager : NSObject

@property (nonatomic, weak) PGPhotoEditor *photoEditor;

- (void)setThumbnailImage:(UIImage *)image;
- (void)requestThumbnailImageForFilter:(PGPhotoFilter *)filter completion:(void (^)(UIImage *thumbnailImage, bool cached, bool finished))completion;
- (void)startCachingThumbnailImagesForFilters:(NSArray *)filters;
- (void)stopCachingThumbnailImagesForFilters:(NSArray *)filters;
- (void)stopCachingThumbnailImagesForAllFilters;
- (void)invalidateThumbnailImages;

- (void)haltCaching;

@end
