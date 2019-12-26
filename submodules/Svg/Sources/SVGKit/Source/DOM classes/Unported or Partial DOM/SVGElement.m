//
//  SVGElement.m
//  SVGKit
//
//  Copyright Matt Rajca 2010-2011. All rights reserved.
//

#import "SVGElement.h"

#import "SVGElement_ForParser.h" //.h" // to solve insane Xcode circular dependencies
#import "StyleSheetList+Mutable.h"

#import "CSSStyleSheet.h"
#import "CSSStyleRule.h"
#import "CSSRuleList+Mutable.h"

#import "SVGGElement.h"

#import "SVGRect.h"

#import "SVGTransformable.h"

@interface SVGElement ()

@property (nonatomic, copy) NSString *stringValue;

@end

/*! main class implementation for the base SVGElement: NOTE: in practice, most of the interesting
 stuff happens in subclasses, e.g.:
 
 SVGShapeElement
 SVGGroupElement
 SVGKImageElement
 SVGLineElement
 SVGPathElement
 ...etc
 */
@implementation SVGElement

@synthesize identifier = _identifier;
@synthesize xmlbase;
@synthesize rootOfCurrentDocumentFragment = _rootOfCurrentDocumentFragment;
@synthesize viewportElement = _viewportElement;
@synthesize stringValue = _stringValue;

@synthesize className; /**< CSS class, from SVGStylable interface */
@synthesize style; /**< CSS style, from SVGStylable interface */

/** from SVGStylable interface */
-(CSSValue*) getPresentationAttribute:(NSString*) name
{
	NSAssert(FALSE, @"getPresentationAttribute: not implemented yet");
	return nil;
}


+ (BOOL)shouldStoreContent {
	return NO;
}

/*! As per the SVG Spec, the local reference to "viewportElement" depends on the values of the
 attributes of the node - does it have a "width" attribute?
 
 NB: by definition, <svg> tags MAY NOT have a width, but they are still viewports */
-(void) reCalculateAndSetViewportElementReferenceUsingFirstSVGAncestor:(SVGElement*) firstAncestor
{
	// NB the root svg element IS a viewport, but SVG Spec defines it as NOT a viewport, and so we will overwrite this later
	BOOL isTagAllowedToBeAViewport = [self.tagName isEqualToString:@"svg"] || [self.tagName isEqualToString:@"foreignObject"]; // NB: Spec lists "image" tag too but only as an IMPLICIT CREATOR - we don't actually handle it (it creates an <SVG> tag ... that will be handled later)
	
	BOOL isTagDefiningAViewport = [self.attributes getNamedItem:@"width"] != nil || [self.attributes getNamedItem:@"height"] != nil;
		
	if( isTagAllowedToBeAViewport && isTagDefiningAViewport )
	{
		SVGKitLogVerbose(@"[%@] WARNING: setting self (tag = %@) to be a viewport", [self class], self.tagName );
		self.viewportElement =  self;
	}
	else
	{
		SVGElement* ancestorsViewport = firstAncestor.viewportElement;
		
		if( ancestorsViewport == nil )
		{
			/**
			 Because of the poorly-designed SVG Spec on Viewports, all the children of the root
			 SVG node will find that their ancestor has a nil viewport! (this is defined in the spec)
			 
			 So, in that special case, we INSTEAD guess that the ancestor itself was the viewport...
			 */
			self.viewportElement = firstAncestor;
		}
		else
			self.viewportElement = ancestorsViewport;
	}
}

/*! Override so that we can automatically set / unset the ownerSVGElement and viewportElement properties,
 as required by SVG Spec */
