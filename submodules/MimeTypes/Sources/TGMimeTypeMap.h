#import <Foundation/Foundation.h>

@interface TGMimeTypeMap : NSObject

+ (NSString *)mimeTypeForExtension:(NSString *)extension;
+ (NSString *)extensionForMimeType:(NSString *)mimeType;

@end
