#import <ShareItemsImpl/TGItemProviderSignals.h>

#import <MtProtoKit/MtProtoKit.h>

#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AddressBook/AddressBook.h>
#import <AVFoundation/AVFoundation.h>
#import <PassKit/PassKit.h>

#import <MimeTypes/MimeTypes.h>

@implementation TGItemProviderSignals

+ (NSArray<MTSignal *> *)itemSignalsForInputItems:(NSArray *)inputItems
{
    NSMutableArray *itemSignals = [[NSMutableArray alloc] init];
    NSMutableArray *providers = [[NSMutableArray alloc] init];
    
    for (NSExtensionItem *item in inputItems)
    {
        for (NSItemProvider *provider in item.attachments)
        {
            if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeMovie])
                [providers addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeAudio])
                [providers addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeImage])
                [providers addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeFileURL])
                [providers addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL]) {
                [providers removeAllObjects];
                
                [providers addObject:provider];
                break;
            }
            else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeVCard])
                [providers addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeText])
                [providers addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeData])
                [providers addObject:provider];
            else if ([provider hasItemConformingToTypeIdentifier:@"com.apple.pkpass"])
                [providers addObject:provider];
        }
    }
    
    NSInteger providerIndex = -1;
    for (NSItemProvider *provider in providers)
    {
        providerIndex++;
        
        MTSignal *dataSignal = nil;
        if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeAudio])
            dataSignal = [self signalForAudioItemProvider:provider];
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeMovie])
            dataSignal = [self signalForVideoItemProvider:provider];
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeGIF])
            dataSignal = [self signalForDataItemProvider:provider];
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeImage])
            dataSignal = [self signalForImageItemProvider:provider];
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeFileURL])
        {
            dataSignal = [[self signalForUrlItemProvider:provider] mapToSignal:^MTSignal *(NSURL *url)
            {
                NSData *data = [[NSData alloc] initWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
                if (data == nil)
                    return [MTSignal fail:nil];
                NSString *fileName = [[url pathComponents] lastObject];
                if (fileName.length == 0)
                    fileName = @"file.bin";
                NSString *extension = [fileName pathExtension];
                NSString *mimeType = [TGMimeTypeMap mimeTypeForExtension:[extension lowercaseString]];
                if (mimeType == nil)
                    mimeType = @"application/octet-stream";
                return [MTSignal single:@{@"data": data, @"fileName": fileName, @"mimeType": mimeType}];
            }];
        }
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeVCard])
            dataSignal = [self signalForVCardItemProvider:provider];
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeText])
            dataSignal = [self signalForTextItemProvider:provider];
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL])
            dataSignal = [self signalForTextUrlItemProvider:provider];
        else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeData])
        {
            dataSignal = [[self signalForDataItemProvider:provider] map:^id(NSDictionary *dict)
            {
                if (dict[@"fileName"] == nil)
                {
                    NSMutableDictionary *updatedDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
                    for (NSString *typeIdentifier in provider.registeredTypeIdentifiers)
                    {
                        NSString *extension = [TGMimeTypeMap extensionForMimeType:typeIdentifier];
                        if (extension == nil)
                            extension = [TGMimeTypeMap extensionForMimeType:[@"application/" stringByAppendingString:typeIdentifier]];
                        
                        if (extension != nil) {
                            updatedDict[@"fileName"] = [@"file" stringByAppendingPathExtension:extension];
                            updatedDict[@"mimeType"] = [TGMimeTypeMap mimeTypeForExtension:extension];
                        }
                    }
                    return updatedDict;
                }
                else
                {
                    return dict;
                }
            }];
        }
        else if ([provider hasItemConformingToTypeIdentifier:@"com.apple.pkpass"])
        {
            dataSignal = [self signalForPassKitItemProvider:provider];
        }

        if (dataSignal != nil)
            [itemSignals addObject:dataSignal];
    }
    
    return itemSignals;
}

+ (MTSignal *)signalForDataItemProvider:(NSItemProvider *)itemProvider
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeData options:nil completionHandler:^(NSData *data, NSError *error)
        {
            if (error != nil)
                [subscriber putError:nil];
            else
            {
                [subscriber putNext:@{@"data": data}];
                [subscriber putCompletion];
            }
        }];
        
        return nil;
    }];
}

