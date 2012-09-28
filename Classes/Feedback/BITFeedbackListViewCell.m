/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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

#define FRAME_SIDE_BORDER 10
#define FRAME_TOP_BORDER 5
#define FRAME_BOTTOM_BORDER 5

#define LABEL_DATE_Y 0
#define LABEL_DATE_HEIGHT 15

#define LABEL_NAME_Y 15
#define LABEL_NAME_HEIGHT 15

#define LABEL_TEXT_Y 40

@interface BITFeedbackListViewCell ()

@property (nonatomic, retain) NSDateFormatter *dateFormatter;

@property (nonatomic, retain) UILabel *labelDate;
@property (nonatomic, retain) UILabel *labelName;
@property (nonatomic, retain) UILabel *labelText;

@end


@implementation BITFeedbackListViewCell


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    // Initialization code
    self.contentView.backgroundColor = [UIColor whiteColor];
    
    _style = BITFeedbackListViewCellStyleNormal;
    _sent = YES;
    
    _date = nil;
    _name = nil;
    _text = nil;
    
    self.dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [self.dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [self.dateFormatter setLocale:[NSLocale currentLocale]];    
    [self.dateFormatter setDoesRelativeDateFormatting:YES];

    self.labelDate = [[[UILabel alloc] init] autorelease];
    self.labelDate.font = [UIFont systemFontOfSize:12];
    
    self.labelName = [[[UILabel alloc] init] autorelease];
    self.labelName.font = [UIFont systemFontOfSize:12];
    
    self.labelText = [[[UILabel alloc] init] autorelease];
    self.labelText.font = [UIFont systemFontOfSize:14];
    self.labelText.numberOfLines = 0;
    self.labelText.textAlignment = UITextAlignmentLeft;
  }
  return self;
}

- (void)dealloc {
  [_dateFormatter release], _dateFormatter = nil;
  
  [_labelDate release], _labelDate = nil;
  [_labelName release], _labelName = nil;
  [_labelText release], _labelText = nil;
  
  [_date release], _date = nil;
  [_name release], _name = nil;
  [_text release], _text = nil;
  
  [super dealloc];
}


#pragma mark - Layout

+ (CGFloat) heightForRowWithText:(NSString *)text tableViewWidth:(CGFloat)width {
  CGFloat calculatedHeight = [text sizeWithFont:[UIFont systemFontOfSize:14] 
                              constrainedToSize:CGSizeMake(width - (2 * FRAME_SIDE_BORDER), CGFLOAT_MAX)].height + LABEL_TEXT_Y + FRAME_BOTTOM_BORDER;
  return calculatedHeight;
}

- (void)layoutSubviews {
  [super layoutSubviews];
    
  NSString *dateString = [self.dateFormatter stringFromDate:self.date];
  [self.labelDate setText:dateString];// [self.date description]];
  [self.labelDate setFrame:CGRectMake(FRAME_SIDE_BORDER, FRAME_TOP_BORDER + LABEL_DATE_Y, self.frame.size.width - (2 * FRAME_SIDE_BORDER), LABEL_DATE_HEIGHT)];
  
  [self.labelName setText:self.name];
  [self.labelName setFrame:CGRectMake(FRAME_SIDE_BORDER, FRAME_TOP_BORDER + LABEL_NAME_Y, self.frame.size.width - (2 * FRAME_SIDE_BORDER), LABEL_NAME_HEIGHT)];
  // header
  if (_style == BITFeedbackListViewCellStyleNormal) {
    self.contentView.backgroundColor = [UIColor whiteColor];
    self.labelDate.backgroundColor = [UIColor whiteColor];
    self.labelName.backgroundColor = [UIColor whiteColor];
    self.labelText.backgroundColor = [UIColor whiteColor];
    
    self.labelDate.textAlignment = UITextAlignmentLeft;
    self.labelName.textAlignment = UITextAlignmentLeft;
  } else {
    self.contentView.backgroundColor = [UIColor lightGrayColor];
    self.labelDate.backgroundColor = [UIColor lightGrayColor];
    self.labelName.backgroundColor = [UIColor lightGrayColor];
    self.labelText.backgroundColor = [UIColor lightGrayColor];
    
    self.labelDate.textAlignment = UITextAlignmentRight;
    self.labelName.textAlignment = UITextAlignmentRight;
  }

  [self addSubview:self.labelDate];
  [self addSubview:self.labelName];

  // text
  [self.labelText setText:self.text];
  CGSize size = CGSizeMake(self.frame.size.width - (2 * FRAME_SIDE_BORDER),
                           [[self class] heightForRowWithText:self.text tableViewWidth:self.frame.size.width] - LABEL_TEXT_Y - FRAME_BOTTOM_BORDER);
  
  [self.labelText setFrame : CGRectMake(FRAME_SIDE_BORDER, LABEL_TEXT_Y, size.width, size.height)];
  if (self.sent) {
    [self.labelText setTextColor:[UIColor darkTextColor]];
  } else {
    [self.labelText setTextColor:[UIColor lightGrayColor]];
  }
  
  [self addSubview:self.labelText];
}


@end
