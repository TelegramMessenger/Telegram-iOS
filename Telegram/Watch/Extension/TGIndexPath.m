#import "TGIndexPath.h"

@implementation TGIndexPath

+ (instancetype)indexPathForRow:(NSUInteger)row inSection:(NSUInteger)section
{
    TGIndexPath *indexPath = [[TGIndexPath alloc] init];
    indexPath.section = section;
    indexPath.row = row;
    return indexPath;
}

- (id)copyWithZone:(NSZone *)zone
{
    TGIndexPath *copy = [[[self class] alloc] init];
    if (copy != nil)
    {
        copy.section = self.section;
        copy.row = self.row;
    }
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGIndexPath *indexPath = (TGIndexPath *)object;
    
    return self.section == indexPath.section && self.row == indexPath.row;
}

@end
