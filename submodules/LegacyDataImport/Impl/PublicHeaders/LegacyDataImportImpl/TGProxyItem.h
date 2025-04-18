#import <Foundation/Foundation.h>

@interface TGProxyItem : NSObject <NSCoding>

@property (nonatomic, readonly) NSString *server;
@property (nonatomic, readonly) int16_t port;
@property (nonatomic, readonly) NSString *username;
@property (nonatomic, readonly) NSString *password;
@property (nonatomic, readonly) NSString *secret;

@property (nonatomic, readonly) bool isMTProxy;

- (instancetype)initWithServer:(NSString *)server port:(int16_t)port username:(NSString *)username password:(NSString *)password secret:(NSString *)secret;

@end
