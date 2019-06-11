//
//  ASTextKitTruncating.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_ENABLE_TEXTNODE

#import <AsyncDisplayKit/ASBaseDefines.h>

#import <vector>

NS_ASSUME_NONNULL_BEGIN

@class ASTextKitContext;

@protocol ASTextKitTruncating <NSObject>

/**
 The character range from the original attributedString that is displayed by the renderer given the parameters in the
 initializer.
 */
@property (nonatomic, readonly) std::vector<NSRange> visibleRanges;

/**
 Returns the first visible range or an NSRange with location of NSNotFound and size of 0 if no first visible
 range exists
 */
@property (nonatomic, readonly) NSRange firstVisibleRange;

/**
 A truncater object is initialized with the full state of the text.  It is a Single Responsibility Object that is
 mutative.  It configures the state of the TextKit components (layout manager, text container, text storage) to achieve
 the intended truncation, then it stores the resulting state for later fetching.

 The truncater may mutate the state of the text storage such that only the drawn string is actually present in the
 text storage itself.

 The truncater should not store a strong reference to the context to prevent retain cycles.
 */
- (instancetype)initWithContext:(ASTextKitContext *)context
     truncationAttributedString:(NSAttributedString * _Nullable)truncationAttributedString
         avoidTailTruncationSet:(NSCharacterSet * _Nullable)avoidTailTruncationSet;

/**
 Actually do the truncation.
 */
- (void)truncate;

@end

NS_ASSUME_NONNULL_END

#endif
