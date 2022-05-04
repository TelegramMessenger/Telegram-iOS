//
//  CardIOPaymentViewController.h
//  Version 5.4.1
//
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <UIKit/UIKit.h>
#import "CardIOPaymentViewControllerDelegate.h"
#import "CardIODetectionMode.h"

/// CardIOPaymentViewController is one of two main entry points into the card.io SDK.
/// @see CardIOView
@interface CardIOPaymentViewController : UINavigationController

/// Initializer for scanning.
/// If scanning is not supported by the user's device, card.io will offer manual entry.
/// @param aDelegate Your CardIOPaymentViewControllerDelegate (typically a UIViewController).
/// @return Properly initialized CardIOPaymentViewController.
- (id)initWithPaymentDelegate:(id<CardIOPaymentViewControllerDelegate>)aDelegate;

/// Initializer for scanning, with extra hooks for controlling whether the camera will
/// be displayed (useful for testing).
/// @param aDelegate Your CardIOPaymentViewControllerDelegate (typically a UIViewController).
/// @param scanningEnabled If scanningEnabled is NO, card.io will offer manual entry,
///        regardless of whether scanning is supported by the user's device.
/// @return Properly initialized CardIOPaymentViewController.
- (id)initWithPaymentDelegate:(id<CardIOPaymentViewControllerDelegate>)aDelegate scanningEnabled:(BOOL)scanningEnabled;

/// The preferred language for all strings appearing in the user interface.
/// If not set, or if set to nil, defaults to the device's current language setting.
///
/// Can be specified as a language code ("en", "fr", "zh-Hans", etc.) or as a locale ("en_AU", "fr_FR", "zh-Hant_HK", etc.).
/// If card.io does not contain localized strings for a specified locale, then it will fall back to the language. E.g., "es_CO" -> "es".
/// If card.io does not contain localized strings for a specified language, then it will fall back to American English.
///
/// If you specify only a language code, and that code matches the device's currently preferred language,
/// then card.io will attempt to use the device's current region as well.
/// E.g., specifying "en" on a device set to "English" and "United Kingdom" will result in "en_GB".
///
/// These localizations are currently included:
/// ar,da,de,en,en_AU,en_GB,es,es_MX,fr,he,is,it,ja,ko,ms,nb,nl,pl,pt,pt_BR,ru,sv,th,tr,zh-Hans,zh-Hant,zh-Hant_TW.
@property(nonatomic, copy, readwrite) NSString *languageOrLocale;

/// @see keepStatusBarStyleForCardIO
@property(nonatomic, assign, readwrite) BOOL keepStatusBarStyle;
/// @see navigationBarStyleForCardIO
@property(nonatomic, assign, readwrite) UIBarStyle navigationBarStyle;
/// @see navigationBarTintColorForCardIO
@property(nonatomic, retain, readwrite) UIColor *navigationBarTintColor;

/// Normally, card.io blurs the screen when the app is backgrounded,
/// to obscure card details in the iOS-saved screenshot.
/// If your app already does its own blurring upon backgrounding,
/// you might choose to disable this behavior.
/// Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL disableBlurWhenBackgrounding;

/// Alter the card guide (bracket) color. Opaque colors recommended.
/// Defaults to nil; if nil, will use card.io green.
@property(nonatomic, retain, readwrite) UIColor *guideColor;

/// If YES, don't have the user confirm the scanned card, just return the results immediately.
/// Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL suppressScanConfirmation;

/// If YES, instead of displaying the image of the scanned card,
/// present the manual entry screen with the scanned card number prefilled.
/// Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL suppressScannedCardImage;

/// After a successful scan, card.io will display an image of the card with
/// the computed card number superimposed. This property controls how long (in seconds)
/// that image will be displayed.
/// Set this to 0.0 to suppress the display entirely.
/// Defaults to 0.1.
@property(nonatomic, assign, readwrite) CGFloat scannedImageDuration;

/// Mask the card number digits as they are manually entered by the user. Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL maskManualEntryDigits;

/// Set the scan instruction text. If nil, use the default text. Defaults to nil.
/// Use newlines as desired to control the wrapping of text onto multiple lines.
@property(nonatomic, copy, readwrite) NSString *scanInstructions;

/// Hide the PayPal or card.io logo in the scan view. Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL hideCardIOLogo;

/// A custom view that will be overlaid atop the entire scan view. Defaults to nil.
/// If you set a scanOverlayView, be sure to:
///
///   * Consider rotation. Be sure to test on the iPad with rotation both enabled and disabled.
///     To make rotation synchronization easier, whenever a scanOverlayView is set, and card.io does an
///     in-place rotation (rotates its UI elements relative to their containers), card.io will generate
///     rotation notifications; see CardIOScanningOrientationDidChangeNotification
///     and associated userInfo key documentation below.
///     As with UIKit, the initial rotation is always UIInterfaceOrientationPortrait.
///
///   * Be sure to pass touches through to the superview as appropriate. Note that the entire camera
///     preview responds to touches (triggers refocusing). Test the light button and the toolbar buttons.
///
///   * Minimize animations, redrawing, or any other CPU/GPU/memory intensive activities
@property(nonatomic, retain, readwrite) UIView *scanOverlayView;

