/**
 
 */
#import "SVGKSource.h"

@interface SVGKSourceURL : SVGKSource

@property (nonatomic, strong) NSURL* URL;

+ (SVGKSource*)sourceFromURL:(NSURL*)u;

@end
