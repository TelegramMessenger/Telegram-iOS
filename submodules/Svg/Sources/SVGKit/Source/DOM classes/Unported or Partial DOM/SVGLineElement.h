//
//  SVGLineElement.h
//  SVGKit
//
//  Copyright Matt Rajca 2010-2011. All rights reserved.
//

#import "BaseClassForAllSVGBasicShapes.h"

@interface SVGLineElement : BaseClassForAllSVGBasicShapes { }

@property (nonatomic, readonly) CGFloat x1;
@property (nonatomic, readonly) CGFloat y1;
@property (nonatomic, readonly) CGFloat x2;
@property (nonatomic, readonly) CGFloat y2;

@end
