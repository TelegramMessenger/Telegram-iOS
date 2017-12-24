//
//  ASDisplayNode+Beta.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASEventLog.h>

#if YOGA
  #import YOGA_HEADER_PATH
  #import <AsyncDisplayKit/ASYogaUtilities.h>
#endif

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN
void ASPerformBlockOnMainThread(void (^block)(void));
void ASPerformBlockOnBackgroundThread(void (^block)(void)); // DISPATCH_QUEUE_PRIORITY_DEFAULT
ASDISPLAYNODE_EXTERN_C_END

#if ASEVENTLOG_ENABLE
  #define ASDisplayNodeLogEvent(node, ...) [node.eventLog logEventWithBacktrace:(AS_SAVE_EVENT_BACKTRACES ? [NSThread callStackSymbols] : nil) format:__VA_ARGS__]
#else
  #define ASDisplayNodeLogEvent(node, ...)
#endif

#if ASEVENTLOG_ENABLE
  #define ASDisplayNodeGetEventLog(node) node.eventLog
#else
  #define ASDisplayNodeGetEventLog(node) nil
#endif

/**
 * Bitmask to indicate what performance measurements the cell should record.
 */
typedef NS_OPTIONS(NSUInteger, ASDisplayNodePerformanceMeasurementOptions) {
  ASDisplayNodePerformanceMeasurementOptionLayoutSpec = 1 << 0,
  ASDisplayNodePerformanceMeasurementOptionLayoutComputation = 1 << 1
};

typedef struct {
  CFTimeInterval layoutSpecTotalTime;
  NSInteger layoutSpecNumberOfPasses;
  CFTimeInterval layoutComputationTotalTime;
  NSInteger layoutComputationNumberOfPasses;
} ASDisplayNodePerformanceMeasurements;

@interface ASDisplayNode (Beta)

/**
 * @abstract Recursively ensures node and all subnodes are displayed.
 * @see Full documentation in ASDisplayNode+FrameworkPrivate.h
 */
- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously;

/**
 * @abstract allow modification of a context before the node's content is drawn
 *
 * @discussion Set the block to be called after the context has been created and before the node's content is drawn.
 * You can override this to modify the context before the content is drawn. You are responsible for saving and
 * restoring context if necessary. Restoring can be done in contextDidDisplayNodeContent
 * This block can be called from *any* thread and it is unsafe to access any UIKit main thread properties from it.
 */
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext;

/**
 * @abstract allow modification of a context after the node's content is drawn
 */
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext;

/**
 * @abstract A bitmask representing which actions (layout spec, layout generation) should be measured.
 */
@property (nonatomic, assign) ASDisplayNodePerformanceMeasurementOptions measurementOptions;

/**
 * @abstract A simple struct representing performance measurements collected.
 */
@property (nonatomic, assign, readonly) ASDisplayNodePerformanceMeasurements performanceMeasurements;

#if ASEVENTLOG_ENABLE
/*
 * @abstract The primitive event tracing object. You shouldn't directly use it to log event. Use the ASDisplayNodeLogEvent macro instead.
 */
@property (nonatomic, strong, readonly) ASEventLog *eventLog;
#endif

/**
 * @abstract Whether this node acts as an accessibility container. If set to YES, then this node's accessibility label will represent
 * an aggregation of all child nodes' accessibility labels. Nodes in this node's subtree that are also accessibility containers will
 * not be included in this aggregation, and will be exposed as separate accessibility elements to UIKit.
 */
@property (nonatomic, assign) BOOL isAccessibilityContainer;

/**
 * @abstract Invoked when a user performs a custom action on an accessible node. Nodes that are children of accessibility containers, have
 * an accessibity label and have an interactive UIAccessibilityTrait will automatically receive custom-action handling.
 */
- (void)performAccessibilityCustomAction:(UIAccessibilityCustomAction *)action;

/**
 * @abstract Currently used by ASNetworkImageNode and ASMultiplexImageNode to allow their placeholders to stay if they are loading an image from the network.
 * Otherwise, a display pass is scheduled and completes, but does not actually draw anything - and ASDisplayNode considers the element finished.
 */
- (BOOL)placeholderShouldPersist AS_WARN_UNUSED_RESULT;

