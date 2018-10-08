//
//  ASCornerLayoutSpecSnapshotTests.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASLayoutSpecSnapshotTestsHelper.h"
#import <AsyncDisplayKit/ASCornerLayoutSpec.h>
#import <AsyncDisplayKit/ASBackgroundLayoutSpec.h>

typedef NS_ENUM(NSInteger, ASCornerLayoutSpecSnapshotTestsOffsetOption) {
  ASCornerLayoutSpecSnapshotTestsOffsetOptionCenter,
  ASCornerLayoutSpecSnapshotTestsOffsetOptionInner,
  ASCornerLayoutSpecSnapshotTestsOffsetOptionOuter,
};


@interface ASCornerLayoutSpecSnapshotTests : ASLayoutSpecSnapshotTestCase

@property (nonatomic, copy) UIColor *boxColor;
@property (nonatomic, copy) UIColor *baseColor;
@property (nonatomic, copy) UIColor *cornerColor;
@property (nonatomic, copy) UIColor *contextColor;

@property (nonatomic) CGSize baseSize;
@property (nonatomic) CGSize cornerSize;
@property (nonatomic) CGSize contextSize;

@property (nonatomic) ASSizeRange contextSizeRange;

@end


@implementation ASCornerLayoutSpecSnapshotTests

- (void)setUp
{
  [super setUp];
  
  self.recordMode = NO;
  
  _boxColor = [UIColor greenColor];
  _baseColor = [UIColor blueColor];
  _cornerColor = [UIColor orangeColor];
  _contextColor = [UIColor lightGrayColor];

  _baseSize = CGSizeMake(60, 60);
  _cornerSize = CGSizeMake(20, 20);
  _contextSize = CGSizeMake(120, 120);
  
  _contextSizeRange = ASSizeRangeMake(CGSizeZero, _contextSize);
}

- (void)testCornerSpecForAllLocations
{
  ASCornerLayoutSpecSnapshotTestsOffsetOption center = ASCornerLayoutSpecSnapshotTestsOffsetOptionCenter;
  
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopLeft offsetOption:center wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopLeft offsetOption:center wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopRight offsetOption:center wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopRight offsetOption:center wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomLeft offsetOption:center wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomLeft offsetOption:center wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomRight offsetOption:center wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomRight offsetOption:center wrapsCorner:YES];
}

- (void)testCornerSpecForAllLocationsWithInnerOffset
{
  ASCornerLayoutSpecSnapshotTestsOffsetOption inner = ASCornerLayoutSpecSnapshotTestsOffsetOptionInner;
  
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopLeft offsetOption:inner wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopLeft offsetOption:inner wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopRight offsetOption:inner wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopRight offsetOption:inner wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomLeft offsetOption:inner wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomLeft offsetOption:inner wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomRight offsetOption:inner wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomRight offsetOption:inner wrapsCorner:YES];
}

- (void)testCornerSpecForAllLocationsWithOuterOffset
{
  ASCornerLayoutSpecSnapshotTestsOffsetOption outer = ASCornerLayoutSpecSnapshotTestsOffsetOptionOuter;
  
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopLeft offsetOption:outer wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopLeft offsetOption:outer wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopRight offsetOption:outer wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationTopRight offsetOption:outer wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomLeft offsetOption:outer wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomLeft offsetOption:outer wrapsCorner:YES];

  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomRight offsetOption:outer wrapsCorner:NO];
  [self testCornerSpecWithLocation:ASCornerLayoutLocationBottomRight offsetOption:outer wrapsCorner:YES];
}

