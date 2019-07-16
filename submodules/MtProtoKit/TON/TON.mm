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

@implementation TONTestGiverAccountState

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

@property (nonatomic, readonly) tonlib::Client *client;
@property (nonatomic, copy, readonly) void (^received)(tonlib::Client::Response &);

@end

@implementation TONReceiveThreadParams

- (instancetype)initWithClient:(tonlib::Client *)client received:(void (^)(tonlib::Client::Response &))received {
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

@interface TONError : NSObject

@property (nonatomic, strong, readonly) NSString *text;

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
    tonlib::Client *_client;
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
        
        _client = new tonlib::Client;
        
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

- (void)dealloc {
    delete _client;
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
                [subscriber putNext:[[TONTestGiverAccountState alloc] initWithBalance:result->balance_ seqno:result->seqno_]];
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

- (MTSignal *)testGiverSendGramsWithAccountState:(TONTestGiverAccountState *)accountState accountAddress:(NSString *)accountAddress amount:(int64_t)amount {
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
                [subscriber putNext:@(result->account_state_->balance_)];
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

@end
