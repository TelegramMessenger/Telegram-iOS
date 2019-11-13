//
//  ASTextKitCoreTextAdditions.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_ENABLE_TEXTNODE

#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 @abstract Returns whether a given attribute is an unsupported Core Text attribute.
 @param attributeName The name of the attribute
 @discussion The following Core Text attributes are not supported on NSAttributedString, and thus will not be preserved during the conversion:
              - kCTForegroundColorFromContextAttributeName
              - kCTSuperscriptAttributeName
              - kCTGlyphInfoAttributeName
              - kCTCharacterShapeAttributeName
              - kCTLanguageAttributeName
              - kCTRunDelegateAttributeName
              - kCTBaselineClassAttributeName
              - kCTBaselineInfoAttributeName
              - kCTBaselineReferenceInfoAttributeName
              - kCTWritingDirectionAttributeName
              - kCTUnderlineColorAttributeName
 @result Whether attributeName is an unsupported Core Text attribute.
 */
AS_EXTERN BOOL ASAttributeWithNameIsUnsupportedCoreTextAttribute(NSString *attributeName);


/**
 @abstract Returns an attributes dictionary for use by NSAttributedString, given a dictionary of Core Text attributes.
 @param coreTextAttributes An NSDictionary whose keys are CFAttributedStringRef attributes.
 @discussion The following Core Text attributes are not supported on NSAttributedString, and thus will not be preserved during the conversion:
              - kCTForegroundColorFromContextAttributeName
              - kCTSuperscriptAttributeName
              - kCTGlyphInfoAttributeName
              - kCTCharacterShapeAttributeName
              - kCTLanguageAttributeName
              - kCTRunDelegateAttributeName
              - kCTBaselineClassAttributeName
              - kCTBaselineInfoAttributeName
              - kCTBaselineReferenceInfoAttributeName
              - kCTWritingDirectionAttributeName
              - kCTUnderlineColorAttributeName
 @result An NSDictionary of attributes for use by NSAttributedString.
 */
AS_EXTERN NSDictionary *NSAttributedStringAttributesForCoreTextAttributes(NSDictionary *coreTextAttributes);

/**
  @abstract Returns an NSAttributedString whose Core Text attributes have been converted, where possible, to NSAttributedString attributes.
  @param dirtyAttributedString An NSAttributedString that may contain Core Text attributes.
  @result An NSAttributedString that's preserved as many CFAttributedString attributes as possible.
 */
AS_EXTERN NSAttributedString *ASCleanseAttributedStringOfCoreTextAttributes(NSAttributedString *dirtyAttributedString);

#pragma mark -
#pragma mark -
@interface NSParagraphStyle (ASTextKitCoreTextAdditions)

/**
  @abstract Returns an NSParagraphStyle initialized with the paragraph specifiers from the given CTParagraphStyleRef.
  @param coreTextParagraphStyle A Core Text paragraph style.
  @discussion It is important to note that not all CTParagraphStyle specifiers are supported by NSParagraphStyle, and consequently, this is a lossy conversion. Notably, the following specifiers will not preserved:
        - kCTParagraphStyleSpecifierTabStops
        - kCTParagraphStyleSpecifierDefaultTabInterval
        - kCTParagraphStyleSpecifierMaximumLineSpacing
        - kCTParagraphStyleSpecifierMinimumLineSpacing
        - kCTParagraphStyleSpecifierLineSpacingAdjustment
        - kCTParagraphStyleSpecifierLineBoundsOptions
  @result An NSParagraphStyle initialized with as many of the paragraph specifiers from `coreTextParagraphStyle` as possible.

 */
+ (NSParagraphStyle *)paragraphStyleWithCTParagraphStyle:(CTParagraphStyleRef)coreTextParagraphStyle NS_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END

#endif
