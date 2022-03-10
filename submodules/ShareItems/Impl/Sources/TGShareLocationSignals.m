#import <ShareItemsImpl/TGShareLocationSignals.h>

#import <MtProtoKit/MtProtoKit.h>

NSString *const TGShareAppleMapsHost = @"maps.apple.com";
NSString *const TGShareAppleMapsPath = @"/maps";
NSString *const TGShareAppleMapsLatLonKey = @"ll";
NSString *const TGShareAppleMapsNameKey = @"q";
NSString *const TGShareAppleMapsAddressKey = @"address";
NSString *const TGShareAppleMapsIdKey = @"auid";
NSString *const TGShareAppleMapsProvider = @"apple";

NSString *const TGShareFoursquareHost = @"foursquare.com";
NSString *const TGShareFoursquareVenuePath = @"/v";

NSString *const TGShareFoursquareVenueEndpointUrl = @"https://api.foursquare.com/v2/venues/";
NSString *const TGShareFoursquareClientId = @"BN3GWQF1OLMLKKQTFL0OADWD1X1WCDNISPPOT1EMMUYZTQV1";
NSString *const TGShareFoursquareClientSecret = @"WEEZHCKI040UVW2KWW5ZXFAZ0FMMHKQ4HQBWXVSX4WXWBWYN";
NSString *const TGShareFoursquareVersion = @"20150326";
NSString *const TGShareFoursquareVenuesCountLimit = @"25";
NSString *const TGShareFoursquareLocale = @"en";
NSString *const TGShareFoursquareProvider = @"foursquare";

NSString *const TGShareGoogleShortenerEndpointUrl = @"https://www.googleapis.com/urlshortener/v1/url";
NSString *const TGShareGoogleAPIKey = @"AIzaSyBCTH4aAdvi0MgDGlGNmQAaFS8GTNBrfj4";
NSString *const TGShareGoogleMapsShortHost = @"goo.gl";
NSString *const TGShareGoogleMapsShortPath = @"/maps";
NSString *const TGShareGoogleMapsHost = @"google.com";
NSString *const TGShareGoogleMapsSearchPath = @"maps/search";
NSString *const TGShareGoogleMapsPlacePath = @"maps/place";
NSString *const TGShareGoogleProvider = @"google";

@implementation TGShareLocationResult

- (instancetype)initWithLatitude:(double)latitude longitude:(double)longitude title:(NSString *)title address:(NSString *)address provider:(NSString *)provider venueId:(NSString *)venueId venueType:(NSString *)venueType {
    self = [super init];
    if (self != nil) {
        _latitude = latitude;
        _longitude = longitude;
        _title = title;
        _address = address;
        _provider = provider;
        _venueId = venueId;
        _venueType = venueType;
    }
    return self;
}

@end

@interface TGQueryStringComponent : NSObject {
@private
    NSString *_key;
    NSString *_value;
}

@property (readwrite, nonatomic, retain) id key;
@property (readwrite, nonatomic, retain) id value;

- (id)initWithKey:(id)key value:(id)value;
- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding;

@end

NSString * TGURLEncodedStringFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
    static NSString * const kAFLegalCharactersToBeEscaped = @"?!@#$^&%*+=,:;'\"`<>()[]{}/\\|~ ";
    NSString *unescapedString = [string stringByReplacingPercentEscapesUsingEncoding:encoding];
    if (unescapedString) {
        string = unescapedString;
    }
    
    return (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)kAFLegalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(encoding));
}

@implementation TGQueryStringComponent
@synthesize key = _key;
@synthesize value = _value;

- (id)initWithKey:(id)key value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.key = key;
    self.value = value;
    
    return self;
}

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding {
    return [NSString stringWithFormat:@"%@=%@", self.key, TGURLEncodedStringFromStringWithEncoding([self.value description], stringEncoding)];
}

@end

static NSString * TGQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding stringEncoding);
static NSArray * TGQueryStringComponentsFromKeyAndValue(NSString *key, id value);
NSArray * TGQueryStringComponentsFromKeyAndDictionaryValue(NSString *key, NSDictionary *value);
NSArray * TGQueryStringComponentsFromKeyAndArrayValue(NSString *key, NSArray *value);

static NSString * TGQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding stringEncoding) {
    NSMutableArray *mutableComponents = [NSMutableArray array];
    for (TGQueryStringComponent *component in TGQueryStringComponentsFromKeyAndValue(nil, parameters)) {
        [mutableComponents addObject:[component URLEncodedStringValueWithEncoding:stringEncoding]];
    }
    
    return [mutableComponents componentsJoinedByString:@"&"];
}

