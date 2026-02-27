//
//  UIView+ASConvenience.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


/**
 These are the properties we support from CALayer (implemented in the pending state)
 */

@protocol ASDisplayProperties <NSObject>

@property (nonatomic) CGPoint position;
@property (nonatomic) CGFloat zPosition;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic) CGFloat cornerRadius;
@property (nullable, nonatomic) id contents;
@property (nonatomic, copy)   NSString *contentsGravity;
@property (nonatomic) CGRect contentsRect;
@property (nonatomic) CGRect contentsCenter;
@property (nonatomic) CGFloat contentsScale;
@property (nonatomic) CGFloat rasterizationScale;
@property (nonatomic) CATransform3D transform;
@property (nonatomic) CATransform3D sublayerTransform;
@property (nonatomic) BOOL needsDisplayOnBoundsChange;
@property (nonatomic) __attribute__((NSObject)) CGColorRef shadowColor;
@property (nonatomic) CGFloat shadowOpacity;
@property (nonatomic) CGSize shadowOffset;
@property (nonatomic) CGFloat shadowRadius;
@property (nonatomic) CGFloat borderWidth;
@property (nonatomic, getter = isOpaque) BOOL opaque;
@property (nonatomic) __attribute__((NSObject)) CGColorRef borderColor;
@property (nonatomic) __attribute__((NSObject)) CGColorRef backgroundColor;
@property (nonatomic) BOOL allowsGroupOpacity;
@property (nonatomic) BOOL allowsEdgeAntialiasing;
@property (nonatomic) unsigned int edgeAntialiasingMask;

- (void)setNeedsDisplay;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;

@end

/**
 These are all of the "good" properties of the UIView API that we support in pendingViewState or view of an ASDisplayNode.
 */
@protocol ASDisplayNodeViewProperties

@property (nonatomic)          BOOL clipsToBounds;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic)          BOOL autoresizesSubviews;
@property (nonatomic)          UIViewAutoresizing autoresizingMask;
@property (nonatomic, null_resettable) UIColor *tintColor;
@property (nonatomic)          CGFloat alpha;
@property (nonatomic)          CGRect bounds;
@property (nonatomic)          CGRect frame;   // Only for use with nodes wrapping synchronous views
@property (nonatomic)          UIViewContentMode contentMode;
@property (nonatomic)          UISemanticContentAttribute semanticContentAttribute API_AVAILABLE(ios(9.0), tvos(9.0));
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, getter=isExclusiveTouch) BOOL exclusiveTouch;
@property (nonatomic, getter=asyncdisplaykit_isAsyncTransactionContainer, setter = asyncdisplaykit_setAsyncTransactionContainer:) BOOL asyncdisplaykit_asyncTransactionContainer;
@property (nonatomic)           UIEdgeInsets layoutMargins;
@property (nonatomic)           BOOL preservesSuperviewLayoutMargins;
@property (nonatomic)           BOOL insetsLayoutMarginsFromSafeArea;

/**
 Following properties of the UIAccessibility informal protocol are supported as well.
 We don't declare them here, so _ASPendingState does not complain about them being not implemented,
 as they are already on NSObject

 @property (nonatomic)           BOOL isAccessibilityElement;
 @property (nonatomic, copy, nullable)   NSString *accessibilityLabel;
 @property (nonatomic, copy, nullable)   NSAttributedString *accessibilityAttributedLabel API_AVAILABLE(ios(11.0),tvos(11.0));
 @property (nonatomic, copy, nullable)   NSString *accessibilityHint;
 @property (nonatomic, copy, nullable)   NSAttributedString *accessibilityAttributedHint API_AVAILABLE(ios(11.0),tvos(11.0));
 @property (nonatomic, copy, nullable)   NSString *accessibilityValue;
 @property (nonatomic, copy, nullable)   NSAttributedString *accessibilityAttributedValue API_AVAILABLE(ios(11.0),tvos(11.0));
 @property (nonatomic)           UIAccessibilityTraits accessibilityTraits;
 @property (nonatomic)           CGRect accessibilityFrame;
 @property (nonatomic, nullable) NSString *accessibilityLanguage;
 @property (nonatomic)           BOOL accessibilityElementsHidden;
 @property (nonatomic)           BOOL accessibilityViewIsModal;
 @property (nonatomic)           BOOL shouldGroupAccessibilityChildren;
 */

// Accessibility identification support
@property (nullable, nonatomic, copy)          NSString *accessibilityIdentifier;

@end

NS_ASSUME_NONNULL_END
