//
//  ASTipNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASTip;

NS_ASSUME_NONNULL_BEGIN

/**
 * ASTipNode will send these up the responder chain.
 */
@protocol ASTipNodeActions <NSObject>
- (void)didTapTipNode:(id)sender;
@end

AS_SUBCLASSING_RESTRICTED
@interface ASTipNode : ASControlNode

- (instancetype)initWithTip:(ASTip *)tip NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) ASTip *tip;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
