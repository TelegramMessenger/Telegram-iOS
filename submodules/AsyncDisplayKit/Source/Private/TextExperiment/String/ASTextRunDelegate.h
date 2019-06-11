//
//  ASTextRunDelegate.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Wrapper for CTRunDelegateRef.
 
 Example:
 
 ASTextRunDelegate *delegate = [ASTextRunDelegate new];
 delegate.ascent = 20;
 delegate.descent = 4;
 delegate.width = 20;
 CTRunDelegateRef ctRunDelegate = delegate.CTRunDelegate;
 if (ctRunDelegate) {
   /// add to attributed string
   CFRelease(ctRunDelegate);
 }
 
 */
@interface ASTextRunDelegate : NSObject <NSCopying, NSCoding>

/**
 Creates and returns the CTRunDelegate.
 
 @discussion You need call CFRelease() after used.
 The CTRunDelegateRef has a strong reference to this ASTextRunDelegate object.
 In CoreText, use CTRunDelegateGetRefCon() to get this ASTextRunDelegate object.
 
 @return The CTRunDelegate object.
 */
- (nullable CTRunDelegateRef)CTRunDelegate CF_RETURNS_RETAINED;

/**
 Additional information about the the run delegate.
 */
@property (nullable, nonatomic) NSDictionary *userInfo;

/**
 The typographic ascent of glyphs in the run.
 */
@property (nonatomic) CGFloat ascent;

/**
 The typographic descent of glyphs in the run.
 */
@property (nonatomic) CGFloat descent;

/**
 The typographic width of glyphs in the run.
 */
@property (nonatomic) CGFloat width;

@end

NS_ASSUME_NONNULL_END
