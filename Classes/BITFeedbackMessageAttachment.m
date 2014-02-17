/*
 * Author: Moritz Haarmann <post@moritzhaarmann.de>
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


#import "BITFeedbackMessageAttachment.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"

@interface BITFeedbackMessageAttachment()

@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSMutableDictionary *thumbnailRepresentations;

@end

@implementation BITFeedbackMessageAttachment

+ (BITFeedbackMessageAttachment *)attachmentWithData:(NSData *)data contentType:(NSString *)contentType {
  BITFeedbackMessageAttachment *newAttachment = [BITFeedbackMessageAttachment new];
  newAttachment.contentType = contentType;
  newAttachment.data = data;
  return newAttachment;
}

-(id)init {
  self = [super init];
  if (self){
    self.thumbnailRepresentations = [NSMutableDictionary new];
  }
  return self;
}

#pragma mark NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.contentType forKey:@"contentType"];
  [aCoder encodeObject:self.filename forKey:@"filename"];

}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super init];
  
  if (self){
    self.contentType = [aDecoder decodeObjectForKey:@"contentType"];
    self.filename = [aDecoder decodeObjectForKey:@"filename"];
    self.thumbnailRepresentations = [NSMutableDictionary new];
  }
  
  return self;
}

- (UIImage *)imageRepresentation {
  if ([self.contentType rangeOfString:@"image"].location != NSNotFound){
    return [UIImage imageWithData:self.data];
  } else {
   // return bit_imageNamed(@"feedbackActiviy.png", BITHOCKEYSDK_BUNDLE);
  }
}

- (UIImage *)thumbnailWithSize:(CGSize)size {
  id<NSCopying> cacheKey = [NSValue valueWithCGSize:size];
  
//  if (!self.thumbnailRepresentations[cacheKey]){
//    UIImage *thumbnail =bit_imageToFitSize(self.imageRepresentation, size, YES);
//    [self.thumbnailRepresentations setObject:thumbnail forKey:cacheKey];
//  }
  
  return self.thumbnailRepresentations[cacheKey];
}

@end
