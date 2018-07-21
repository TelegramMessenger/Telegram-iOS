//
//  ASTextNode.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASTextNodeCommon.h>

NS_ASSUME_NONNULL_BEGIN

/**
 @abstract Draws interactive rich text.
 @discussion Backed by TextKit.
 */
@interface ASTextNode : ASControlNode

/**
 @abstract The styled text displayed by the node.
 @discussion Defaults to nil, no text is shown.
 For inline image attachments, add an attribute of key NSAttachmentAttributeName, with a value of an NSTextAttachment.
 */
@property (nullable, copy) NSAttributedString *attributedText;

#pragma mark - Truncation

/**
 @abstract The attributedText to use when the text must be truncated.
 @discussion Defaults to a localized ellipsis character.
 */
@property (nullable, copy) NSAttributedString *truncationAttributedText;

/**
 @summary The second attributed string appended for truncation.
 @discussion This string will be highlighted on touches.
 @default nil
 */
@property (nullable, copy) NSAttributedString *additionalTruncationMessage;

/**
 @abstract Determines how the text is truncated to fit within the receiver's maximum size.
 @discussion Defaults to NSLineBreakByWordWrapping.
 @note Setting a truncationMode in attributedString will override the truncation mode set here.
 */
@property NSLineBreakMode truncationMode;

/**
 @abstract If the text node is truncated. Text must have been sized first.
 */
@property (readonly, getter=isTruncated) BOOL truncated;

/**
 @abstract The maximum number of lines to render of the text before truncation.
 @default 0 (No limit)
 */
@property NSUInteger maximumNumberOfLines;

/**
 @abstract The number of lines in the text. Text must have been sized first.
 */
@property (readonly) NSUInteger lineCount;

/**
 * An array of path objects representing the regions where text should not be displayed.
 *
 * @discussion The default value of this property is an empty array. You can
 * assign an array of UIBezierPath objects to exclude text from one or more regions in
 * the text node's bounds. You can use this property to have text wrap around images,
 * shapes or other text like a fancy magazine.
 */
@property (nullable, copy) NSArray<UIBezierPath *> *exclusionPaths;

#pragma mark - Placeholders

/**
 * @abstract ASTextNode has a special placeholder behavior when placeholderEnabled is YES.
 *
 * @discussion Defaults to NO.  When YES, it draws rectangles for each line of text,
 * following the true shape of the text's wrapping.  This visually mirrors the overall
 * shape and weight of paragraphs, making the appearance of the finished text less jarring.
 */
@property BOOL placeholderEnabled;

/**
 @abstract The placeholder color.
 */
@property (nullable, copy) UIColor *placeholderColor;

/**
 @abstract Inset each line of the placeholder.
 */
@property UIEdgeInsets placeholderInsets;

#pragma mark - Shadow

/**
 @abstract When you set these ASDisplayNode properties, they are composited into the bitmap instead of being applied by CA.

 @property (nonatomic) CGColorRef shadowColor;
 @property (nonatomic) CGFloat    shadowOpacity;
 @property (nonatomic) CGSize     shadowOffset;
 @property (nonatomic) CGFloat    shadowRadius;
 */

/**
 @abstract The number of pixels used for shadow padding on each side of the receiver.
 @discussion Each inset will be less than or equal to zero, so that applying
 UIEdgeInsetsRect(boundingRectForText, shadowPadding)
 will return a CGRect large enough to fit both the text and the appropriate shadow padding.
 */
@property (readonly) UIEdgeInsets shadowPadding;

#pragma mark - Positioning

/**
 @abstract Returns an array of rects bounding the characters in a given text range.
 @param textRange A range of text. Must be valid for the receiver's string.
 @discussion Use this method to detect all the different rectangles a given range of text occupies.
 The rects returned are not guaranteed to be contiguous (for example, if the given text range spans
 a line break, the rects returned will be on opposite sides and different lines). The rects returned
 are in the coordinate system of the receiver.
 */
- (NSArray<NSValue *> *)rectsForTextRange:(NSRange)textRange AS_WARN_UNUSED_RESULT;

