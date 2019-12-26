#import "SVGTextElement.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import "SVGElement_ForParser.h" // to resolve Xcode circular dependencies; in long term, parsing SHOULD NOT HAPPEN inside any class whose name starts "SVG" (because those are reserved classes for the SVG Spec)
#import "SVGGradientLayer.h"
#import "SVGHelperUtilities.h"
#import "SVGUtils.h"
#import "SVGTextLayer.h"

@implementation SVGTextElement

@synthesize transform; // each SVGElement subclass that conforms to protocol "SVGTransformable" has to re-synthesize this to work around bugs in Apple's Objective-C 2.0 design that don't allow @properties to be extended by categories / protocols


- (CALayer *) newLayer
{
	/**
	 BY DESIGN: we work out the positions of all text in ABSOLUTE space, and then construct the Apple CALayers and CATextLayers around
	 them, as required.
	 
	 Because: Apple's classes REQUIRE us to provide a lot of this info up-front. Sigh
	 And: SVGKit works by pre-baking everything into position (its faster, and avoids Apple's broken CALayer.transform property)
	 */
	CGAffineTransform textTransformAbsolute = [SVGHelperUtilities transformAbsoluteIncludingViewportForTransformableOrViewportEstablishingElement:self];
	/** add on the local x,y that will NOT BE iNCLUDED IN THE TRANSFORM
	 AUTOMATICALLY BECAUSE THEY ARE NOT TRANSFORM COMMANDS IN SVG SPEC!!
	 -- but they ARE part of the "implicit transform" of text elements!! (bad SVG Spec design :( )
	 
	 NB: the local bits (x/y offset) have to be pre-transformed by
	 */
    CGRect viewport = CGRectFromSVGRect(self.rootOfCurrentDocumentFragment.viewBox);
	CGAffineTransform textTransformAbsoluteWithLocalPositionOffset = CGAffineTransformConcat( CGAffineTransformMakeTranslation( [self.x pixelsValueWithDimension:viewport.size.width], [self.y pixelsValueWithDimension:viewport.size.height]), textTransformAbsolute);
	
	/**
	 Apple's CATextLayer is poor - one of those classes Apple hasn't finished writing?
	 
	 It's incompatible with UIFont (Apple states it is so), and it DOES NOT WORK by default:
	 
	 If you assign a font, and a font size, and text ... you get a blank empty layer of
	 size 0,0
	 
	 Because Apple requires you to ALSO do all the work of calculating the font size, shape,
	 position etc.
	 
	 But its the easiest way to get FULL control over size/position/rotation/etc in a CALayer
	 */
    
    /**
     Create font based on many information (font-family, font-weight, etc), fallback to system font when there are no available font matching the information.
     */
    UIFont *font = [SVGTextElement matchedFontWithElement:self];
	
	/** Convert the size down using the SVG transform at this point, before we calc the frame size etc */
//	effectiveFontSize = CGSizeApplyAffineTransform( CGSizeMake(0,effectiveFontSize), textTransformAbsolute ).height; // NB important that we apply a transform to a "CGSize" here, so that Apple's library handles worrying about whether to ignore skew transforms etc

	/** Convert all whitespace to spaces, and trim leading/trailing (SVG doesn't support leading/trailing whitespace, and doesnt support CR LF etc) */
	
	NSString* effectiveText = self.textContent; // FIXME: this is a TEMPORARY HACK, UNTIL PROPER PARSING OF <TSPAN> ELEMENTS IS ADDED
	
	effectiveText = [effectiveText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	effectiveText = [effectiveText stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    
    /**
     Stroke color && stroke width
     Apple's `CATextLayer` can not stroke gradient on the layer (we can only fill the layer)
     */
    CGColorRef strokeColor = [SVGHelperUtilities parseStrokeForElement:self];
    CGFloat strokeWidth = 0;
    NSString* actualStrokeWidth = [self cascadedValueForStylableProperty:@"stroke-width"];
    if (actualStrokeWidth)
    {
        SVGRect r = ((SVGSVGElement*)self.viewportElement).viewport;
        strokeWidth = [[SVGLength svgLengthFromNSString:actualStrokeWidth]
                       pixelsValueWithDimension: hypot(r.width, r.height)];
    }
    
    /**
     Fill color
     Apple's `CATextLayer` can be filled using mask.
     */
    CGColorRef fillColor = [SVGHelperUtilities parseFillForElement:self];
	
	/** Calculate 
	 
	 1. Create an attributed string (Apple's APIs are hard-coded to require this)
	 2. Set the font to be the correct one + correct size for whole string, inside the string
	 3. Ask apple how big the final thing should be
	 4. Use that to provide a layer.frame
	 */
	NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithString:effectiveText];
    NSRange stringRange = NSMakeRange(0, attributedString.string.length);
	[attributedString addAttribute:NSFontAttributeName
                             value:font
                             range:stringRange];
    if (fillColor) {
        [attributedString addAttribute:NSForegroundColorAttributeName
                                 value:(__bridge id)fillColor
                                 range:stringRange];
    }
    if (strokeWidth != 0 && strokeColor) {
        [attributedString addAttribute:NSStrokeColorAttributeName
                                 value:(__bridge id)strokeColor
                                 range:stringRange];
        // If both fill && stroke, pass negative value; only fill, pass positive value
        // A typical value for outlined text is 3.0. Actually this is not so accurate, but until we directly draw the text glyph using Core Text, we can not control the detailed stroke width follow SVG spec
        CGFloat strokeValue = strokeWidth / 3.0;
        if (fillColor) {
            strokeValue = -strokeValue;
        }
        [attributedString addAttribute:NSStrokeWidthAttributeName
                                 value:@(strokeValue)
                                 range:stringRange];
    }
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString( (CFMutableAttributedStringRef) attributedString );
    CGSize suggestedUntransformedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), NULL);
    CFRelease(framesetter);
	
	CGRect unTransformedFinalBounds = CGRectMake( 0,
											  0,
											  suggestedUntransformedSize.width,
											  suggestedUntransformedSize.height); // everything's been pre-scaled by [self transformAbsolute]
	
    CATextLayer *label = [SVGTextLayer layer];
    [SVGHelperUtilities configureCALayer:label usingElement:self];
	
	/** This is complicated for three reasons.
	 Partly: Apple and SVG use different defitions for the "origin" of a piece of text
	 Partly: Bugs in Apple's CoreText
	 Partly: flaws in Apple's CALayer's handling of frame,bounds,position,anchorPoint,affineTransform
	 
	 1. CALayer.frame DOES NOT EXIST AS A REAL PROPERTY - if you read Apple's docs you eventually realise it is fake. Apple explicitly says it is "not defined". They should DELETE IT from their API!
	 2. CALayer.bounds and .position ARE NOT AFFECTED BY .affineTransform - only the contents of the layer is affected
	 3. SVG defines two SEMI-INCOMPATIBLE ways of positioning TEXT objects, that we have to correctly combine here.
	 4. So ... to apply a transform to the layer text:
	     i. find the TRANSFORM
	     ii. merge it with the local offset (.x and .y from SVG) - which defaults to (0,0)
	     iii. apply that to the layer
	     iv. set the position to 0
	     v. BECAUSE SVG AND APPLE DEFINE ORIGIN DIFFERENTLY: subtract the "untransformed" height of the font ... BUT: pre-transformed ONLY BY the 'multiplying (non-translating)' part of the TRANSFORM.
	     vi. set the bounds to be (whatever Apple's CoreText says is necessary to render TEXT at FONT SIZE, with NO TRANSFORMS)
	 */
    label.bounds = unTransformedFinalBounds;
	
	/** NB: specific to Apple: the "origin" is the TOP LEFT corner of first line of text, whereas SVG uses the font's internal origin
	 (which is BOTTOM LEFT CORNER OF A LETTER SUCH AS 'a' OR 'x' THAT SITS ON THE BASELINE ... so we have to make the FRAME start "font leading" higher up
	 
	 WARNING: Apple's font-rendering system has some nasty bugs (c.f. StackOverflow)
	 
	 We TRIED to use the font's built-in numbers to correct the position, but Apple's own methods often report incorrect values,
	 and/or Apple has deprecated REQUIRED methods in their API (with no explanation - e.g. "font leading")
	 
	 If/when Apple fixes their bugs - or if you know enough about their API's to workaround the bugs, feel free to fix this code.
	 */
    CTLineRef line = CTLineCreateWithAttributedString( (CFMutableAttributedStringRef) attributedString );
    CGFloat ascent = 0;
    CTLineGetTypographicBounds(line, &ascent, NULL, NULL);
    CFRelease(line);
	CGFloat offsetToConvertSVGOriginToAppleOrigin = -ascent;
	CGSize fakeSizeToApplyNonTranslatingPartsOfTransform = CGSizeMake( 0, offsetToConvertSVGOriginToAppleOrigin);
	
	label.position = CGPointMake( 0,
								 0 + CGSizeApplyAffineTransform( fakeSizeToApplyNonTranslatingPartsOfTransform, textTransformAbsoluteWithLocalPositionOffset).height);
    
    NSString *textAnchor = [self cascadedValueForStylableProperty:@"text-anchor"];
    if( [@"middle" isEqualToString:textAnchor] )
        label.anchorPoint = CGPointMake(0.5, 0.0);
    else if( [@"end" isEqualToString:textAnchor] )
        label.anchorPoint = CGPointMake(1.0, 0.0);
    else
        label.anchorPoint = CGPointZero; // WARNING: SVG applies transforms around the top-left as origin, whereas Apple defaults to center as origin, so we tell Apple to work "like SVG" here.
    
	label.affineTransform = textTransformAbsoluteWithLocalPositionOffset;
    label.string = [attributedString copy];
    label.alignmentMode = kCAAlignmentLeft;
    
