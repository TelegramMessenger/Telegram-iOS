//
//  ASLayoutTestNode.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASLayoutTestNode.h"
#import <OCMock/OCMock.h>
#import "OCMockObject+ASAdditions.h"

@implementation ASLayoutTestNode

- (instancetype)init
{
  if (self = [super init]) {
    _mock = OCMStrictClassMock([ASDisplayNode class]);

    // If errors occur (e.g. unexpected method) we need to quickly figure out
    // which node is at fault, so we inject the node name into the mock instance
    // description.
    __weak __typeof(self) weakSelf = self;
    [_mock setModifyDescriptionBlock:^(id mock, NSString *baseDescription){
      return [NSString stringWithFormat:@"Mock(%@)", weakSelf.description];
    }];
  }
  return self;
}

- (ASLayout *)currentLayoutBasedOnFrames
{
  return [self _currentLayoutBasedOnFramesForRootNode:YES];
}

- (ASLayout *)_currentLayoutBasedOnFramesForRootNode:(BOOL)isRootNode
{
  const auto sublayouts = [[NSMutableArray<ASLayout *> alloc] init];
  for (ASLayoutTestNode *subnode in self.subnodes) {
    [sublayouts addObject:[subnode _currentLayoutBasedOnFramesForRootNode:NO]];
  }
  CGPoint rootPosition = isRootNode ? ASPointNull : self.frame.origin;
  return [ASLayout layoutWithLayoutElement:self size:self.frame.size position:rootPosition sublayouts:sublayouts];
}

- (void)setTestSize:(CGSize)testSize
{
  if (!CGSizeEqualToSize(testSize, _testSize)) {
    _testSize = testSize;
    [self setNeedsLayout];
  }
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  [_mock calculateLayoutThatFits:constrainedSize];

  // If we have a layout spec block, or no test size, return super.
  if (self.layoutSpecBlock || CGSizeEqualToSize(self.testSize, CGSizeZero)) {
    return [super calculateLayoutThatFits:constrainedSize];
  } else {
    // Interestingly, the infra will auto-clamp sizes from calculateSizeThatFits, but not from calculateLayoutThatFits.
    const auto size = ASSizeRangeClamp(constrainedSize, self.testSize);
    return [ASLayout layoutWithLayoutElement:self size:size];
  }
}

#pragma mark - Forwarding to mock

- (void)calculatedLayoutDidChange
{
  [_mock calculatedLayoutDidChange];
  [super calculatedLayoutDidChange];
}

- (void)didCompleteLayoutTransition:(id<ASContextTransitioning>)context
{
  [_mock didCompleteLayoutTransition:context];
  [super didCompleteLayoutTransition:context];
}

- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  [_mock animateLayoutTransition:context];
  [super animateLayoutTransition:context];
}

@end
