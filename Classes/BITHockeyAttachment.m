/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2014 HockeyApp, Bit Stadium GmbH.
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

#import "BITHockeyAttachment.h"

@implementation BITHockeyAttachment

- (instancetype)initWithFilename:(NSString *)filename
            hockeyAttachmentData:(NSData *)hockeyAttachmentData
                     contentType:(NSString *)contentType
{
  if (self = [super init]) {
    _filename = filename;

    _hockeyAttachmentData = hockeyAttachmentData;
    
    if (contentType) {
      _contentType = contentType;
    } else {
      _contentType = @"application/octet-stream";
    }

  }
  
  return self;
}


#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)encoder {
  if (self.filename) {
    [encoder encodeObject:self.filename forKey:@"filename"];
  }
  if (self.hockeyAttachmentData) {
    [encoder encodeObject:self.hockeyAttachmentData forKey:@"data"];
  }
  [encoder encodeObject:self.contentType forKey:@"contentType"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  if ((self = [super init])) {
    _filename = [decoder decodeObjectForKey:@"filename"];
    _hockeyAttachmentData = [decoder decodeObjectForKey:@"data"];
    _contentType = [decoder decodeObjectForKey:@"contentType"];
  }
  return self;
}

@end
