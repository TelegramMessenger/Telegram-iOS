//
//  ASTextNodeCommon.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASAvailability.h>

@class ASTextNode;

#define AS_TEXT_ALERT_UNIMPLEMENTED_FEATURE() { \
  static dispatch_once_t onceToken; \
  dispatch_once(&onceToken, ^{ \
    NSLog(@"[Texture] Warning: Feature %@ is unimplemented in %@.", NSStringFromSelector(_cmd), NSStringFromClass(self.class)); \
  });\
}

/**
 * Highlight styles.
 */
typedef NS_ENUM(NSUInteger, ASTextNodeHighlightStyle) {
  /**
   * Highlight style for text on a light background.
   */
  ASTextNodeHighlightStyleLight,
  
  /**
   * Highlight style for text on a dark background.
   */
  ASTextNodeHighlightStyleDark
};

/**
 * @abstract Text node delegate.
 */
@protocol ASTextNodeDelegate <NSObject>
@optional

/**
 @abstract Indicates to the delegate that a link was tapped within a text node.
 @param textNode The ASTextNode containing the link that was tapped.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was tapped.
 @param textRange The range of highlighted text.
 */
- (void)textNode:(ASTextNode *)textNode tappedLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point textRange:(NSRange)textRange;

/**
 @abstract Indicates to the delegate that a link was tapped within a text node.
 @param textNode The ASTextNode containing the link that was tapped.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was tapped.
 @param textRange The range of highlighted text.
 @discussion In addition to implementing this method, the delegate must be set on the text
 node before it is loaded (the recognizer is created in -didLoad)
 */
- (void)textNode:(ASTextNode *)textNode longPressedLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point textRange:(NSRange)textRange;

//! @abstract Called when the text node's truncation string has been tapped.
- (void)textNodeTappedTruncationToken:(ASTextNode *)textNode;

/**
 @abstract Indicates to the text node if an attribute should be considered a link.
 @param textNode The text node containing the entity attribute.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was touched to trigger a highlight.
 @discussion If not implemented, the default value is YES.
 @return YES if the entity attribute should be a link, NO otherwise.
 */
- (BOOL)textNode:(ASTextNode *)textNode shouldHighlightLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point;

/**
 @abstract Indicates to the text node if an attribute is a valid long-press target
 @param textNode The text node containing the entity attribute.
 @param attribute The attribute that was tapped. Will not be nil.
 @param value The value of the tapped attribute.
 @param point The point within textNode, in textNode's coordinate system, that was long-pressed.
 @discussion If not implemented, the default value is NO.
 @return YES if the entity attribute should be treated as a long-press target, NO otherwise.
 */
- (BOOL)textNode:(ASTextNode *)textNode shouldLongPressLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point;

@end