static UIImage *TGScaleImageToPixelSize(UIImage *image, CGSize size) {
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0f);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

static CGSize TGFitSize(CGSize size, CGSize maxSize) {
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (size.width > maxSize.width)
    {
        size.height = floor((size.height * maxSize.width / size.width));
        size.width = maxSize.width;
    }
    if (size.height > maxSize.height)
    {
        size.width = floor((size.width * maxSize.height / size.height));
        size.height = maxSize.height;
    }
    return size;
}

+ (MTSignal *)signalForImageItemProvider:(NSItemProvider *)itemProvider
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        bool preferAsFile = false;
#if DEBUG
        preferAsFile = true;
#endif
        
        CGSize maxSize = CGSizeMake(1280.0, 1280.0);
        NSDictionary *imageOptions = @{
            NSItemProviderPreferredImageSizeKey: [NSValue valueWithCGSize:maxSize]
        };
        if (preferAsFile) {
            imageOptions = nil;
        }
        if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeImage]) {
            [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeImage options:imageOptions completionHandler:^(id<NSSecureCoding> _Nullable item, NSError * _Null_unspecified error) {
                if (error != nil && ![(NSObject *)item respondsToSelector:@selector(CGImage)] && ![(NSObject *)item respondsToSelector:@selector(absoluteString)]) {
                    [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeData options:nil completionHandler:^(UIImage *image, NSError *error)
                     {
                         if (error != nil)
                             [subscriber putError:nil];
                         else
                         {
                             [subscriber putNext:@{@"image": image}];
                             [subscriber putCompletion];
                         }
                     }];
                } else {
                    if ([(NSObject *)item respondsToSelector:@selector(absoluteString)]) {
                        NSURL *url = (NSURL *)item;
                        
                        if (preferAsFile) {
                            NSData *data = [[NSData alloc] initWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
                            if (data == nil) {
                                [subscriber putError:nil];
                                return;
                            }
                            NSString *fileName = [[url pathComponents] lastObject];
                            if (fileName.length == 0) {
                                fileName = @"file.bin";
                            }
                            NSString *extension = [fileName pathExtension];
                            NSString *mimeType = [TGMimeTypeMap mimeTypeForExtension:[extension lowercaseString]];
                            if (mimeType == nil) {
                                mimeType = @"application/octet-stream";
                            }
                            [subscriber putNext:@{@"data": data, @"fileName": fileName, @"mimeType": mimeType, @"treatAsFile": @true}];
                            [subscriber putCompletion];
                        } else {
                            CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef) url, NULL);

                            CFDictionaryRef options = (__bridge CFDictionaryRef) @{
                                (id) kCGImageSourceCreateThumbnailWithTransform : @YES,
                                (id) kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                (id) kCGImageSourceThumbnailMaxPixelSize : @(maxSize.width)
                            };
                            
                            CGImageRef image = CGImageSourceCreateThumbnailAtIndex(src, 0, options);
                            CFRelease(src);
                            
                            if (image == nil) {
                                [subscriber putError:nil];
                                return;
                            }
                            
                            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"img%d", (int)arc4random()]];
                            CFURLRef tempUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:tempPath];
                            CGImageDestinationRef destination = CGImageDestinationCreateWithURL(tempUrl, kUTTypeJPEG, 1, NULL);
                            NSDictionary *properties = @{ (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(0.52)};

                            CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)properties);
                            CGImageDestinationAddImage(destination, image, nil);
                            
                            if (!CGImageDestinationFinalize(destination)) {
                                CFRelease(destination);
                                
                                [subscriber putError:nil];
                                return;
                            }
                            
                            CFRelease(destination);
                            NSData *resultData = [[NSData alloc] initWithContentsOfFile:tempPath options:NSDataReadingMappedIfSafe error:nil];
                            if (resultData != nil) {
                                [subscriber putNext:@{@"scaledImageData": resultData, @"scaledImageDimensions": [NSValue valueWithCGSize:CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image))]}];
                                [subscriber putCompletion];
                            } else {
                                [subscriber putError:nil];
                            }
                        }
                    } else {
                        [subscriber putNext:@{@"image": item}];
                        [subscriber putCompletion];
                    }
                }
            }];
        } else {
            [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeData options:nil completionHandler:^(UIImage *image, NSError *error)
             {
                 if (error != nil)
                     [subscriber putError:nil];
                 else
                 {
                     [subscriber putNext:@{@"image": image}];
                     [subscriber putCompletion];
                 }
             }];
        }
        
        return nil;
    }];
}

