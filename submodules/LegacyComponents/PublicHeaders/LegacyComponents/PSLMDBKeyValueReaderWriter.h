#import <LegacyComponents/lmdb.h>
#import <LegacyComponents/PSKeyValueReader.h>
#import <LegacyComponents/PSKeyValueWriter.h>

@class PSLMDBTable;

@interface PSLMDBKeyValueReaderWriter : NSObject <PSKeyValueReader, PSKeyValueWriter>

- (instancetype)initWithTable:(PSLMDBTable *)table transaction:(MDB_txn *)transaction;

@end
