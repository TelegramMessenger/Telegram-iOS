//
//  CardIOViewDelegate.h
//  Version 5.4.1
//
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <Foundation/Foundation.h>

@class CardIOCreditCardInfo;
@class CardIOView;

/// The receiver will be notified when the CardIOView completes it work.
@protocol CardIOViewDelegate<NSObject>

@required

/// This method will be called when the CardIOView completes its work.
/// It is up to you to hide or remove the CardIOView.
/// At a minimum, you should give the user an opportunity to confirm that the card information was captured correctly.
/// @param cardIOView The active CardIOView.
/// @param cardInfo The results of the scan.
/// @note cardInfo will be nil if exiting due to a problem (e.g., no available camera).
- (void)cardIOView:(CardIOView *)cardIOView didScanCard:(CardIOCreditCardInfo *)cardInfo;

@end

