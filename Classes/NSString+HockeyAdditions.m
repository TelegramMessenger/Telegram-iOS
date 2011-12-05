//
//  NSString+HockeyAdditions.m
//
//  Created by Jon Crosby on 10/19/07.
//  Copyright 2007 Kaboomerang LLC. All rights reserved.
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


#import "NSString+HockeyAdditions.h"


@implementation NSString (HockeyAdditions)

- (NSString *)bw_URLEncodedString {
  NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                         (CFStringRef)self,
                                                                         NULL,
                                                                         CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                         kCFStringEncodingUTF8);
  [result autorelease];
  return result;
}

- (NSString*)bw_URLDecodedString {
  NSString *result = (NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                         (CFStringRef)self,
                                                                                         CFSTR(""),
                                                                                         kCFStringEncodingUTF8);
  [result autorelease];
  return result;
}

- (NSComparisonResult)versionCompare:(NSString *)other
{
	// Extract plain version number from self
	NSString *plainSelf = self;
	NSRange letterRange = [plainSelf rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
	if (letterRange.length)
		plainSelf = [plainSelf substringToIndex: letterRange.location];
	
	// Extract plain version number from other
	NSString *plainOther = other;
	letterRange = [plainOther rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
	if (letterRange.length)
		plainOther = [plainOther substringToIndex: letterRange.location];
	
	// Compare plain versions
	NSComparisonResult result = [plainSelf compare:plainOther options:NSNumericSearch];
	
	// If plain versions are equal, compare full versions
	if (result == NSOrderedSame)
		result = [self compare:other options:NSNumericSearch];
	
	// Done
	return result;
}

@end
