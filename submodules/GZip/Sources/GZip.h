#import <Foundation/Foundation.h>

//! Project version number for GZip.
FOUNDATION_EXPORT double GZipVersionNumber;

//! Project version string for GZip.
FOUNDATION_EXPORT const unsigned char GZipVersionString[];

#ifdef __cplusplus
extern "C" {
#endif
    
NSData * _Nonnull TGGZipData(NSData * _Nonnull data, float level);
NSData * _Nullable TGGUnzipData(NSData * _Nonnull data, uint sizeLimit);
    
#ifdef __cplusplus
}
#endif

