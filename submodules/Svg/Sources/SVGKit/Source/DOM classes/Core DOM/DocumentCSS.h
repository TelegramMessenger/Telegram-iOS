/**
 http://www.w3.org/TR/2000/REC-DOM-Level-2-Style-20001113/css.html#CSS-DocumentCSS
 
 interface DocumentCSS : stylesheets::DocumentStyle {
 CSSStyleDeclaration getOverrideStyle(in Element elt,
 in DOMString pseudoElt);
 */
#import <Foundation/Foundation.h>
#import "DocumentStyle.h"

#import "CSSStyleDeclaration.h"

@class Element;

@protocol DocumentCSS <DocumentStyle>

-(CSSStyleDeclaration *)getOverrideStyle:(Element *)element pseudoElt:(NSString *)pseudoElt;

@end
