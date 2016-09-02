#import "BITDevice.h"

/// Data contract class for type Device.
@implementation BITDevice

///
/// Adds all members of this class to a dictionary
/// @param dictionary to which the members of this class will be added.
///
- (NSDictionary *)serializeToDictionary {
    NSMutableDictionary *dict = [super serializeToDictionary].mutableCopy;
    if (self.deviceId != nil) {
        [dict setObject:self.deviceId forKey:@"ai.device.id"];
    }
    if (self.ip != nil) {
        [dict setObject:self.ip forKey:@"ai.device.ip"];
    }
    if (self.language != nil) {
        [dict setObject:self.language forKey:@"ai.device.language"];
    }
    if (self.locale != nil) {
        [dict setObject:self.locale forKey:@"ai.device.locale"];
    }
    if (self.model != nil) {
        [dict setObject:self.model forKey:@"ai.device.model"];
    }
    if (self.network != nil) {
        [dict setObject:self.network forKey:@"ai.device.network"];
    }
    if(self.networkName != nil) {
        [dict setObject:self.networkName forKey:@"ai.device.networkName"];
    }
    if (self.oemName != nil) {
        [dict setObject:self.oemName forKey:@"ai.device.oemName"];
    }
    if (self.os != nil) {
        [dict setObject:self.os forKey:@"ai.device.os"];
    }
    if (self.osVersion != nil) {
        [dict setObject:self.osVersion forKey:@"ai.device.osVersion"];
    }
    if (self.roleInstance != nil) {
        [dict setObject:self.roleInstance forKey:@"ai.device.roleInstance"];
    }
    if (self.roleName != nil) {
        [dict setObject:self.roleName forKey:@"ai.device.roleName"];
    }
    if (self.screenResolution != nil) {
        [dict setObject:self.screenResolution forKey:@"ai.device.screenResolution"];
    }
    if (self.type != nil) {
        [dict setObject:self.type forKey:@"ai.device.type"];
    }
    if (self.machineName != nil) {
        [dict setObject:self.machineName forKey:@"ai.device.machineName"];
    }
    if(self.vmName != nil) {
        [dict setObject:self.vmName forKey:@"ai.device.vmName"];
    }
  return dict;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super init];
  if(self) {
    _deviceId = [coder decodeObjectForKey:@"self.deviceId"];
    _ip = [coder decodeObjectForKey:@"self.ip"];
    _language = [coder decodeObjectForKey:@"self.language"];
    _locale = [coder decodeObjectForKey:@"self.locale"];
    _model = [coder decodeObjectForKey:@"self.model"];
    _network = [coder decodeObjectForKey:@"self.network"];
    _oemName = [coder decodeObjectForKey:@"self.oemName"];
    _os = [coder decodeObjectForKey:@"self.os"];
    _osVersion = [coder decodeObjectForKey:@"self.osVersion"];
    _roleInstance = [coder decodeObjectForKey:@"self.roleInstance"];
    _roleName = [coder decodeObjectForKey:@"self.roleName"];
    _screenResolution = [coder decodeObjectForKey:@"self.screenResolution"];
    _type = [coder decodeObjectForKey:@"self.type"];
    _machineName = [coder decodeObjectForKey:@"self.machineName"];
    _networkName = [coder decodeObjectForKey:@"self.networkName"];
    _vmName = [coder decodeObjectForKey:@"self.vmName"];
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.deviceId forKey:@"self.deviceId"];
  [coder encodeObject:self.ip forKey:@"self.ip"];
  [coder encodeObject:self.language forKey:@"self.language"];
  [coder encodeObject:self.locale forKey:@"self.locale"];
  [coder encodeObject:self.model forKey:@"self.model"];
  [coder encodeObject:self.network forKey:@"self.network"];
  [coder encodeObject:self.networkName forKey:@"self.networkName"];
  [coder encodeObject:self.oemName forKey:@"self.oemName"];
  [coder encodeObject:self.os forKey:@"self.os"];
  [coder encodeObject:self.osVersion forKey:@"self.osVersion"];
  [coder encodeObject:self.roleInstance forKey:@"self.roleInstance"];
  [coder encodeObject:self.roleName forKey:@"self.roleName"];
  [coder encodeObject:self.screenResolution forKey:@"self.screenResolution"];
  [coder encodeObject:self.type forKey:@"self.type"];
  [coder encodeObject:self.machineName forKey:@"self.machineName"];
  [coder encodeObject:self.vmName forKey:@"self.vmName"];
}


@end