#if SVGKIT_MAC
    label.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
#else
    label.contentsScale = [[UIScreen mainScreen] scale];
#endif
    
    return [self newCALayerForTextLayer:label transformAbsolute:textTransformAbsolute];

	/** VERY USEFUL when trying to debug text issues:
	label.backgroundColor = [UIColor colorWithRed:0.5 green:0 blue:0 alpha:0.5].CGColor;
	label.borderColor = [UIColor redColor].CGColor;
	//DEBUG: SVGKitLogVerbose(@"font size %2.1f at %@ ... final frame of layer = %@", effectiveFontSize, NSStringFromCGPoint(transformedOrigin), NSStringFromCGRect(label.frame));
	*/
}

-(CALayer *) newCALayerForTextLayer:(CATextLayer *)label transformAbsolute:(CGAffineTransform)transformAbsolute
{
    CALayer *fillLayer = label;
    NSString* actualFill = [self cascadedValueForStylableProperty:@"fill"];

    if ( [actualFill hasPrefix:@"url"] )
    {
        NSArray *fillArgs = [actualFill componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *fillIdArg = fillArgs.firstObject;
        NSRange idKeyRange = NSMakeRange(5, fillIdArg.length - 6);
        NSString* fillId = [fillIdArg substringWithRange:idKeyRange];

        /** Replace the return layer with a special layer using the URL fill */
        /** fetch the fill layer by URL using the DOM */
        SVGGradientLayer *gradientLayer = [SVGHelperUtilities getGradientLayerWithId:fillId forElement:self withRect:label.frame transform:transformAbsolute];
        if (gradientLayer) {
            gradientLayer.mask = label;
            fillLayer = gradientLayer;
        } else {
            // no gradient, fallback
        }
    }

    NSString* actualOpacity = [self cascadedValueForStylableProperty:@"opacity" inherit:NO];
    fillLayer.opacity = actualOpacity.length > 0 ? [actualOpacity floatValue] : 1; // unusually, the "opacity" attribute defaults to 1, not 0

    return fillLayer;
}

/**
 Return the best matched font with all posible CSS font property (like `font-family`, `font-size`, etc)

 @param svgElement svgElement
 @return The matched font, or fallback to system font, non-nil
 */
+ (UIFont *)matchedFontWithElement:(SVGElement *)svgElement {
    // Using top-level API to walkthough all availble font-family
    NSString *actualSize = [svgElement cascadedValueForStylableProperty:@"font-size"];
    NSString *actualFamily = [svgElement cascadedValueForStylableProperty:@"font-family"];
    // TODO- Using font descriptor to match best font consider `font-style`, `font-weight`
    NSString *actualFontStyle = [svgElement cascadedValueForStylableProperty:@"font-style"];
    NSString *actualFontWeight = [svgElement cascadedValueForStylableProperty:@"font-weight"];
    NSString *actualFontStretch = [svgElement cascadedValueForStylableProperty:@"font-stretch"];
    
    CGFloat effectiveFontSize = (actualSize.length > 0) ? [actualSize floatValue] : 12; // I chose 12. I couldn't find an official "default" value in the SVG spec.
    
    NSArray<NSString *> *actualFontFamilies = [SVGTextElement fontFamiliesWithCSSValue:actualFamily];
    NSString *matchedFontFamily;
    if (actualFontFamilies) {
        // walkthrough all available font-families to find the best matched one
        NSSet<NSString *> *availableFontFamilies;
#if SVGKIT_MAC
        availableFontFamilies = [NSSet setWithArray:NSFontManager.sharedFontManager.availableFontFamilies];
#else
        availableFontFamilies = [NSSet setWithArray:UIFont.familyNames];
#endif
        for (NSString *fontFamily in actualFontFamilies) {
            if ([availableFontFamilies containsObject:fontFamily]) {
                matchedFontFamily = fontFamily;
                break;
            }
        }
    }
    
    // we provide enough hint information, let Core Text using their algorithm to detect which fontName should be used
    // if `matchedFontFamily` is nil, use the system default font family instead (allows `font-weight` these information works)
    NSDictionary *attributes = [self fontAttributesWithFontFamily:matchedFontFamily fontStyle:actualFontStyle fontWeight:actualFontWeight fontStretch:actualFontStretch];
    CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attributes);
    CTFontRef fontRef = CTFontCreateWithFontDescriptor(descriptor, effectiveFontSize, NULL);
    UIFont *font = (__bridge_transfer UIFont *)fontRef;
    
    return font;
}

