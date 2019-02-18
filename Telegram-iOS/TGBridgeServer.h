#import <SSignalKit/SSignalKit.h>
#import <UIKit/UIKit.h>

@class TGBridgeSubscription;

@interface TGBridgeServer : NSObject

@property (nonatomic, readonly) NSURL * _Nullable temporaryFilesURL;

@property (nonatomic, readonly) bool isRunning;

- (instancetype)initWithHandler:(SSignal *(^)(TGBridgeSubscription *))handler fileHandler:(void (^)(NSString *, NSDictionary *))fileHandler dispatchOnQueue:(void (^)(void (^)(void)))dispatchOnQueue logFunction:(void (^)(NSString *))logFunction allowBackgroundTimeExtension:(void (^)())allowBackgroundTimeExtension;
- (void)startRunning;

- (SSignal *)watchAppInstalledSignal;
- (SSignal *)runningRequestsSignal;

- (void)setAuthorized:(bool)authorized userId:(int32_t)userId;
- (void)setMicAccessAllowed:(bool)allowed;
- (void)setStartupData:(NSDictionary *)data;
- (void)pushContext;

- (void)sendFileWithURL:(NSURL *)url metadata:(NSDictionary *)metadata asMessageData:(bool)asMessageData;
- (void)sendFileWithData:(NSData *)data metadata:(NSDictionary *)metadata errorHandler:(void (^)(void))errorHandler;

- (NSInteger)wakeupNetwork;
- (void)suspendNetworkIfReady:(NSInteger)token;

@end
