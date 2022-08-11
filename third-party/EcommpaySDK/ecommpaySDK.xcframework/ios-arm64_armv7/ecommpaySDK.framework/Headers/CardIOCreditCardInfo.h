//
//  CardIOCreditCardInfo.h
//  Version 5.4.1
//
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// CardIOCreditCardType Identifies type of card.
typedef NS_ENUM(NSInteger, CardIOCreditCardType) {
  /// The card number does not correspond to any recognizable card type.
  CardIOCreditCardTypeUnrecognized = 0,
  /// The card number corresponds to multiple card types (e.g., when only a few digits have been entered).
  CardIOCreditCardTypeAmbiguous = 1,
  /// American Express
  CardIOCreditCardTypeAmex = '3',
  /// Japan Credit Bureau
  CardIOCreditCardTypeJCB = 'J',
  /// VISA
  CardIOCreditCardTypeVisa = '4',
  /// MasterCard
  CardIOCreditCardTypeMastercard = '5',
  /// Discover Card
  CardIOCreditCardTypeDiscover = '6'
};


/// Container for the information about a card.
@interface CardIOCreditCardInfo : NSObject<NSCopying>

/// Card number.
@property(nonatomic, copy, readwrite) NSString *cardNumber;

/// Card number with all but the last four digits obfuscated.
@property(nonatomic, copy, readonly) NSString *redactedCardNumber;

/// January == 1
/// @note expiryMonth & expiryYear may be 0, if expiry information was not requested.
@property(nonatomic, assign, readwrite) NSUInteger expiryMonth;

/// The full four digit year.
/// @note expiryMonth & expiryYear may be 0, if expiry information was not requested.
@property(nonatomic, assign, readwrite) NSUInteger expiryYear;

/// Security code (aka CSC, CVV, CVV2, etc.)
/// @note May be nil, if security code was not requested.
@property(nonatomic, copy, readwrite) NSString *cvv;

/// Postal code. Format is country dependent.
/// @note May be nil, if postal code information was not requested.
@property(nonatomic, copy, readwrite) NSString *postalCode;

/// Cardholder Name.
/// @note May be nil, if cardholder name was not requested.
@property(nonatomic, copy, readwrite) NSString *cardholderName;

/// Was the card number scanned (as opposed to entered manually)?
@property(nonatomic, assign, readwrite) BOOL scanned;

/// The rectified card image; usually 428x270.
@property(nonatomic, strong, readwrite) UIImage *cardImage;

/// Derived from cardNumber.
/// @note CardIOCreditInfo objects returned by either of the delegate methods
///       userDidProvideCreditCardInfo:inPaymentViewController:
///       or cardIOView:didScanCard:
///       will never return a cardType of CardIOCreditCardTypeAmbiguous.
@property(nonatomic, assign, readonly) CardIOCreditCardType cardType;

/// Convenience method which returns a card type string suitable for display (e.g. "Visa", "American Express", "JCB", "MasterCard", or "Discover").
/// Where appropriate, this string will be translated into the language specified.
/// @param cardType The card type.
/// @param languageOrLocale See CardIOPaymentViewController.h for a detailed explanation of languageOrLocale.
/// @return Card type string suitable for display.
+ (NSString *)displayStringForCardType:(CardIOCreditCardType)cardType usingLanguageOrLocale:(NSString *)languageOrLocale;

/// Returns a 36x25 credit card logo, at a resolution appropriate for the device.
/// @param cardType The card type.
/// @return 36x25 credit card logo.
+ (UIImage *)logoForCardType:(CardIOCreditCardType)cardType;

@end

