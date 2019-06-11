#import "PSLMDBTable.h"

@implementation PSLMDBTable

- (instancetype)initWithDbi:(MDB_dbi)dbi
{
    self = [super init];
    if (self != nil)
    {
        _dbi = dbi;
    }
    return self;
}

@end
