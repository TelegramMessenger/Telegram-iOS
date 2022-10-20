#import "TGMediaAttachment.h"

#import "LegacyComponentsInternal.h"

@implementation TGMediaAttachment

@synthesize type = _type;
@synthesize isMeta = _isMeta;

- (void)serialize:(NSMutableData *)__unused data
{
    TGLegacyLog(@"***** TGMediaAttachment: default implementation not provided");
}

@end
