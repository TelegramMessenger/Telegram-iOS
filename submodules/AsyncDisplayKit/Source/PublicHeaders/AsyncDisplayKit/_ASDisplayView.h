//
//  _ASDisplayView.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// This class is only for use by ASDisplayNode and should never be subclassed or used directly.
// Note that the "node" property is added to UIView directly via a category in ASDisplayNode.

@class ASDisplayNode;

@interface _ASDisplayView : UIView

/**
 @discussion This property overrides the UIView category method which implements this via associated objects.
 This should result in much better performance for _ASDisplayView.
 */
@property (nullable, nonatomic, weak) ASDisplayNode *asyncdisplaykit_node;

// These methods expose a way for ASDisplayNode touch events to let the view call super touch events
// Some UIKit mechanisms, like UITableView and UICollectionView selection handling, require this to work
- (void)__forwardTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)__forwardTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)__forwardTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)__forwardTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

// These methods expose a way for ASDisplayNode responder methods to let the view call super responder methods
// They are called from ASDisplayNode to pass through UIResponder methods to the view
- (BOOL)__canBecomeFirstResponder;
- (BOOL)__becomeFirstResponder;
- (BOOL)__canResignFirstResponder;
- (BOOL)__resignFirstResponder;
- (BOOL)__isFirstResponder;

@end

NS_ASSUME_NONNULL_END