/// CardIODetectionModeCardImageAndNumber: the scanner must successfully identify the card number.
/// CardIODetectionModeCardImageOnly: don't scan the card, just detect a credit-card-shaped card.
/// CardIODetectionModeAutomatic: start as CardIODetectionModeCardImageAndNumber, but fall back to
///        CardIODetectionModeCardImageOnly if scanning has not succeeded within a reasonable time.
/// Defaults to CardIODetectionModeCardImageAndNumber.
///
/// @note Images returned in CardIODetectionModeCardImageOnly mode may be less focused, to accomodate scanning
///       cards that are dominantly white (e.g., the backs of drivers licenses), and thus
///       hard to calculate accurate focus scores for.
@property(nonatomic, assign, readwrite) CardIODetectionMode detectionMode;

/// Set to NO if you don't need to collect the card expiration. Defaults to YES.
@property(nonatomic, assign, readwrite) BOOL collectExpiry;

/// Set to NO if you don't need to collect the CVV from the user. Defaults to YES.
@property(nonatomic, assign, readwrite) BOOL collectCVV;

/// Set to YES if you need to collect the billing postal code. Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL collectPostalCode;

/// Set to YES if the postal code should only collect numeric input. Defaults to NO. Set this if you know the
/// <a href="https://en.wikipedia.org/wiki/Postal_code">expected country's postal code</a> has only numeric postal
/// codes.
@property(nonatomic, assign, readwrite) BOOL restrictPostalCodeToNumericOnly;

/// Set to YES if you need to collect the cardholder name. Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL collectCardholderName;

/// Set to NO if you don't want the camera to try to scan the card expiration.
/// Applies only if collectExpiry is also YES.
/// Defaults to YES.
@property(nonatomic, assign, readwrite) BOOL scanExpiry;

/// Set to YES to show the card.io logo over the camera view instead of the PayPal logo. Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL useCardIOLogo;

/// By default, in camera view the card guide and the buttons always rotate to match the device's orientation.
///   All four orientations are permitted, regardless of any app or viewcontroller constraints.
/// If you wish, the card guide and buttons can instead obey standard iOS constraints, including
///   the UISupportedInterfaceOrientations settings in your app's plist.
/// Set to NO to follow standard iOS constraints. Defaults to YES. (Does not affect the manual entry screen.)
@property(nonatomic, assign, readwrite) BOOL allowFreelyRotatingCardGuide;

/// Set to YES to prevent card.io from showing its "Enter Manually" button. Defaults to NO.
///
/// @note If [CardIOUtilities canReadCardWithCamera] returns false, then if card.io is presented it will
///       automatically display its manual entry screen.
///       Therefore, if you want to prevent users from *ever* seeing card.io's manual entry screen,
///       you should first check [CardIOUtilities canReadCardWithCamera] before initing the view controller.
@property(nonatomic, assign, readwrite) BOOL disableManualEntryButtons;

/// Access to the delegate.
@property(nonatomic, weak, readwrite) id<CardIOPaymentViewControllerDelegate> paymentDelegate;

/// Name for orientation change notification.
extern NSString * const CardIOScanningOrientationDidChangeNotification;

/// userInfo key for orientation change notification, to get the current scanning orientation.
///
/// Returned as an NSValue wrapping a UIDeviceOrientation. Sample extraction code:
/// @code
///     NSValue *wrappedOrientation = notification.userInfo[CardIOCurrentScanningOrientation];
///     UIDeviceOrientation scanningOrientation = UIDeviceOrientationPortrait; // set a default value just to be safe
///     [wrappedOrientation getValue:&scanningOrientation];
///     // use scanningOrientation...
/// @endcode
extern NSString * const CardIOCurrentScanningOrientation;

/// userInfo key for orientation change notification, to get the duration of the card.io rotation animations.
///
/// Returned as an NSNumber wrapping an NSTimeInterval (i.e. a double).
extern NSString * const CardIOScanningOrientationAnimationDuration;

@end

/// Methods with names that do not conflict with Apple's private APIs.
@interface CardIOPaymentViewController (NonConflictingAPINames)

/// If YES, the status bar's style will be kept as whatever your app has set it to.
/// If NO, the status bar style will be set to the default style.
/// Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL keepStatusBarStyleForCardIO;

/// The default appearance of the navigation bar is navigationBarStyleForCardIO == UIBarStyleDefault;
/// tintColor == nil (pre-iOS 7), barTintColor == nil (iOS 7).
/// Set either or both of these properties if you want to override these defaults.
/// @see navigationBarTintColorForCardIO
@property(nonatomic, assign, readwrite) UIBarStyle navigationBarStyleForCardIO;

/// The default appearance of the navigation bar is navigationBarStyleForCardIO == UIBarStyleDefault;
/// tintColor == nil (pre-iOS 7), barTintColor == nil (iOS 7).
/// Set either or both of these properties if you want to override these defaults.
/// @see navigationBarStyleForCardIO
@property(nonatomic, retain, readwrite) UIColor *navigationBarTintColorForCardIO;

@end

