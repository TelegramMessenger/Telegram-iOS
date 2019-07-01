#import <Foundation/Foundation.h>

//! Project version number for GZip.
FOUNDATION_EXPORT double GZipVersionNumber;

//! Project version string for GZip.
FOUNDATION_EXPORT const unsigned char GZipVersionString[];

#ifdef __cplusplus
extern "C" {
#endif
    
NSData *TGGZipData(NSData *data, float level);
NSData * _Nullable TGGUnzipData(NSData *data);
    
#ifdef __cplusplus
}
#endif

