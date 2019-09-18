#import "TON.h"

#import "MTLogging.h"
#import "tonlib/Client.h"
#import "MTQueue.h"
#import "MTSignal.h"

static td::SecureString makeSecureString(NSData * _Nonnull data) {
    if (data == nil || data.length == 0) {
        return td::SecureString();
    } else {
        return td::SecureString((const char *)data.bytes, (size_t)data.length);
    }
}

static std::string makeString(NSData * _Nonnull data) {
    if (data == nil || data.length == 0) {
        return std::string();
    } else {
        return std::string((const char *)data.bytes, ((const char *)data.bytes) + data.length);
    }
}

@implementation TONKey

- (instancetype)initWithPublicKey:(NSString *)publicKey secret:(NSData *)secret {
    self = [super init];
    if (self != nil) {
        _publicKey = publicKey;
        _secret = secret;
    }
    return self;
}

@end

@implementation TONAccountState

- (instancetype)initWithBalance:(int64_t)balance seqno:(int32_t)seqno {
    self = [super init];
    if (self != nil) {
        _balance = balance;
        _seqno = seqno;
    }
    return self;
}

@end

using tonlib_api::make_object;

@interface TONReceiveThreadParams : NSObject

@property (nonatomic, readonly) std::shared_ptr<tonlib::Client> client;
@property (nonatomic, copy, readonly) void (^received)(tonlib::Client::Response &);

@end

@implementation TONReceiveThreadParams

- (instancetype)initWithClient:(std::shared_ptr<tonlib::Client>)client received:(void (^)(tonlib::Client::Response &))received {
    self = [super init];
    if (self != nil) {
        _client = client;
        _received = [received copy];
    }
    return self;
}

@end

@interface TONRequestHandler : NSObject

@property (nonatomic, copy, readonly) void (^completion)(tonlib_api::object_ptr<tonlib_api::Object> &);

@end

@implementation TONRequestHandler

- (instancetype)initWithCompletion:(void (^)(tonlib_api::object_ptr<tonlib_api::Object> &))completion {
    self = [super init];
    if (self != nil) {
        _completion = [completion copy];
    }
    return self;
}

@end

@implementation TONError

- (instancetype)initWithText:(NSString *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

@end

typedef enum {
    TONInitializationStatusInitializing,
    TONInitializationStatusReady,
    TONInitializationStatusError
} TONInitializationStatus;

@interface TON () {
    std::shared_ptr<tonlib::Client> _client;
    uint64_t _nextRequestId;
    NSLock *_requestHandlersLock;
    NSMutableDictionary<NSNumber *, TONRequestHandler *> *_requestHandlers;
    MTPipe *_initializedStatus;
}

@end

@implementation TON

+ (void)receiveThread:(TONReceiveThreadParams *)params {
    while (true) {
        auto response = params.client->receive(1000);
        if (response.object) {
            params.received(response);
        }
    }
}

- (instancetype)initWithKeystoreDirectory:(NSString *)keystoreDirectory config:(NSString *)config {
    self = [super init];
    if (self != nil) {
        _requestHandlersLock = [[NSLock alloc] init];
        _requestHandlers = [[NSMutableDictionary alloc] init];
        _initializedStatus = [[MTPipe alloc] initWithReplay:true];
        _initializedStatus.sink(@(TONInitializationStatusInitializing));
        _nextRequestId = 1;
        
        _client = std::make_shared<tonlib::Client>();
        
        NSLock *requestHandlersLock = _requestHandlersLock;
        NSMutableDictionary *requestHandlers = _requestHandlers;
        NSThread *thread = [[NSThread alloc] initWithTarget:[self class] selector:@selector(receiveThread:) object:[[TONReceiveThreadParams alloc] initWithClient:_client received:^(tonlib::Client::Response &response) {
            NSNumber *requestId = @(response.id);
            [requestHandlersLock lock];
            TONRequestHandler *handler = requestHandlers[requestId];
            [requestHandlers removeObjectForKey:requestId];
            [requestHandlersLock unlock];
            if (handler != nil) {
                handler.completion(response.object);
            }
        }]];
        [thread start];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:keystoreDirectory withIntermediateDirectories:true attributes:nil error:nil];
        
        MTPipe *initializedStatus = _initializedStatus;
        [[self requestInitWithConfigString:config keystoreDirectory:keystoreDirectory] startWithNext:nil error:^(id error) {
            NSString *errorText = @"Unknown error";
            if ([error isKindOfClass:[TONError class]]) {
                errorText = ((TONError *)error).text;
            }
            initializedStatus.sink(@(TONInitializationStatusError));
        } completed:^{
            initializedStatus.sink(@(TONInitializationStatusReady));
        }];
    }
    return self;
}

