#import <Foundation/Foundation.h>

@interface BuildConfig : NSObject

+ (instancetype _Nonnull)sharedBuildConfig;

@property (nonatomic, strong, readonly) NSData * _Nullable bundleData;
@property (nonatomic, strong, readonly) NSString * _Nullable hockeyAppId;
@property (nonatomic, readonly) int32_t apiId;
@property (nonatomic, strong, readonly) NSString * _Nonnull apiHash;
@property (nonatomic, readonly) bool isInternalBuild;
@property (nonatomic, readonly) bool isAppStoreBuild;
@property (nonatomic, readonly) int64_t appStoreId;
@property (nonatomic, strong, readonly) NSString * _Nonnull appSpecificUrlScheme;

@end
