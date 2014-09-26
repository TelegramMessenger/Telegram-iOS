/*
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

#import "BITActivityIndicatorButton.h"

@interface BITActivityIndicatorButton()

@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic) BOOL indicatorVisible;

@end

@implementation BITActivityIndicatorButton

- (void)setShowsActivityIndicator:(BOOL)showsIndicator {
  if (self.indicatorVisible == showsIndicator){
    return;
  }
  
  if (!self.indicator){
    self.indicator = [[UIActivityIndicatorView alloc] initWithFrame:self.bounds];
    [self addSubview:self.indicator];
    [self.indicator setColor:[UIColor blackColor]];
  }
  
  self.indicatorVisible = showsIndicator;
  
  if (showsIndicator){
    [self.indicator startAnimating];
    self.indicator.alpha = 1;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.layer.cornerRadius = 5;
    self.imageView.image = nil;
  } else {
    [self.indicator stopAnimating];
    self.layer.cornerRadius = 0;
    self.indicator.alpha = 0;
    self.layer.borderWidth = 0;

  }
  
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  [self.indicator setFrame:self.bounds];
  
}


@end
