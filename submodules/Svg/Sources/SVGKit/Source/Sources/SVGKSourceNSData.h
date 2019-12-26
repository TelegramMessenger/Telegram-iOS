/**
 
 */
#import "SVGKSource.h"

@interface SVGKSourceNSData : SVGKSource

@property (nonatomic, strong) NSData* rawData;
@property (nonatomic, strong) NSURL* effectiveURL;

+ (SVGKSource*)sourceFromData:(NSData*)data URLForRelativeLinks:(NSURL*) url;

@end
