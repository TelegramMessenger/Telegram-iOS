/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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


#import "BITFeedbackMessage.h"

@implementation BITFeedbackMessage


#pragma mark - NSObject

- (id) init {
  if ((self = [super init])) {
    _text = nil;
    _userID = nil;
    _name = nil;
    _email = nil;
    _date = [[NSDate alloc] init];
    _token = nil;
    _id = [[NSNumber alloc] initWithInteger:0];
    _status = BITFeedbackMessageStatusSendPending;
    _userMessage = NO;
  }
  return self;
}


#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)encoder {
  [encoder encodeObject:self.text forKey:@"text"];
  [encoder encodeObject:self.userID forKey:@"userID"];
  [encoder encodeObject:self.name forKey:@"name"];
  [encoder encodeObject:self.email forKey:@"email"];
  [encoder encodeObject:self.date forKey:@"date"];
  [encoder encodeObject:self.id forKey:@"id"];
  [encoder encodeInteger:self.status forKey:@"status"];
  [encoder encodeBool:self.userMessage forKey:@"userMessage"];
  [encoder encodeObject:self.token forKey:@"token"];
}

- (id)initWithCoder:(NSCoder *)decoder {
  if ((self = [super init])) {
    self.text = [decoder decodeObjectForKey:@"text"];
    self.userID = [decoder decodeObjectForKey:@"userID"];
    self.name = [decoder decodeObjectForKey:@"name"];
    self.email = [decoder decodeObjectForKey:@"email"];
    self.date = [decoder decodeObjectForKey:@"date"];
    self.id = [decoder decodeObjectForKey:@"id"];
    self.status = (BITFeedbackMessageStatus)[decoder decodeIntegerForKey:@"status"];
    self.userMessage = [decoder decodeBoolForKey:@"userMessage"];
    self.token = [decoder decodeObjectForKey:@"token"];
  }
  return self;
}

@end
