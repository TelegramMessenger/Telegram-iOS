#import "BITEnvelope.h"
#import "BITData.h"
#import "BITHockeyLogger.h"

/// Data contract class for type Envelope.
@implementation BITEnvelope

/// Initializes a new instance of the class.
- (instancetype)init {
  if((self = [super init])) {
    _version = @1;
    _sampleRate = @100.0;
    _tags = [NSDictionary dictionary];
  }
  return self;
}

///
/// Adds all members of this class to a dictionary
/// @returns dictionary to which the members of this class will be added.
///
- (NSDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary].mutableCopy;
  if(self.version != nil) {
    [dict setObject:self.version forKey:@"ver"];
  }
  if(self.name != nil) {
    [dict setObject:self.name forKey:@"name"];
  }
  if(self.time != nil) {
    [dict setObject:self.time forKey:@"time"];
  }
  if(self.sampleRate != nil) {
    [dict setObject:self.sampleRate forKey:@"sampleRate"];
  }
  if(self.seq != nil) {
    [dict setObject:self.seq forKey:@"seq"];
  }
  if(self.iKey != nil) {
    [dict setObject:self.iKey forKey:@"iKey"];
  }
  if(self.flags != nil) {
    [dict setObject:self.flags forKey:@"flags"];
  }
  if(self.deviceId != nil) {
    [dict setObject:self.deviceId forKey:@"deviceId"];
  }
  if(self.os != nil) {
    [dict setObject:self.os forKey:@"os"];
  }
  if(self.osVer != nil) {
    [dict setObject:self.osVer forKey:@"osVer"];
  }
  if(self.appId != nil) {
    [dict setObject:self.appId forKey:@"appId"];
  }
  if(self.appVer != nil) {
    [dict setObject:self.appVer forKey:@"appVer"];
  }
  if(self.userId != nil) {
    [dict setObject:self.userId forKey:@"userId"];
  }
  if(self.tags != nil) {
    [dict setObject:self.tags forKey:@"tags"];
  }
    
  NSDictionary *dataDict = [self.data serializeToDictionary];
  if ([NSJSONSerialization isValidJSONObject:dataDict]) {
    [dict setObject:dataDict forKey:@"data"];
  } else {
    BITHockeyLogError(@"[HockeySDK] Some of the telemetry data was not NSJSONSerialization compatible and could not be serialized!");
  }
  return dict;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super init];
  if(self) {
    _version = [coder decodeObjectForKey:@"self.version"];
    _name = [coder decodeObjectForKey:@"self.name"];
    _time = [coder decodeObjectForKey:@"self.time"];
    _sampleRate = [coder decodeObjectForKey:@"self.sampleRate"];
    _seq = [coder decodeObjectForKey:@"self.seq"];
    _iKey = [coder decodeObjectForKey:@"self.iKey"];
    _flags = [coder decodeObjectForKey:@"self.flags"];
    _deviceId = [coder decodeObjectForKey:@"self.deviceId"];
    _os = [coder decodeObjectForKey:@"self.os"];
    _osVer = [coder decodeObjectForKey:@"self.osVer"];
    _appId = [coder decodeObjectForKey:@"self.appId"];
    _appVer = [coder decodeObjectForKey:@"self.appVer"];
    _userId = [coder decodeObjectForKey:@"self.userId"];
    _tags = [coder decodeObjectForKey:@"self.tags"];
    _data = [coder decodeObjectForKey:@"self.data"];
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.version forKey:@"self.version"];
  [coder encodeObject:self.name forKey:@"self.name"];
  [coder encodeObject:self.time forKey:@"self.time"];
  [coder encodeObject:self.sampleRate forKey:@"self.sampleRate"];
  [coder encodeObject:self.seq forKey:@"self.seq"];
  [coder encodeObject:self.iKey forKey:@"self.iKey"];
  [coder encodeObject:self.flags forKey:@"self.flags"];
  [coder encodeObject:self.deviceId forKey:@"self.deviceId"];
  [coder encodeObject:self.os forKey:@"self.os"];
  [coder encodeObject:self.osVer forKey:@"self.osVer"];
  [coder encodeObject:self.appId forKey:@"self.appId"];
  [coder encodeObject:self.appVer forKey:@"self.appVer"];
  [coder encodeObject:self.userId forKey:@"self.userId"];
  [coder encodeObject:self.tags forKey:@"self.tags"];
  [coder encodeObject:self.data forKey:@"self.data"];
}


@end
