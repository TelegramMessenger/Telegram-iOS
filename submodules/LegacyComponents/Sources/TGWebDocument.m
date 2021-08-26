#import "TGWebDocument.h"

#import "LegacyComponentsInternal.h"

#import "PSKeyValueEncoder.h"
#import "PSKeyValueDecoder.h"

@implementation TGWebDocumentReference

- (instancetype)initWithUrl:(NSString *)url accessHash:(int64_t)accessHash size:(int32_t)size datacenterId:(int32_t)datacenterId {
    self = [super init];
    if (self != nil) {
        _url = url;
        _accessHash = accessHash;
        _size = size;
        _datacenterId = datacenterId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithUrl:[coder decodeStringForCKey:"u"] accessHash:[coder decodeInt64ForCKey:"a"] size:[coder decodeInt32ForCKey:"s"] datacenterId:[coder decodeInt32ForCKey:"d"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeString:_url forCKey:"u"];
    [coder encodeInt64:_accessHash forCKey:"a"];
    [coder encodeInt32:_size forCKey:"s"];
    [coder encodeInt32:_datacenterId forCKey:"d"];
}

- (instancetype)initWithString:(NSString *)string {
    if ([string hasPrefix:@"webdoc"]) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:[string substringFromIndex:6] options:NSDataBase64DecodingIgnoreUnknownCharacters];
        if (data != nil) {
            PSKeyValueDecoder *decoder = [[PSKeyValueDecoder alloc] initWithData:data];
            return [[TGWebDocumentReference alloc] initWithKeyValueCoder:decoder];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (NSString *)toString {
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [self encodeWithKeyValueCoder:encoder];
    return [@"webdoc" stringByAppendingString:[[encoder data] base64EncodedStringWithOptions:0]];
}

@end

@implementation TGWebDocument

- (instancetype)initWithNoProxy:(bool)noProxy url:(NSString *)url accessHash:(int64_t)accessHash size:(int32_t)size mimeType:(NSString *)mimeType attributes:(NSArray *)attributes datacenterId:(int32_t)datacenterId {
    self = [super init];
    if (self != nil) {
        _noProxy = noProxy;
        _url = url;
        _accessHash = accessHash;
        _size = size;
        _mimeType = mimeType;
        _attributes = attributes;
        _datacenterId = datacenterId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithNoProxy:[aDecoder decodeBoolForKey:@"noProxy"] url:[aDecoder decodeObjectForKey:@"url"] accessHash:[aDecoder decodeInt64ForKey:@"accessHash"] size:[aDecoder decodeInt32ForKey:@"size"] mimeType:[aDecoder decodeObjectForKey:@"mimeType"] attributes:[aDecoder decodeObjectForKey:@"attributes"] datacenterId:[aDecoder decodeInt32ForKey:@"datacenterId"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:_noProxy forKey:@"noProxy"];
    [aCoder encodeObject:_url forKey:@"url"];
    [aCoder encodeInt64:_accessHash forKey:@"accessHash"];
    [aCoder encodeInt32:_size forKey:@"size"];
    [aCoder encodeObject:_mimeType forKey:@"mimeType"];
    [aCoder encodeObject:_attributes forKey:@"attributes"];
    [aCoder encodeInt32:_datacenterId forKey:@"datacenterId"];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TGWebDocument class]]) {
        return false;
    }
    TGWebDocument *other = object;
    if (_noProxy != other->_noProxy) {
        return false;
    }
    if (!TGStringCompare(_url, other->_url)) {
        return false;
    }
    if (_accessHash != other->_accessHash) {
        return false;
    }
    if (_size != other->_size) {
        return false;
    }
    if (!TGStringCompare(_mimeType, other->_mimeType)) {
        return false;
    }
    if (!TGObjectCompare(_attributes, other->_attributes)) {
        return false;
    }
    if (_datacenterId != other->_datacenterId) {
        return false;
    }
    return true;
}

- (TGWebDocumentReference *)reference {
    return [[TGWebDocumentReference alloc] initWithUrl:_url accessHash:_accessHash size:_size datacenterId:_datacenterId];
}

@end
