#import <Foundation/Foundation.h>

@interface MTInternalMessageParser : NSObject

+ (id)parseMessage:(NSData *)data;
+ (id)unwrapMessage:(NSData *)data;

@end
