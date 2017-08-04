//
//  ASTextInput.m
//  Modified from YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/4/17.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <AsyncDisplayKit/ASTextInput.h>
#import <AsyncDisplayKit/ASTextUtilities.h>


@implementation ASTextPosition

+ (instancetype)positionWithOffset:(NSInteger)offset {
  return [self positionWithOffset:offset affinity:ASTextAffinityForward];
}

+ (instancetype)positionWithOffset:(NSInteger)offset affinity:(ASTextAffinity)affinity {
  ASTextPosition *p = [self new];
  p->_offset = offset;
  p->_affinity = affinity;
  return p;
}

- (instancetype)copyWithZone:(NSZone *)zone {
  return [self.class positionWithOffset:_offset affinity:_affinity];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@: %p> (%@%@)", self.class, self, @(_offset), _affinity == ASTextAffinityForward ? @"F":@"B"];
}

- (NSUInteger)hash {
  return _offset * 2 + (_affinity == ASTextAffinityForward ? 1 : 0);
}

- (BOOL)isEqual:(ASTextPosition *)object {
  if (!object) return NO;
  return _offset == object.offset && _affinity == object.affinity;
}

- (NSComparisonResult)compare:(ASTextPosition *)otherPosition {
  if (!otherPosition) return NSOrderedAscending;
  if (_offset < otherPosition.offset) return NSOrderedAscending;
  if (_offset > otherPosition.offset) return NSOrderedDescending;
  if (_affinity == ASTextAffinityBackward && otherPosition.affinity == ASTextAffinityForward) return NSOrderedAscending;
  if (_affinity == ASTextAffinityForward && otherPosition.affinity == ASTextAffinityBackward) return NSOrderedDescending;
  return NSOrderedSame;
}

@end



@implementation ASTextRange {
  ASTextPosition *_start;
  ASTextPosition *_end;
}

- (instancetype)init {
  self = [super init];
  if (!self) return nil;
  _start = [ASTextPosition positionWithOffset:0];
  _end = [ASTextPosition positionWithOffset:0];
  return self;
}

- (ASTextPosition *)start {
  return _start;
}

- (ASTextPosition *)end {
  return _end;
}

- (BOOL)isEmpty {
  return _start.offset == _end.offset;
}

- (NSRange)asRange {
  return NSMakeRange(_start.offset, _end.offset - _start.offset);
}

+ (instancetype)rangeWithRange:(NSRange)range {
  return [self rangeWithRange:range affinity:ASTextAffinityForward];
}

+ (instancetype)rangeWithRange:(NSRange)range affinity:(ASTextAffinity)affinity {
  ASTextPosition *start = [ASTextPosition positionWithOffset:range.location affinity:affinity];
  ASTextPosition *end = [ASTextPosition positionWithOffset:range.location + range.length affinity:affinity];
  return [self rangeWithStart:start end:end];
}

+ (instancetype)rangeWithStart:(ASTextPosition *)start end:(ASTextPosition *)end {
  if (!start || !end) return nil;
  if ([start compare:end] == NSOrderedDescending) {
    ASTEXT_SWAP(start, end);
  }
  ASTextRange *range = [ASTextRange new];
  range->_start = start;
  range->_end = end;
  return range;
}

+ (instancetype)defaultRange {
  return [self new];
}

- (instancetype)copyWithZone:(NSZone *)zone {
  return [self.class rangeWithStart:_start end:_end];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@: %p> (%@, %@)%@", self.class, self, @(_start.offset), @(_end.offset - _start.offset), _end.affinity == ASTextAffinityForward ? @"F":@"B"];
}

- (NSUInteger)hash {
  return (sizeof(NSUInteger) == 8 ? OSSwapInt64(_start.hash) : OSSwapInt32(_start.hash)) + _end.hash;
}

- (BOOL)isEqual:(ASTextRange *)object {
  if (!object) return NO;
  return [_start isEqual:object.start] && [_end isEqual:object.end];
}

@end



@implementation ASTextSelectionRect

@synthesize rect = _rect;
@synthesize writingDirection = _writingDirection;
@synthesize containsStart = _containsStart;
@synthesize containsEnd = _containsEnd;
@synthesize isVertical = _isVertical;

- (id)copyWithZone:(NSZone *)zone {
  ASTextSelectionRect *one = [self.class new];
  one.rect = _rect;
  one.writingDirection = _writingDirection;
  one.containsStart = _containsStart;
  one.containsEnd = _containsEnd;
  one.isVertical = _isVertical;
  return one;
}

@end
