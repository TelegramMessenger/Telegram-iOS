#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTPKCS : NSObject

@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSData *data;

+ (MTPKCS * _Nullable)parse:(const unsigned char *)buffer size:(int)size;

@end

NS_ASSUME_NONNULL_END