- (MTSignal *)requestInitWithConfigString:(NSString *)configString keystoreDirectory:(NSString *)keystoreDirectory {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else {
                [subscriber putCompletion];
            }
        }];
        
        auto query = make_object<tonlib_api::init>(make_object<tonlib_api::options>(configString.UTF8String, keystoreDirectory.UTF8String));
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)createKeyWithLocalPassword:(NSData *)localPassword mnemonicPassword:(NSData *)mnemonicPassword {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::key::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::key>(object);
                NSString *publicKey = [[NSString alloc] initWithData:[[NSData alloc] initWithBytes:result->public_key_.data() length:result->public_key_.length()] encoding:NSUTF8StringEncoding];
                if (publicKey == nil) {
                    [subscriber putError:[[TONError alloc] initWithText:@"Error decoding UTF8 string in createKeyWithLocalPassword"]];
                    return;
                }
                NSData *secret = [[NSData alloc] initWithBytes:result->secret_.data() length:result->secret_.length()];
                [subscriber putNext:[[TONKey alloc] initWithPublicKey:publicKey secret:secret]];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        auto query = make_object<tonlib_api::createNewKey>(
            makeSecureString(localPassword),
            makeSecureString(mnemonicPassword),
            td::SecureString()
        );
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)getTestWalletAccountAddressWithPublicKey:(NSString *)publicKey {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSData *publicKeyData = [publicKey dataUsingEncoding:NSUTF8StringEncoding];
        if (publicKeyData == nil) {
            [subscriber putError:[[TONError alloc] initWithText:@"Error encoding UTF8 string in getTestWalletAccountAddressWithPublicKey"]];
            return [[MTBlockDisposable alloc] initWithBlock:^{}];
        }
        
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::accountAddress::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::accountAddress>(object);
                [subscriber putNext:[[NSString alloc] initWithUTF8String:result->account_address_.c_str()]];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        auto query = make_object<tonlib_api::testWallet_getAccountAddress>(
            make_object<tonlib_api::testWallet_initialAccountState>(
                makeString(publicKeyData)
            )
        );
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)getTestGiverAccountState {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::testGiver_accountState::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::testGiver_accountState>(object);
                [subscriber putNext:[[TONAccountState alloc] initWithBalance:result->balance_ seqno:result->seqno_]];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        auto query = make_object<tonlib_api::testGiver_getAccountState>();
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)testGiverSendGramsWithAccountState:(TONAccountState *)accountState accountAddress:(NSString *)accountAddress amount:(int64_t)amount {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else {
                [subscriber putCompletion];
            }
        }];
        
        auto query = make_object<tonlib_api::testGiver_sendGrams>(make_object<tonlib_api::accountAddress>(accountAddress.UTF8String), accountState.seqno, amount);
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)getAccountStateWithAddress:(NSString *)accountAddress {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::generic_accountStateUninited::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::generic_accountStateUninited>(object);
                [subscriber putNext:[[TONAccountState alloc] initWithBalance:result->account_state_->balance_ seqno:-1]];
                [subscriber putCompletion];
            } else if (object->get_id() == tonlib_api::generic_accountStateTestWallet::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::generic_accountStateTestWallet>(object);
                [subscriber putNext:[[TONAccountState alloc] initWithBalance:result->account_state_->balance_ seqno:result->account_state_->seqno_]];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        auto query = make_object<tonlib_api::generic_getAccountState>(make_object<tonlib_api::accountAddress>(accountAddress.UTF8String));
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)sendGramsFromKey:(TONKey *)key localPassword:(NSData *)localPassword fromAddress:(NSString *)fromAddress toAddress:(NSString *)address amount:(int64_t)amount {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSData *publicKeyData = [key.publicKey dataUsingEncoding:NSUTF8StringEncoding];
        if (publicKeyData == nil) {
            [subscriber putError:[[TONError alloc] initWithText:@"Error encoding UTF8 string in sendGramsFromKey"]];
            return [[MTBlockDisposable alloc] initWithBlock:^{}];
        }
        
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else {
                [subscriber putCompletion];
            }
        }];
        
        auto query = make_object<tonlib_api::generic_sendGrams>(
            make_object<tonlib_api::inputKey>(
                make_object<tonlib_api::key>(
                    makeString(publicKeyData),
                    makeSecureString(key.secret)
                ),
                makeSecureString(localPassword)
            ),
            make_object<tonlib_api::accountAddress>(fromAddress.UTF8String),
            make_object<tonlib_api::accountAddress>(address.UTF8String),
            amount
        );
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)exportKey:(TONKey *)key localPassword:(NSData *)localPassword {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSData *publicKeyData = [key.publicKey dataUsingEncoding:NSUTF8StringEncoding];
        if (publicKeyData == nil) {
            [subscriber putError:[[TONError alloc] initWithText:@"Error encoding UTF8 string in exportKey"]];
            return [[MTBlockDisposable alloc] initWithBlock:^{}];
        }
        
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::exportedKey::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::exportedKey>(object);
                NSMutableArray *wordList = [[NSMutableArray alloc] init];
                for (auto &it : result->word_list_) {
                    NSString *string = [[NSString alloc] initWithData:[[NSData alloc] initWithBytes:it.data() length:it.size()] encoding:NSUTF8StringEncoding];
                    if (string == nil) {
                        [subscriber putError:[[TONError alloc] initWithText:@"Error decoding UTF8 string in exportedKey::word_list"]];
                        return;
                    }
                    [wordList addObject:string];
                }
                [subscriber putNext:wordList];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        auto query = make_object<tonlib_api::exportKey>(
            make_object<tonlib_api::inputKey>(
                make_object<tonlib_api::key>(
                    makeString(publicKeyData),
                    makeSecureString(key.secret)
                ),
                makeSecureString(localPassword)
            )
        );
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)makeWalletInitialized:(TONKey *)key localPassword:(NSData *)localPassword {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSData *publicKeyData = [key.publicKey dataUsingEncoding:NSUTF8StringEncoding];
        if (publicKeyData == nil) {
            [subscriber putError:[[TONError alloc] initWithText:@"Error encoding UTF8 string in exportKey"]];
            return [[MTBlockDisposable alloc] initWithBlock:^{}];
        }
        
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else {
                [subscriber putCompletion];
            }
        }];
        
        auto query = make_object<tonlib_api::testWallet_init>(
            make_object<tonlib_api::inputKey>(
                make_object<tonlib_api::key>(
                    makeString(publicKeyData),
                    makeSecureString(key.secret)
                ),
                makeSecureString(localPassword)
            )
        );
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)importKeyWithLocalPassword:(NSData *)localPassword mnemonicPassword:(NSData *)mnemonicPassword wordList:(NSArray<NSString *> *)wordList {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::key::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::key>(object);
                NSString *publicKey = [[NSString alloc] initWithData:[[NSData alloc] initWithBytes:result->public_key_.data() length:result->public_key_.length()] encoding:NSUTF8StringEncoding];
                if (publicKey == nil) {
                    [subscriber putError:[[TONError alloc] initWithText:@"Error decoding UTF8 string in importKeyWithLocalPassword"]];
                    return;
                }
                NSData *secret = [[NSData alloc] initWithBytes:result->secret_.data() length:result->secret_.length()];
                [subscriber putNext:[[TONKey alloc] initWithPublicKey:publicKey secret:secret]];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        std::vector<td::SecureString> wordVector;
        for (NSString *word in wordList) {
            NSData *wordData = [word dataUsingEncoding:NSUTF8StringEncoding];
            wordVector.push_back(makeSecureString(wordData));
        }
        
        auto query = make_object<tonlib_api::importKey>(
            makeSecureString(localPassword),
            makeSecureString(mnemonicPassword),
            make_object<tonlib_api::exportedKey>(std::move(wordVector)));
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)deleteKeyWithPublicKey:(NSString *)publicKey {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSData *publicKeyData = [publicKey dataUsingEncoding:NSUTF8StringEncoding];
        if (publicKeyData == nil) {
            [subscriber putError:[[TONError alloc] initWithText:@"Error encoding UTF8 string in deleteKeyWithPublicKey"]];
            return [[MTBlockDisposable alloc] initWithBlock:^{}];
        }
        
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else {
                [subscriber putCompletion];
            }
        }];
        
        auto query = make_object<tonlib_api::deleteKey>(
            makeString(publicKeyData)
        );
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

@end
