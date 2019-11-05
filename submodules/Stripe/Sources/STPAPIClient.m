//
//  STPAPIClient.m
//  StripeExample
//
//  Created by Jack Flintermann on 12/18/14.
//  Copyright (c) 2014 Stripe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <sys/utsname.h>

#import "STPAPIClient.h"
#import "STPAPIClient+ApplePay.h"
#import "STPFormEncoder.h"
#import "STPBankAccount.h"
#import "STPCard.h"
#import "STPToken.h"
#import "STPAPIPostRequest.h"
#import "STPPaymentConfiguration.h"
#import "NSString+Stripe_CardBrands.h"

#if __has_include("Fabric.h")
#import "Fabric+FABKits.h"
#import "FABKitProtocol.h"
#endif

#ifdef STP_STATIC_LIBRARY_BUILD
#import "STPCategoryLoader.h"
#endif

#define FAUXPAS_IGNORED_IN_METHOD(...)
FAUXPAS_IGNORED_IN_FILE(APIAvailability)

static NSString *const apiURLBase = @"api.stripe.com/v1";
static NSString *const tokenEndpoint = @"tokens";
static NSString *const stripeAPIVersion = @"2015-10-12";

@implementation Stripe

+ (void)setDefaultPublishableKey:(NSString *)publishableKey {
    [STPPaymentConfiguration sharedConfiguration].publishableKey = publishableKey;
}

+ (NSString *)defaultPublishableKey {
    return [STPPaymentConfiguration sharedConfiguration].publishableKey;
}

+ (void)disableAnalytics {
}

@end

#if __has_include("Fabric.h")
@interface STPAPIClient ()<FABKit>
#else
@interface STPAPIClient()
#endif
@property (nonatomic, readwrite) NSURL *apiURL;
@property (nonatomic, readwrite) NSURLSession *urlSession;
@end

@implementation STPAPIClient

+ (NSString *)stringWithCardBrand:(STPCardBrand)brand {
    return [NSString stp_stringWithCardBrand:brand];
}

+ (void)initialize {
#ifdef STP_STATIC_LIBRARY_BUILD
    [STPCategoryLoader loadCategories];
#endif
}

+ (instancetype)sharedClient {
    static id sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedClient = [[self alloc] init]; });
    return sharedClient;
}

- (instancetype)init {
    return [self initWithConfiguration:[STPPaymentConfiguration sharedConfiguration]];
}

- (instancetype)initWithPublishableKey:(NSString *)publishableKey {
    STPPaymentConfiguration *config = [[STPPaymentConfiguration alloc] init];
    config.publishableKey = [publishableKey copy];
    [self.class validateKey:publishableKey];
    return [self initWithConfiguration:config];
}

- (instancetype)initWithConfiguration:(STPPaymentConfiguration *)configuration {
    self = [super init];
    if (self) {
        _apiURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", apiURLBase]];
        _configuration = configuration;
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSString *auth = [@"Bearer " stringByAppendingString:self.publishableKey];
        sessionConfiguration.HTTPAdditionalHeaders = @{
                                                       @"X-Stripe-User-Agent": [self.class stripeUserAgentDetails],
                                                       @"Stripe-Version": stripeAPIVersion,
                                                       @"Authorization": auth,
                                                       };
        _urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration];

    }
    return self;
}

- (instancetype)initWithPublishableKey:(NSString *)publishableKey
                               baseURL:(NSString *)baseURL {
    self = [self initWithPublishableKey:publishableKey];
    if (self) {
        _apiURL = [NSURL URLWithString:baseURL];
    }
    return self;
}

- (void)setPublishableKey:(NSString *)publishableKey {
    self.configuration.publishableKey = [publishableKey copy];
}

- (NSString *)publishableKey {
    return self.configuration.publishableKey;
}

- (void)createTokenWithData:(NSData *)data
                 completion:(STPTokenCompletionBlock)completion {
    NSCAssert(data != nil, @"'data' is required to create a token");
    NSCAssert(completion != nil, @"'completion' is required to use the token that is created");
    [STPAPIPostRequest<STPToken *> startWithAPIClient:self
                                             endpoint:tokenEndpoint
                                             postData:data
                                           serializer:[STPToken new]
                                           completion:^(STPToken *object, NSHTTPURLResponse *response, NSError *error) {
                                               completion(object, error);
                                           }];
}

- (void)createTokenWithCard:(STPCard *)card completion:(STPTokenCompletionBlock)completion {
    NSData *data = [STPFormEncoder formEncodedDataForObject:card];
    [self createTokenWithData:data completion:completion];
}

#pragma mark - private helpers

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
+ (void)validateKey:(NSString *)publishableKey {
    NSCAssert(publishableKey != nil && ![publishableKey isEqualToString:@""],
              @"You must use a valid publishable key to create a token. For more info, see https://stripe.com/docs/stripe.js");
    BOOL secretKey = [publishableKey hasPrefix:@"sk_"];
    NSCAssert(!secretKey,
              @"You are using a secret key to create a token, instead of the publishable one. For more info, see https://stripe.com/docs/stripe.js");
#ifndef DEBUG
    if ([publishableKey.lowercaseString hasPrefix:@"pk_test"]) {
        FAUXPAS_IGNORED_IN_METHOD(NSLogUsed);
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"ℹ️ You're using your Stripe testmode key. Make sure to use your livemode key when submitting to the App Store!");
        });
    }
#endif
}
#pragma clang diagnostic pop

#pragma mark Utility methods -

