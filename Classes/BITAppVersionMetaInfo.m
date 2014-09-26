/*
 * Author: Peter Steinberger
 *         Andreas Linde
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde, Peter Steinberger.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BITAppVersionMetaInfo.h"
#import "HockeySDKPrivate.h"


@implementation BITAppVersionMetaInfo


#pragma mark - Static

+ (BITAppVersionMetaInfo *)appVersionMetaInfoFromDict:(NSDictionary *)dict {
  BITAppVersionMetaInfo *appVersionMetaInfo = [[[self class] alloc] init];
  
  if ([dict isKindOfClass:[NSDictionary class]]) {
    appVersionMetaInfo.name = [dict objectForKey:@"title"];
    appVersionMetaInfo.version = [dict objectForKey:@"version"];
    appVersionMetaInfo.shortVersion = [dict objectForKey:@"shortversion"];
    appVersionMetaInfo.minOSVersion = [dict objectForKey:@"minimum_os_version"];
    [appVersionMetaInfo setDateWithTimestamp:[[dict objectForKey:@"timestamp"] doubleValue]];
    appVersionMetaInfo.size = [dict objectForKey:@"appsize"];
    appVersionMetaInfo.notes = [dict objectForKey:@"notes"];
    appVersionMetaInfo.mandatory = [dict objectForKey:@"mandatory"];
    appVersionMetaInfo.versionID = [dict objectForKey:@"id"];
    appVersionMetaInfo.uuids = [dict objectForKey:@"uuids"];
  }
  
  return appVersionMetaInfo;
}


#pragma mark - NSObject

- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  if (!other || ![other isKindOfClass:[self class]])
    return NO;
  return [self isEqualToAppVersionMetaInfo:other];
}

- (BOOL)isEqualComparingString:(NSString *)stringA withString:(NSString *)stringB {
  if ([stringA isKindOfClass:[NSString class]] && [stringB isKindOfClass:[NSString class]]) {
    return [stringA isEqualToString:stringB];
  }

  return NO;
}

- (BOOL)isEqualComparingNumber:(NSNumber *)numberA withNumber:(NSNumber *)numberB {
  if ([numberA isKindOfClass:[NSNumber class]] && [numberB isKindOfClass:[NSNumber class]]) {
    return [numberA isEqualToNumber:numberB];
  }

  return NO;
}

- (BOOL)isEqualComparingDate:(NSDate *)dateA withDate:(NSDate *)dateB {
  if ([dateA isKindOfClass:[NSDate class]] && [dateB isKindOfClass:[NSDate class]]) {
    return [dateA isEqualToDate:dateB];
  }

  return NO;
}

- (BOOL)isEqualComparingDictionary:(NSDictionary *)dictA withDate:(NSDictionary *)dictB {
  if ([dictA isKindOfClass:[NSDictionary class]] && [dictB isKindOfClass:[NSDictionary class]]) {
    return [dictA isEqualToDictionary:dictB];
  }
  
  return NO;
}

- (BOOL)isEqualToAppVersionMetaInfo:(BITAppVersionMetaInfo *)anAppVersionMetaInfo {
  if (self == anAppVersionMetaInfo)
    return YES;
  if (![self isEqualComparingString:self.name withString:anAppVersionMetaInfo.name])
    return NO;
  if (![self isEqualComparingString:self.version withString:anAppVersionMetaInfo.version])
    return NO;
  if (![self isEqualComparingString:self.shortVersion withString:anAppVersionMetaInfo.shortVersion])
    return NO;
  if (![self isEqualComparingString:self.minOSVersion withString:anAppVersionMetaInfo.minOSVersion])
    return NO;
  if (![self isEqualComparingString:self.notes withString:anAppVersionMetaInfo.notes])
    return NO;
  if (![self isEqualComparingDate:self.date withDate:anAppVersionMetaInfo.date])
    return NO;
  if (![self isEqualComparingNumber:self.size withNumber:anAppVersionMetaInfo.size])
    return NO;
  if (![self isEqualComparingNumber:self.mandatory withNumber:anAppVersionMetaInfo.mandatory])
    return NO;
  if (![self isEqualComparingDictionary:self.uuids withDate:anAppVersionMetaInfo.uuids])
    return NO;
  return YES;
}


#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)encoder {
  [encoder encodeObject:self.name forKey:@"name"];
  [encoder encodeObject:self.version forKey:@"version"];
  [encoder encodeObject:self.shortVersion forKey:@"shortVersion"];
  [encoder encodeObject:self.minOSVersion forKey:@"minOSVersion"];
  [encoder encodeObject:self.notes forKey:@"notes"];
  [encoder encodeObject:self.date forKey:@"date"];
  [encoder encodeObject:self.size forKey:@"size"];
  [encoder encodeObject:self.mandatory forKey:@"mandatory"];
  [encoder encodeObject:self.versionID forKey:@"versionID"];
  [encoder encodeObject:self.uuids forKey:@"uuids"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  if ((self = [super init])) {
    self.name = [decoder decodeObjectForKey:@"name"];
    self.version = [decoder decodeObjectForKey:@"version"];
    self.shortVersion = [decoder decodeObjectForKey:@"shortVersion"];
    self.minOSVersion = [decoder decodeObjectForKey:@"minOSVersion"];
    self.notes = [decoder decodeObjectForKey:@"notes"];
    self.date = [decoder decodeObjectForKey:@"date"];
    self.size = [decoder decodeObjectForKey:@"size"];
    self.mandatory = [decoder decodeObjectForKey:@"mandatory"];
    self.versionID = [decoder decodeObjectForKey:@"versionID"];
    self.uuids = [decoder decodeObjectForKey:@"uuids"];
  }
  return self;
}


#pragma mark - Properties

- (NSString *)nameAndVersionString {
  NSString *appNameAndVersion = [NSString stringWithFormat:@"%@ %@", self.name, [self versionString]];
  return appNameAndVersion;
}

- (NSString *)versionString {
  NSString *shortString = ([self.shortVersion respondsToSelector:@selector(length)] && [self.shortVersion length]) ? [NSString stringWithFormat:@"%@", self.shortVersion] : @"";
  NSString *versionString = [shortString length] ? [NSString stringWithFormat:@" (%@)", self.version] : self.version;
  return [NSString stringWithFormat:@"%@ %@%@", BITHockeyLocalizedString(@"UpdateVersion"), shortString, versionString];
}

- (NSString *)dateString {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateStyle:NSDateFormatterMediumStyle];
  
  return [formatter stringFromDate:self.date];
}

- (NSString *)sizeInMB {
  if ([_size isKindOfClass: [NSNumber class]] && [_size doubleValue] > 0) {
    double appSizeInMB = [_size doubleValue]/(1024*1024);
    NSString *appSizeString = [NSString stringWithFormat:@"%.1f MB", appSizeInMB];
    return appSizeString;
  }
  
  return @"0 MB";
}

- (void)setDateWithTimestamp:(NSTimeInterval)timestamp {
  if (timestamp) {
    NSDate *appDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
    self.date = appDate;
  } else {
    self.date = nil;
  }
}

- (NSString *)notesOrEmptyString {
  if (self.notes) {
    return self.notes;
  }else {
    return [NSString string];
  }
}


// A valid app needs at least following properties: name, version, date
- (BOOL)isValid {
  BOOL valid = [self.name length] && [self.version length] && self.date;  
  return valid;
}

- (BOOL)hasUUID:(NSString *)uuid {
  if (!uuid) return NO;
  if (!self.uuids) return NO;
  
  __block BOOL hasUUID = NO;
  
  [self.uuids enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    if (obj && [uuid compare:obj] == NSOrderedSame) {
      hasUUID = YES;
      *stop = YES;
    }
  }];
  
  return hasUUID;
}
@end