+ (MTSignal *)signalForAudioItemProvider:(NSItemProvider *)itemProvider
{
    MTSignal *itemSignal = [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeAudio options:nil completionHandler:^(NSURL *url, NSError *error)
        {
            if (error != nil)
               [subscriber putError:nil];
            else
            {
                [subscriber putNext:url];
                [subscriber putCompletion];
            }
        }];
        return nil;
    }];
    
    return [itemSignal map:^id(NSURL *url)
    {
        AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        if (asset == nil)
            return [MTSignal fail:nil];
        
        NSString *extension = url.pathExtension;
        NSString *mimeType = [TGMimeTypeMap mimeTypeForExtension:[extension lowercaseString]];
        if (mimeType == nil)
            mimeType = @"application/octet-stream";
        
        NSString *title = (NSString *)[[AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon] firstObject];
        NSString *artist = (NSString *)[[AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon] firstObject];
        
        NSString *software = nil;
        AVMetadataItem *softwareItem = [[AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeySoftware keySpace:AVMetadataKeySpaceCommon] firstObject];
        if ([softwareItem isKindOfClass:[AVMetadataItem class]] && ([softwareItem.value isKindOfClass:[NSString class]]))
            software = (NSString *)[softwareItem value];
        
        bool isVoice = [software hasPrefix:@"com.apple.VoiceMemos"];
            
        NSTimeInterval duration =  CMTimeGetSeconds(asset.duration);
        
        NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        result[@"audio"] = url;
        result[@"mimeType"] = mimeType;
        result[@"duration"] = @(duration);
        result[@"isVoice"] = @(isVoice);
        
        NSString *artistString = @"";
        if ([artist respondsToSelector:@selector(characterAtIndex:)]) {
            artistString = artist;
        } else if ([artist isKindOfClass:[AVMetadataItem class]]) {
            artistString = [(AVMetadataItem *)artist stringValue];
        }
        
        NSString *titleString = @"";
        if ([artist respondsToSelector:@selector(characterAtIndex:)]) {
            titleString = title;
        } else if ([title isKindOfClass:[AVMetadataItem class]]) {
            titleString = [(AVMetadataItem *)title stringValue];
        }
        
        if (artistString.length > 0)
            result[@"artist"] = artistString;
        if (titleString.length > 0)
            result[@"title"] = titleString;
        
        return result;
    }];
}

+ (MTSignal *)detectRoundVideo:(AVAsset *)asset
{
    MTSignal *imageSignal = [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subsriber)
    {
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        imageGenerator.appliesPreferredTrackTransform = true;
        [imageGenerator generateCGImagesAsynchronouslyForTimes:@[ [NSValue valueWithCMTime:kCMTimeZero] ] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error)
        {
            if (error != nil)
            {
                [subsriber putError:nil];
            }
            else
            {
                [subsriber putNext:[UIImage imageWithCGImage:image]];
                [subsriber putCompletion];
            }
        }];
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            [imageGenerator cancelAllCGImageGeneration];
        }];
    }];
    
    return [imageSignal map:^NSNumber *(UIImage *image)
    {
        CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
        const UInt8 *data = CFDataGetBytePtr(pixelData);
        
        bool (^isWhitePixel)(NSInteger, NSInteger) = ^bool(NSInteger x, NSInteger y)
        {
            int pixelInfo = ((image.size.width  * y) + x ) * 4;
            
            UInt8 red = data[pixelInfo];
            UInt8 green = data[(pixelInfo + 1)];
            UInt8 blue = data[pixelInfo + 2];
            
            return (red > 250 && green > 250 && blue > 250);
        };
        
        CFRelease(pixelData);

        return @(isWhitePixel(0, 0) && isWhitePixel(image.size.width - 1, 0) && isWhitePixel(0, image.size.height - 1) && isWhitePixel(image.size.width - 1, image.size.height - 1));
    }];
}

