//
//  TinySVGTextAreaElement.m
//  SVGKit-iOS
//
//  Created by David Gileadi on 8/26/14.
//  Copyright (c) 2014 na. All rights reserved.
//

#import "TinySVGTextAreaElement.h"
#import "SVGKParseResult.h"
#import "SVGElement_ForParser.h"


@interface TinySVGTextAreaElement()
@property(nonatomic,strong,readwrite) SVGLength* /* FIXME: should be SVGAnimatedLengthList */ width;
@property(nonatomic,strong,readwrite) SVGLength* /* FIXME: should be SVGAnimatedLengthList */ height;
@end


@implementation TinySVGTextAreaElement

@synthesize width;
@synthesize height;


- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult
{
    [super postProcessAttributesAddingErrorsTo:parseResult];
    
    self.width = [self getAttributeAsSVGLength:@"width"];
    self.height = [self getAttributeAsSVGLength:@"height"];
}

- (CALayer *) newLayer
{
    CATextLayer *label = (CATextLayer *) [super newLayer];
    
    label.wrapped = YES;
    
    float w = [self.width pixelsValue];
    float h = [self.height pixelsValue];
    if( w > 0 && h > 0 ) {
        if( w == 0.0f )
            w = label.bounds.size.width;
        if( h == 0.0f )
            h = label.bounds.size.height;
        label.bounds = CGRectMake(0, 0, w, h);
    }
    
    NSString* textAlign = [self cascadedValueForStylableProperty:@"text-align"];
    if( [@"start" isEqualToString:textAlign] )
        label.alignmentMode = kCAAlignmentLeft;
    else if( [@"center" isEqualToString:textAlign] )
        label.alignmentMode = kCAAlignmentCenter;
    else if( [@"end" isEqualToString:textAlign] )
        label.alignmentMode = kCAAlignmentRight;
    else if( [@"justify" isEqualToString:textAlign] )
        label.alignmentMode = kCAAlignmentJustified;
    
    label.position = CGPointZero;
    
    return label;
}

@end
