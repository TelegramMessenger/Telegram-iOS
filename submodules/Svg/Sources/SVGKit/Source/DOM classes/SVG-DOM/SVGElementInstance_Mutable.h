#import "SVGElementInstance.h"

@interface SVGElementInstance ()
@property(nonatomic,weak, readwrite) SVGElement* correspondingElement;
@property(nonatomic,weak, readwrite) SVGUseElement* correspondingUseElement;
@property(nonatomic,strong, readwrite) SVGElementInstance* parentNode;
@property(nonatomic,strong, readwrite) SVGElementInstanceList* childNodes;
@end
