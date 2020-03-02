#import <LegacyDataImportImpl/TGProxyItem.h>

static bool TGObjectCompare(id obj1, id obj2) {
    if (obj1 == nil && obj2 == nil)
        return true;
    
    return [obj1 isEqual:obj2];
}

@implementation TGProxyItem

- (instancetype)initWithServer:(NSString *)server port:(int16_t)port username:(NSString *)username password:(NSString *)password secret:(NSString *)secret
{
    self = [super init];
    if (self != nil)
    {
        _server = server;
        _port = port;
        _username = username;
        _password = password;
        _secret = secret;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithServer:[aDecoder decodeObjectForKey:@"server"] port:(int16_t)[aDecoder decodeInt32ForKey:@"port"] username:[aDecoder decodeObjectForKey:@"user"] password:[aDecoder decodeObjectForKey:@"pass"] secret:[aDecoder decodeObjectForKey:@"secret"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_server forKey:@"server"];
    [aCoder encodeInt32:_port forKey:@"port"];
    [aCoder encodeObject:_username forKey:@"user"];
    [aCoder encodeObject:_password forKey:@"pass"];
    [aCoder encodeObject:_secret forKey:@"secret"];
}

- (bool)isMTProxy
{
    return _secret.length > 0;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGProxyItem *proxy = (TGProxyItem *)object;
    
    if (![_server isEqualToString:proxy.server])
        return false;
        
    if (_port != proxy.port)
        return false;
    
    if (!TGObjectCompare(_username ?: @"", proxy.username ?: @""))
        return false;
    
    if (!TGObjectCompare(_password ?: @"", proxy.password ?: @""))
        return false;
    
    if (!TGObjectCompare(_secret ?: @"", proxy.secret ?: @""))
        return false;
    
    return true;
}

@end