+ (NSString *)stripeUserAgentDetails {
    NSMutableDictionary *details = [@{
        @"lang": @"objective-c",
        @"bindings_version": STPSDKVersion,
    } mutableCopy];
    NSString *version = [UIDevice currentDevice].systemVersion;
    if (version) {
        details[@"os_version"] = version;
    }
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceType = @(systemInfo.machine);
    if (deviceType) {
        details[@"type"] = deviceType;
    }
    NSString *model = [UIDevice currentDevice].localizedModel;
    if (model) {
        details[@"model"] = model;
    }
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        NSString *vendorIdentifier = [[[UIDevice currentDevice] performSelector:@selector(identifierForVendor)] performSelector:@selector(UUIDString)];
        if (vendorIdentifier) {
            details[@"vendor_identifier"] = vendorIdentifier;
        }
    }
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:[details copy] options:0 error:NULL] encoding:NSUTF8StringEncoding];
}

#pragma mark Fabric
#if __has_include("Fabric.h")

+ (NSString *)bundleIdentifier {
    return @"com.stripe.stripe-ios";
}

+ (NSString *)kitDisplayVersion {
    return STPSDKVersion;
}

+ (void)initializeIfNeeded {
    Class fabric = NSClassFromString(@"Fabric");
    if (fabric) {
        // The app must be using Fabric, as it exists at runtime. We fetch our default publishable key from Fabric.
        NSDictionary *fabricConfiguration = [fabric configurationDictionaryForKitClass:[STPAPIClient class]];
        NSString *publishableKey = fabricConfiguration[@"publishable"];
        if (!publishableKey) {
            NSLog(@"Configuration dictionary returned by Fabric was nil, or doesn't have publishableKey. Can't initialize Stripe.");
            return;
        }
        [self validateKey:publishableKey];
        [Stripe setDefaultPublishableKey:publishableKey];
    } else {
        NSCAssert(fabric, @"initializeIfNeeded method called from a project that doesn't have Fabric.");
    }
}

#endif

@end

#pragma mark - Bank Accounts
@implementation STPAPIClient (BankAccounts)

- (void)createTokenWithBankAccount:(STPBankAccountParams *)bankAccount
                        completion:(STPTokenCompletionBlock)completion {
    NSData *data = [STPFormEncoder formEncodedDataForObject:bankAccount];
    [self createTokenWithData:data completion:completion];
}

@end

#pragma mark - Credit Cards

@implementation Stripe (ApplePay)

+ (BOOL)canSubmitPaymentRequest:(PKPaymentRequest *)paymentRequest {
    if (![self deviceSupportsApplePay]) {
        return NO;
    }
    if (paymentRequest == nil) {
        return NO;
    }
    if (paymentRequest.merchantIdentifier == nil) {
        return NO;
    }
    return [[[paymentRequest.paymentSummaryItems lastObject] amount] floatValue] > 0;
}

+ (NSArray<NSString *> *)supportedPKPaymentNetworks {
    NSArray *supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa];
    if ((&PKPaymentNetworkDiscover) != NULL) {
        supportedNetworks = [supportedNetworks arrayByAddingObject:PKPaymentNetworkDiscover];
    }
    return supportedNetworks;
}

+ (BOOL)deviceSupportsApplePay {
    return [PKPaymentAuthorizationViewController class] && [PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[self supportedPKPaymentNetworks]];
}

+ (PKPaymentRequest *)paymentRequestWithMerchantIdentifier:(NSString *)merchantIdentifier {
    if (![PKPaymentRequest class]) {
        return nil;
    }
    PKPaymentRequest *paymentRequest = [PKPaymentRequest new];
    [paymentRequest setMerchantIdentifier:merchantIdentifier];
    [paymentRequest setSupportedNetworks:[self supportedPKPaymentNetworks]];
    [paymentRequest setMerchantCapabilities:PKMerchantCapability3DS];
    [paymentRequest setCountryCode:@"US"];
    [paymentRequest setCurrencyCode:@"USD"];
    return paymentRequest;
}

+ (void)createTokenWithPayment:(PKPayment *)payment
                    completion:(STPTokenCompletionBlock)handler {
    [[STPAPIClient sharedClient] createTokenWithPayment:payment completion:handler];
}

@end

@implementation Stripe (Deprecated)

+ (id)alloc {
    NSCAssert(NO, @"'Stripe' is a static class and cannot be instantiated.");
    return nil;
}

#pragma mark Shorthand methods -

+ (void)createTokenWithCard:(STPCard *)card completion:(STPCompletionBlock)handler {
    [[STPAPIClient sharedClient] createTokenWithCard:card completion:handler];
}

+ (void)createTokenWithCard:(STPCard *)card publishableKey:(NSString *)publishableKey completion:(STPCompletionBlock)handler {
    STPPaymentConfiguration *config = [STPPaymentConfiguration new];
    config.publishableKey = publishableKey;
    [[[STPAPIClient alloc] initWithConfiguration:config] createTokenWithCard:card completion:handler];
}

+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount completion:(STPCompletionBlock)handler {
    [[STPAPIClient sharedClient] createTokenWithBankAccount:bankAccount completion:handler];
}

+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount publishableKey:(NSString *)publishableKey completion:(STPCompletionBlock)handler {
    STPPaymentConfiguration *config = [STPPaymentConfiguration new];
    config.publishableKey = publishableKey;
    [[[STPAPIClient alloc] initWithConfiguration:config] createTokenWithBankAccount:bankAccount completion:handler];
}

@end
