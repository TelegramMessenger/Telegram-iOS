//
//  ASTipsWindow.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASViewController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASDisplayNode, ASDisplayNodeTipState;

NS_ASSUME_NONNULL_BEGIN

/**
 * A window that shows tips. This was originally meant to be a view controller
 * but UIKit will not manage view controllers in non-key windows correctly AT ALL
 * as of the time of this writing.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASTipsWindow : UIWindow

/// The main application window that the tips are tracking.
@property (nonatomic, weak) UIWindow *mainWindow;

@property (nonatomic, copy, nullable) NSMapTable<ASDisplayNode *, ASDisplayNodeTipState *> *nodeToTipStates;

@end

NS_ASSUME_NONNULL_END

#endif
