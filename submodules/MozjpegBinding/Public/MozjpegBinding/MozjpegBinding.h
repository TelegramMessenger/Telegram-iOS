#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

NSData * _Nullable compressJPEGData(UIImage * _Nonnull sourceImage, NSString * _Nonnull tempFilePath);
NSArray<NSNumber *> * _Nonnull extractJPEGDataScans(NSData * _Nonnull data);
NSData * _Nullable compressMiniThumbnail(UIImage * _Nonnull image, CGSize size);
UIImage * _Nullable decompressImage(NSData * _Nonnull sourceData);

NSData * _Nullable compressJPEGXLData(UIImage * _Nonnull sourceImage, int quality);
UIImage * _Nullable decompressJPEGXLData(NSData * _Nonnull data);

#ifdef __cplusplus
}
#endif
