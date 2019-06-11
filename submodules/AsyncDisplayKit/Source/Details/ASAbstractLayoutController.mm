//
//  ASAbstractLayoutController.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAbstractLayoutController.h>
#import <AsyncDisplayKit/ASAbstractLayoutController+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASAssert.h>

ASRangeTuningParameters const ASRangeTuningParametersZero = {};

BOOL ASRangeTuningParametersEqualToRangeTuningParameters(ASRangeTuningParameters lhs, ASRangeTuningParameters rhs)
{
  return lhs.leadingBufferScreenfuls == rhs.leadingBufferScreenfuls && lhs.trailingBufferScreenfuls == rhs.trailingBufferScreenfuls;
}

ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferHorizontal(ASScrollDirection scrollDirection,
                                                                    ASRangeTuningParameters rangeTuningParameters)
{
  ASDirectionalScreenfulBuffer horizontalBuffer = {0, 0};
  BOOL movingRight = ASScrollDirectionContainsRight(scrollDirection);
  
  horizontalBuffer.positiveDirection = movingRight ? rangeTuningParameters.leadingBufferScreenfuls
                                                   : rangeTuningParameters.trailingBufferScreenfuls;
  horizontalBuffer.negativeDirection = movingRight ? rangeTuningParameters.trailingBufferScreenfuls
                                                   : rangeTuningParameters.leadingBufferScreenfuls;
  return horizontalBuffer;
}

ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferVertical(ASScrollDirection scrollDirection,
                                                                  ASRangeTuningParameters rangeTuningParameters)
{
  ASDirectionalScreenfulBuffer verticalBuffer = {0, 0};
  BOOL movingDown = ASScrollDirectionContainsDown(scrollDirection);
  
  verticalBuffer.positiveDirection = movingDown ? rangeTuningParameters.leadingBufferScreenfuls
                                                : rangeTuningParameters.trailingBufferScreenfuls;
  verticalBuffer.negativeDirection = movingDown ? rangeTuningParameters.trailingBufferScreenfuls
                                                : rangeTuningParameters.leadingBufferScreenfuls;
  return verticalBuffer;
}

CGRect CGRectExpandHorizontally(CGRect rect, ASDirectionalScreenfulBuffer buffer)
{
  CGFloat negativeDirectionWidth = buffer.negativeDirection * rect.size.width;
  CGFloat positiveDirectionWidth = buffer.positiveDirection * rect.size.width;
  rect.size.width = negativeDirectionWidth + rect.size.width + positiveDirectionWidth;
  rect.origin.x -= negativeDirectionWidth;
  return rect;
}

CGRect CGRectExpandVertically(CGRect rect, ASDirectionalScreenfulBuffer buffer)
{
  CGFloat negativeDirectionHeight = buffer.negativeDirection * rect.size.height;
  CGFloat positiveDirectionHeight = buffer.positiveDirection * rect.size.height;
  rect.size.height = negativeDirectionHeight + rect.size.height + positiveDirectionHeight;
  rect.origin.y -= negativeDirectionHeight;
  return rect;
}

CGRect CGRectExpandToRangeWithScrollableDirections(CGRect rect, ASRangeTuningParameters tuningParameters,
                                                   ASScrollDirection scrollableDirections, ASScrollDirection scrollDirection)
{
  // Can scroll horizontally - expand the range appropriately
  if (ASScrollDirectionContainsHorizontalDirection(scrollableDirections)) {
    ASDirectionalScreenfulBuffer horizontalBuffer = ASDirectionalScreenfulBufferHorizontal(scrollDirection, tuningParameters);
    rect = CGRectExpandHorizontally(rect, horizontalBuffer);
  }

  // Can scroll vertically - expand the range appropriately
  if (ASScrollDirectionContainsVerticalDirection(scrollableDirections)) {
    ASDirectionalScreenfulBuffer verticalBuffer = ASDirectionalScreenfulBufferVertical(scrollDirection, tuningParameters);
    rect = CGRectExpandVertically(rect, verticalBuffer);
  }
  
  return rect;
}

@interface ASAbstractLayoutController () {
  std::vector<std::vector<ASRangeTuningParameters>> _tuningParameters;
}
@end

@implementation ASAbstractLayoutController

+ (std::vector<std::vector<ASRangeTuningParameters>>)defaultTuningParameters
{
  auto tuningParameters = std::vector<std::vector<ASRangeTuningParameters>> (ASLayoutRangeModeCount, std::vector<ASRangeTuningParameters> (ASLayoutRangeTypeCount));

  tuningParameters[ASLayoutRangeModeFull][ASLayoutRangeTypeDisplay] = {
    .leadingBufferScreenfuls = 1.0,
    .trailingBufferScreenfuls = 0.5
  };

  tuningParameters[ASLayoutRangeModeFull][ASLayoutRangeTypePreload] = {
    .leadingBufferScreenfuls = 2.5,
    .trailingBufferScreenfuls = 1.5
  };

  tuningParameters[ASLayoutRangeModeMinimum][ASLayoutRangeTypeDisplay] = {
    .leadingBufferScreenfuls = 0.25,
    .trailingBufferScreenfuls = 0.25
  };
  tuningParameters[ASLayoutRangeModeMinimum][ASLayoutRangeTypePreload] = {
    .leadingBufferScreenfuls = 0.5,
    .trailingBufferScreenfuls = 0.25
  };

  tuningParameters[ASLayoutRangeModeVisibleOnly][ASLayoutRangeTypeDisplay] = {
    .leadingBufferScreenfuls = 0,
    .trailingBufferScreenfuls = 0
  };
  tuningParameters[ASLayoutRangeModeVisibleOnly][ASLayoutRangeTypePreload] = {
    .leadingBufferScreenfuls = 0,
    .trailingBufferScreenfuls = 0
  };

  // The Low Memory range mode has special handling. Because a zero range still includes the visible area / bounds,
  // in order to implement the behavior of releasing all graphics memory (backing stores), ASRangeController must check
  // for this range mode and use an empty set for displayIndexPaths rather than querying the ASLayoutController for the indexPaths.
  tuningParameters[ASLayoutRangeModeLowMemory][ASLayoutRangeTypeDisplay] = {
    .leadingBufferScreenfuls = 0,
    .trailingBufferScreenfuls = 0
  };
  tuningParameters[ASLayoutRangeModeLowMemory][ASLayoutRangeTypePreload] = {
    .leadingBufferScreenfuls = 0,
    .trailingBufferScreenfuls = 0
  };
  return tuningParameters;
}

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  ASDisplayNodeAssert(self.class != [ASAbstractLayoutController class], @"Should never create instances of abstract class ASAbstractLayoutController.");
  
  _tuningParameters = [[self class] defaultTuningParameters];
  
  return self;
}

#pragma mark - Tuning Parameters

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  return [self setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(), @"Requesting a range that is OOB for the configured tuning parameters");
  return _tuningParameters[rangeMode][rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(), @"Setting a range that is OOB for the configured tuning parameters");
  _tuningParameters[rangeMode][rangeType] = tuningParameters;
}

#pragma mark - Abstract Index Path Range Support

- (NSHashTable<ASCollectionElement *> *)elementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType map:(ASElementMap *)map
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)allElementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode displaySet:(NSHashTable<ASCollectionElement *> *__autoreleasing  _Nullable *)displaySet preloadSet:(NSHashTable<ASCollectionElement *> *__autoreleasing  _Nullable *)preloadSet map:(ASElementMap *)map
{
  ASDisplayNodeAssertNotSupported();
}

@end
