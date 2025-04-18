#import "TGDocumentAttributeAnimated.h"

@implementation TGDocumentAttributeAnimated

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)__unused coder
{
    return [self init];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)__unused coder
{
}

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder
{
    return [self init];
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder
{
}

- (BOOL)isEqual:(id)object
{
    return [object isEqual:[TGDocumentAttributeAnimated class]];
}

@end
