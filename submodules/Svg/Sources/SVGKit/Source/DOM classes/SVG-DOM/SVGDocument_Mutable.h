/**
 Makes the writable properties all package-private, effectively
 */

#import "SVGDocument.h"

@interface SVGDocument ()
@property (nonatomic, strong, readwrite) NSString* title;
@property (nonatomic, strong, readwrite) NSString* referrer;
@property (nonatomic, strong, readwrite) NSString* domain;
@property (nonatomic, strong, readwrite) NSString* URL;
@property (nonatomic, strong, readwrite) SVGSVGElement* rootElement;
@end
