#import <Foundation/Foundation.h>

#import "StoredAccountInfos.h"
#import "Api.h"
#import <BuildConfig/BuildConfig.h>

NS_ASSUME_NONNULL_BEGIN

dispatch_block_t fetchImage(BuildConfig *buildConfig, AccountProxyConnection * _Nullable proxyConnection, StoredAccountInfo *account, Api1_InputFileLocation *inputFileLocation, int32_t datacenterId, void (^_completion)(NSData * _Nullable));

NS_ASSUME_NONNULL_END
