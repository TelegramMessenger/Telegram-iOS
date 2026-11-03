//
//  StripeError.m
//  Stripe
//
//  Created by Saikat Chakrabarti on 11/4/12.
//
//

#import "StripeError.h"
#import "STPFormEncoder.h"

NSString *const StripeDomain = @"com.stripe.lib";
NSString *const STPCardErrorCodeKey = @"com.stripe.lib:CardErrorCodeKey";
NSString *const STPErrorMessageKey = @"com.stripe.lib:ErrorMessageKey";
NSString *const STPErrorParameterKey = @"com.stripe.lib:ErrorParameterKey";
NSString *const STPInvalidNumber = @"com.stripe.lib:InvalidNumber";
NSString *const STPInvalidExpMonth = @"com.stripe.lib:InvalidExpiryMonth";
NSString *const STPInvalidExpYear = @"com.stripe.lib:InvalidExpiryYear";
NSString *const STPInvalidCVC = @"com.stripe.lib:InvalidCVC";
NSString *const STPIncorrectNumber = @"com.stripe.lib:IncorrectNumber";
NSString *const STPExpiredCard = @"com.stripe.lib:ExpiredCard";
NSString *const STPCardDeclined = @"com.stripe.lib:CardDeclined";
NSString *const STPProcessingError = @"com.stripe.lib:ProcessingError";
NSString *const STPIncorrectCVC = @"com.stripe.lib:IncorrectCVC";

@implementation NSError(Stripe)

+ (NSError *)stp_errorFromStripeResponse:(NSDictionary *)jsonDictionary {
    NSDictionary *errorDictionary = jsonDictionary[@"error"];
    if (!errorDictionary) {
        return nil;
    }
    NSString *type = errorDictionary[@"type"];
    NSString *devMessage = errorDictionary[@"message"];
    NSString *parameter = errorDictionary[@"param"];
    NSInteger code = 0;
    
    // There should always be a message and type for the error
    if (devMessage == nil || type == nil) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: [self stp_unexpectedErrorMessage],
                                   STPErrorMessageKey: @"Could not interpret the error response that was returned from Stripe."
                                   };
        return [[self alloc] initWithDomain:StripeDomain code:STPAPIError userInfo:userInfo];
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[STPErrorMessageKey] = devMessage;
    
    if (parameter) {
        userInfo[STPErrorParameterKey] = [STPFormEncoder stringByReplacingSnakeCaseWithCamelCase:parameter];
    }
    
    if ([type isEqualToString:@"api_error"]) {
        code = STPAPIError;
        userInfo[NSLocalizedDescriptionKey] = [self stp_unexpectedErrorMessage];
    } else if ([type isEqualToString:@"invalid_request_error"]) {
        code = STPInvalidRequestError;
        userInfo[NSLocalizedDescriptionKey] = devMessage;
    } else if ([type isEqualToString:@"card_error"]) {
        code = STPCardError;
        NSDictionary *errorCodes = @{
                                     @"incorrect_number": @{@"code": STPIncorrectNumber, @"message": [self stp_cardErrorInvalidNumberUserMessage]},
                                     @"invalid_number": @{@"code": STPInvalidNumber, @"message": [self stp_cardErrorInvalidNumberUserMessage]},
                                     @"invalid_expiry_month": @{@"code": STPInvalidExpMonth, @"message": [self stp_cardErrorInvalidExpMonthUserMessage]},
                                     @"invalid_expiry_year": @{@"code": STPInvalidExpYear, @"message": [self stp_cardErrorInvalidExpYearUserMessage]},
                                     @"invalid_cvc": @{@"code": STPInvalidCVC, @"message": [self stp_cardInvalidCVCUserMessage]},
                                     @"expired_card": @{@"code": STPExpiredCard, @"message": [self stp_cardErrorExpiredCardUserMessage]},
                                     @"incorrect_cvc": @{@"code": STPIncorrectCVC, @"message": [self stp_cardInvalidCVCUserMessage]},
                                     @"card_declined": @{@"code": STPCardDeclined, @"message": [self stp_cardErrorDeclinedUserMessage]},
                                     @"processing_error": @{@"code": STPProcessingError, @"message": [self stp_cardErrorProcessingErrorUserMessage]},
                                     };
        NSDictionary *codeMapEntry = errorCodes[errorDictionary[@"code"]];
        
        if (codeMapEntry) {
            userInfo[STPCardErrorCodeKey] = codeMapEntry[@"code"];
            userInfo[NSLocalizedDescriptionKey] = codeMapEntry[@"message"];
        } else {
            userInfo[STPCardErrorCodeKey] = errorDictionary[@"code"];
            userInfo[NSLocalizedDescriptionKey] = devMessage;
        }
    }
    
    return [[self alloc] initWithDomain:StripeDomain code:code userInfo:userInfo];
}

+ (nonnull NSError *)stp_genericFailedToParseResponseError {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: [self stp_unexpectedErrorMessage],
                               STPErrorMessageKey: @"The response from Stripe failed to get parsed into valid JSON."
                               };
    return [[self alloc] initWithDomain:StripeDomain code:STPAPIError userInfo:userInfo];
}

- (BOOL)stp_isUnknownCheckoutError {
    return self.code == STPCheckoutUnknownError;
}

- (BOOL)stp_isURLSessionCancellationError {
    return [self.domain isEqualToString:NSURLErrorDomain] && self.code == NSURLErrorCancelled;
}

#pragma mark Strings

+ (nonnull NSString *)stp_cardErrorInvalidNumberUserMessage {
    return @"Your_cards_number_is_invalid";
}

+ (nonnull NSString *)stp_cardInvalidCVCUserMessage {
    return @"Your_cards_security_code_is_invalid";
}

+ (nonnull NSString *)stp_cardErrorInvalidExpMonthUserMessage {
    return @"Your_cards_expiration_month_is_invalid";
}

+ (nonnull NSString *)stp_cardErrorInvalidExpYearUserMessage {
    return @"Your_cards_expiration_year_is_invalid";
}

+ (nonnull NSString *)stp_cardErrorExpiredCardUserMessage {
    return @"Your_card_has_expired";
}

+ (nonnull NSString *)stp_cardErrorDeclinedUserMessage {
    return @"Your_card_was_declined";
}

+ (nonnull NSString *)stp_unexpectedErrorMessage {
    return @"Error.Generic";
}

+ (nonnull NSString *)stp_cardErrorProcessingErrorUserMessage {
    return @"Error.Generic";
}

@end
