//
//  ASTableViewInternal.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASTableView.h>

@class ASDataController;
@class ASTableNode;
@class ASRangeController;
@class ASEventLog;

@interface ASTableView (Internal)

@property (nonatomic, readonly) ASDataController *dataController;
@property (nonatomic, weak) ASTableNode *tableNode;
@property (nonatomic, readonly) ASRangeController *rangeController;

/**
 * Initializer.
 *
 * @param frame A rectangle specifying the initial location and size of the table view in its superview’s coordinates.
 * The frame of the table view changes as table cells are added and deleted.
 *
 * @param style A constant that specifies the style of the table view. See UITableViewStyle for descriptions of valid constants.
 *
 * @param dataControllerClass A controller class injected to and used to create a data controller for the table view.
 *
 * @param eventLog An event log passed through to the data controller.
 */
- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass owningNode:(ASTableNode *)tableNode eventLog:(ASEventLog *)eventLog;

/// Set YES and we'll log every time we call [super insertRows…] etc
@property (nonatomic) BOOL test_enableSuperUpdateCallLogging;

/**
 * Attempt to get the view-layer index path for the row with the given index path.
 *
 * @param indexPath The index path of the row.
 * @param wait If the item hasn't reached the view yet, this attempts to wait for updates to commit.
 */
- (NSIndexPath *)convertIndexPathFromTableNode:(NSIndexPath *)indexPath waitingIfNeeded:(BOOL)wait;

/**
 * Attempt to get the node index path given the view-layer index path.
 *
 * @param indexPath The index path of the row.
 */
- (NSIndexPath *)convertIndexPathToTableNode:(NSIndexPath *)indexPath;

/**
 * Attempt to get the node index paths given the view-layer index paths.
 *
 * @param indexPaths An array of index paths in the view space
 */
- (NSArray<NSIndexPath *> *)convertIndexPathsToTableNode:(NSArray<NSIndexPath *> *)indexPaths;

/// Returns the width of the section index view on the right-hand side of the table, if one is present.
- (CGFloat)sectionIndexWidth;

@end

#endif
