//
//  ASTextNodeWordKerner.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/NSLayoutManager.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
  @abstract This class acts as the NSLayoutManagerDelegate for ASTextNode.
  @discussion Its current job is word kerning, i.e. adjusting the width of spaces to match the set
    wordKernedSpaceWidth. If word kerning is not needed, set the layoutManager's delegate to nil.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASTextNodeWordKerner : NSObject <NSLayoutManagerDelegate>

/**
  The following @optional NSLayoutManagerDelegate methods are implemented:

- (NSUInteger)layoutManager:(NSLayoutManager *)layoutManager shouldGenerateGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props characterIndexes:(const NSUInteger *)charIndexes font:(UIFont *)aFont forGlyphRange:(NSRange)glyphRange NS_AVAILABLE_IOS(7_0);

- (NSControlCharacterAction)layoutManager:(NSLayoutManager *)layoutManager shouldUseAction:(NSControlCharacterAction)action forControlCharacterAtIndex:(NSUInteger)charIndex NS_AVAILABLE_IOS(7_0);

- (CGRect)layoutManager:(NSLayoutManager *)layoutManager boundingBoxForControlGlyphAtIndex:(NSUInteger)glyphIndex forTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)proposedRect glyphPosition:(CGPoint)glyphPosition characterIndex:(NSUInteger)charIndex NS_AVAILABLE_IOS(7_0);
 */

@end

NS_ASSUME_NONNULL_END
