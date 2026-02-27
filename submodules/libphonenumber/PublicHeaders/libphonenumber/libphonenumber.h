#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
//! Project version number for libphonenumber_iOS.
FOUNDATION_EXPORT double libphonenumber_iOSVersionNumber;

//! Project version string for libphonenumber_iOS.
FOUNDATION_EXPORT const unsigned char libphonenumber_iOSVersionString[];

#import <libphonenumber/NBPhoneNumberDefines.h>
#import <libphonenumber/NBPhoneNumber.h>
#import <libphonenumber/NBPhoneNumberUtil.h>
#import <libphonenumber/NBAsYouTypeFormatter.h>
