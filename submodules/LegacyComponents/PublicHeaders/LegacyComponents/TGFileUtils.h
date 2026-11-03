#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGMimeTypeForFileExtension(NSString *fileExtension);
NSString *TGMimeTypeForFileUTI(NSString *fileUTI);
NSString *TGTemporaryFileName(NSString *fileExtension);
    
#ifdef __cplusplus
}
#endif