-(void)setParentNode:(Node *)newParent
{
	[super setParentNode:newParent];
	
	/** SVG Spec: if "outermost SVG tag" then both element refs should be nil */
	if( [self isKindOfClass:[SVGSVGElement class]]
	&& (self.parentNode == nil || ! [self.parentNode isKindOfClass:[SVGElement class]]) )
	{
		self.rootOfCurrentDocumentFragment = nil;
		self.viewportElement = nil;
	}
	else
	{
		/**
		 SVG Spec: we have to set a reference to the "root SVG tag of this part of the tree".
		 
		 If the tree is purely SVGElement nodes / subclasses, that's easy.
		 
		 But if there are custom nodes in there (any other DOM node, for instance), it gets
		more tricky. We have to recurse up the tree until we find an SVGElement we can latch
		 onto
		 */
		
		if( [self isKindOfClass:[SVGSVGElement class]] )
		{
			self.rootOfCurrentDocumentFragment = (SVGSVGElement*) self;
			self.viewportElement = self;
		}
		else
		{
			Node* currentAncestor = newParent;
			SVGElement*	firstAncestorThatIsAnyKindOfSVGElement = nil;
			while( firstAncestorThatIsAnyKindOfSVGElement == nil
				  && currentAncestor != nil ) // if we run out of tree! This would be an error (see below)
			{
				if( [currentAncestor isKindOfClass:[SVGElement class]] )
					firstAncestorThatIsAnyKindOfSVGElement = (SVGElement*) currentAncestor;
				else
					currentAncestor = currentAncestor.parentNode;
			}
			
			if( newParent == nil )
			{
				/** We've set the parent to nil, thereby "orphaning" this Node and the tree underneath it.
				 
				 This usually happens when you remove a Node from its parent.
				 
				 I'm not sure what the spec expects at that point - you have a valid DOM tree, but *not* a valid SVG fragment;
				 or maybe it is valid, for some special-case kind of SVG fragment definition?
				 
				 TODO: this may also relate to SVG <use> nodes and instancing: if you're fixing that code, check this comment to see if you can improve it.
				 
				 For now: we simply "do nothing but set everything to nil"
				 */
				SVGKitLogWarn( @"SVGElement has had its parent set to nil; this makes the element and tree beneath it no-longer-valid SVG data; this may require fix-up if you try to re-add that SVGElement or any of its children back to an existing/new SVG tree");
				self.rootOfCurrentDocumentFragment = nil;
			}
			else
			{
				NSAssert( firstAncestorThatIsAnyKindOfSVGElement != nil, @"This node has no valid SVG tags as ancestor, but it's not an <svg> tag, so this is an impossible SVG file" );
				
				
				if( [firstAncestorThatIsAnyKindOfSVGElement isKindOfClass:[SVGSVGElement class]] )
					self.rootOfCurrentDocumentFragment = (SVGSVGElement*) firstAncestorThatIsAnyKindOfSVGElement;
				else
					self.rootOfCurrentDocumentFragment = firstAncestorThatIsAnyKindOfSVGElement.rootOfCurrentDocumentFragment;
				
				[self reCalculateAndSetViewportElementReferenceUsingFirstSVGAncestor:firstAncestorThatIsAnyKindOfSVGElement];
				
#if DEBUG_SVG_ELEMENT_PARSING
				SVGKitLogVerbose(@"viewport Element = %@ ... for node/element = %@", self.viewportElement, self.tagName);
#endif
			}
		}
	}
}

- (void)setRootOfCurrentDocumentFragment:(SVGSVGElement *)root {
    _rootOfCurrentDocumentFragment = root;
    for (Node *child in self.childNodes)
        if ([child isKindOfClass:SVGElement.class])
            ((SVGElement *) child).rootOfCurrentDocumentFragment = root;
}

- (void)setViewportElement:(SVGElement *)viewport {
    _viewportElement = viewport;
    for (Node *child in self.childNodes)
        if ([child isKindOfClass:SVGElement.class])
            ((SVGElement *) child).viewportElement = viewport;
}


- (void)loadDefaults {
	// to be overriden by subclasses
}

-(SVGLength*) getAttributeAsSVGLength:(NSString*) attributeName
{
	NSString* attributeAsString = [self getAttribute:attributeName];
	SVGLength* svgLength = [SVGLength svgLengthFromNSString:attributeAsString];
	
	return svgLength;
}

