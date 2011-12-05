//
//  BWApp.m
//  HockeyDemo
//
//  Created by Peter Steinberger on 04.02.11.
//  Copyright 2011 Buzzworks. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BWApp.h"
#import "BWGlobal.h"

@implementation BWApp

@synthesize name = name_;
@synthesize version = version_;
@synthesize shortVersion = shortVersion_;
@synthesize notes = notes_;
@synthesize date = date_;
@synthesize size = size_;
@synthesize mandatory = mandatory_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark static

+ (BWApp *)appFromDict:(NSDictionary *)dict {
  BWApp *app = [[[[self class] alloc] init] autorelease];
  
  //    NSParameterAssert([dict isKindOfClass:[NSDictionary class]]);
  if ([dict isKindOfClass:[NSDictionary class]]) {
    app.name = [dict objectForKey:@"title"];
    app.version = [dict objectForKey:@"version"];
    app.shortVersion = [dict objectForKey:@"shortversion"];
    [app setDateWithTimestamp:[[dict objectForKey:@"timestamp"] doubleValue]];
    app.size = [dict objectForKey:@"appsize"];
    app.notes = [dict objectForKey:@"notes"];
    app.mandatory = [dict objectForKey:@"mandatory"];
  }
  
  return app;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject

- (void)dealloc {
  [name_ release];
  [version_ release];
  [shortVersion_ release];
  [notes_ release];
  [date_ release];
  [size_ release];
  [mandatory_ release];
  
  [super dealloc];
}

- (BOOL)isEqual:(id)other {
  if (other == self)
    return YES;
  if (!other || ![other isKindOfClass:[self class]])
    return NO;
  return [self isEqualToBWApp:other];
}

- (BOOL)isEqualToBWApp:(BWApp *)anApp {
  if (self == anApp)
    return YES;
  if (self.name != anApp.name && ![self.name isEqualToString:anApp.name])
    return NO;
  if (self.version != anApp.version && ![self.version isEqualToString:anApp.version])
    return NO;
  if (self.shortVersion != anApp.shortVersion && ![self.shortVersion isEqualToString:anApp.shortVersion])
    return NO;
  if (self.notes != anApp.notes && ![self.notes isEqualToString:anApp.notes])
    return NO;
  if (self.date != anApp.date && ![self.date isEqualToDate:anApp.date])
    return NO;
  if (self.size != anApp.size && ![self.size isEqualToNumber:anApp.size])
    return NO;
  if (self.mandatory != anApp.mandatory && ![self.mandatory isEqualToNumber:anApp.mandatory])
    return NO;
  return YES;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSCoder

- (void)encodeWithCoder:(NSCoder *)encoder {
  [encoder encodeObject:self.name forKey:@"name"];
  [encoder encodeObject:self.version forKey:@"version"];
  [encoder encodeObject:self.shortVersion forKey:@"shortVersion"];
  [encoder encodeObject:self.notes forKey:@"notes"];
  [encoder encodeObject:self.date forKey:@"date"];
  [encoder encodeObject:self.size forKey:@"size"];
  [encoder encodeObject:self.mandatory forKey:@"mandatory"];
}

- (id)initWithCoder:(NSCoder *)decoder {
  if ((self = [super init])) {
    self.name = [decoder decodeObjectForKey:@"name"];
    self.version = [decoder decodeObjectForKey:@"version"];
    self.shortVersion = [decoder decodeObjectForKey:@"shortVersion"];
    self.notes = [decoder decodeObjectForKey:@"notes"];
    self.date = [decoder decodeObjectForKey:@"date"];
    self.size = [decoder decodeObjectForKey:@"size"];
    self.mandatory = [decoder decodeObjectForKey:@"mandatory"];
  }
  return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Properties

- (NSString *)nameAndVersionString {
  NSString *appNameAndVersion = [NSString stringWithFormat:@"%@ %@", self.name, [self versionString]];
  return appNameAndVersion;
}

- (NSString *)versionString {
  NSString *shortString = ([self.shortVersion respondsToSelector:@selector(length)] && [self.shortVersion length]) ? [NSString stringWithFormat:@"%@", self.shortVersion] : @"";
  NSString *versionString = [shortString length] ? [NSString stringWithFormat:@" (%@)", self.version] : self.version;
  return [NSString stringWithFormat:@"%@ %@%@", BWHockeyLocalize(@"HockeyVersion"), shortString, versionString];
}

- (NSString *)dateString {
  NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
  [formatter setDateStyle:NSDateFormatterMediumStyle];
  
  return [formatter stringFromDate:self.date];
}

- (NSString *)sizeInMB {
  if ([size_ isKindOfClass: [NSNumber class]] && [size_ doubleValue] > 0) {
    double appSizeInMB = [size_ doubleValue]/(1024*1024);
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

// a valid app needs at least following properties: name, version, date
- (BOOL)isValid {
  BOOL valid = [self.name length] && [self.version length] && self.date;
  return valid;
}

@end
