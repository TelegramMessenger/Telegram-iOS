/**
 
 */
#import "SVGKSource.h"

@interface SVGKSourceString : SVGKSource

@property (nonatomic, strong) NSString* rawString;

+ (SVGKSource*)sourceFromContentsOfString:(NSString*)rawString;

@end
