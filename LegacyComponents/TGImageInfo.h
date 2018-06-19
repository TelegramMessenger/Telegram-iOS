

#import <UIKit/UIKit.h>

@interface TGImageInfo : NSObject <NSCoding>

- (void)addImageWithSize:(CGSize)size url:(NSString *)url;
- (void)addImageWithSize:(CGSize)size url:(NSString *)url fileSize:(int)fileSize;

- (NSString *)closestImageUrlWithWidth:(int)width resultingSize:(CGSize *)resultingSize;
- (NSString *)closestImageUrlWithHeight:(int)height resultingSize:(CGSize *)resultingSize;
- (NSString *)closestImageUrlWithSize:(CGSize)size resultingSize:(CGSize *)resultingSize;
- (NSString *)closestImageUrlWithSize:(CGSize)size resultingSize:(CGSize *)resultingSize pickLargest:(bool)pickLargest;
- (NSString *)closestImageUrlWithSize:(CGSize)size resultingSize:(CGSize *)resultingSize resultingFileSize:(int *)resultingFileSize;
- (NSString *)closestImageUrlWithSize:(CGSize)size resultingSize:(CGSize *)resultingSize resultingFileSize:(int *)resultingFileSize pickLargest:(bool)pickLargest;
- (NSString *)imageUrlWithExactSize:(CGSize)size;
- (NSString *)imageUrlForLargestSize:(CGSize *)actualSize;
- (NSString *)imageUrlForSizeLargerThanSize:(CGSize)size actualSize:(CGSize *)actualSize;

- (bool)containsSizeWithUrl:(NSString *)url;
- (int)fileSizeForUrl:(NSString *)url;

- (NSDictionary *)allSizes;
- (bool)empty;

- (void)serialize:(NSMutableData *)data;
+ (TGImageInfo *)deserialize:(NSInputStream *)is;

@end
