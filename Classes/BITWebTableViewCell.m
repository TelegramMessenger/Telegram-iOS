/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011-2012 Peter Steinberger.
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

#import "BITWebTableViewCell.h"


@implementation BITWebTableViewCell

static NSString* BITWebTableViewCellHtmlTemplate = @"\
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\
<html xmlns=\"http://www.w3.org/1999/xhtml\">\
<head>\
<style type=\"text/css\">\
body { font: 13px 'Helvetica Neue', Helvetica; color:#626262; word-wrap:break-word; padding:8px;} ul {padding-left: 18px;}\
</style>\
<meta name=\"viewport\" content=\"user-scalable=no width=%@\" /></head>\
<body>\
%@\
</body>\
</html>\
";


#pragma mark - private

- (void)addWebView {
  if(_webViewContent) {
    CGRect webViewRect = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    if(!_webView) {
      _webView = [[UIWebView alloc] initWithFrame:webViewRect];
      [self addSubview:_webView];
      _webView.hidden = YES;
      _webView.backgroundColor = self.cellBackgroundColor;
      _webView.opaque = NO;
      _webView.delegate = self;
      _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      
      for(UIView* subView in _webView.subviews){
        if([subView isKindOfClass:[UIScrollView class]]){
          // disable scrolling
          UIScrollView *sv = (UIScrollView *)subView;
          sv.scrollEnabled = NO;
          sv.bounces = NO;
          
          // hide shadow
          for (UIView* shadowView in [subView subviews]) {
            if ([shadowView isKindOfClass:[UIImageView class]]) {
              shadowView.hidden = YES;
            }
          }
        }
      }
    }
    else
      _webView.frame = webViewRect;
    
    NSString *deviceWidth = [NSString stringWithFormat:@"%.0f", CGRectGetWidth(self.bounds)];
    
    //HockeySDKLog(@"%@\n%@\%@", PSWebTableViewCellHtmlTemplate, deviceWidth, self.webViewContent);
    NSString *contentHtml = [NSString stringWithFormat:BITWebTableViewCellHtmlTemplate, deviceWidth, self.webViewContent];
    [_webView loadHTMLString:contentHtml baseURL:nil];
  }
}

- (void)showWebView {
  _webView.hidden = NO;
  self.textLabel.text = @"";
  [self setNeedsDisplay];
}


- (void)removeWebView {
  if(_webView) {
    _webView.delegate = nil;
    [_webView resignFirstResponder];
    [_webView removeFromSuperview];
  }
  _webView = nil;
  [self setNeedsDisplay];
}


- (void)setWebViewContent:(NSString *)aWebViewContent {
  if (_webViewContent != aWebViewContent) {
    _webViewContent = aWebViewContent;
    
    // add basic accessibility (prevents "snarfed from ivar layout") logs
    self.accessibilityLabel = aWebViewContent;
  }
}


#pragma mark - NSObject

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
    self.cellBackgroundColor = [UIColor clearColor];
  }
  return self;
}

- (void)dealloc {
  [self removeWebView];
}


#pragma mark - UIView

- (void)setFrame:(CGRect)aFrame {
  BOOL needChange = !CGRectEqualToRect(aFrame, self.frame);
  [super setFrame:aFrame];
  
  if (needChange) {
    [self addWebView];
  }
}


#pragma mark - UITableViewCell

- (void)prepareForReuse {
	[self removeWebView];
  self.webViewContent = nil;
	[super prepareForReuse];
}


#pragma mark - UIWebView

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
  if(navigationType == UIWebViewNavigationTypeOther)
    return YES;
  
  return NO;
}


- (void)webViewDidFinishLoad:(UIWebView *)webView {
  if(_webViewContent)
    [self showWebView];
  
  CGRect frame = _webView.frame;
  frame.size.height = 1;
  _webView.frame = frame;
  CGSize fittingSize = [_webView sizeThatFits:CGSizeZero];
  frame.size = fittingSize;
  _webView.frame = frame;
  
  // sizeThatFits is not reliable - use javascript for optimal height
  NSString *output = [_webView stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"];
  self.webViewSize = CGSizeMake(fittingSize.width, [output integerValue]);
}

@end
