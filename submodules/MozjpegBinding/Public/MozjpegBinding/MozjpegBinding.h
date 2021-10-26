#import <UIKit/UIKit.h>

NSData * _Nullable compressJPEGData(UIImage * _Nonnull sourceImage);
NSArray<NSNumber *> * _Nonnull extractJPEGDataScans(NSData * _Nonnull data);
NSData * _Nullable compressMiniThumbnail(UIImage * _Nonnull image, CGSize size);
UIImage * _Nullable decompressImage(NSData * _Nonnull sourceData);
