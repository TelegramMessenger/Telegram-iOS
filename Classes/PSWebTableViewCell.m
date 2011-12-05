//
//  PSWebTableViewCell.m
//  HockeyDemo
//
//  Created by Peter Steinberger on 04.02.11.
//  Copyright 2011 Peter Steinberger. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "PSWebTableViewCell.h"
#import "BWGlobal.h"

@implementation PSWebTableViewCell

static NSString* PSWebTableViewCellHtmlTemplate = @"\
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\
<html xmlns=\"http://www.w3.org/1999/xhtml\">\
<head>\
<style type=\"text/css\">\
body { font: 13px 'Helvetica Neue', Helvetica; word-wrap:break-word; padding:8px;} p {margin:0;} ul {padding-left: 18px;}\
</style>\
<meta name=\"viewport\" content=\"user-scalable=no width=%@\" /></head>\
<body>\
%@\
</body>\
</html>\
";

@synthesize webView = webView_;
@synthesize webViewContent = webViewContent_;
@synthesize webViewSize = webViewSize_;
@synthesize cellBackgroundColor = cellBackgroundColor_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark private

- (void)addWebView {
	if(webViewContent_) {
    CGRect webViewRect = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
		if(!webView_) {
			webView_ = [[[UIWebView alloc] initWithFrame:webViewRect] retain];
			[self addSubview:webView_];
			webView_.hidden = YES;
			webView_.backgroundColor = self.cellBackgroundColor;
			webView_.opaque = NO;
			webView_.delegate = self;
      webView_.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      
      for(UIView* subView in webView_.subviews){
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
			webView_.frame = webViewRect;
    
    NSString *deviceWidth = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? [NSString stringWithFormat:@"%d", CGRectGetWidth(self.bounds)] : @"device-width";
    //BWHockeyLog(@"%@\n%@\%@", PSWebTableViewCellHtmlTemplate, deviceWidth, self.webViewContent);
    NSString *contentHtml = [NSString stringWithFormat:PSWebTableViewCellHtmlTemplate, deviceWidth, self.webViewContent];
		[webView_ loadHTMLString:contentHtml baseURL:nil];
	}
}

- (void)showWebView {
	webView_.hidden = NO;
  self.textLabel.text = @"";
	[self setNeedsDisplay];
}


- (void)removeWebView {
	if(webView_) {
		webView_.delegate = nil;
		[webView_ resignFirstResponder];
		[webView_ removeFromSuperview];
		[webView_ release];
	}
	webView_ = nil;
	[self setNeedsDisplay];
}


- (void)setWebViewContent:(NSString *)aWebViewContent {
  if (webViewContent_ != aWebViewContent) {
    [webViewContent_ release];
    webViewContent_ = [aWebViewContent retain];
    
    // add basic accessiblity (prevents "snarfed from ivar layout") logs
    self.accessibilityLabel = aWebViewContent;
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
    self.cellBackgroundColor = [UIColor clearColor];
  }
  return self;
}

- (void)dealloc {
  [self removeWebView];
  [webViewContent_ release];
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIView

- (void)setFrame:(CGRect)aFrame {
  BOOL needChange = !CGRectEqualToRect(aFrame, self.frame);
  [super setFrame:aFrame];
  
  if (needChange) {
    [self addWebView];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITableViewCell

- (void)prepareForReuse {
	[self removeWebView];
  self.webViewContent = nil;
	[super prepareForReuse];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIWebView

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	if(navigationType == UIWebViewNavigationTypeOther)
		return YES;
  
  return NO;
}


- (void)webViewDidFinishLoad:(UIWebView *)webView {
	if(webViewContent_)
    [self showWebView];
  
  CGRect frame = webView_.frame;
  frame.size.height = 1;
  webView_.frame = frame;
  CGSize fittingSize = [webView_ sizeThatFits:CGSizeZero];
  frame.size = fittingSize;
  webView_.frame = frame;
  
  // sizeThatFits is not reliable - use javascript for optimal height
  NSString *output = [webView_ stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"];
  self.webViewSize = CGSizeMake(fittingSize.width, [output integerValue]);
}

@end
