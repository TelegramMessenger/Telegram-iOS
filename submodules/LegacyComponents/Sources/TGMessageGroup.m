#import "TGMessageGroup.h"

@implementation TGMessageGroup

- (instancetype)initWithMinId:(int32_t)minId minTimestamp:(int32_t)minTimestamp maxId:(int32_t)maxId maxTimestamp:(int32_t)maxTimestamp count:(int32_t)count {
    self = [super init];
    if (self != nil) {
        _minId = minId;
        _minTimestamp = minTimestamp;
        _maxId = maxId;
        _maxTimestamp = maxTimestamp;
        _count = count;
    }
    return self;
}

- (bool)isEqual:(id)object {
    return [object isKindOfClass:[TGMessageGroup class]] && ((TGMessageGroup *)object)->_minId == _minId && ((TGMessageGroup *)object)->_maxId == _maxId && ((TGMessageGroup *)object)->_maxTimestamp == _maxTimestamp && ((TGMessageGroup *)object)->_count == _count;
}

- (NSString *)description {
    return [[NSString alloc] initWithFormat:@"(%d...%d at %d)", _minId, _maxId, _maxTimestamp];
}

- (bool)intersects:(TGMessageGroup *)other {
    if (other == nil)
        return false;
    
    return _minId <= other.maxId && _maxId >= other.minId;
}

@end
