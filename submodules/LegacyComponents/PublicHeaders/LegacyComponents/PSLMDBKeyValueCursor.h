#import <Foundation/Foundation.h>

#import <LegacyComponents/lmdb.h>

@class PSLMDBTable;

typedef enum {
    PSKeyValueCursorDirectionForward = 0,
    PSKeyValueCursorDirectionBack = 1
} PSKeyValueCursorDirection;

@interface PSLMDBKeyValueCursor : NSObject

- (instancetype)initWithTable:(PSLMDBTable *)table transaction:(MDB_txn *)transaction cursor:(MDB_cursor *)cursor;

- (bool)positionAt:(uint8_t const **)key keyLength:(NSUInteger *)keyLength value:(uint8_t const **)value valueLength:(NSUInteger *)valueLength directionIfNotFound:(PSKeyValueCursorDirection)directionIfNotFound;
- (bool)previous:(uint8_t const **)key keyLength:(NSUInteger *)keyLength value:(uint8_t const **)value valueLength:(NSUInteger *)valueLength;
- (bool)next:(uint8_t const **)key keyLength:(NSUInteger *)keyLength value:(uint8_t const **)value valueLength:(NSUInteger *)valueLength;

@end
