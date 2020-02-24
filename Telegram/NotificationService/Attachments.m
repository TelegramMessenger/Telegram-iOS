#import "Attachments.h"

#import <MTProtoKit/MTProtoKit.h>

#import "Api.h"

id _Nullable parseAttachment(NSData * _Nonnull data) {
    if (data.length < 4) {
        return nil;
    }
    
    MTInputStream *inputStream = [[MTInputStream alloc] initWithData:data];
    
    int32_t signature = [inputStream readInt32];
    
    NSData *dataToParse = nil;
    if (signature == 0x3072cfa1) {
        NSData *bytes = [inputStream readBytes];
        if (bytes != nil) {
            dataToParse = [MTGzip decompress:bytes];
        }
    } else {
        dataToParse = data;
    }
    
    if (dataToParse == nil) {
        return nil;
    }
    
    return [Api1__Environment parseObject:dataToParse];
}
