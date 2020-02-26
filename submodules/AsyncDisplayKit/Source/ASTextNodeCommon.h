//
//  ASTextNodeCommon.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASAvailability.h>

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