+ (MTSignal *)signalForVideoItemProvider:(NSItemProvider *)itemProvider
{
    MTSignal *assetSignal = [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeMovie options:nil completionHandler:^(NSURL *url, NSError *error)
        {
            if (error != nil)
            {
                [subscriber putError:nil];
            }
            else
            {
                AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
                [subscriber putNext:asset];
                [subscriber putCompletion];
            }
        }];
        
        return nil;
    }];
    
    return [assetSignal mapToSignal:^MTSignal *(AVURLAsset *asset)
    {
        AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        if (videoTrack == nil)
        {
            return [MTSignal fail:nil];
        }
        else
        {
            CGSize dimensions = CGRectApplyAffineTransform((CGRect){CGPointZero, videoTrack.naturalSize}, videoTrack.preferredTransform).size;
            NSString *extension = asset.URL.pathExtension;
            NSString *mimeType = [TGMimeTypeMap mimeTypeForExtension:[extension lowercaseString]];
            if (mimeType == nil)
                mimeType = @"application/octet-stream";
            
            NSString *software = nil;
            AVMetadataItem *softwareItem = [[AVMetadataItem metadataItemsFromArray:asset.metadata withKey:AVMetadataCommonKeySoftware keySpace:AVMetadataKeySpaceCommon] firstObject];
            if ([softwareItem isKindOfClass:[AVMetadataItem class]] && ([softwareItem.value isKindOfClass:[NSString class]]))
                software = (NSString *)[softwareItem value];
            
            bool isAnimation = false;
            if ([software hasPrefix:@"Boomerang"])
                isAnimation = true;
            
            if (isAnimation || fabs(dimensions.width - dimensions.height) > FLT_EPSILON)
            {
                return [MTSignal single:@{@"video": asset, @"mimeType": mimeType, @"isAnimation": @(isAnimation), @"width": @(dimensions.width), @"height": @(dimensions.height)}];
            }
            else
            {
                return [[self detectRoundVideo:asset] mapToSignal:^MTSignal *(NSNumber *isRoundVideo)
                {
                    return [MTSignal single:@{@"video": asset, @"mimeType": mimeType, @"isAnimation": @(isAnimation), @"width": @(dimensions.width), @"height": @(dimensions.height), @"isRoundMessage": isRoundVideo}];
                }];
            }
        }
    }];
}

+ (MTSignal *)signalForUrlItemProvider:(NSItemProvider *)itemProvider
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeFileURL options:nil completionHandler:^(NSURL *url, NSError *error)
        {
            if (error != nil)
                [subscriber putError:nil];
            else
            {
                [subscriber putNext:url];
                [subscriber putCompletion];
            }
        }];
        
        return nil;
    }];
}

+ (MTSignal *)signalForTextItemProvider:(NSItemProvider *)itemProvider
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeText options:nil completionHandler:^(NSString *text, NSError *error)
        {
            if (error != nil)
                [subscriber putError:nil];
            else
            {
                [subscriber putNext:@{@"text": text}];
                [subscriber putCompletion];
            }
        }];
        
        return nil;
    }];
}

+ (MTSignal *)signalForTextUrlItemProvider:(NSItemProvider *)itemProvider
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeURL options:nil completionHandler:^(NSURL *url, NSError *error)
        {
            if (error != nil)
                [subscriber putError:nil];
            else
            {
                [subscriber putNext:@{@"url": url}];
                [subscriber putCompletion];
            }
        }];
        
        return nil;
    }];
}

+ (MTSignal *)signalForVCardItemProvider:(NSItemProvider *)itemProvider
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeVCard options:nil completionHandler:^(NSData *vcard, NSError *error)
        {
            if (error != nil)
                [subscriber putError:nil];
            else
            {
                [subscriber putNext:@{@"contact": vcard}];
                [subscriber putCompletion];
            }
        }];
        
        return nil;
    }];
}

+ (MTSignal *)signalForPassKitItemProvider:(NSItemProvider *)itemProvider
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        [itemProvider loadItemForTypeIdentifier:@"com.apple.pkpass" options:nil completionHandler:^(id data, NSError *error)
        {
            if (error != nil)
            {
                [subscriber putError:nil];
            }
            else
            {
                NSError *parseError;
                PKPass *pass = [[PKPass alloc] initWithData:data error:&parseError];
                if (parseError != nil)
                {
                    [subscriber putError:nil];
                }
                else
                {
                    NSString *fileName = [NSString stringWithFormat:@"%@.pkpass", pass.serialNumber];
                    [subscriber putNext:@{@"data": data, @"fileName": fileName, @"mimeType": @"application/vnd.apple.pkpass"}];
                    [subscriber putCompletion];
                }
            }
        }];
        
        return nil;
    }];
}