- (void)postProcessAttributesAddingErrorsTo:(SVGKParseResult *)parseResult  {
	// to be overriden by subclasses
	// make sure super implementation is called
	
	if( [[self getAttribute:@"id"] length] > 0 )
		self.identifier = [self getAttribute:@"id"];
	
	/** CSS styles and classes */
	if ( [self getAttributeNode:@"style"] )
	{
		self.style = [[CSSStyleDeclaration alloc] init];
		self.style.cssText = [self getAttribute:@"style"]; // causes all the LOCALLY EMBEDDED style info to be parsed
	}
	if( [self getAttributeNode:@"class"])
	{
		self.className = [self getAttribute:@"class"];
	}
	
	
	/**
	 http://www.w3.org/TR/SVG/coords.html#TransformAttribute
	 
	 The available types of transform definitions include:
	 
	 * matrix(<a> <b> <c> <d> <e> <f>), which specifies a transformation in the form of a transformation matrix of six values. matrix(a,b,c,d,e,f) is equivalent to applying the transformation matrix [a b c d e f].
	 
	 * translate(<tx> [<ty>]), which specifies a translation by tx and ty. If <ty> is not provided, it is assumed to be zero.
	 
	 * scale(<sx> [<sy>]), which specifies a scale operation by sx and sy. If <sy> is not provided, it is assumed to be equal to <sx>.
	 
	 * rotate(<rotate-angle> [<cx> <cy>]), which specifies a rotation by <rotate-angle> degrees about a given point.
	 If optional parameters <cx> and <cy> are not supplied, the rotate is about the origin of the current user coordinate system. The operation corresponds to the matrix [cos(a) sin(a) -sin(a) cos(a) 0 0].
	 If optional parameters <cx> and <cy> are supplied, the rotate is about the point (cx, cy). The operation represents the equivalent of the following specification: translate(<cx>, <cy>) rotate(<rotate-angle>) translate(-<cx>, -<cy>).
	 
	 * skewX(<skew-angle>), which specifies a skew transformation along the x-axis.
	 
	 * skewY(<skew-angle>), which specifies a skew transformation along the y-axis.
	 */
	if( [[self getAttribute:@"transform"] length] > 0  || [[self getAttribute:@"gradientTransform"] length] > 0)
	{
		if( [self conformsToProtocol:@protocol(SVGTransformable)] )
		{
			SVGElement<SVGTransformable>* selfTransformable = (SVGElement<SVGTransformable>*) self;
			
		/**
		 http://www.w3.org/TR/SVG/coords.html#TransformAttribute
		 
		 The individual transform definitions are separated by whitespace and/or a comma. 
		 */
		NSString* value = [self getAttribute:@"transform"];
            if (!value.length) {
                value = [self getAttribute:@"gradientTransform"];
            }
		
		NSError* error = nil;
		NSRegularExpression* regexpTransformListItem = [NSRegularExpression regularExpressionWithPattern:@"[^\\(\\),]*\\([^\\)]*" options:0 error:&error]; // anything except space and brackets ... followed by anything except open bracket ... plus anything until you hit a close bracket
		
		[regexpTransformListItem enumerateMatchesInString:value options:0 range:NSMakeRange(0, [value length]) usingBlock:
		 ^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
		{
			NSString* transformString = [value substringWithRange:[result range]];
			
			//EXTREME DEBUG: SVGKitLogVerbose(@"[%@] DEBUG: found a transform element (should be command + open bracket + args + close bracket) = %@", [self class], transformString);
			
			NSRange loc = [transformString rangeOfString:@"("];
			if( loc.length == 0 )
			{
				SVGKitLogError(@"[%@] ERROR: input file is illegal, has an item in the SVG transform attribute which has no open-bracket. Item = %@, transform attribute value = %@", [self class], transformString, value );
				return;
			}
			NSString* command = [transformString substringToIndex:loc.location];
            NSString* rawParametersString = [transformString substringFromIndex:loc.location+1];
			NSArray* parameterStrings = [rawParametersString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
			
			/** if you get ", " (comma AND space), Apple sends you an extra 0-length match - "" - between your args. We strip that here */
			parameterStrings = [parameterStrings filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
			
			//EXTREME DEBUG: SVGKitLogVerbose(@"[%@] DEBUG: found parameters = %@", [self class], parameterStrings);
			
			command = [command stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
			
			if( [command isEqualToString:@"translate"] )
			{
				CGFloat xtrans = [(NSString*)[parameterStrings objectAtIndex:0] floatValue];
				CGFloat ytrans = [parameterStrings count] > 1 ? [(NSString*)[parameterStrings objectAtIndex:1] floatValue] : 0.0;
				
				CGAffineTransform nt = CGAffineTransformMakeTranslation(xtrans, ytrans);
				selfTransformable.transform = CGAffineTransformConcat( nt, selfTransformable.transform ); // Apple's method appears to be backwards, and not doing what Apple's docs state
				
			}
			else if( [command isEqualToString:@"scale"] )
			{
				CGFloat xScale = [(NSString*)[parameterStrings objectAtIndex:0] floatValue];
				CGFloat yScale = [parameterStrings count] > 1 ? [(NSString*)[parameterStrings objectAtIndex:1] floatValue] : xScale;
				
				CGAffineTransform nt = CGAffineTransformMakeScale(xScale, yScale);
				selfTransformable.transform = CGAffineTransformConcat( nt, selfTransformable.transform ); // Apple's method appears to be backwards, and not doing what Apple's docs state
			}
			else if( [command isEqualToString:@"matrix"] )
			{
				CGFloat a = [(NSString*)[parameterStrings objectAtIndex:0] floatValue];
				CGFloat b = [(NSString*)[parameterStrings objectAtIndex:1] floatValue];
				CGFloat c = [(NSString*)[parameterStrings objectAtIndex:2] floatValue];
				CGFloat d = [(NSString*)[parameterStrings objectAtIndex:3] floatValue];
				CGFloat tx = [(NSString*)[parameterStrings objectAtIndex:4] floatValue];
				CGFloat ty = [(NSString*)[parameterStrings objectAtIndex:5] floatValue];
				
				CGAffineTransform nt = CGAffineTransformMake(a, b, c, d, tx, ty );
				selfTransformable.transform = CGAffineTransformConcat( nt, selfTransformable.transform ); // Apple's method appears to be backwards, and not doing what Apple's docs state
				
			}
			else if( [command isEqualToString:@"rotate"] )
			{
				/**
				 This section merged from warpflyght's commit:
				 
				 https://github.com/warpflyght/SVGKit/commit/c1bd9b3d0607635dda14ec03579793fc682763d9
				 
				 */
				if( [parameterStrings count] == 1)
				{
					CGFloat degrees = [[parameterStrings objectAtIndex:0] floatValue];
					CGFloat radians = degrees * M_PI / 180.0;
                    
					selfTransformable.transform = CGAffineTransformRotate(selfTransformable.transform, radians);
//					CGAffineTransform nt = CGAffineTransformMakeRotation(radians);
//					selfTransformable.transform = CGAffineTransformConcat( nt, selfTransformable.transform ); // Apple's method appears to be backwards, and not doing what Apple's docs state
				}
				else if( [parameterStrings count] == 3)
				{
					CGFloat degrees = [[parameterStrings objectAtIndex:0] floatValue];
					CGFloat radians = degrees * M_PI / 180.0;
					CGFloat centerX = [[parameterStrings objectAtIndex:1] floatValue];
					CGFloat centerY = [[parameterStrings objectAtIndex:2] floatValue];
                    
                    selfTransformable.transform = CGAffineTransformTranslate(selfTransformable.transform, centerX, centerY);
                    selfTransformable.transform = CGAffineTransformRotate(selfTransformable.transform, radians);
                    selfTransformable.transform = CGAffineTransformTranslate(selfTransformable.transform, -1.0 * centerX, -1.0 * centerY);
//					CGAffineTransform nt = CGAffineTransformIdentity;
//					nt = CGAffineTransformConcat( nt, CGAffineTransformMakeTranslation(centerX, centerY) );
//					nt = CGAffineTransformConcat( nt, CGAffineTransformMakeRotation(radians) );
//					nt = CGAffineTransformConcat( nt, CGAffineTransformMakeTranslation(-1.0 * centerX, -1.0 * centerY) );
//					selfTransformable.transform = CGAffineTransformConcat( nt, selfTransformable.transform ); // Apple's method appears to be backwards, and not doing what Apple's docs state
					} else
					{
					SVGKitLogError(@"[%@] ERROR: input file is illegal, has an SVG matrix transform attribute without the required 1 or 3 parameters. Item = %@, transform attribute value = %@", [self class], transformString, value );
					return;
				}
			}
			else if( [command isEqualToString:@"skewX"] )
			{
                CGFloat degrees = [[parameterStrings objectAtIndex:0] floatValue];
                CGFloat radians = degrees * M_PI / 180.0;
                
                CGAffineTransform nt = CGAffineTransformMake(1, 0, tan(radians), 1, 0, 0);
                selfTransformable.transform = CGAffineTransformConcat( nt, selfTransformable.transform );
			}
			else if( [command isEqualToString:@"skewY"] )
			{
                CGFloat degrees = [[parameterStrings objectAtIndex:0] floatValue];
                CGFloat radians = degrees * M_PI / 180.0;
                
                CGAffineTransform nt = CGAffineTransformMake(1, tan(radians), 0, 1, 0, 0);
                selfTransformable.transform = CGAffineTransformConcat( nt, selfTransformable.transform );
			}
			else
			{
				NSAssert( FALSE, @"Not implemented yet: transform = %@ %@", command, transformString );
			}
		}];
		
		//DEBUG: SVGKitLogVerbose(@"[%@] Set local / relative transform = (%2.2f, %2.2f // %2.2f, %2.2f) + (%2.2f, %2.2f translate)", [self class], selfTransformable.transform.a, selfTransformable.transform.b, selfTransformable.transform.c, selfTransformable.transform.d, selfTransformable.transform.tx, selfTransformable.transform.ty );
		}
	}

}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@ %p | id=%@ | prefix:localName=%@:%@ | tagName=%@ | stringValue=%@ | children=%ld>", 
			[self class], self, _identifier, self.prefix, self.localName, self.tagName, _stringValue, (unsigned long)self.childNodes.length];
}

#pragma mark - Objective-C init methods (not in SVG Spec - the official spec has no explicit way to create nodes, which is clearly a bug in the Spec. Until they fix the spec, we have to do something or else SVG would be unusable)

- (id)initWithLocalName:(NSString*) n attributes:(NSMutableDictionary*) attributes
{
	self = [super initWithLocalName:n attributes:attributes];
	if( self )
	{
		[self loadDefaults];
		
		if( [self conformsToProtocol:@protocol(SVGTransformable)] )
		{
			SVGElement<SVGTransformable>* selfTransformable = (SVGElement<SVGTransformable>*) self;
		selfTransformable.transform = CGAffineTransformIdentity;
		}
	}
	return self;
}
- (id)initWithQualifiedName:(NSString*) n inNameSpaceURI:(NSString*) nsURI attributes:(NSMutableDictionary*) attributes
{
	self = [super initWithQualifiedName:n inNameSpaceURI:nsURI attributes:attributes];
	if( self )
	{
		[self loadDefaults];
		
		if( [self conformsToProtocol:@protocol(SVGTransformable)] )
		{
			SVGElement<SVGTransformable>* selfTransformable = (SVGElement<SVGTransformable>*) self;
		selfTransformable.transform = CGAffineTransformIdentity;
		}
	}
	return self;
}

- (NSRange) nextSelectorGroupFromText:(NSString *) selectorText startFrom:(NSRange) previous
{
    previous.location = previous.location + previous.length;
    if( previous.location < selectorText.length )
    {
        if( [selectorText characterAtIndex:previous.location] == ',' )
            previous.location = previous.location + 1;
        
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        while( previous.location < selectorText.length && [whitespace characterIsMember:[selectorText characterAtIndex:previous.location]] )
            previous.location = previous.location + 1;
        
        if( previous.location < selectorText.length ) {
            previous.length = selectorText.length - previous.location;
            NSRange nextGroup = [selectorText rangeOfString:@"," options:0 range:previous];
            if( nextGroup.location == NSNotFound )
                return previous;
            else
                return NSMakeRange(previous.location, nextGroup.location - previous.location);
        }
    }
    return NSMakeRange(NSNotFound, -1);
}

- (NSRange) nextSelectorRangeFromText:(NSString *) selectorText startFrom:(NSRange) previous
{
    NSMutableCharacterSet *identifier = [NSMutableCharacterSet alphanumericCharacterSet];
    [identifier addCharactersInString:@"-_"];
	NSCharacterSet *selectorStart = [NSCharacterSet characterSetWithCharactersInString:@"#."];
    
    NSInteger start = -1;
    NSUInteger end = 0;
    for( NSUInteger i = previous.location + previous.length; i < selectorText.length; i++ )
    {
        unichar c = [selectorText characterAtIndex:i];
        if( [selectorStart characterIsMember:c] )
        {
            if( start == -1 )
                start = i;
            else
                break;
        }
        else if( [identifier characterIsMember:c] )
        {
            if( start == -1 )
                start = i;
            end = i;
        }
        else if( start != -1 )
        {
            break;
        }
    }
    
    if( start != -1 )
        return NSMakeRange(start, end + 1 - start);
    else
        return NSMakeRange(NSNotFound, -1);
}

- (BOOL) selector:(NSString *)selector appliesTo:(SVGElement *) element specificity:(NSInteger*) specificity
{
    if( [selector characterAtIndex:0] == '.' )
    {
        if( element.className != nil )
        {
            NSScanner *classNameScanner = [NSScanner scannerWithString:element.className];
            NSMutableCharacterSet *whitespaceAndCommaSet = [NSMutableCharacterSet whitespaceCharacterSet];
            NSString *substring;
            
            [whitespaceAndCommaSet addCharactersInString:@","];
            selector = [selector substringFromIndex:1];
            __block BOOL matched = NO;

            while ([classNameScanner scanUpToCharactersFromSet:whitespaceAndCommaSet intoString:&substring])
            {
                if( [substring isEqualToString:selector] )
                {
                    matched = YES;
                    break;
                }
				
                if (!classNameScanner.isAtEnd)
                    classNameScanner.scanLocation = classNameScanner.scanLocation+1L;
            }
            if( matched )
            {
                *specificity += 100;
                return YES;
            }
        }
    }
    else if( [selector characterAtIndex:0] == '#' )
    {
        if( element.identifier != nil && [element.identifier isEqualToString:[selector substringFromIndex:1]] )
        {
            *specificity += 10000;
            return YES;
        }
    }
    else if( element.nodeName != nil && [element.nodeName isEqualToString:selector] )
    {
        *specificity += 1;
        return YES;
    }
    else if( [selector isEqualToString:@"*"] )
    {
        return YES;
    }
    return NO;
}

- (BOOL) styleRule:(CSSStyleRule *) styleRule appliesTo:(SVGElement *) element specificity:(NSInteger*) specificity
{
    NSRange nextGroup = [self nextSelectorGroupFromText:styleRule.selectorText startFrom:NSMakeRange(0, 0)];
    while( nextGroup.location != NSNotFound )
    {
        NSRange nextRule = [self nextSelectorRangeFromText:styleRule.selectorText startFrom:NSMakeRange(nextGroup.location, 0)];
        
        BOOL match = nextRule.location != NSNotFound;
        while( nextRule.location != NSNotFound )
        {
            if( ![self selector:[styleRule.selectorText substringWithRange:nextRule] appliesTo:element specificity:specificity] )
            {
                match = NO;
                break;
            }
            nextRule = [self nextSelectorRangeFromText:styleRule.selectorText startFrom:nextRule];
            if( nextRule.location > (nextGroup.location + nextGroup.length) )
                break;
        }
        
        if( match )
            return YES;
        
        nextGroup = [self nextSelectorGroupFromText:styleRule.selectorText startFrom:nextGroup];
    }
    return NO;
}

#pragma mark - CSS cascading special attributes
-(NSString*) cascadedValueForStylableProperty:(NSString*) stylableProperty
{
	return [self cascadedValueForStylableProperty:stylableProperty inherit:YES];
}

-(NSString*) cascadedValueForStylableProperty:(NSString*) stylableProperty inherit:(BOOL)inherit
{
	/**
	 This is the core implementation of Cascading Style Sheets, inside SVG.
	 
	 c.f.: http://www.w3.org/TR/SVG/styling.html
	 
	 In SVG, the set of things that can be cascaded is strictly defined, c.f.:
	 
	 http://www.w3.org/TR/SVG/propidx.html
	 
	 For each of those, the implementation is the same.
	 
	 ********* WAWRNING: THE CURRENT IMPLEMENTATION BELOW IS VERY MUCH INCOMPLETE, BUT IT WORKS FOR VERY SIMPLE SVG'S ************
	 */
    NSString* localStyleValue = [self.style getPropertyValue:stylableProperty];
    
    if( localStyleValue != nil )
        return localStyleValue;
    
    /** we have a locally declared CSS class; let's go hunt for it in the document's stylesheets */
    
    @autoreleasepool /** DOM / CSS is insanely verbose, so this is likely to generate a lot of crud objects */
    {
        CSSStyleRule *mostSpecificRule = nil;
        NSInteger mostSpecificity = -1;
        
        for( StyleSheet* genericSheet in self.rootOfCurrentDocumentFragment.styleSheets.internalArray.reverseObjectEnumerator ) // because it's far too much effort to use CSS's low-quality iteration here...
        {
            if( [genericSheet isKindOfClass:[CSSStyleSheet class]])
            {
                CSSStyleSheet* cssSheet = (CSSStyleSheet*) genericSheet;
                
                for( CSSRule* genericRule in cssSheet.cssRules.internalArray.reverseObjectEnumerator)
                {
                    if( [genericRule isKindOfClass:[CSSStyleRule class]])
                    {
                        CSSStyleRule* styleRule = (CSSStyleRule*) genericRule;
                        
                        if( [styleRule.style getPropertyCSSValue:stylableProperty] != nil )
                        {
                            NSInteger ruleSpecificity = 0;
                            if( [self styleRule:styleRule appliesTo:self specificity:&ruleSpecificity] )
                            {
                                if( ruleSpecificity > mostSpecificity ) {
                                    mostSpecificity = ruleSpecificity;
                                    mostSpecificRule = styleRule;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if( mostSpecificRule != nil )
            return [mostSpecificRule.style getPropertyValue:stylableProperty];
    }
    
    /** if there's a local property, use that */
    if( [self hasAttribute:stylableProperty])
        return [self getAttribute:stylableProperty];
    
    if( inherit )
    {
        /** Finally: move up the tree until you find a <G> or <SVG> node, and ask it to provide the value
         */
        
        Node* parentElement = self.parentNode;
        while( parentElement != nil
              && ! [parentElement isKindOfClass:[SVGGElement class]]
              && ! [parentElement isKindOfClass:[SVGSVGElement class]])
        {
            parentElement = parentElement.parentNode;
        }
        
        if( parentElement == nil )
        {
            return nil; // give up!
        }
        else
        {
            return [((SVGElement*)parentElement) cascadedValueForStylableProperty:stylableProperty];
        }
    }
    else
    {
        return nil;
    }
}

@end
