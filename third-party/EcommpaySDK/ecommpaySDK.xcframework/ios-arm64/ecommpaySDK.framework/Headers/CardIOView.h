//
//  CardIOView.h
//  Version 5.4.1
//
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <UIKit/UIKit.h>
#import "CardIOViewDelegate.h"
#import "CardIODetectionMode.h"

/// CardIOView is one of two main entry points into the card.io SDK.
/// @see CardIOPaymentViewController
@interface CardIOView : UIView


#pragma mark - Properties you MUST set

/// Typically, your view controller will set itself as this delegate.
@property(nonatomic, weak, readwrite) id<CardIOViewDelegate> delegate;


#pragma mark - Properties you MAY set

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

/// Alter the card guide (bracket) color. Opaque colors recommended.
/// Defaults to nil; if nil, will use card.io green.
@property(nonatomic, retain, readwrite) UIColor *guideColor;

/// Set to YES to show the card.io logo over the camera instead of the PayPal logo. Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL useCardIOLogo;

/// Hide the PayPal or card.io logo in the scan view. Defaults to NO.
@property(nonatomic, assign, readwrite) BOOL hideCardIOLogo;

/// By default, in camera view the card guide and the buttons always rotate to match the device's orientation.
///   All four orientations are permitted, regardless of any app or viewcontroller constraints.
/// If you wish, the card guide and buttons can instead obey standard iOS constraints, including
///   the UISupportedInterfaceOrientations settings in your app's plist.
/// Set to NO to follow standard iOS constraints. Defaults to YES. (Does not affect the manual entry screen.)
@property(nonatomic, assign, readwrite) BOOL allowFreelyRotatingCardGuide;

/// Set the scan instruction text. If nil, use the default text. Defaults to nil.
/// Use newlines as desired to control the wrapping of text onto multiple lines.
@property(nonatomic, copy, readwrite) NSString *scanInstructions;

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

/// Set to NO if you don't want the camera to try to scan the card expiration.
/// Defaults to YES.
@property(nonatomic, assign, readwrite) BOOL scanExpiry;

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

/// After a successful scan, the CardIOView will briefly display an image of the card with
/// the computed card number superimposed. This property controls how long (in seconds)
/// that image will be displayed.
/// Set this to 0.0 to suppress the display entirely.
/// Defaults to 1.0.
@property(nonatomic, assign, readwrite) CGFloat scannedImageDuration;

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


#pragma mark - Property you MAY get

/// The actual camera preview area within the CardIOView. Location is relative to the CardIOView's origin.
/// You might want to use this, for example, when adjusting your view controller's view layout.
@property(nonatomic, assign, readonly) CGRect cameraPreviewFrame;

@end