static NSArray * TGQueryStringComponentsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    
    if([value isKindOfClass:[NSDictionary class]]) {
        [mutableQueryStringComponents addObjectsFromArray:TGQueryStringComponentsFromKeyAndDictionaryValue(key, value)];
    } else if([value isKindOfClass:[NSArray class]]) {
        [mutableQueryStringComponents addObjectsFromArray:TGQueryStringComponentsFromKeyAndArrayValue(key, value)];
    } else {
        [mutableQueryStringComponents addObject:[[TGQueryStringComponent alloc] initWithKey:key value:value]];
    }
    
    return mutableQueryStringComponents;
}

NSArray * TGQueryStringComponentsFromKeyAndDictionaryValue(NSString *key, NSDictionary *value){
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    
    [value enumerateKeysAndObjectsUsingBlock:^(id nestedKey, id nestedValue, __unused BOOL *stop) {
        [mutableQueryStringComponents addObjectsFromArray:TGQueryStringComponentsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
    }];
    
    return mutableQueryStringComponents;
}

NSArray * TGQueryStringComponentsFromKeyAndArrayValue(NSString *key, NSArray *value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    
    [value enumerateObjectsUsingBlock:^(id nestedValue, __unused NSUInteger idx, __unused BOOL *stop) {
        [mutableQueryStringComponents addObjectsFromArray:TGQueryStringComponentsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
    }];
    
    return mutableQueryStringComponents;
}

@implementation TGShareLocationSignals

+ (MTSignal *)locationMessageContentForURL:(NSURL *)url
{
    if ([self isAppleMapsURL:url])
        return [self _appleMapsLocationContentForURL:url];
    else if ([self isFoursquareURL:url])
        return [self _foursquareLocationForURL:url];

    return [MTSignal single:nil];
}

+ (MTSignal *)_appleMapsLocationContentForURL:(NSURL *)url
{
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:false];
    NSArray *queryItems = urlComponents.queryItems;
    
    NSString *latLon = nil;
    NSString *name = nil;
    NSString *address = nil;
    NSString *venueId = nil;
    for (NSURLQueryItem *queryItem in queryItems)
    {
        if ([queryItem.name isEqualToString:TGShareAppleMapsLatLonKey])
        {
            latLon = queryItem.value;
        }
        else if ([queryItem.name isEqualToString:TGShareAppleMapsNameKey])
        {
            if (![queryItem.value isEqualToString:latLon])
                name = queryItem.value;
        }
        else if ([queryItem.name isEqualToString:TGShareAppleMapsAddressKey])
        {
            address = queryItem.value;
        }
        else if ([queryItem.name isEqualToString:TGShareAppleMapsIdKey])
        {
            venueId = queryItem.value;
        }
    }
    
    if (latLon == nil)
        return [MTSignal fail:nil];
    
    NSArray *coordComponents = [latLon componentsSeparatedByString:@","];
    if (coordComponents.count != 2)
        return [MTSignal fail:nil];
    
    double latitude = [coordComponents.firstObject floatValue];
    double longitude = [coordComponents.lastObject floatValue];
    
    return [MTSignal single:[[TGShareLocationResult alloc] initWithLatitude:latitude longitude:longitude title:name address:address provider:TGShareAppleMapsProvider venueId:venueId venueType:@""]];
}

+ (MTSignal *)_foursquareLocationForURL:(NSURL *)url
{
    NSArray *pathComponents = url.pathComponents;
    NSString *venueId = nil;
    for (NSString *component in pathComponents)
    {
        if (component.length == 24)
        {
            venueId = component;
            break;
        }
    }
    
    if (venueId == nil)
        return [MTSignal fail:nil];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", [TGShareFoursquareVenueEndpointUrl stringByAppendingPathComponent:venueId], TGQueryStringFromParametersWithEncoding([self _defaultParametersForFoursquare], NSUTF8StringEncoding)];
    
    return [[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:urlString]] mapToSignal:^id(MTHttpResponse *response)
    {
        NSData *data = response.data;
        
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSDictionary *venue = json[@"response"][@"venue"];
        if (![venue respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSString *name = venue[@"name"];
        
        NSDictionary *location = venue[@"location"];
        
        NSString *address = location[@"address"];
        if (address.length == 0)
            address = location[@"crossStreet"];
        if (address.length == 0)
            address = location[@"city"];
        if (address.length == 0)
            address = location[@"country"];
        if (address.length == 0)
            address = @"";
        
        double latitude = [location[@"lat"] doubleValue];
        double longitude = [location[@"lng"] doubleValue];
        
        if (name.length == 0)
            return [MTSignal fail:nil];
        
        return [MTSignal single:[[TGShareLocationResult alloc] initWithLatitude:latitude longitude:longitude title:name address:address provider:TGShareFoursquareProvider venueId:venueId venueType:@""]];
    }];
}

+ (MTSignal *)_googleMapsLocationForURL:(NSURL *)url
{
    NSString *shortenerUrl = [NSString stringWithFormat:@"%@?fields=longUrl,status&shortUrl=%@&key=%@", TGShareGoogleShortenerEndpointUrl, TGURLEncodedStringFromStringWithEncoding(url.absoluteString, NSUTF8StringEncoding), TGShareGoogleAPIKey];
    
    MTSignal *shortenerSignal = [[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:shortenerUrl]] mapToSignal:^MTSignal *(MTHttpResponse *response)
        {
        NSData *data = response.data;
        
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json respondsToSelector:@selector(objectForKey:)])
            return [MTSignal fail:nil];
        
        NSString *status = json[@"status"];
        if (![status isEqualToString:@"OK"])
            return [MTSignal fail:nil];
        
        return [MTSignal single:[NSURL URLWithString:json[@"longUrl"]]];
    }];
    
    MTSignal *(^processLongUrl)(NSURL *) = ^MTSignal *(NSURL *longUrl)
    {
        NSArray *pathComponents = longUrl.pathComponents;
        
        bool isSearch = false;
        double latitude = 0.0;
        double longitude = 0.0;
        
        for (NSString *component in pathComponents)
        {
            if ([component isEqualToString:@"search"])
            {
                isSearch = true;
            }
            else if ([component isEqualToString:@"place"])
            {
                return [MTSignal fail:nil];
            }
            else if (isSearch && [component containsString:@","])
            {
                NSArray *coordinates = [component componentsSeparatedByString:@","];
                if (coordinates.count == 2)
                {
                    latitude = [coordinates.firstObject doubleValue];
                    longitude = [coordinates.lastObject doubleValue];
                    break;
                }
            }
        }
        
        if (fabs(latitude) < DBL_EPSILON && fabs(longitude) < DBL_EPSILON)
            return [MTSignal fail:nil];
        
        return [MTSignal single:[[TGShareLocationResult alloc] initWithLatitude:latitude longitude:longitude title:nil address:nil provider:nil venueId:nil venueType:nil]];
    };
    
    MTSignal *signal = nil;
    if ([self _isShortGoogleMapsURL:url])
    {
        signal = [shortenerSignal mapToSignal:^MTSignal *(NSURL *longUrl)
        {
            return processLongUrl(longUrl);
        }];
    }
    else
    {
        signal = processLongUrl(url);
    }
    
    return [signal catch:^MTSignal *(id error)
    {
        return [MTSignal single:url.absoluteString];
    }];
}

