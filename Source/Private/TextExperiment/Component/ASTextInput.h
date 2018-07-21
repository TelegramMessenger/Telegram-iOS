//
//  ASTextInput.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) through the present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Text position affinity. For example, the offset appears after the last
 character on a line is backward affinity, before the first character on
 the following line is forward affinity.
 */
typedef NS_ENUM(NSInteger, ASTextAffinity) {
  ASTextAffinityForward  = 0, ///< offset appears before the character
  ASTextAffinityBackward = 1, ///< offset appears after the character
};


/**
 A ASTextPosition object represents a position in a text container; in other words,
 it is an index into the backing string in a text-displaying view.
 
 ASTextPosition has the same API as Apple's implementation in UITextView/UITextField,
 so you can alse use it to interact with UITextView/UITextField.
 */
@interface ASTextPosition : UITextPosition <NSCopying>

@property (nonatomic, readonly) NSInteger offset;
@property (nonatomic, readonly) ASTextAffinity affinity;

+ (instancetype)positionWithOffset:(NSInteger)offset NS_RETURNS_RETAINED;
+ (instancetype)positionWithOffset:(NSInteger)offset affinity:(ASTextAffinity) affinity NS_RETURNS_RETAINED;

- (NSComparisonResult)compare:(id)otherPosition;

@end


/**
 A ASTextRange object represents a range of characters in a text container; in other words,
 it identifies a starting index and an ending index in string backing a text-displaying view.
 
 ASTextRange has the same API as Apple's implementation in UITextView/UITextField,
 so you can alse use it to interact with UITextView/UITextField.
 */
@interface ASTextRange : UITextRange <NSCopying>

@property (nonatomic, readonly) ASTextPosition *start;
@property (nonatomic, readonly) ASTextPosition *end;
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

+ (instancetype)rangeWithRange:(NSRange)range NS_RETURNS_RETAINED;
+ (instancetype)rangeWithRange:(NSRange)range affinity:(ASTextAffinity) affinity NS_RETURNS_RETAINED;
+ (instancetype)rangeWithStart:(ASTextPosition *)start end:(ASTextPosition *)end NS_RETURNS_RETAINED;
+ (instancetype)defaultRange NS_RETURNS_RETAINED; ///< <{0,0} Forward>

- (NSRange)asRange;

@end


/**
 A ASTextSelectionRect object encapsulates information about a selected range of
 text in a text-displaying view.
 
 ASTextSelectionRect has the same API as Apple's implementation in UITextView/UITextField,
 so you can alse use it to interact with UITextView/UITextField.
 */
@interface ASTextSelectionRect : UITextSelectionRect <NSCopying>

@property (nonatomic) CGRect rect;
@property (nonatomic) UITextWritingDirection writingDirection;
@property (nonatomic) BOOL containsStart;
@property (nonatomic) BOOL containsEnd;
@property (nonatomic) BOOL isVertical;

@end

NS_ASSUME_NONNULL_END
