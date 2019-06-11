/**********************************************************************************
 AudioPlayer.m
 
 Created by Thong Nguyen on 14/05/2012.
 https://github.com/tumtumtum/audjustable
 
 Copyright (c) 2012 Thong Nguyen (tumtumtum@gmail.com). All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. All advertising materials mentioning features or use of this software
 must display the following acknowledgement:
 This product includes software developed by Thong Nguyen (tumtumtum@gmail.com)
 4. Neither the name of Thong Nguyen nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY Thong Nguyen ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THONG NGUYEN BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**********************************************************************************/

#import "STKLocalFileDataSource.h"

@interface STKLocalFileDataSource()
{
    SInt64 position;
    SInt64 length;
    AudioFileTypeID audioFileTypeHint;
}
@property (readwrite, copy) NSString* filePath;
-(void) open;
@end

@implementation STKLocalFileDataSource
@synthesize filePath;

-(id) initWithFilePath:(NSString*)filePathIn
{
    if (self = [super init])
    {
        self.filePath = filePathIn;
        
        audioFileTypeHint = [STKLocalFileDataSource audioFileTypeHintFromFileExtension:filePathIn.pathExtension];
    }
    
    return self;
}

+(AudioFileTypeID) audioFileTypeHintFromFileExtension:(NSString*)fileExtension
{
    static dispatch_once_t onceToken;
    static NSDictionary* fileTypesByFileExtensions;
    
    dispatch_once(&onceToken, ^
    {
        fileTypesByFileExtensions =
        @{
            @"mp3": @(kAudioFileMP3Type),
            @"wav": @(kAudioFileWAVEType),
            @"aifc": @(kAudioFileAIFCType),
            @"aiff": @(kAudioFileAIFFType),
            @"m4a": @(kAudioFileM4AType),
            @"mp4": @(kAudioFileMPEG4Type),
            @"caf": @(kAudioFileCAFType),
            @"aac": @(kAudioFileAAC_ADTSType),
            @"ac3": @(kAudioFileAC3Type),
            @"3gp": @(kAudioFile3GPType)
        };
    });
    
    NSNumber* number = [fileTypesByFileExtensions objectForKey:fileExtension];
    
    if (!number)
    {
        return 0;
    }
    
    return (AudioFileTypeID)number.intValue;
}

-(AudioFileTypeID) audioFileTypeHint
{
    return audioFileTypeHint;
}

-(void) dealloc
{
    [self close];
}

-(void) close
{
    if (stream)
    {
        [self unregisterForEvents];

        CFReadStreamClose(stream);
        
        stream = 0;
    }
}

-(void) open
{
    if (stream)
    {
        [self unregisterForEvents];
        
        CFReadStreamClose(stream);
        CFRelease(stream);
        
        stream = 0;
    }
    
    NSURL* url = [[NSURL alloc] initFileURLWithPath:self.filePath];
    
    stream = CFReadStreamCreateWithFile(NULL, (__bridge CFURLRef)url);
    
    NSError* fileError;
    NSFileManager* manager = [[NSFileManager alloc] init];
    NSDictionary* attributes = [manager attributesOfItemAtPath:filePath error:&fileError];

    if (fileError)
    {
        CFReadStreamClose(stream);
        CFRelease(stream);
        stream = 0;
        return;
    }

    NSNumber* number = [attributes objectForKey:@"NSFileSize"];
    
    if (number)
    {
        length = number.longLongValue;
    }
    
    [self reregisterForEvents];

    CFReadStreamOpen(stream);
}

-(SInt64) position
{
    return position;
}

-(SInt64) length
{
    return length;
}

-(int) readIntoBuffer:(UInt8*)buffer withSize:(int)size
{
    int retval = (int)CFReadStreamRead(stream, buffer, size);

    if (retval > 0)
    {
        position += retval;
    }
    else
    {
        NSNumber* property = (__bridge_transfer NSNumber*)CFReadStreamCopyProperty(stream, kCFStreamPropertyFileCurrentOffset);
        
        position = property.longLongValue;
    }
    
    return retval;
}

-(void) seekToOffset:(SInt64)offset
{
    CFStreamStatus status = kCFStreamStatusClosed;
    
    if (stream != 0)
    {
		status = CFReadStreamGetStatus(stream);
    }
    
    BOOL reopened = NO;
    
    if (status == kCFStreamStatusAtEnd || status == kCFStreamStatusClosed || status == kCFStreamStatusError)
    {
        reopened = YES;
        
        [self close];        
        [self open];
    }
    
    if (stream == 0)
    {
        CFRunLoopPerformBlock(eventsRunLoop.getCFRunLoop, NSRunLoopCommonModes, ^
        {
            [self errorOccured];
        });
        
        CFRunLoopWakeUp(eventsRunLoop.getCFRunLoop);
        
        return;
    }
    
    if (CFReadStreamSetProperty(stream, kCFStreamPropertyFileCurrentOffset, (__bridge CFTypeRef)[NSNumber numberWithLongLong:offset]) != TRUE)
    {
        position = 0;
    }
    else
    {
        position = offset;
    }
    
    if (!reopened)
    {
        CFRunLoopPerformBlock(eventsRunLoop.getCFRunLoop, NSRunLoopCommonModes, ^
        {
            if ([self hasBytesAvailable])
            {
                [self dataAvailable];
            }
        });
        
        CFRunLoopWakeUp(eventsRunLoop.getCFRunLoop);
    }
}

-(NSString*) description
{
    return self->filePath;
}

@end
