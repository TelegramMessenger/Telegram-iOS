#import <Foundation/Foundation.h>

@protocol MTDisposable;

@interface MTRequestPendingVerificationData : NSObject

@property (nonatomic, strong, readonly) NSString *nonce;
@property (nonatomic, strong) NSString *secret;
@property (nonatomic) bool isResolved;
@property (nonatomic, strong) id<MTDisposable> disposable;

- (instancetype)initWithNonce:(NSString *)nonce;

@end

@interface MTRequestPendingRecaptchaVerificationData : NSObject

@property (nonatomic, strong, readonly) NSString *siteKey;
@property (nonatomic, strong) NSString *token;
@property (nonatomic) bool isResolved;
@property (nonatomic, strong) id<MTDisposable> disposable;

- (instancetype)initWithSiteKey:(NSString *)siteKey;

@end

@interface MTRequestErrorContext : NSObject

@property (nonatomic) CFAbsoluteTime minimalExecuteTime;

@property (nonatomic) NSUInteger internalServerErrorCount;
@property (nonatomic) NSUInteger floodWaitSeconds;
@property (nonatomic, strong) NSString *floodWaitErrorText;

@property (nonatomic) bool waitingForTokenExport;
@property (nonatomic, strong) id waitingForRequestToComplete;

@property (nonatomic, strong) MTRequestPendingVerificationData *pendingVerificationData;
@property (nonatomic, strong) MTRequestPendingRecaptchaVerificationData *pendingRecaptchaVerificationData;

@end
