/*
 http://www.w3.org/TR/SVG/struct.html#InterfaceSVGElementInstanceList
 
 interface SVGElementInstanceList {
 
 readonly attribute unsigned long length;
 
 SVGElementInstance item(in unsigned long index);
*/

#import "SVGElement.h"

@class SVGElementInstance;

@interface SVGElementInstanceList : SVGElement

@property(nonatomic, readonly) unsigned long length;

-(SVGElementInstance*) item:(unsigned long) index;
						
@end
