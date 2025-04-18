#import "PSLMDBKeyValueReaderWriter.h"

#import "LegacyComponentsInternal.h"

#import "PSLMDBTable.h"
#import "PSLMDBKeyValueCursor.h"

@interface PSLMDBKeyValueReaderWriter ()
{
    PSLMDBTable *_table;
    MDB_dbi _dbi;
    MDB_txn *_txn;
}

@end

@implementation PSLMDBKeyValueReaderWriter

- (instancetype)initWithTable:(PSLMDBTable *)table transaction:(MDB_txn *)transaction
{
    self = [super init];
    if (self != nil)
    {
        _table = table;
        _dbi = table.dbi;
        _txn = transaction;
    }
    return self;
}

- (bool)readValueForRawKey:(PSConstData *)key value:(PSConstData *)value
{
    if (key == NULL)
        return false;
    
    MDB_val mdbKey;
    MDB_val mdbData;
    
    mdbKey.mv_data = (uint8_t *)key->data;
    mdbKey.mv_size = (size_t)key->length;
    
    int rc = 0;
    rc = mdb_get(_txn, _dbi, &mdbKey, &mdbData);
    
    if (rc == MDB_SUCCESS)
    {
        if (value != NULL)
        {
            value->data = mdbData.mv_data;
            value->length = (NSUInteger)mdbData.mv_size;
        }
        
        return true;
    }
    else
    {
        if (rc != MDB_NOTFOUND)
            TGLegacyLog(@"[PSLMDBKeyValueReader mdb_get error %d]", rc);
        
        return false;
    }
}

- (void)writeValueForRawKey:(const uint8_t *)key keyLength:(NSUInteger)keyLength value:(const uint8_t *)value valueLength:(NSUInteger)valueLength
{
    if (key == NULL || keyLength == 0)
        return;
    
    MDB_val mdbKey;
    MDB_val mdbData;
    
    mdbKey.mv_data = (uint8_t *)key;
    mdbKey.mv_size = keyLength;
    
    mdbData.mv_data = (uint8_t *)value;
    mdbData.mv_size = valueLength;
    
    int rc = 0;
    rc = mdb_put(_txn, _dbi, &mdbKey, &mdbData, 0);
    
    if (rc != MDB_SUCCESS)
        TGLegacyLog(@"[PSLMDBKeyValueWriter mdb_put error %d]", rc);
}

- (void)readWithCursor:(void (^)(PSLMDBKeyValueCursor *))readWithCursorBlock
{
    if (!readWithCursorBlock)
        return;
    
    MDB_cursor *cursor = NULL;
    int rc = 0;
    rc = mdb_cursor_open(_txn, _dbi, &cursor);
    if (rc == MDB_SUCCESS)
    {
        readWithCursorBlock([[PSLMDBKeyValueCursor alloc] initWithTable:_table transaction:_txn cursor:cursor]);
        
        mdb_cursor_close(cursor);
    }
    else
        TGLegacyLog(@"[PSLMDBKeyValueWriter mdb_cursor_open error %d]", rc);
}

- (bool)readValueBetweenLowerBoundKey:(PSConstData *)lowerBoundKey upperBoundKey:(PSConstData *)upperBoundKey selectKey:(PSKeyValueReaderSelectKey)selectKey selectedKey:(PSConstData *)selectedKey selectedValue:(PSConstData *)selectedValue
{
    __block bool result = false;
    
    [self enumerateKeysAndValuesBetweenLowerBoundKey:lowerBoundKey upperBoundKey:upperBoundKey options:selectKey == PSKeyValueReaderSelectHigherKey ? PSKeyValueReaderEnumerationReverse : 0 withBlock:^(PSData *key, PSData *value, bool *stop)
    {
        if (selectedKey)
            *selectedKey = *key;
        if (selectedValue)
            *selectedValue = *value;
        
        if (stop)
            *stop = true;
        
        result = true;
    }];
    
    return result;
}

