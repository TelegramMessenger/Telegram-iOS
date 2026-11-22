#import <Foundation/Foundation.h>

@interface TGDataItem : NSObject

- (instancetype)initWithData:(NSData *)data;
- (void)appendData:(NSData *)data;
- (bool)replaceData:(NSData *)data;
- (NSData *)data;

@end

