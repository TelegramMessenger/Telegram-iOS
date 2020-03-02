#import "PSLMDBKeyValueStore.h"

#import "LegacyComponentsInternal.h"

#import "lmdb.h"

#import "PSLMDBTable.h"
#import "PSLMDBKeyValueReaderWriter.h"

@interface PSLMDBKeyValueStore ()
{
    NSString *_path;
    MDB_env *_env;
    PSLMDBTable *_table;
}

@end

@implementation PSLMDBKeyValueStore

+ (instancetype)storeWithPath:(NSString *)path size:(NSUInteger)size
{
    if (path.length == 0)
        return nil;
    
    PSLMDBKeyValueStore *result = [[PSLMDBKeyValueStore alloc] init];
    if (result != nil)
    {
        result->_path = path;
        
        if (![result _open:size])
        {
            [result close];
            
            return nil;
        }
    }
    
    return result;
}

- (bool)_open:(NSUInteger)size
{
    int rc = 0;
    
    rc = mdb_env_create(&_env);
    if (rc != MDB_SUCCESS)
        return false;
    
    bool createDirectory = false;
    
    BOOL isDirectory = false;
    if ([[NSFileManager defaultManager] fileExistsAtPath:_path isDirectory:&isDirectory])
    {
        if (!isDirectory)
        {
            [[NSFileManager defaultManager] removeItemAtPath:_path error:nil];
            createDirectory = true;
        }
    }
    else
        createDirectory = true;
    
    if (createDirectory)
        [[NSFileManager defaultManager] createDirectoryAtPath:_path withIntermediateDirectories:true attributes:nil error:nil];
    
    mdb_env_set_mapsize(_env, (size_t)size);
    mdb_env_set_maxdbs(_env, 64);
    
    rc = mdb_env_open(_env, [_path UTF8String], MDB_NOSYNC, 0664);
    if (rc != MDB_SUCCESS)
    {
        if (rc == MDB_INVALID)
        {
            [[NSFileManager defaultManager] removeItemAtPath:_path error:nil];
            [[NSFileManager defaultManager] createDirectoryAtPath:_path withIntermediateDirectories:true attributes:nil error:nil];
            
            rc = mdb_env_create(&_env);
            mdb_env_set_mapsize(_env, (size_t)size);
            mdb_env_set_maxdbs(_env, 64);
            rc = mdb_env_open(_env, [_path UTF8String], MDB_NOSYNC, 0664);
            
            if (rc == MDB_INVALID)
                return false;
        }
        else
            return false;
    }
    
    int removedReaders = 0;
    rc = mdb_reader_check(_env, &removedReaders);
    
    if (removedReaders != 0)
        TGLegacyLog(@"[PSLMDBKeyValueStore removed %d stale readers]", removedReaders);
    
    _table = [self _createTableWithName:@"main"];
    
    return true;
}

- (void)close
{
    mdb_close(_env, _table.dbi);
    
    mdb_env_close(_env);
    
    _env = NULL;
}

- (void)sync
{
    int rc = 0;
    rc = mdb_env_sync(_env, 1);
    
    if (rc != MDB_SUCCESS)
        TGLegacyLog(@"[PSLMDBKeyValueStore sync: mdb_env_sync error %d]", rc);
}

- (void)panic
{
    
}

- (PSLMDBTable *)_createTableWithName:(NSString *)name
{
    PSLMDBTable *result = nil;
    
    if (result == nil)
    {
        int rc = 0;
        
        MDB_txn *txn = NULL;
        rc = mdb_txn_begin(_env, NULL, 0, &txn);
        if (rc != MDB_SUCCESS)
        {
            TGLegacyLog(@"[PSLMDBKeyValueStore transaction begin failed %d]", rc);
            
            if (rc == MDB_PANIC)
            {
                TGLegacyLog(@"[PSLMDBKeyValueStore critical error received]");
                
                [self panic];
            }
        }
        
        MDB_dbi dbi;
        
        rc = mdb_dbi_open(txn, [name UTF8String], MDB_CREATE, &dbi);
        if (rc != MDB_SUCCESS)
        {
            mdb_txn_abort(txn);
            
            TGLegacyLog(@"[PSLMDBKeyValueStore mdb_dbi_open failed %d]", rc);
        }
        else
        {
            mdb_txn_commit(txn);
            
            PSLMDBTable *createdTable = [[PSLMDBTable alloc] initWithDbi:dbi];
            result = createdTable;
        }
    }
    
    return result;
}

- (void)readInTransaction:(void (^)(id<PSKeyValueReader>))transaction
{
    if (transaction == nil)
        return;
    
    PSLMDBTable *table = _table;
    if (table != nil)
    {
        int rc = 0;
        MDB_txn *txn = NULL;
        
        rc = mdb_txn_begin(_env, NULL, MDB_RDONLY, &txn);
        if (rc != MDB_SUCCESS)
        {
            TGLegacyLog(@"[PSLMDBKeyValueStore mdb_txn_begin failed %d", rc);
            
            if (rc == MDB_PANIC)
            {
                TGLegacyLog(@"[PSLMDBKeyValueStore critical error received]");
                
                [self panic];
            }
        }
        else
        {
            transaction([[PSLMDBKeyValueReaderWriter alloc] initWithTable:table transaction:txn]);
            
            rc = mdb_txn_commit(txn);
            
            if (rc != MDB_SUCCESS)
                TGLegacyLog(@"[PSLMDBKeyValueStore mdb_txn_commit error %d]", rc);
        }
    }
}

- (void)readWriteInTransaction:(void (^)(id<PSKeyValueReader, PSKeyValueWriter>))transaction
{
    if (transaction == nil)
        return;
    
    PSLMDBTable *table = _table;
    if (table != nil)
    {
        int rc = 0;
        MDB_txn *txn = NULL;
        
        rc = mdb_txn_begin(_env, NULL, 0, &txn);
        if (rc != MDB_SUCCESS)
        {
            TGLegacyLog(@"[PSLMDBKeyValueStore mdb_txn_begin failed %d", rc);
            
            if (rc == MDB_PANIC)
            {
                TGLegacyLog(@"[PSLMDBKeyValueStore critical error received]");
                
                [self panic];
            }
        }
        else
        {
            transaction([[PSLMDBKeyValueReaderWriter alloc] initWithTable:table transaction:txn]);
            
            rc = mdb_txn_commit(txn);
            
            if (rc != MDB_SUCCESS)
                TGLegacyLog(@"[PSLMDBKeyValueStore mdb_txn_commit error %d]", rc);
        }
    }
}

@end
