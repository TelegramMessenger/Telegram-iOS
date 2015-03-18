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
#import <MobileCoreServices/MobileCoreServices.h>

#define kCacheFolderName @"attachments"

@interface BITFeedbackMessageAttachment()

@property (nonatomic, strong) NSMutableDictionary *thumbnailRepresentations;
@property (nonatomic, strong) NSData *internalData;
@property (nonatomic, copy) NSString *filename;


@end

@implementation BITFeedbackMessageAttachment {
  NSString *_tempFilename;
  
  NSString *_cachePath;
  
  NSFileManager *_fm;
}


+ (BITFeedbackMessageAttachment *)attachmentWithData:(NSData *)data contentType:(NSString *)contentType {
  
  static NSDateFormatter *formatter;
  
  if(!formatter) {
    formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
  }
  
  BITFeedbackMessageAttachment *newAttachment = [BITFeedbackMessageAttachment new];
  newAttachment.contentType = contentType;
  newAttachment.data = data;
  newAttachment.originalFilename = [NSString stringWithFormat:@"Attachment: %@", [formatter stringFromDate:[NSDate date]]];

  return newAttachment;
}

- (instancetype)init {
  if ((self = [super init])) {
    _isLoading = NO;
    _thumbnailRepresentations = [NSMutableDictionary new];
    
    _fm = [[NSFileManager alloc] init];
    _cachePath = [bit_settingsDir() stringByAppendingPathComponent:kCacheFolderName];
    
    BOOL isDirectory;
    
    if (![_fm fileExistsAtPath:_cachePath isDirectory:&isDirectory]){
      [_fm createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
  }
  return self;
}

- (void)setData:(NSData *)data {
  self->_internalData = data;
  self.filename = [self possibleFilename];
  [self->_internalData writeToFile:self.filename atomically:NO];
}

- (NSData *)data {
  if (!self->_internalData && self.filename) {
    self.internalData = [NSData dataWithContentsOfFile:self.filename];
  }
  
  if (self.internalData) {
    return self.internalData;
  }
  
  return nil;
}

- (void)replaceData:(NSData *)data {
  self.data = data;
  self.thumbnailRepresentations = [NSMutableDictionary new];
}

- (BOOL)needsLoadingFromURL {
  return (self.sourceURL && ![_fm fileExistsAtPath:[self.localURL path]]);
}

- (BOOL)isImage {
  return ([self.contentType rangeOfString:@"image"].location != NSNotFound);
}

- (NSURL *)localURL {
  if (self.filename && [_fm fileExistsAtPath:self.filename]) {
    return [NSURL fileURLWithPath:self.filename];
  }
  
  return nil;
}


#pragma mark NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.contentType forKey:@"contentType"];
  [aCoder encodeObject:self.filename forKey:@"filename"];
  [aCoder encodeObject:self.originalFilename forKey:@"originalFilename"];
  [aCoder encodeObject:self.sourceURL forKey:@"url"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  if ((self = [self init])) {
    self.contentType = [aDecoder decodeObjectForKey:@"contentType"];
    self.filename = [aDecoder decodeObjectForKey:@"filename"];
    self.thumbnailRepresentations = [NSMutableDictionary new];
    self.originalFilename = [aDecoder decodeObjectForKey:@"originalFilename"];
    self.sourceURL = [aDecoder decodeObjectForKey:@"url"];
  }
  
  return self;
}


#pragma mark - Thumbnails / Image Representation

- (UIImage *)imageRepresentation {
  if ([self.contentType rangeOfString:@"image"].location != NSNotFound && self.filename ) {
    return [UIImage imageWithData:self.data];
  } else {
    // Create a Icon ..
    UIDocumentInteractionController* docController = [[UIDocumentInteractionController alloc] init];
    docController.name = self.originalFilename;
    NSArray* icons = docController.icons;
    if (icons.count){
      return icons[0];
    } else {
      return nil;
    }
  }
}

- (UIImage *)thumbnailWithSize:(CGSize)size {
  id<NSCopying> cacheKey = [NSValue valueWithCGSize:size];
  
  if (!self.thumbnailRepresentations[cacheKey]) {
    UIImage *image = self.imageRepresentation;
    // consider the scale.
    if (!image) {
      return nil;
    }
    
    CGFloat scale = [UIScreen mainScreen].scale;
    
    if (scale != image.scale) {
      
      CGSize scaledSize = CGSizeApplyAffineTransform(size, CGAffineTransformMakeScale(scale, scale));
      UIImage *thumbnail = bit_imageToFitSize(image, scaledSize, YES) ;
      
      UIImage *scaledThumbnail = [UIImage imageWithCGImage:thumbnail.CGImage scale:scale orientation:thumbnail.imageOrientation];
      if (thumbnail) {
        [self.thumbnailRepresentations setObject:scaledThumbnail forKey:cacheKey];
      }
      
    } else {
      UIImage *thumbnail = bit_imageToFitSize(image, size, YES) ;
      
      [self.thumbnailRepresentations setObject:thumbnail forKey:cacheKey];
      
    }
    
  }
  
  return self.thumbnailRepresentations[cacheKey];
}


#pragma mark - Persistence Helpers

- (NSString *)possibleFilename {
  if (_tempFilename) {
    return _tempFilename;
  }
  
  NSString *uniqueString = bit_UUID();
  _tempFilename = [_cachePath stringByAppendingPathComponent:uniqueString];
  
  // File extension that suits the Content type.
  
  CFStringRef mimeType = (__bridge CFStringRef)self.contentType;
  CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, NULL);
  CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
  if (extension) {
    _tempFilename = [_tempFilename stringByAppendingPathExtension:(__bridge NSString *)(extension)];
    CFRelease(extension);
  }
  
  CFRelease(uti);
  
  return _tempFilename;
}

- (void)deleteContents {
  if (self.filename) {
    [_fm removeItemAtPath:self.filename error:nil];
    self.filename = nil;
  }
}


#pragma mark - QLPreviewItem

- (NSString *)previewItemTitle {
  return self.originalFilename;
}

- (NSURL *)previewItemURL {
  if (self.localURL){
    return self.localURL;
  } else if (self.sourceURL) {
    NSString *filename = self.possibleFilename;
    if (filename) {
      return [NSURL fileURLWithPath:filename];
    }
  }
  
  return nil;
}

@end
