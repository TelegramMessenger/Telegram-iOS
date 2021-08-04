#import "TGPassportICloud.h"

#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/TGPassportAttachMenu.h>

@interface TGPassportICloudFileDescription : NSObject

@property (nonatomic, readonly) NSString *urlData;
@property (nonatomic, readonly) NSString *fileName;
@property (nonatomic, readonly) NSUInteger fileSize;

+ (instancetype)descriptionWithURL:(NSURL *)url;

@end

@implementation TGPassportICloudFileDescription

+ (instancetype)descriptionWithURL:(NSURL *)url
{
    if (![url startAccessingSecurityScopedResource])
        return nil;
    
    NSError *error;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *urlData = [[url bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile includingResourceValuesForKeys:nil relativeToURL:nil error:&error] base64Encoding];
#pragma clang diagnostic pop
    if (error != nil || urlData == nil)
        return nil;
    
    NSNumber *fileSizeValue;
    [url getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:&error];
    if (error != nil || fileSizeValue == nil)
        return nil;
    
    NSString *fileName = [url.lastPathComponent stringByRemovingPercentEncoding];
    if (fileName == nil)
        return nil;
    
    TGPassportICloudFileDescription *description = [[TGPassportICloudFileDescription alloc] init];
    description->_urlData = urlData;
    description->_fileSize = fileSizeValue.unsignedIntegerValue;
    description->_fileName = fileName;
    
    [url stopAccessingSecurityScopedResource];
    
    return description;
}

@end

@implementation TGPassportICloud

+ (SSignal *)iCloudFileDescriptionForURL:(NSURL *)url
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        bool isRemote = false;
        bool isCurrent = true;
        
        NSError *error;
        NSDictionary *fileAttributes = [url resourceValuesForKeys:@[ NSURLUbiquitousItemDownloadingStatusKey ] error:&error];
        NSString *status = fileAttributes[NSURLUbiquitousItemDownloadingStatusKey];
        if (status != nil)
        {
            isRemote = true;
            if (![status isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent])
                isCurrent = false;
        }
        
        if (!isRemote || isCurrent)
        {
            [subscriber putNext:[TGPassportICloudFileDescription descriptionWithURL:url]];
            [subscriber putCompletion];
            return nil;
        }
        else
        {
            NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
            query.searchScopes = @[NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope];
            query.predicate = [NSPredicate predicateWithFormat:@"%K.lastPathComponent = %@", NSMetadataItemFSNameKey, url.lastPathComponent];
            query.valueListAttributes = @[NSMetadataItemFSSizeKey];
            
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSMetadataQueryDidFinishGatheringNotification object:query queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
            {
                [query disableUpdates];
                
                NSMetadataItem *metadataItem = query.results.firstObject;
                if (metadataItem == nil)
                {
                    [query enableUpdates];
                    return;
                }
                
                [query stopQuery];
                
                NSUInteger fileSize = [[metadataItem valueForAttribute:NSMetadataItemFSSizeKey] unsignedIntegerValue];
                if (fileSize == 0)
                {
                    [subscriber putNext:nil];
                    [subscriber putCompletion];
                    return;
                }
            }];
            
            [query startQuery];
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [query stopQuery];
                    [[NSNotificationCenter defaultCenter] removeObserver:observer];
                });
            }];
        }
    }];
}

+ (SSignal *)fetchICloudFileWithDescription:(TGPassportICloudFileDescription *)description
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSData *urlData = [[NSData alloc] initWithBase64Encoding:description.urlData];
#pragma clang diagnostic pop
        if (urlData == nil)
        {
            [subscriber putCompletion];
            return nil;
        }
        
        NSError *error;
        bool bookmarkIsStale = false;
        NSURL *url = [NSURL URLByResolvingBookmarkData:urlData options:kNilOptions relativeToURL:nil bookmarkDataIsStale:&bookmarkIsStale error:&error];
        if (error != nil || url == nil)
        {
            [subscriber putCompletion];
            return nil;
        }
        
        bool isRemote = false;
        bool isCurrent = true;
        
        NSDictionary *fileAttributes = [url resourceValuesForKeys:@[ NSURLUbiquitousItemDownloadingStatusKey ] error:&error];
        NSString *status = fileAttributes[NSURLUbiquitousItemDownloadingStatusKey];
        if (status != nil)
        {
            isRemote = true;
            if (![status isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent])
                isCurrent = false;
        }
        
        if (![url startAccessingSecurityScopedResource])
        {
            [subscriber putCompletion];
            return nil;
        }
        
        NSURL *targetURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"icloud_doc%@", [NSString stringWithFormat:@"%ld", lrand48()]]]];
        if (!isRemote || isCurrent)
        {
            NSError *fileCopyError;
            [[NSFileManager defaultManager] copyItemAtURL:url toURL:targetURL error:&fileCopyError];
            [url stopAccessingSecurityScopedResource];
            [subscriber putNext:targetURL];
            [subscriber putCompletion];
            return nil;
        }
        
        NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        NSFileAccessIntent *fileAccessIntent = [NSFileAccessIntent readingIntentWithURL:url options:NSFileCoordinatorReadingWithoutChanges];
        [fileCoordinator coordinateAccessWithIntents:@[fileAccessIntent] queue:[NSOperationQueue mainQueue] byAccessor:^(NSError * _Nullable error)
        {
            if (error == nil)
            {
                NSError *fileCopyError;
                [[NSFileManager defaultManager] copyItemAtURL:url toURL:targetURL error:&fileCopyError];
                [url stopAccessingSecurityScopedResource];
                [subscriber putNext:targetURL];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putCompletion];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [fileCoordinator cancel];
        }];
    }];
}

+ (SSignal *)fetchICloudFileWith:(NSURL *)url
{
    return [[self iCloudFileDescriptionForURL:url] mapToSignal:^SSignal *(TGPassportICloudFileDescription *description) {
        return [self fetchICloudFileWithDescription:description];
    }];
}

@end
