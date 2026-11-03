

#import <Foundation/Foundation.h>

@interface MTDatacenterAddress : NSObject <NSCoding, NSCopying>

@property (nonatomic, strong, readonly) NSString * _Nullable host;
@property (nonatomic, strong, readonly) NSString * _Nullable ip;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) bool preferForMedia;
@property (nonatomic, readonly) bool restrictToTcp;
@property (nonatomic, readonly) bool cdn;
@property (nonatomic, readonly) bool preferForProxy;
@property (nonatomic, readonly) NSData * _Nullable secret;

- (instancetype _Nonnull)initWithIp:(NSString * _Nonnull)ip port:(uint16_t)port preferForMedia:(bool)preferForMedia restrictToTcp:(bool)restrictToTcp cdn:(bool)cdn preferForProxy:(bool)preferForProxy secret:(NSData * _Nullable)secret;

- (BOOL)isEqualToAddress:(MTDatacenterAddress * _Nonnull)other;
- (BOOL)isIpv6;

@end