/**
 Convert CSS font detailed information into Core Text descriptor attributes (determine the best matched font).

 @param fontFamily fontFamily
 @param fontStyle fontStyle
 @param fontWeight fontWeight
 @param fontStretch fontStretch
 @return Core Text descriptor attributes
 */
+ (NSDictionary *)fontAttributesWithFontFamily:(NSString *)fontFamily fontStyle:(NSString *)fontStyle fontWeight:(NSString *)fontWeight fontStretch:(NSString *)fontStretch {
    // Default value
    if (!fontFamily.length) fontFamily = [self systemDefaultFontFamily];
    if (!fontStyle.length) fontStyle = @"normal";
    if (!fontWeight.length) fontWeight = @"normal";
    if (!fontStretch.length) fontStretch = @"normal";
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[(__bridge NSString *)kCTFontFamilyNameAttribute] = fontFamily;
    // font-weight is in the sub-dictionary
    NSMutableDictionary *traits = [NSMutableDictionary dictionary];
    // CSS font weight is from 0-1000
    CGFloat weight;
    if ([fontWeight isEqualToString:@"normal"]) {
        weight = 400;
    } else if ([fontWeight isEqualToString:@"bold"]) {
        weight = 700;
    } else if ([fontWeight isEqualToString:@"bolder"]) {
        weight = 900;
    } else if ([fontWeight isEqualToString:@"lighter"]) {
        weight = 100;
    } else {
        CGFloat value = [fontWeight doubleValue];
        weight = MIN(MAX(value, 1), 1000);
    }
    // map from CSS [1, 1000] to Core Text [-1.0, 1.0], 400 represent 0.0
    CGFloat coreTextFontWeight;
    if (weight < 400) {
        coreTextFontWeight = (weight - 400) / 1000 * (1 / 0.4);
    } else {
        coreTextFontWeight = (weight - 400) / 1000 * (1 / 0.6);
    }
    
    // CSS font style
    CTFontSymbolicTraits style = 0;
    if ([fontStyle isEqualToString:@"normal"]) {
        style |= 0;
    } else if ([fontStyle isEqualToString:@"italic"] || [fontStyle rangeOfString:@"oblique"].location != NSNotFound) {
        // Actually we can control the detailed slant degree via `kCTFontSlantTrait`, but it's rare usage so treat them the same, TODO in the future
        style |= kCTFontItalicTrait;
    }
    
    // CSS font stretch
    if ([fontStretch rangeOfString:@"condensed"].location != NSNotFound) {
        // Actually we can control the detailed percent via `kCTFontWidthTrait`, but it's rare usage so treat them the same, TODO in the future
        style |= kCTFontTraitCondensed;
    } else if ([fontStretch rangeOfString:@"expanded"].location != NSNotFound) {
        style |= kCTFontTraitExpanded;
    }
    
    traits[(__bridge NSString *)kCTFontSymbolicTrait] = @(style);
    traits[(__bridge NSString *)kCTFontWeightTrait] = @(coreTextFontWeight);
    attributes[(__bridge NSString *)kCTFontTraitsAttribute] = [traits copy];
    
    return [attributes copy];
}

/**
 Parse the `font-family` CSS value into array of font-family name

 @param value value
 @return array of font-family name
 */
+ (NSArray<NSString *> *)fontFamiliesWithCSSValue:(NSString *)value {
    if (value.length == 0) {
        return nil;
    }
    NSArray<NSString *> *args = [value componentsSeparatedByString:@","];
    if (args.count == 0) {
        return nil;
    }
    NSMutableArray<NSString *> *fontFamilies = [NSMutableArray arrayWithCapacity:args.count];
    for (NSString *arg in args) {
        // parse: font-family: "Goudy Bookletter 1911", sans-serif;
        // delete ""
        NSString *fontFamily = [arg stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        // trim white space
        [fontFamily stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        [fontFamilies addObject:fontFamily];
    }
    
    return [fontFamilies copy];
}

+ (NSString *)systemDefaultFontFamily {
    static dispatch_once_t onceToken;
    static NSString *fontFamily;
    dispatch_once(&onceToken, ^{
        UIFont *font = [UIFont systemFontOfSize:12.f];
        fontFamily = font.familyName;
    });
    return fontFamily;
}

- (void)layoutLayer:(CALayer *)layer
{
	
}

@end
