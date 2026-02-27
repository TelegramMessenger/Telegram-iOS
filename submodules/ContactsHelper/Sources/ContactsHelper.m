#import <ContactsHelper/ContactsHelper.h>

@implementation ContactsEnumerateChangeResult

- (instancetype)initWithStateToken:(NSData *)stateToken {
    self = [super init];
    if (self != nil) {
        _stateToken = stateToken;
    }
    return self;
}

@end

@implementation ContactsEnumerateResult

- (instancetype)initWithStateToken:(NSData *)stateToken {
    self = [super init];
    if (self != nil) {
        _stateToken = stateToken;
    }
    return self;
}

@end

ContactsEnumerateChangeResult * _Nullable ContactsEnumerateChangeRequest(CNContactStore *store, CNChangeHistoryFetchRequest *fetchRequest, id<CNChangeHistoryEventVisitor> visitor) {
    NSError *error = nil;
    CNFetchResult<NSEnumerator<CNChangeHistoryEvent *> *> *fetchResult = [store enumeratorForChangeHistoryFetchRequest:fetchRequest error:&error];
    
    for (CNChangeHistoryEvent *event in fetchResult.value) {
        [event acceptEventVisitor:visitor];
    }
    
    return [[ContactsEnumerateChangeResult alloc] initWithStateToken:fetchResult.currentHistoryToken];
}

ContactsEnumerateResult * _Nullable ContactsEnumerateRequest(CNContactStore *store, CNContactFetchRequest *fetchRequest, void (^onContact)(CNContact *)) {
    NSError *error = nil;
    CNFetchResult<NSEnumerator<CNContact *> *> *fetchResult = [store enumeratorForContactFetchRequest:fetchRequest error:&error];
    for (CNContact *contact in fetchResult.value) {
        onContact(contact);
    }
    
    return [[ContactsEnumerateResult alloc] initWithStateToken:fetchResult.currentHistoryToken];
}
