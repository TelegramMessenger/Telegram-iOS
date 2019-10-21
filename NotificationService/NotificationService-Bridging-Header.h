#ifndef NotificationService_BridgingHeader_h
#define NotificationService_BridgingHeader_h

#import <Foundation/Foundation.h>
#import <BuildConfig/BuildConfig.h>

@protocol SyncProvider <NSObject>

- (void)addIncomingMessageWithRootPath:(NSString * _Nonnull)rootPath accountId:(int64_t)accountId encryptionParameters:(DeviceSpecificEncryptionParameters * _Nonnull)encryptionParameters peerId:(int64_t)peerId messageId:(int32_t)messageId completion:(void (^)(int32_t))completion;

@end

#endif
