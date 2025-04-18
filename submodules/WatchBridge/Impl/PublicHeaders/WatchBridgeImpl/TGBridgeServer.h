#import <SSignalKit/SSignalKit.h>
#import <UIKit/UIKit.h>

@class TGBridgeSubscription;

@interface TGBridgeServer : NSObject

@property (nonatomic, readonly) NSURL * _Nullable temporaryFilesURL;

@property (nonatomic, readonly) bool isRunning;

- (instancetype _Nonnull)initWithHandler:(SSignal * _Nullable (^ _Nonnull)(TGBridgeSubscription * _Nullable))handler fileHandler:(void (^ _Nonnull)(NSString * _Nullable, NSDictionary * _Nullable))fileHandler dispatchOnQueue:(void (^ _Nonnull)(void (^ _Nonnull)(void)))dispatchOnQueue logFunction:(void (^ _Nonnull)(NSString * _Nullable))logFunction allowBackgroundTimeExtension:(void (^ _Nonnull)())allowBackgroundTimeExtension;
- (void)startRunning;

- (SSignal * _Nonnull)watchAppInstalledSignal;
- (SSignal * _Nonnull)runningRequestsSignal;

- (void)setAuthorized:(bool)authorized userId:(int64_t)userId;
- (void)setMicAccessAllowed:(bool)allowed;
- (void)setStartupData:(NSDictionary * _Nullable)data;
- (void)pushContext;

- (void)sendFileWithURL:(NSURL * _Nonnull)url metadata:(NSDictionary * _Nullable)metadata asMessageData:(bool)asMessageData;
- (void)sendFileWithData:(NSData * _Nonnull)data metadata:(NSDictionary * _Nullable)metadata errorHandler:(void (^ _Nullable)(void))errorHandler;

- (NSInteger)wakeupNetwork;
- (void)suspendNetworkIfReady:(NSInteger)token;

@end
