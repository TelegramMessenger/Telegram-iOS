//
//  ASTextKitComponents.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASTextKitComponentsTextView : UITextView
- (instancetype)initWithFrame:(CGRect)frame textContainer:(nullable NSTextContainer *)textContainer NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder __unavailable;
- (instancetype)init __unavailable;
@end

AS_SUBCLASSING_RESTRICTED
@interface ASTextKitComponents : NSObject

/**
 @abstract Creates the stack of TextKit components.
 @param attributedSeedString The attributed string to seed the returned text storage with, or nil to receive an blank text storage.
 @param textContainerSize The size of the text-container. Typically, size specifies the constraining width of the layout, and CGFLOAT_MAX for height. Pass CGSizeZero if these components will be hooked up to a UITextView, which will manage the text container's size itself.
 @return An `ASTextKitComponents` containing the created components. The text view component will be nil.
 @discussion The returned components will be hooked up together, so they are ready for use as a system upon return.
 */
+ (instancetype)componentsWithAttributedSeedString:(nullable NSAttributedString *)attributedSeedString
                                 textContainerSize:(CGSize)textContainerSize NS_RETURNS_RETAINED;

/**
 @abstract Creates the stack of TextKit components.
 @param textStorage The NSTextStorage to use.
 @param textContainerSize The size of the text-container. Typically, size specifies the constraining width of the layout, and CGFLOAT_MAX for height. Pass CGSizeZero if these components will be hooked up to a UITextView, which will manage the text container's size itself.
 @param layoutManager The NSLayoutManager to use.
 @return An `ASTextKitComponents` containing the created components. The text view component will be nil.
 @discussion The returned components will be hooked up together, so they are ready for use as a system upon return.
 */
+ (instancetype)componentsWithTextStorage:(NSTextStorage *)textStorage
                        textContainerSize:(CGSize)textContainerSize
                            layoutManager:(NSLayoutManager *)layoutManager NS_RETURNS_RETAINED;

/**
 @abstract Returns the bounding size for the text view's text.
 @param constrainedWidth The constraining width to be used during text-sizing. Usually, this value should be the receiver's calculated size.
 @result A CGSize representing the bounding size for the receiver's text.
 */
- (CGSize)sizeForConstrainedWidth:(CGFloat)constrainedWidth;

- (CGSize)sizeForConstrainedWidth:(CGFloat)constrainedWidth
              forMaxNumberOfLines:(NSInteger)numberOfLines;

@property (nonatomic, readonly) NSTextStorage *textStorage;
@property (nonatomic, readonly) NSTextContainer *textContainer;
@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, nullable) ASTextKitComponentsTextView *textView;

@end

NS_ASSUME_NONNULL_END
