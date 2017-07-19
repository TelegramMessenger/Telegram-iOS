#import "TGMessageHole.h"

@implementation TGMessageHole

- (instancetype)initWithMinId:(int32_t)minId minTimestamp:(int32_t)minTimestamp maxId:(int32_t)maxId maxTimestamp:(int32_t)maxTimestamp {
    self = [super init];
    if (self != nil) {
        _minId = minId;
        _minTimestamp = minTimestamp;
        _maxId = maxId;
        _maxTimestamp = maxTimestamp;
    }
    return self;
}

- (bool)isEqual:(id)object {
    return [object isKindOfClass:[TGMessageHole class]] && ((TGMessageHole *)object)->_minId == _minId && ((TGMessageHole *)object)->_maxId == _maxId && ((TGMessageHole *)object)->_maxTimestamp == _maxTimestamp;
}

- (NSString *)description {
    return [[NSString alloc] initWithFormat:@"(%d...%d at %d)", _minId, _maxId, _maxTimestamp];
}

- (bool)intersects:(TGMessageHole *)other {
    if (other == nil)
        return false;
    
    return _minId <= other.maxId && _maxId >= other.minId;
}

- (bool)covers:(TGMessageHole *)other {
    return other.minId >= _minId && other.maxId <= _maxId;
}

- (NSArray *)exclude:(TGMessageHole *)other {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (other.minId <= _minId) {
        if (other.maxId < _maxId) {
            [result addObject:[[TGMessageHole alloc] initWithMinId:other.maxId + 1 minTimestamp:other.maxTimestamp maxId:_maxId maxTimestamp:_maxTimestamp]];
        }
    } else {
        [result addObject:[[TGMessageHole alloc] initWithMinId:_minId minTimestamp:_minTimestamp maxId:other.minId - 1 maxTimestamp:other.minTimestamp]];
        
        if (other.maxId < _maxId) {
            [result addObject:[[TGMessageHole alloc] initWithMinId:other.maxId + 1 minTimestamp:other.maxTimestamp maxId:_maxId maxTimestamp:_maxTimestamp]];
        }
    }
    return result;
}

@end
