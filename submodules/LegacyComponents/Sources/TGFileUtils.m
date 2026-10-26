#import <LegacyComponents/TGFileUtils.h>

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSString *TGMimeTypeForFileExtension(NSString *fileExtension)
{
    if (fileExtension == nil)
        return TGMimeTypeForFileUTI(nil);
    return TGMimeTypeForFileUTI([UTType typeWithFilenameExtension:fileExtension].identifier);
}

NSString *TGMimeTypeForFileUTI(NSString *fileUTI)
{
    NSString *mimeType = fileUTI != nil ? [UTType typeWithIdentifier:fileUTI].preferredMIMEType : nil;
    if (mimeType == nil)
        mimeType = @"application/octet-stream";
    return mimeType;
}

NSString *TGTemporaryFileName(NSString *fileExtension)
{
    if (fileExtension == nil)
        fileExtension = @"bin";
    
    int64_t randomId = 0;
    arc4random_buf(&randomId, sizeof(randomId));
    
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%" PRIx64 ".%@", randomId, fileExtension]];
}
