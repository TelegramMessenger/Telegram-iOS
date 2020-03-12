#import "TGMessageHole.h"

@implementation TGMessageHole

- (instancetype)initWithMinId:(int32_t)minId minTimestamp:(int32_t)minTimestamp maxId:(int32_t)maxId maxTimestamp:(int32_t)maxTimestamp {
    self = [super init];
    if (self != nil) {
        _minId = minId;
        _minTimestamp = minTimestamp;
        _minPeerId = 0;
        _maxId = maxId;
        _maxTimestamp = maxTimestamp;
        _maxPeerId = 0;
    }
    return self;
}

- (instancetype)initWithMinId:(int32_t)minId minTimestamp:(int32_t)minTimestamp minPeerId:(int64_t)minPeerId maxId:(int32_t)maxId maxTimestamp:(int32_t)maxTimestamp maxPeerId:(int64_t)maxPeerId {
    self = [super init];
    if (self != nil) {
        _minId = minId;
        _minTimestamp = minTimestamp;
        _minPeerId = minPeerId;
        _maxId = maxId;
        _maxTimestamp = maxTimestamp;
        _maxPeerId = maxPeerId;
    }
    return self;
}

- (bool)isEqual:(id)object {
    return [object isKindOfClass:[TGMessageHole class]] && ((TGMessageHole *)object)->_minId == _minId && ((TGMessageHole *)object)->_maxId == _maxId && ((TGMessageHole *)object)->_maxTimestamp == _maxTimestamp && ((TGMessageHole *)object)->_minPeerId == _minPeerId && ((TGMessageHole *)object)->_maxPeerId == _maxPeerId;
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

- (bool)intersectsByTimestamp:(TGMessageHole *)other {
    if (other == nil)
        return false;
    
    return _minTimestamp <= other.maxTimestamp && _maxTimestamp >= other.minTimestamp;
}

- (bool)coversByTimestamp:(TGMessageHole *)other {
    return other.minTimestamp >= _minTimestamp && other.maxTimestamp <= _maxTimestamp;
}

- (NSArray *)excludeByTimestamp:(TGMessageHole *)other {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (other.minTimestamp <= _minTimestamp) {
        if (other.maxTimestamp < _maxTimestamp) {
            [result addObject:[[TGMessageHole alloc] initWithMinId:other.maxId minTimestamp:other.maxTimestamp minPeerId:other.maxPeerId maxId:_maxId maxTimestamp:_maxTimestamp maxPeerId:_maxPeerId]];
        }
    } else {
        [result addObject:[[TGMessageHole alloc] initWithMinId:_minId minTimestamp:_minTimestamp minPeerId:_minPeerId maxId:other.minId maxTimestamp:other.minTimestamp maxPeerId:other.minPeerId]];
        
        if (other.maxTimestamp < _maxTimestamp) {
            [result addObject:[[TGMessageHole alloc] initWithMinId:other.maxId minTimestamp:other.maxTimestamp minPeerId:other.maxPeerId maxId:_maxId maxTimestamp:_maxTimestamp maxPeerId:_maxPeerId]];
        }
    }
    return result;
}

@end
