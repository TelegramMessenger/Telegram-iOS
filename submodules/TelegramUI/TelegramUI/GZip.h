#ifndef Telegram_GZip_h
#define Telegram_GZip_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSData *TGGZipData(NSData *data, float level);
NSData *TGGUnzipData(NSData *data);
    
#ifdef __cplusplus
}
#endif

#endif
