//
//  SVGGradientStop
//  SVGPad
//
//  Created by Kevin Stich on 2/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//


#import "SVGGradientStop.h"
#import "SVGElement_ForParser.h"

#import "SVGUtils.h"
#import "SVGKParser.h"

#import "SVGLength.h"

@implementation SVGGradientStop

@synthesize offset = _offset;
@synthesize stopColor = _stopColor;
@synthesize stopOpacity = _stopOpacity;

//@synthesize style = _style;

-(void)loadDefaults
{
	_stopOpacity = 1.0f;
}

-(void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult
{
	[super postProcessAttributesAddingErrorsTo:parseResult];
	
	if( [self getAttribute:@"offset"].length > 0 )
        _offset = [[SVGLength svgLengthFromNSString:[self getAttribute:@"offset"]] numberValue];
    
	/** Second, over-ride the style with any locally-specified values */
    NSString *stopColor = [self cascadedValueForStylableProperty:@"stop-color" inherit:NO];
    if( stopColor.length > 0 )
        _stopColor = SVGColorFromString( [stopColor UTF8String] );
	
    NSString *stopOpacity = [self cascadedValueForStylableProperty:@"stop-opacity" inherit:NO];
    if( stopOpacity.length > 0 )
        _stopOpacity = [stopOpacity floatValue];
	
	_stopColor.a = (_stopOpacity * 255);
}

//no memory allocated by this subclass
//-(void)dealloc
//{
//    
//    
//    [super dealloc];
//}

@end
