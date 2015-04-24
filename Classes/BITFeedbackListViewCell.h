/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import <UIKit/UIKit.h>
#import "BITFeedbackMessage.h"
#import "BITAttributedLabel.h"

@class BITFeedbackMessageAttachment;

@protocol BITFeedbackListViewCellDelegate <NSObject>

- (void)listCell:(id)cell didSelectAttachment:(BITFeedbackMessageAttachment *)attachment;

@end


/**
 * Cell style depending on the iOS version
 */
typedef NS_ENUM(NSUInteger, BITFeedbackListViewCellPresentationStyle) {
  /**
   * Default is iOS 6 style
   */
  BITFeedbackListViewCellPresentationStyleDefault = 0,
  /**
   * Draw cells in the iOS 7 style
   */
  BITFeedbackListViewCellPresentationStyleOS7 = 1
};

/**
 * Cell background style
 */
typedef NS_ENUM(NSUInteger, BITFeedbackListViewCellBackgroundStyle) {
  /**
   * For even rows
   */
  BITFeedbackListViewCellBackgroundStyleNormal = 0,
  /**
   * For uneven rows
   */
  BITFeedbackListViewCellBackgroundStyleAlternate = 1
};


@interface BITFeedbackListViewCell : UITableViewCell

@property (nonatomic, strong) BITFeedbackMessage *message;

@property (nonatomic) BITFeedbackListViewCellPresentationStyle style;

@property (nonatomic) BITFeedbackListViewCellBackgroundStyle backgroundStyle;

@property (nonatomic, strong) BITAttributedLabel *labelText;

@property (nonatomic, weak) id<BITFeedbackListViewCellDelegate> delegate;

+ (CGFloat) heightForRowWithMessage:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width;

- (void)setAttachments:(NSArray *)attachments;

///-----------------------------------------------------------------------------
/// @name Deprecated
///-----------------------------------------------------------------------------

typedef DEPRECATED_MSG_ATTRIBUTE("Use the properly spelled enum `BITFeedbackListViewCellPresentationStyle` instead.") NS_ENUM(NSUInteger, BITFeedbackListViewCellPresentatationStyle) {
  BITFeedbackListViewCellPresentatationStyleDefault DEPRECATED_MSG_ATTRIBUTE("Use the properly spelled constant `BITFeedbackListViewCellPresentationStyleDefault` instead.") = 0,
  BITFeedbackListViewCellPresentatationStyleOS7 DEPRECATED_MSG_ATTRIBUTE("Use the properly spelled constant `BITFeedbackListViewCellPresentationStyleOS7` instead.") = 1
};

@end
