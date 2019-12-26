//
//  SVGGroupElement.h
//  SVGKit
//
//  Copyright Matt Rajca 2010-2011. All rights reserved.
//

#import "SVGElement.h"
#import "ConverterSVGToCALayer.h"

@interface SVGGroupElement : SVGElement < ConverterSVGToCALayer > { }

@property (nonatomic, readonly) CGFloat opacity;

@end
