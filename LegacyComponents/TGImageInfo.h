#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    bool extractFileUrlComponents(NSString *fileUrl, int *datacenterId, int64_t *volumeId, int *localId, int64_t *secret);
    bool extractFileUrlComponentsWithFileRef(NSString *fileUrl, int *datacenterId, int64_t *volumeId, int *localId, int64_t *secret, NSString **fileReferenceStr);
    
#ifdef __cplusplus
}
#endif

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
