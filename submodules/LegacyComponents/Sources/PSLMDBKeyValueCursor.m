#import "PSLMDBKeyValueCursor.h"

#import "LegacyComponentsInternal.h"

#import "PSLMDBTable.h"

@interface PSLMDBKeyValueCursor ()
{
    MDB_dbi _dbi;
    MDB_txn *_txn;
    MDB_cursor *_cursor;
}

@end

@implementation PSLMDBKeyValueCursor

- (instancetype)initWithTable:(PSLMDBTable *)table transaction:(MDB_txn *)transaction cursor:(MDB_cursor *)cursor
{
    self = [super init];
    if (self != nil)
    {
        _dbi = table.dbi;
        _txn = transaction;
        _cursor = cursor;
    }
    return self;
}

- (bool)positionAt:(uint8_t const **)key keyLength:(NSUInteger *)keyLength value:(uint8_t const **)value valueLength:(NSUInteger *)valueLength directionIfNotFound:(PSKeyValueCursorDirection)directionIfNotFound
{
    if (key == NULL || keyLength == 0)
        return false;
    
    MDB_val mdbKey = {.mv_data = (void *)*key, .mv_size = *keyLength};
    MDB_val mdbData = {.mv_data = NULL, .mv_size = 0};
    
    int rc = 0;
    rc = mdb_cursor_get(_cursor, &mdbKey, &mdbData, directionIfNotFound == PSKeyValueCursorDirectionForward ? MDB_SET_RANGE : MDB_SET_KEY);
    
    if (rc == MDB_SUCCESS)
    {
        *key = mdbKey.mv_data;
        *keyLength = mdbKey.mv_size;
        
        if (value != NULL)
            *value = mdbData.mv_data;
        
        if (valueLength != NULL)
            *valueLength = mdbData.mv_size;
        
        return true;
    }
    else if (rc == MDB_NOTFOUND)
    {
        if (directionIfNotFound == PSKeyValueCursorDirectionBack)
            return [self previous:key keyLength:keyLength value:value valueLength:valueLength];
    }
    else
    {
        TGLegacyLog(@"[PSLMDBKeyValueReader mdb_cursor_get error %d]", rc);
        
        return false;
    }
    
    return false;
}

- (bool)previous:(uint8_t const **)key keyLength:(NSUInteger *)keyLength value:(uint8_t const **)value valueLength:(NSUInteger *)valueLength
{
    if (key == NULL || keyLength == 0)
        return false;
    
    MDB_val mdbKey = {.mv_data = NULL, .mv_size = 0};
    MDB_val mdbData = {.mv_data = NULL, .mv_size = 0};
    
    int rc = 0;
    rc = mdb_cursor_get(_cursor, &mdbKey, &mdbData, MDB_PREV);
    
    if (rc == MDB_SUCCESS)
    {
        *key = mdbKey.mv_data;
        *keyLength = mdbKey.mv_size;
        
        if (value != NULL)
            *value = mdbData.mv_data;
        
        if (valueLength != NULL)
            *valueLength = mdbData.mv_size;
        
        return true;
    }
    else
    {
        if (rc != MDB_NOTFOUND)
            TGLegacyLog(@"[PSLMDBKeyValueReader mdb_cursor_get error %d]", rc);
        
        return false;
    }
    
    return false;
}

- (bool)next:(uint8_t const **)key keyLength:(NSUInteger *)keyLength value:(uint8_t const **)value valueLength:(NSUInteger *)valueLength
{
    if (key == NULL || keyLength == 0)
        return false;
    
    MDB_val mdbKey = {.mv_data = NULL, .mv_size = 0};
    MDB_val mdbData = {.mv_data = NULL, .mv_size = 0};
    
    int rc = 0;
    rc = mdb_cursor_get(_cursor, &mdbKey, &mdbData, MDB_NEXT);
    
    if (rc == MDB_SUCCESS)
    {
        *key = mdbKey.mv_data;
        *keyLength = mdbKey.mv_size;
        
        if (value != NULL)
            *value = mdbData.mv_data;
        
        if (valueLength != NULL)
            *valueLength = mdbData.mv_size;
        
        return true;
    }
    else
    {
        if (rc != MDB_NOTFOUND)
            TGLegacyLog(@"[PSLMDBKeyValueReader mdb_cursor_get error %d]", rc);
        
        return false;
    }
    
    return false;
}

@end
