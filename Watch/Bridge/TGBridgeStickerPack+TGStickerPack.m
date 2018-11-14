#import "TGBridgeStickerPack+TGStickerPack.h"
#import <LegacyComponents/TGStickerPack.h>
#import "TGBridgeDocumentMediaAttachment+TGDocumentMediaAttachment.h"

@implementation TGBridgeStickerPack (TGStickerPack)

+ (TGBridgeStickerPack *)stickerPackWithTGStickerPack:(TGStickerPack *)stickerPack
{
    TGBridgeStickerPack *bridgeStickerPack = [[TGBridgeStickerPack alloc] init];
    bridgeStickerPack->_builtIn = [stickerPack.packReference isKindOfClass:[TGStickerPackBuiltinReference class]];
    bridgeStickerPack->_title = stickerPack.title;

    NSMutableArray *bridgeDocuments = [[NSMutableArray alloc] init];
    for (TGDocumentMediaAttachment *document in stickerPack.documents)
    {
        TGBridgeDocumentMediaAttachment *bridgeDocument = [TGBridgeDocumentMediaAttachment attachmentWithTGDocumentMediaAttachment:document];
        if (bridgeDocument != nil)
            [bridgeDocuments addObject:bridgeDocument];
    }
    
    bridgeStickerPack->_documents = bridgeDocuments;
    
    return bridgeStickerPack;
}

@end