/**
 @abstract Returns an array of rects used for highlighting the characters in a given text range.
 @param textRange A range of text. Must be valid for the receiver's string.
 @discussion Use this method to detect all the different rectangles the highlights of a given range of text occupies.
 The rects returned are not guaranteed to be contiguous (for example, if the given text range spans
 a line break, the rects returned will be on opposite sides and different lines). The rects returned
 are in the coordinate system of the receiver. This method is useful for visual coordination with a
 highlighted range of text.
 */
- (NSArray<NSValue *> *)highlightRectsForTextRange:(NSRange)textRange AS_WARN_UNUSED_RESULT;

/**
 @abstract Returns a bounding rect for the given text range.
 @param textRange A range of text. Must be valid for the receiver's string.
 @discussion The height of the frame returned is that of the receiver's line-height; adjustment for
 cap-height and descenders is not performed. This method raises an exception if textRange is not
 a valid substring range of the receiver's string.
 */
- (CGRect)frameForTextRange:(NSRange)textRange AS_WARN_UNUSED_RESULT;

/**
 @abstract Returns the trailing rectangle of space in the receiver, after the final character.
 @discussion Use this method to detect which portion of the receiver is not occupied by characters.
 The rect returned is in the coordinate system of the receiver.
 */
- (CGRect)trailingRect AS_WARN_UNUSED_RESULT;


#pragma mark - Actions

/**
 @abstract The set of attribute names to consider links.  Defaults to NSLinkAttributeName.
 */
@property (copy) NSArray<NSString *> *linkAttributeNames;

/**
 @abstract Indicates whether the receiver has an entity at a given point.
 @param point The point, in the receiver's coordinate system.
 @param attributeNameOut The name of the attribute at the point. Can be NULL.
 @param rangeOut The ultimate range of the found text. Can be NULL.
 @result YES if an entity exists at `point`; NO otherwise.
 */
- (nullable id)linkAttributeValueAtPoint:(CGPoint)point attributeName:(out NSString * _Nullable * _Nullable)attributeNameOut range:(out NSRange * _Nullable)rangeOut AS_WARN_UNUSED_RESULT;

/**
 @abstract The style to use when highlighting text.
 */
@property ASTextNodeHighlightStyle highlightStyle;

/**
 @abstract The range of text highlighted by the receiver. Changes to this property are not animated by default.
 */
@property NSRange highlightRange;

/**
 @abstract Set the range of text to highlight, with optional animation.

 @param highlightRange The range of text to highlight.

 @param animated Whether the text should be highlighted with an animation.
 */
- (void)setHighlightRange:(NSRange)highlightRange animated:(BOOL)animated;

/**
 @abstract Responds to actions from links in the text node.
 @discussion The delegate must be set before the node is loaded, and implement
             textNode:longPressedLinkAttribute:value:atPoint:textRange: in order for
             the long press gesture recognizer to be installed.
 */
@property (nullable, weak) id<ASTextNodeDelegate> delegate;

/**
 @abstract If YES and a long press is recognized, touches are cancelled. Default is NO
 */
@property (nonatomic) BOOL longPressCancelsTouches;

/**
 @abstract if YES will not intercept touches for non-link areas of the text. Default is NO.
 */
@property (nonatomic) BOOL passthroughNonlinkTouches;

@end

@interface ASTextNode (Unavailable)

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock NS_UNAVAILABLE;

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock NS_UNAVAILABLE;

@end

/**
 * @abstract Text node deprecated properties
 */
@interface ASTextNode (Deprecated)

/**
 The attributedString and attributedText properties are equivalent, but attributedText is now the standard API
 name in order to match UILabel and ASEditableTextNode.
 
 @see attributedText
 */
@property (nullable, copy) NSAttributedString *attributedString ASDISPLAYNODE_DEPRECATED_MSG("Use .attributedText instead.");


/**
 The truncationAttributedString and truncationAttributedText properties are equivalent, but truncationAttributedText is now the
 standard API name in order to match UILabel and ASEditableTextNode.
 
 @see truncationAttributedText
 */
@property (nullable, copy) NSAttributedString *truncationAttributedString ASDISPLAYNODE_DEPRECATED_MSG("Use .truncationAttributedText instead.");

@end

NS_ASSUME_NONNULL_END
