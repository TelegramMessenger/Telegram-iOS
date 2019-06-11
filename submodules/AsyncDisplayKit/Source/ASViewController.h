//
//  ASViewController.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASVisibilityProtocols.h>

@class ASTraitCollection;

NS_ASSUME_NONNULL_BEGIN

typedef ASTraitCollection * _Nonnull (^ASDisplayTraitsForTraitCollectionBlock)(UITraitCollection *traitCollection);
typedef ASTraitCollection * _Nonnull (^ASDisplayTraitsForTraitWindowSizeBlock)(CGSize windowSize);

/**
 * ASViewController allows you to have a completely node backed hierarchy. It automatically
 * handles @c ASVisibilityDepth, automatic range mode and propogating @c ASDisplayTraits to contained nodes.
 *
 * You can opt-out of node backed hierarchy and use it like a normal UIViewController.
 * More importantly, you can use it as a base class for all of your view controllers among which some use a node hierarchy and some don't.
 * See examples/ASDKgram project for actual implementation.
 */
@interface ASViewController<__covariant DisplayNodeType : ASDisplayNode *> : UIViewController <ASVisibilityDepth>

/**
 * ASViewController initializer.
 *
 * @param node An ASDisplayNode which will provide the root view (self.view)
 * @return An ASViewController instance whose root view will be backed by the provided ASDisplayNode.
 *
 * @see ASVisibilityDepth
 */
- (instancetype)initWithNode:(DisplayNodeType)node NS_DESIGNATED_INITIALIZER;

NS_ASSUME_NONNULL_END

/**
 * @return node Returns the ASDisplayNode which provides the backing view to the view controller.
 */
@property (nonatomic, readonly, null_unspecified) DisplayNodeType node;

NS_ASSUME_NONNULL_BEGIN

/**
 * Set this block to customize the ASDisplayTraits returned when the VC transitions to the given traitCollection.
 */
@property (nonatomic, copy) ASDisplayTraitsForTraitCollectionBlock overrideDisplayTraitsWithTraitCollection;

/**
 * Set this block to customize the ASDisplayTraits returned when the VC transitions to the given window size.
 */
@property (nonatomic, copy) ASDisplayTraitsForTraitWindowSizeBlock overrideDisplayTraitsWithWindowSize ASDISPLAYNODE_DEPRECATED_MSG("This property is actually never accessed inside the framework");

/**
 * @abstract Passthrough property to the the .interfaceState of the node.
 * @return The current ASInterfaceState of the node, indicating whether it is visible and other situational properties.
 * @see ASInterfaceState
 */
@property (nonatomic, readonly) ASInterfaceState interfaceState;


// AsyncDisplayKit 2.0 BETA: This property is still being tested, but it allows
// blocking as a view controller becomes visible to ensure no placeholders flash onscreen.
// Refer to examples/SynchronousConcurrency, AsyncViewController.m
@property (nonatomic) BOOL neverShowPlaceholders;

/* Custom container UIViewController subclasses can use this property to add to the overlay
 that UIViewController calculates for the safeAreaInsets for contained view controllers.
 */
@property(nonatomic) UIEdgeInsets additionalSafeAreaInsets;

@end

@interface ASViewController (ASRangeControllerUpdateRangeProtocol)

/**
 * Automatically adjust range mode based on view events. If you set this to YES, the view controller or its node
 * must conform to the ASRangeControllerUpdateRangeProtocol. 
 *
 * Default value is YES *if* node or view controller conform to ASRangeControllerUpdateRangeProtocol otherwise it is NO.
 */
@property (nonatomic) BOOL automaticallyAdjustRangeModeBasedOnViewEvents;

@end

NS_ASSUME_NONNULL_END

#endif