/**
 * @abstract Indicates that the receiver and all subnodes have finished displaying. May be called more than once, for example if the receiver has
 * a network image node. This is called after the first display pass even if network image nodes have not downloaded anything (text would be done,
 * and other nodes that are ready to do their final display). Each render of every progressive jpeg network node would cause this to be called, so
 * this hook could be called up to 1 + (pJPEGcount * pJPEGrenderCount) times. The render count depends on how many times the downloader calls the
 * progressImage block.
 */
- (void)hierarchyDisplayDidFinish;

/**
 * Only ASLayoutRangeModeVisibleOnly or ASLayoutRangeModeLowMemory are recommended.  Default is ASLayoutRangeModeVisibleOnly,
 * because this is the only way to ensure an application will not have blank / flashing views as the user navigates back after
 * a memory warning.  Apps that wish to use the more effective / aggressive ASLayoutRangeModeLowMemory may need to take steps
 * to mitigate this behavior, including: restoring a larger range mode to the next controller before the user navigates there,
 * enabling .neverShowPlaceholders on ASCellNodes so that the navigation operation is blocked on redisplay completing, etc.
 */
+ (void)setRangeModeForMemoryWarnings:(ASLayoutRangeMode)rangeMode;

/**
 * @abstract Whether to draw all descendent nodes' contents into this node's layer's backing store.
 *
 * @discussion
 * When called, causes all descendent nodes' contents to be drawn directly into this node's layer's backing
 * store.
 *
 * If a node's descendants are static (never animated or never change attributes after creation) then that node is a
 * good candidate for rasterization.  Rasterizing descendants has two main benefits:
 * 1) Backing stores for descendant layers are not created.  Instead the layers are drawn directly into the rasterized
 * container.  This can save a great deal of memory.
 * 2) Since the entire subtree is drawn into one backing store, compositing and blending are eliminated in that subtree
 * which can help improve animation/scrolling/etc performance.
 *
 * Rasterization does not currently support descendants with transform, sublayerTransform, or alpha. Those properties
 * will be ignored when rasterizing descendants.
 *
 * Note: this has nothing to do with -[CALayer shouldRasterize], which doesn't work with ASDisplayNode's asynchronous
 * rendering model.
 *
 * Note: You cannot add subnodes whose layers/views are already loaded to a rasterized node.
 * Note: You cannot call this method after the receiver's layer/view is loaded.
 */
- (void)enableSubtreeRasterization;

@end

#pragma mark - Yoga Layout Support

#if YOGA

extern void ASDisplayNodePerformBlockOnEveryYogaChild(ASDisplayNode * _Nullable node, void(^block)(ASDisplayNode *node));

@interface ASDisplayNode (Yoga)

@property (nonatomic, strong, nullable) NSArray *yogaChildren;

- (void)addYogaChild:(ASDisplayNode *)child;
- (void)removeYogaChild:(ASDisplayNode *)child;
- (void)insertYogaChild:(ASDisplayNode *)child atIndex:(NSUInteger)index;

- (void)semanticContentAttributeDidChange:(UISemanticContentAttribute)attribute;

@property (nonatomic, assign) BOOL yogaLayoutInProgress;
@property (nonatomic, strong, nullable) ASLayout *yogaCalculatedLayout;

// These methods are intended to be used internally to Texture, and should not be called directly.
- (BOOL)shouldHaveYogaMeasureFunc;
- (void)invalidateCalculatedYogaLayout;
- (void)calculateLayoutFromYogaRoot:(ASSizeRange)rootConstrainedSize;

@end

@interface ASLayoutElementStyle (Yoga)

- (YGNodeRef)yogaNodeCreateIfNeeded;
@property (nonatomic, assign, readonly) YGNodeRef yogaNode;

@property (nonatomic, assign, readwrite) ASStackLayoutDirection flexDirection;
@property (nonatomic, assign, readwrite) YGDirection direction;
@property (nonatomic, assign, readwrite) ASStackLayoutJustifyContent justifyContent;
@property (nonatomic, assign, readwrite) ASStackLayoutAlignItems alignItems;
@property (nonatomic, assign, readwrite) YGPositionType positionType;
@property (nonatomic, assign, readwrite) ASEdgeInsets position;
@property (nonatomic, assign, readwrite) ASEdgeInsets margin;
@property (nonatomic, assign, readwrite) ASEdgeInsets padding;
@property (nonatomic, assign, readwrite) ASEdgeInsets border;
@property (nonatomic, assign, readwrite) CGFloat aspectRatio;
@property (nonatomic, assign, readwrite) YGWrap flexWrap;

@end

#endif

NS_ASSUME_NONNULL_END
