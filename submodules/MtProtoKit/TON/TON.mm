#import "TON.h"

#import "tonlib_client_json.h"
#import "MTLogging.h"
#import "Client.h"
#import "MTQueue.h"
#import "MTSignal.h"

@implementation TONKey

- (instancetype)initWithPublicKey:(NSString *)publicKey secret:(NSString *)secret {
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

@interface TON () {
    std::shared_ptr<tonlib::Client> _client;
    uint64_t _nextRequestId;
    NSLock *_requestHandlersLock;
    NSMutableDictionary<NSNumber *, TONRequestHandler *> *_requestHandlers;
    MTPipe *_initialized;
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
        _initialized = [[MTPipe alloc] initWithReplay:true];
        _initialized.sink(@false);
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
        
        [[self requestInitWithConfigString:config keystoreDirectory:keystoreDirectory] startWithNext:nil completed:^{
            _initialized.sink(@true);
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

- (MTSignal *)createKeyWithLocalPassword:(NSString *)localPassword mnemonicPassword:(NSString *)mnemonicPassword {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::key::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::key>(object);
                NSString *publicKey = [[[NSData alloc] initWithBytes:result->public_key_.data() length:result->public_key_.length()] base64EncodedStringWithOptions:0];
                NSString *secret = [[[NSData alloc] initWithBytes:result->secret_.data() length:result->secret_.length()] base64EncodedStringWithOptions:0];
                [subscriber putNext:[[TONKey alloc] initWithPublicKey:publicKey secret:secret]];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        auto query = make_object<tonlib_api::createNewKey>(localPassword.UTF8String, mnemonicPassword.UTF8String);
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)getTestWalletAccountAddressWithPublicKey:(NSString *)publicKey {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
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
        
        NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:publicKey options:0];
        std::string publicKeyString((uint8_t *)publicKeyData.bytes, (uint8_t *)publicKeyData.bytes + publicKeyData.length);
        
        auto query = make_object<tonlib_api::testWallet_getAccountAddress>(make_object<tonlib_api::testWallet_initialAccountState>(publicKeyString));
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

- (MTSignal *)sendGramsFromKey:(TONKey *)key localPassword:(NSString *)localPassword fromAddress:(NSString *)fromAddress toAddress:(NSString *)address amount:(int64_t)amount {
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
        
        NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:key.publicKey options:0];
        std::string publicKeyString((uint8_t *)publicKeyData.bytes, (uint8_t *)publicKeyData.bytes + publicKeyData.length);
        
        NSData *secretData = [[NSData alloc] initWithBase64EncodedString:key.secret options:0];
        std::string secretString((uint8_t *)secretData.bytes, (uint8_t *)secretData.bytes + secretData.length);
        
        NSData *localPasswordData = [localPassword dataUsingEncoding:NSUTF8StringEncoding];
        std::string localPasswordString((uint8_t *)localPasswordData.bytes, (uint8_t *)localPasswordData.bytes + localPasswordData.length);
        
        auto query = make_object<tonlib_api::generic_sendGrams>(make_object<tonlib_api::inputKey>(make_object<tonlib_api::key>(publicKeyString, secretString), localPasswordString), make_object<tonlib_api::accountAddress>(fromAddress.UTF8String), make_object<tonlib_api::accountAddress>(address.UTF8String), amount);
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)exportKey:(TONKey *)key localPassword:(NSString *)localPassword {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::exportedKey::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::exportedKey>(object);
                NSMutableArray *wordList = [[NSMutableArray alloc] init];
                for (auto it : result->word_list_) {
                    [wordList addObject:[[NSString alloc] initWithUTF8String:it.c_str()]];
                }
                [subscriber putNext:wordList];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:key.publicKey options:0];
        std::string publicKeyString((uint8_t *)publicKeyData.bytes, (uint8_t *)publicKeyData.bytes + publicKeyData.length);
        
        NSData *secretData = [[NSData alloc] initWithBase64EncodedString:key.secret options:0];
        std::string secretString((uint8_t *)secretData.bytes, (uint8_t *)secretData.bytes + secretData.length);
        
        NSData *localPasswordData = [localPassword dataUsingEncoding:NSUTF8StringEncoding];
        std::string localPasswordString((uint8_t *)localPasswordData.bytes, (uint8_t *)localPasswordData.bytes + localPasswordData.length);
        
        auto query = make_object<tonlib_api::exportKey>(make_object<tonlib_api::inputKey>(make_object<tonlib_api::key>(publicKeyString, secretString), localPasswordString));
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)importKeyWithLocalPassword:(NSString *)localPassword mnemonicPassword:(NSString *)mnemonicPassword wordList:(NSArray<NSString *> *)wordList {
    return [[[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        uint64_t requestId = _nextRequestId;
        _nextRequestId += 1;
        
        _requestHandlers[@(requestId)] = [[TONRequestHandler alloc] initWithCompletion:^(tonlib_api::object_ptr<tonlib_api::Object> &object) {
            if (object->get_id() == tonlib_api::error::ID) {
                auto error = tonlib_api::move_object_as<tonlib_api::error>(object);
                [subscriber putError:[[TONError alloc] initWithText:[[NSString alloc] initWithUTF8String:error->message_.c_str()]]];
            } else if (object->get_id() == tonlib_api::key::ID) {
                auto result = tonlib_api::move_object_as<tonlib_api::key>(object);
                NSString *publicKey = [[[NSData alloc] initWithBytes:result->public_key_.data() length:result->public_key_.length()] base64EncodedStringWithOptions:0];
                NSString *secret = [[[NSData alloc] initWithBytes:result->secret_.data() length:result->secret_.length()] base64EncodedStringWithOptions:0];
                [subscriber putNext:[[TONKey alloc] initWithPublicKey:publicKey secret:secret]];
                [subscriber putCompletion];
            } else {
                assert(false);
            }
        }];
        
        NSData *localPasswordData = [localPassword dataUsingEncoding:NSUTF8StringEncoding];
        std::string localPasswordString((uint8_t *)localPasswordData.bytes, (uint8_t *)localPasswordData.bytes + localPasswordData.length);
        
        NSData *mnemonicPasswordData = [mnemonicPassword dataUsingEncoding:NSUTF8StringEncoding];
        std::string mnemonicPasswordString((uint8_t *)mnemonicPasswordData.bytes, (uint8_t *)mnemonicPasswordData.bytes + mnemonicPasswordData.length);
        
        std::vector<std::string> wordVector;
        for (NSString *word in wordList) {
            NSData *wordData = [word dataUsingEncoding:NSUTF8StringEncoding];
            std::string wordString((uint8_t *)wordData.bytes, (uint8_t *)wordData.bytes + wordData.length);
            wordVector.push_back(wordString);
        }
        
        auto query = make_object<tonlib_api::importKey>(localPasswordString, mnemonicPasswordString, make_object<tonlib_api::exportedKey>(std::move(wordVector)));
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

- (MTSignal *)deleteKeyWithPublicKey:(NSString *)publicKey {
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
        
        NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:publicKey options:0];
        std::string publicKeyString((uint8_t *)publicKeyData.bytes, (uint8_t *)publicKeyData.bytes + publicKeyData.length);
        
        auto query = make_object<tonlib_api::deleteKey>(publicKeyString);
        _client->send({ requestId, std::move(query) });
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
        }];
    }] startOn:[MTQueue mainQueue]] deliverOn:[MTQueue mainQueue]];
}

@end