- (void)testCornerSpecWithLocation:(ASCornerLayoutLocation)location
                      offsetOption:(ASCornerLayoutSpecSnapshotTestsOffsetOption)offsetOption
                       wrapsCorner:(BOOL)wrapsCorner
{
  ASDisplayNode *baseNode = ASDisplayNodeWithBackgroundColor(_baseColor, _baseSize);
  ASDisplayNode *cornerNode = ASDisplayNodeWithBackgroundColor(_cornerColor, _cornerSize);
  ASDisplayNode *debugBoxNode = ASDisplayNodeWithBackgroundColor(_boxColor);
  
  baseNode.style.layoutPosition = CGPointMake((_contextSize.width - _baseSize.width) / 2,
                                              (_contextSize.height - _baseSize.height) / 2);
  
  ASCornerLayoutSpec *cornerSpec = [ASCornerLayoutSpec cornerLayoutSpecWithChild:baseNode
                                                                          corner:cornerNode
                                                                        location:location];
  
  CGPoint delta = (CGPoint){ _cornerSize.width / 2, _cornerSize.height / 2 };
  cornerSpec.offset = [self offsetForOption:offsetOption location:location delta:delta];
  cornerSpec.wrapsCorner = wrapsCorner;
  
  ASBackgroundLayoutSpec *backgroundSpec = [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:cornerSpec
                                                                                      background:debugBoxNode];
  
  [self testLayoutSpec:backgroundSpec
             sizeRange:_contextSizeRange
              subnodes:@[debugBoxNode, baseNode, cornerNode]
            identifier:[self suffixWithLocation:location option:offsetOption wrapsCorner:wrapsCorner]];
}

- (CGPoint)offsetForOption:(ASCornerLayoutSpecSnapshotTestsOffsetOption)option
                  location:(ASCornerLayoutLocation)location
                     delta:(CGPoint)delta
{
  CGFloat x = delta.x;
  CGFloat y = delta.y;
  
  switch (option) {
      
    case ASCornerLayoutSpecSnapshotTestsOffsetOptionCenter:
      return CGPointZero;
      
    case ASCornerLayoutSpecSnapshotTestsOffsetOptionInner:
      
      switch (location) {
        case ASCornerLayoutLocationTopLeft: return (CGPoint){ x, y };
        case ASCornerLayoutLocationTopRight: return (CGPoint){ -x, y };
        case ASCornerLayoutLocationBottomLeft: return (CGPoint){ x, -y };
        case ASCornerLayoutLocationBottomRight: return (CGPoint){ -x, -y };
      }
      
    case ASCornerLayoutSpecSnapshotTestsOffsetOptionOuter:
      
      switch (location) {
        case ASCornerLayoutLocationTopLeft: return (CGPoint){ -x, -y };
        case ASCornerLayoutLocationTopRight: return (CGPoint){ x, -y };
        case ASCornerLayoutLocationBottomLeft: return (CGPoint){ -x, y };
        case ASCornerLayoutLocationBottomRight: return (CGPoint){ x, y };
      }
      
  }
  
}

- (NSString *)suffixWithLocation:(ASCornerLayoutLocation)location
                          option:(ASCornerLayoutSpecSnapshotTestsOffsetOption)option
                     wrapsCorner:(BOOL)wrapsCorner
{  
  NSMutableString *desc = [NSMutableString string];
  
  switch (location) {
    case ASCornerLayoutLocationTopLeft:
      [desc appendString:@"topLeft"];
      break;
    case ASCornerLayoutLocationTopRight:
      [desc appendString:@"topRight"];
      break;
    case ASCornerLayoutLocationBottomLeft:
      [desc appendString:@"bottomLeft"];
      break;
    case ASCornerLayoutLocationBottomRight:
      [desc appendString:@"bottomRight"];
      break;
  }
  
  [desc appendString:@"_"];
  
  switch (option) {
    case ASCornerLayoutSpecSnapshotTestsOffsetOptionCenter:
      [desc appendString:@"center"];
      break;
    case ASCornerLayoutSpecSnapshotTestsOffsetOptionInner:
      [desc appendString:@"inner"];
      break;
    case ASCornerLayoutSpecSnapshotTestsOffsetOptionOuter:
      [desc appendString:@"outer"];
      break;
  }
  
  [desc appendString:@"_"];
  
  if (wrapsCorner) {
    [desc appendString:@"fullSize"];
  } else {
    [desc appendString:@"childSize"];
  }
  
  return desc.copy;
}

@end
