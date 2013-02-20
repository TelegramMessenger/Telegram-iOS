/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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


#import "BITFeedbackListViewCell.h"
#import "HockeySDKPrivate.h"

#define BACKGROUNDCOLOR_DEFAULT BIT_RGBCOLOR(245, 245, 245)
#define BACKGROUNDCOLOR_ALTERNATE BIT_RGBCOLOR(235, 235, 235)

#define TEXTCOLOR_TITLE BIT_RGBCOLOR(75, 75, 75)

#define TEXTCOLOR_DEFAULT BIT_RGBCOLOR(25, 25, 25)
#define TEXTCOLOR_PENDING BIT_RGBCOLOR(75, 75, 75)

#define TITLE_FONTSIZE 12
#define TEXT_FONTSIZE 15

#define FRAME_SIDE_BORDER 10
#define FRAME_TOP_BORDER 8
#define FRAME_BOTTOM_BORDER 5
#define FRAME_LEFT_RESPONSE_BORDER 20

#define LABEL_TITLE_Y 3
#define LABEL_TITLE_HEIGHT 15

#define LABEL_TEXT_Y 25

@interface BITFeedbackListViewCell ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;

@property (nonatomic, strong) UILabel *labelTitle;

@end


@implementation BITFeedbackListViewCell


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    // Initialization code
    _backgroundStyle = BITFeedbackListViewCellBackgroundStyleNormal;
    
    _message = nil;
    
    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [self.dateFormatter setLocale:[NSLocale currentLocale]];    
    [self.dateFormatter setDoesRelativeDateFormatting:YES];

    self.timeFormatter = [[NSDateFormatter alloc] init];
    [self.timeFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self.timeFormatter setDateStyle:NSDateFormatterNoStyle];
    [self.timeFormatter setLocale:[NSLocale currentLocale]];
    [self.timeFormatter setDoesRelativeDateFormatting:YES];

    self.labelTitle = [[UILabel alloc] init];
    self.labelTitle.font = [UIFont systemFontOfSize:TITLE_FONTSIZE];
    
    self.labelText = [[BITAttributedLabel alloc] init];
    self.labelText.font = [UIFont systemFontOfSize:TEXT_FONTSIZE];
    self.labelText.numberOfLines = 0;
    self.labelText.textAlignment = kBITTextLabelAlignmentLeft;
    self.labelText.dataDetectorTypes = UIDataDetectorTypeAll;
  }
  return self;
}


#pragma mark - Private

- (BOOL)isSameDayWithDate1:(NSDate*)date1 date2:(NSDate*)date2 {
  NSCalendar* calendar = [NSCalendar currentCalendar];
  
  unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
  NSDateComponents *dateComponent1 = [calendar components:unitFlags fromDate:date1];
  NSDateComponents *dateComponent2 = [calendar components:unitFlags fromDate:date2];
  
  return ([dateComponent1 day] == [dateComponent2 day] &&
          [dateComponent1 month] == [dateComponent2 month] &&
          [dateComponent1 year]  == [dateComponent2 year]);
}


#pragma mark - Layout

+ (CGFloat) heightForRowWithMessage:(BITFeedbackMessage *)message tableViewWidth:(CGFloat)width {
  CGFloat calculatedHeight = [message.text sizeWithFont:[UIFont systemFontOfSize:TEXT_FONTSIZE]
                              constrainedToSize:CGSizeMake(width - (2 * FRAME_SIDE_BORDER), CGFLOAT_MAX)].height + FRAME_TOP_BORDER + LABEL_TEXT_Y + FRAME_BOTTOM_BORDER;
  return calculatedHeight;
}

- (void)layoutSubviews {
  UIView *accessoryViewBackground = [[UIView alloc] initWithFrame:CGRectMake(0, 2, self.frame.size.width * 2, self.frame.size.height - 2)];
  accessoryViewBackground.autoresizingMask = UIViewAutoresizingFlexibleHeight;
  accessoryViewBackground.clipsToBounds = YES;
  
  // colors
  if (_backgroundStyle == BITFeedbackListViewCellBackgroundStyleNormal) {
    accessoryViewBackground.backgroundColor = BACKGROUNDCOLOR_DEFAULT;
    self.contentView.backgroundColor = BACKGROUNDCOLOR_DEFAULT;
    self.labelTitle.backgroundColor = BACKGROUNDCOLOR_DEFAULT;
    self.labelText.backgroundColor = BACKGROUNDCOLOR_DEFAULT;
  } else {
    accessoryViewBackground.backgroundColor = BACKGROUNDCOLOR_ALTERNATE;
    self.contentView.backgroundColor = BACKGROUNDCOLOR_ALTERNATE;
    self.labelTitle.backgroundColor = BACKGROUNDCOLOR_ALTERNATE;
    self.labelText.backgroundColor = BACKGROUNDCOLOR_ALTERNATE;
  }
  self.labelTitle.textColor = TEXTCOLOR_TITLE;
  if (_message.status == BITFeedbackMessageStatusSendPending || _message.status == BITFeedbackMessageStatusSendInProgress) {
    [self.labelText setTextColor:TEXTCOLOR_PENDING];
  } else {
    [self.labelText setTextColor:TEXTCOLOR_DEFAULT];
  }

  // background for deletion accessory view
  [self addSubview:accessoryViewBackground];
  
  // header
  NSString *dateString = @"";
  if (_message.status == BITFeedbackMessageStatusSendPending || _message.status == BITFeedbackMessageStatusSendInProgress) {
    dateString = BITHockeyLocalizedString(@"Pending");
  } else if (_message.date) {
    if ([self isSameDayWithDate1:[NSDate date] date2:_message.date]) {
      dateString = [self.timeFormatter stringFromDate:_message.date];
    } else {
      dateString = [self.dateFormatter stringFromDate:_message.date];
    }
  }
  [self.labelTitle setText:dateString];
  [self.labelTitle setFrame:CGRectMake(FRAME_SIDE_BORDER, FRAME_TOP_BORDER + LABEL_TITLE_Y, self.frame.size.width - (2 * FRAME_SIDE_BORDER), LABEL_TITLE_HEIGHT)];
    
  if (_message.userMessage) {
    self.labelTitle.textAlignment = kBITTextLabelAlignmentRight;
    self.labelText.textAlignment = kBITTextLabelAlignmentRight;
  } else {
    self.labelTitle.textAlignment = kBITTextLabelAlignmentLeft;
    self.labelText.textAlignment = kBITTextLabelAlignmentLeft;
  }

  [self addSubview:self.labelTitle];

  // text
  [self.labelText setText:_message.text];
  CGSize size = CGSizeMake(self.frame.size.width - (2 * FRAME_SIDE_BORDER),
                           [[self class] heightForRowWithMessage:_message tableViewWidth:self.frame.size.width] - LABEL_TEXT_Y - FRAME_BOTTOM_BORDER);
  
  [self.labelText setFrame:CGRectMake(FRAME_SIDE_BORDER, LABEL_TEXT_Y, size.width, size.height)];
  
  [self addSubview:self.labelText];
  
  [super layoutSubviews];
}


@end
