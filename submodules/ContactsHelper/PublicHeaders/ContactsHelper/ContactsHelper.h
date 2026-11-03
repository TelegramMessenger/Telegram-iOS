#ifndef ContactsHelper_h
#define ContactsHelper_h

#import <Foundation/Foundation.h>
#import <Contacts/Contacts.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContactsEnumerateChangeResult : NSObject

@property (nonatomic, strong) NSData * _Nullable stateToken;

- (instancetype)initWithStateToken:(NSData *)stateToken;

@end

@interface ContactsEnumerateResult : NSObject

@property (nonatomic, strong) NSData * _Nullable stateToken;

- (instancetype)initWithStateToken:(NSData *)stateToken;

@end

ContactsEnumerateChangeResult * _Nullable ContactsEnumerateChangeRequest(CNContactStore *store, CNChangeHistoryFetchRequest *fetchRequest, id<CNChangeHistoryEventVisitor> visitor);
ContactsEnumerateResult * _Nullable ContactsEnumerateRequest(CNContactStore *store, CNContactFetchRequest *fetchRequest, void (^onContact)(CNContact *));
    
NS_ASSUME_NONNULL_END

#endif /* ContactsHelper_h */
