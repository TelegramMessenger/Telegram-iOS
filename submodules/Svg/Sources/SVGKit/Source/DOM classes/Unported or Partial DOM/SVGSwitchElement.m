
#import "SVGSwitchElement.h"
#import "CALayerWithChildHitTest.h"
#import "SVGHelperUtilities.h"
#import "NodeList+Mutable.h"

@implementation SVGSwitchElement

@synthesize visibleChildNodes = _visibleChildNodes;


- (CALayer *) newLayer
{
    CALayer* _layer = [CALayerWithChildHitTest layer];
    
    [SVGHelperUtilities configureCALayer:_layer usingElement:self];
    
    return _layer;
}

- (NodeList *)visibleChildNodes
{
    if (_visibleChildNodes)
        return _visibleChildNodes;
    
    _visibleChildNodes = [[NodeList alloc] init];
    
    NSString* localLanguage = [[NSLocale preferredLanguages] firstObject];
    
    for ( SVGElement<ConverterSVGToCALayer> *child in self.childNodes )
    {
        if ([child conformsToProtocol:@protocol(ConverterSVGToCALayer)])
        {
            // spec says if there is no attribute at all then pick it
            if (![child hasAttribute:@"systemLanguage"])
            {
                [_visibleChildNodes.internalArray addObject:child];
                break;
            }
            
            NSString* languages = [child getAttribute:@"systemLanguage"];

            NSArray* languageCodes = [languages componentsSeparatedByCharactersInSet:
                                      [NSCharacterSet characterSetWithCharactersInString:@", \t\n\r"]];

            if ([languageCodes containsObject:localLanguage])
            {
                [_visibleChildNodes.internalArray addObject:child];
                break;
            }
        
        }
    }
    return _visibleChildNodes;
}

- (void)layoutLayer:(CALayer *)layer
{
    
}
@end