- (void)enumerateKeysAndValuesBetweenLowerBoundKey:(PSConstData *)lowerBoundKey upperBoundKey:(PSConstData *)upperBoundKey options:(NSInteger)options withBlock:(void (^)(PSConstData *key, PSConstData *value, bool *stop))block
{
    if (!block || upperBoundKey == NULL || lowerBoundKey == NULL)
        return;
    
    [self readWithCursor:^(PSLMDBKeyValueCursor *cursor)
    {
        MDB_val upperBoundKeyVal = {.mv_data = (uint8_t *)upperBoundKey->data, .mv_size = upperBoundKey->length};
        MDB_val lowerBoundKeyVal = {.mv_data = (uint8_t *)lowerBoundKey->data, .mv_size = lowerBoundKey->length};
        
        if (options & PSKeyValueReaderEnumerationReverse)
        {
            uint8_t const *positionedKey = upperBoundKey->data;
            NSUInteger positionedKeyLength = upperBoundKey->length;
            
            uint8_t const *positionedValue = NULL;
            NSUInteger positionedValueLength = 0;
            
            if ([cursor positionAt:&positionedKey keyLength:&positionedKeyLength value:&positionedValue valueLength:&positionedValueLength directionIfNotFound:PSKeyValueCursorDirectionBack])
            {
                MDB_val positionedKeyVal = {.mv_data = (uint8_t *)positionedKey, .mv_size = positionedKeyLength};
                
                bool continueSearch = true;
                
                if ((options & PSKeyValueReaderEnumerationUpperBoundExclusive) && mdb_cmp(_txn, _dbi, &upperBoundKeyVal, &positionedKeyVal) == 0)
                {
                    continueSearch = [cursor previous:&positionedKey keyLength:&positionedKeyLength value:&positionedValue valueLength:&positionedValueLength];
                }
                
                if (continueSearch)
                {
                    int cmpResult = mdb_cmp(_txn, _dbi, &positionedKeyVal, &lowerBoundKeyVal);
                    if ((options & PSKeyValueReaderEnumerationLowerBoundExclusive) ? (cmpResult > 0) : (cmpResult >= 0))
                    {
                        bool stop = false;
                        PSData positionedKeyData = {.data = (uint8_t *)positionedKey, .length = positionedKeyLength};
                        PSData positionedValueData = {.data = (uint8_t *)positionedValue, .length = positionedValueLength};
                        block(&positionedKeyData, &positionedValueData, &stop);
                        
                        while (!stop)
                        {
                            if (![cursor previous:&positionedKey keyLength:&positionedKeyLength value:&positionedValue valueLength:&positionedValueLength])
                                break;
                            
                            MDB_val positionedKeyVal = {.mv_data = (uint8_t *)positionedKey, .mv_size = positionedKeyLength};
                            
                            int cmpResult = mdb_cmp(_txn, _dbi, &positionedKeyVal, &lowerBoundKeyVal);
                            if ((options & PSKeyValueReaderEnumerationLowerBoundExclusive) ? (cmpResult > 0) : (cmpResult >= 0))
                            {
                                PSData positionedKeyData = {.data = (uint8_t *)positionedKey, .length = positionedKeyLength};
                                PSData positionedValueData = {.data = (uint8_t *)positionedValue, .length = positionedValueLength};
                                block(&positionedKeyData, &positionedValueData, &stop);
                            }
                            else
                                break;
                        }
                    }
                }
            }
        }
        else
        {
            uint8_t const *positionedKey = lowerBoundKey->data;
            NSUInteger positionedKeyLength = lowerBoundKey->length;
            
            uint8_t const *positionedValue = NULL;
            NSUInteger positionedValueLength = 0;
            
            if ([cursor positionAt:&positionedKey keyLength:&positionedKeyLength value:&positionedValue valueLength:&positionedValueLength directionIfNotFound:PSKeyValueCursorDirectionForward])
            {
                MDB_val positionedKeyVal = {.mv_data = (uint8_t *)positionedKey, .mv_size = positionedKeyLength};
                
                bool continueSearch = true;
                if ((options & PSKeyValueReaderEnumerationLowerBoundExclusive) && mdb_cmp(_txn, _dbi, &lowerBoundKeyVal, &positionedKeyVal) == 0)
                {
                    continueSearch = [cursor next:&positionedKey keyLength:&positionedKeyLength value:&positionedValue valueLength:&positionedValueLength];
                }
                
                if (continueSearch)
                {
                    int cmpResult = mdb_cmp(_txn, _dbi, &positionedKeyVal, &upperBoundKeyVal);
                    if ((options & PSKeyValueReaderEnumerationUpperBoundExclusive) ? (cmpResult < 0) : (cmpResult <= 0))
                    {
                        bool stop = false;
                        PSData positionedKeyData = {.data = (uint8_t *)positionedKey, .length = positionedKeyLength};
                        PSData positionedValueData = {.data = (uint8_t *)positionedValue, .length = positionedValueLength};
                        block(&positionedKeyData, &positionedValueData, &stop);
                        
                        while (!stop)
                        {
                            if (![cursor next:&positionedKey keyLength:&positionedKeyLength value:&positionedValue valueLength:&positionedValueLength])
                                break;
                            
                            MDB_val positionedKeyVal = {.mv_data = (uint8_t *)positionedKey, .mv_size = positionedKeyLength};
                            
                            int cmpResult = mdb_cmp(_txn, _dbi, &positionedKeyVal, &upperBoundKeyVal);
                            if ((options & PSKeyValueReaderEnumerationUpperBoundExclusive) ? (cmpResult < 0) : (cmpResult <= 0))
                            {
                                PSData positionedKeyData = {.data = (uint8_t *)positionedKey, .length = positionedKeyLength};
                                PSData positionedValueData = {.data = (uint8_t *)positionedValue, .length = positionedValueLength};
                                block(&positionedKeyData, &positionedValueData, &stop);
                            }
                            else
                                break;
                        }
                    }
                }
            }
        }
    }];
}

- (bool)deleteValueForRawKey:(PSData *)key
{
    if (key == NULL || key->data == NULL || key->length == 0)
        return false;
    
    MDB_val mdbKey;
    mdbKey.mv_data = (uint8_t *)key->data;
    mdbKey.mv_size = (size_t)key->length;
    
    int rc = 0;
    rc = mdb_del(_txn, _dbi, &mdbKey, NULL);
    
    if (rc != MDB_SUCCESS && rc != MDB_NOTFOUND)
        TGLegacyLog(@"[PSLMDBKeyValueWriter mdb_del error %d]", rc);
    
    return rc == MDB_SUCCESS;
}

- (void)deleteAllValues
{
    MDB_cursor *cursor = NULL;
    int rc = 0;
    rc = mdb_cursor_open(_txn, _dbi, &cursor);
    if (rc == MDB_SUCCESS)
    {
        rc = mdb_cursor_get(cursor, NULL, NULL, MDB_FIRST);
        while (rc == MDB_SUCCESS)
        {
            rc = mdb_cursor_del(cursor, 0);
            rc = mdb_cursor_get(cursor, NULL, NULL, MDB_NEXT);
        }
        mdb_cursor_close(cursor);
    }
}

@end