static void set_bits(uint8_t *bytes, int32_t bitOffset, int32_t numBits, int32_t value) {
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    uint8_t *data = bytes;
    data += bitOffset / 8;
    bitOffset %= 8;
    *((int32_t *)data) |= ((value) << bitOffset);
}

+ (NSData *)audioWaveform:(NSURL *)url {
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    if (asset == nil) {
        NSLog(@"asset is not defined!");
        return nil;
    }
    
    NSError *assetError = nil;
    AVAssetReader *iPodAssetReader = [AVAssetReader assetReaderWithAsset:asset error:&assetError];
    if (assetError) {
        NSLog (@"error: %@", assetError);
        return nil;
    }
    
    AVAssetReaderOutput *readerOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:outputSettings];
    
    if (! [iPodAssetReader canAddOutput: readerOutput]) {
        NSLog (@"can't add reader output... die!");
        return nil;
    }
    
    // add output reader to reader
    [iPodAssetReader addOutput: readerOutput];
    
    if (![iPodAssetReader startReading]) {
        NSLog(@"Unable to start reading!");
        return nil;
    }
    
    NSMutableData *_waveformSamples = [[NSMutableData alloc] init];
    int16_t _waveformPeak = 0;
    int _waveformPeakCount = 0;
    
    while (iPodAssetReader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef nextBuffer = [readerOutput copyNextSampleBuffer];
        
        if (nextBuffer) {
            AudioBufferList abl;
            CMBlockBufferRef blockBuffer = NULL;
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
            UInt64 size = CMSampleBufferGetTotalSampleSize(nextBuffer);
            if (size != 0) {
                int16_t *samples = (int16_t *)(abl.mBuffers[0].mData);
                int count = (int)size / 2;
                
                for (int i = 0; i < count; i++) {
                    int16_t sample = samples[i];
                    if (sample < 0) {
                        sample = -sample;
                    }
                    
                    if (_waveformPeak < sample) {
                        _waveformPeak = sample;
                    }
                    _waveformPeakCount++;
                    
                    if (_waveformPeakCount >= 100) {
                        [_waveformSamples appendBytes:&_waveformPeak length:2];
                        _waveformPeak = 0;
                        _waveformPeakCount = 0;
                    }
                }
            }
            
            CFRelease(nextBuffer);
            if (blockBuffer) {
                CFRelease(blockBuffer);
            }
        }
        else {
            break;
        }
    }
    
    int16_t scaledSamples[100];
    memset(scaledSamples, 0, 100 * 2);
    int16_t *samples = _waveformSamples.mutableBytes;
    int count = (int)_waveformSamples.length / 2;
    for (int i = 0; i < count; i++) {
        int16_t sample = samples[i];
        int index = i * 100 / count;
        if (scaledSamples[index] < sample) {
            scaledSamples[index] = sample;
        }
    }
    
    int16_t peak = 0;
    int64_t sumSamples = 0;
    for (int i = 0; i < 100; i++) {
        int16_t sample = scaledSamples[i];
        if (peak < sample) {
            peak = sample;
        }
        sumSamples += sample;
    }
    uint16_t calculatedPeak = 0;
    calculatedPeak = (uint16_t)(sumSamples * 1.8f / 100);
    
    if (calculatedPeak < 2500) {
        calculatedPeak = 2500;
    }
    
    for (int i = 0; i < 100; i++) {
        uint16_t sample = (uint16_t)((int64_t)samples[i]);
        if (sample > calculatedPeak) {
            scaledSamples[i] = calculatedPeak;
        }
    }
    
    int numSamples = 100;
    int bitstreamLength = (numSamples * 5) / 8 + (((numSamples * 5) % 8) == 0 ? 0 : 1);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:bitstreamLength];
    {
        int32_t maxSample = peak;
        uint16_t const *samples = (uint16_t *)scaledSamples;
        uint8_t *bytes = result.mutableBytes;
        
        for (int i = 0; i < numSamples; i++) {
            int32_t value = MIN(31, ABS((int32_t)samples[i]) * 31 / maxSample);
            set_bits(bytes, i * 5, 5, value & 31);
        }
    }
    
    return result;
}

@end