+ (NSDictionary *)_defaultParametersForFoursquare
{
    return @
    {
        @"v": TGShareFoursquareVersion,
        @"locale": TGShareFoursquareLocale,
        @"client_id": TGShareFoursquareClientId,
        @"client_secret" :TGShareFoursquareClientSecret
    };
}

+ (bool)isLocationURL:(NSURL *)url
{
    return [self isAppleMapsURL:url] || [self isFoursquareURL:url];
}

+ (bool)isAppleMapsURL:(NSURL *)url
{
    return ([url.host isEqualToString:TGShareAppleMapsHost] && [url.path isEqualToString:TGShareAppleMapsPath]);
}

+ (bool)isFoursquareURL:(NSURL *)url
{
    return ([url.host isEqualToString:TGShareFoursquareHost] && [url.path hasPrefix:TGShareFoursquareVenuePath]);
}

+ (bool)_isShortGoogleMapsURL:(NSURL *)url
{
    return ([url.host isEqualToString:TGShareGoogleMapsShortHost] && [url.path hasPrefix:TGShareGoogleMapsShortPath]);
}

+ (bool)_isLongGoogleMapsURL:(NSURL *)url
{
    return ([url.host isEqualToString:TGShareGoogleMapsHost] && ([url.path hasPrefix:TGShareGoogleMapsSearchPath] || [url.path hasPrefix:TGShareGoogleMapsPlacePath]));
}

+ (bool)isGoogleMapsURL:(NSURL *)url
{
    return [self _isShortGoogleMapsURL:url] || [self _isLongGoogleMapsURL:url];
}

@end
