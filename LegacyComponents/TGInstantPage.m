#import "TGInstantPage.h"

#import "TGConversation.h"
#import "PSKeyValueEncoder.h"
#import "PSKeyValueDecoder.h"

@implementation TGRichText

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder {
    self = [super init];
    if (self != nil) {
        
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder {
}

@end

@implementation TGRichTextPlain

- (instancetype)initWithText:(NSString *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGRichTextBold

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGRichTextItalic

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGRichTextUnderline

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGRichTextStrikethrough

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGRichTextFixed

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGRichTextUrl

- (instancetype)initWithText:(TGRichText *)text url:(NSString *)url webpageId:(int64_t)webpageId {
    self = [super init];
    if (self != nil) {
        _text = text;
        _url = url;
        _webpageId = webpageId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
        _url = [aDecoder decodeObjectForKey:@"url"];
        _webpageId = [aDecoder decodeInt64ForKey:@"wpid"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_url forKey:@"url"];
    [aCoder encodeInt64:_webpageId forKey:@"wpid"];
}

@end

@implementation TGRichTextEmail: TGRichText

- (instancetype)initWithText:(TGRichText *)text email:(NSString *)email {
    self = [super init];
    if (self != nil) {
        _text = text;
        _email = email;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
        _email = [aDecoder decodeObjectForKey:@"email"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_email forKey:@"email"];
}

@end

@implementation TGRichTextCollection

- (instancetype)initWithTexts:(NSArray<TGRichText *> *)texts {
    self = [super init];
    if (self != nil) {
        _texts = texts;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _texts = [aDecoder decodeObjectForKey:@"texts"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_texts forKey:@"texts"];
}

@end

@implementation TGInstantPageBlock

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder {
    self = [super init];
    if (self != nil) {
        
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder {
    
}

@end

@implementation TGInstantPageBlockCover

- (instancetype)initWithBlock:(TGInstantPageBlock *)block {
    self = [super init];
    if (self != nil) {
        _block = block;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _block = [aDecoder decodeObjectForKey:@"block"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_block forKey:@"block"];
}


@end

@implementation TGInstantPageBlockChannel

- (instancetype)initWithChannel:(TGConversation *)channel {
    self = [super init];
    if (self != nil) {
        _channel = channel;
    }
    return self;
}
    
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        NSData *data = [aDecoder decodeObjectForKey:@"channelData"];
        PSKeyValueDecoder *decoder = [[PSKeyValueDecoder alloc] initWithData:data];
        _channel = (TGConversation *)[decoder decodeObjectForKey:@"channel"];
    }
    return self;
}
    
- (void)encodeWithCoder:(NSCoder *)aCoder {
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [encoder encodeObject:_channel forKey:@"channel"];
    [aCoder encodeObject:[encoder data] forKey:@"channelData"];
}

@end

@implementation TGInstantPageBlockTitle

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGInstantPageBlockSubtitle

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGInstantPageBlockAuthorAndDate

- (instancetype)initWithAuthor:(TGRichText *)author date:(int32_t)date {
    self = [super init];
    if (self != nil) {
        _author = author;
        _date = date;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        TGRichText *richAuthor = [aDecoder decodeObjectForKey:@"rauthor"];
        if (richAuthor != nil) {
            _author = richAuthor;
        } else {
            NSString *author = [aDecoder decodeObjectForKey:@"author"];
            _author = [[TGRichTextPlain alloc] initWithText:author];
        }
        _date = [aDecoder decodeInt32ForKey:@"date"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_author forKey:@"rauthor"];
    [aCoder encodeInt32:_date forKey:@"date"];
}

@end

@implementation TGInstantPageBlockHeader

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGInstantPageBlockSubheader

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGInstantPageBlockParagraph

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGInstantPageBlockPreFormatted

- (instancetype)initWithText:(TGRichText *)text language:(NSString *)language {
    self = [super init];
    if (self != nil) {
        _text = text;
        _language = language;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
        _language = [aDecoder decodeObjectForKey:@"lang"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_language forKey:@"lang"];
}

@end

@implementation TGInstantPageBlockFooter

- (instancetype)initWithText:(TGRichText *)text {
    self = [super init];
    if (self != nil) {
        _text = text;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
}

@end

@implementation TGInstantPageBlockDivider

- (instancetype)initWithCoder:(NSCoder *)__unused aDecoder {
    self = [super init];
    if (self != nil) {
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)__unused aCoder {
}

@end

@implementation TGInstantPageBlockList

- (instancetype)initWithOrdered:(bool)ordered items:(NSArray<TGRichText *> *)items {
    self = [super init];
    if (self != nil) {
        _ordered = ordered;
        _items = items;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _ordered = [aDecoder decodeBoolForKey:@"ord"];
        _items = [aDecoder decodeObjectForKey:@"items"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:_ordered forKey:@"ord"];
    [aCoder encodeObject:_items forKey:@"items"];
}

@end

@implementation TGInstantPageBlockBlockQuote

- (instancetype)initWithText:(TGRichText *)text caption:(TGRichText *)caption {
    self = [super init];
    if (self != nil) {
        _text = text;
        _caption = caption;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_caption forKey:@"caption"];
}

@end

@implementation TGInstantPageBlockPullQuote

- (instancetype)initWithText:(TGRichText *)text caption:(TGRichText *)caption {
    self = [super init];
    if (self != nil) {
        _text = text;
        _caption = caption;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _text = [aDecoder decodeObjectForKey:@"text"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_caption forKey:@"caption"];
}

@end

@implementation TGInstantPageBlockPhoto

- (instancetype)initWithPhotoId:(int64_t)photoId caption:(TGRichText *)caption {
    self = [super init];
    if (self != nil) {
        _photoId = photoId;
        _caption = caption;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _photoId = [aDecoder decodeInt64ForKey:@"pid"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:_photoId forKey:@"pid"];
    [aCoder encodeObject:_caption forKey:@"caption"];
}

@end

@implementation TGInstantPageBlockVideo

- (instancetype)initWithVideoId:(int64_t)videoId caption:(TGRichText *)caption autoplay:(bool)autoplay loop:(bool)loop {
    self = [super init];
    if (self != nil) {
        _videoId = videoId;
        _caption = caption;
        _autoplay = autoplay;
        _loop = loop;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _videoId = [aDecoder decodeInt64ForKey:@"vid"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
        _autoplay = [aDecoder decodeBoolForKey:@"autoplay"];
        _loop = [aDecoder decodeBoolForKey:@"loop"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:_videoId forKey:@"vid"];
    [aCoder encodeObject:_caption forKey:@"caption"];
    [aCoder encodeBool:_autoplay forKey:@"autoplay"];
    [aCoder encodeBool:_loop forKey:@"loop"];
}

@end

@implementation TGInstantPageBlockEmbed

- (instancetype)initWithUrl:(NSString *)url html:(NSString *)html posterPhotoId:(int64_t)posterPhotoId caption:(TGRichText *)caption size:(CGSize)size fillWidth:(bool)fillWidth enableScrolling:(bool)enableScrolling {
    self = [super init];
    if (self != nil) {
        _url = url;
        _html = html;
        _posterPhotoId = posterPhotoId;
        _caption = caption;
        _size = size;
        _fillWidth = fillWidth;
        _enableScrolling = enableScrolling;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _url = [aDecoder decodeObjectForKey:@"url"];
        _html = [aDecoder decodeObjectForKey:@"html"];
        _posterPhotoId = [aDecoder decodeInt64ForKey:@"posterPhotoId"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
        _size = [aDecoder decodeCGSizeForKey:@"size"];
        _fillWidth = [aDecoder decodeBoolForKey:@"fillWidth"];
        _enableScrolling = [aDecoder decodeBoolForKey:@"enableScrolling"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_url forKey:@"url"];
    [aCoder encodeObject:_html forKey:@"html"];
    [aCoder encodeInt64:_posterPhotoId forKey:@"posterPhotoId"];
    [aCoder encodeObject:_caption forKey:@"caption"];
    [aCoder encodeCGSize:_size forKey:@"size"];
    [aCoder encodeBool:_fillWidth forKey:@"fillWidth"];
    [aCoder encodeBool:_enableScrolling forKey:@"enableScrolling"];
}

@end

@implementation TGInstantPageBlockSlideshow

- (instancetype)initWithItems:(NSArray<TGInstantPageBlock *> *)items caption:(TGRichText *)caption {
    self = [super init];
    if (self != nil) {
        _items = items;
        _caption = caption;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _items = [aDecoder decodeObjectForKey:@"items"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_items forKey:@"items"];
    [aCoder encodeObject:_caption forKey:@"caption"];
}

@end

@implementation TGInstantPageBlockCollage

- (instancetype)initWithItems:(NSArray<TGInstantPageBlock *> *)items caption:(TGRichText *)caption {
    self = [super init];
    if (self != nil) {
        _items = items;
        _caption = caption;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _items = [aDecoder decodeObjectForKey:@"items"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_items forKey:@"items"];
    [aCoder encodeObject:_caption forKey:@"caption"];
}

@end

@implementation TGInstantPageBlockAnchor

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self != nil) {
        _name = name;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _name = [aDecoder decodeObjectForKey:@"name"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_name forKey:@"name"];
}

@end

@implementation TGInstantPageBlockEmbedPost

- (instancetype)initWithAuthor:(NSString *)author date:(int32_t)date caption:(TGRichText *)caption url:(NSString *)url webpageId:(int64_t)webpageId blocks:(NSArray<TGInstantPageBlock *> *)blocks authorPhotoId:(int64_t)authorPhotoId {
    self = [super init];
    if (self != nil) {
        _author = author;
        _date = date;
        _caption = caption;
        _url = url;
        _webpageId = webpageId;
        _blocks = blocks;
        _authorPhotoId = authorPhotoId;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _author = [aDecoder decodeObjectForKey:@"author"];
        _date = [aDecoder decodeInt32ForKey:@"date"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
        _url = [aDecoder decodeObjectForKey:@"url"];
        _webpageId = [aDecoder decodeInt64ForKey:@"webpageId"];
        _blocks = [aDecoder decodeObjectForKey:@"blocks"];
        _authorPhotoId = [aDecoder decodeInt64ForKey:@"authorPhotoId"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_author forKey:@"author"];
    [aCoder encodeInt32:_date forKey:@"date"];
    [aCoder encodeObject:_caption forKey:@"caption"];
    [aCoder encodeObject:_url forKey:@"url"];
    [aCoder encodeInt64:_webpageId forKey:@"webpageId"];
    [aCoder encodeObject:_blocks forKey:@"blocks"];
    [aCoder encodeInt64:_authorPhotoId forKey:@"authorPhotoId"];
}

@end

@implementation TGInstantPageBlockAudio

- (instancetype)initWithAudioId:(int64_t)audioId caption:(TGRichText *)caption {
    self = [super init];
    if (self != nil) {
        _audioId = audioId;
        _caption = caption;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _audioId = [aDecoder decodeInt64ForKey:@"audioId"];
        _caption = [aDecoder decodeObjectForKey:@"caption"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:_audioId forKey:@"audioId"];
    [aCoder encodeObject:_caption forKey:@"caption"];
}

@end

@implementation TGInstantPage

- (instancetype)initWithIsPartial:(bool)isPartial blocks:(NSArray<TGInstantPageBlock *> *)blocks images:(NSDictionary *)images videos:(NSDictionary *)videos documents:(NSDictionary<NSNumber *,TGDocumentMediaAttachment *> *)documents {
    self = [super init];
    if (self != nil) {
        _isPartial = isPartial;
        _blocks = blocks;
        _images = images;
        _videos = videos;
        _documents = documents;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _isPartial = [aDecoder decodeBoolForKey:@"partial"];
        _blocks = [aDecoder decodeObjectForKey:@"blocks"];
        _images = [aDecoder decodeObjectForKey:@"images"];
        _videos = [aDecoder decodeObjectForKey:@"videos"];
        _documents = [aDecoder decodeObjectForKey:@"documents"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:_isPartial forKey:@"partial"];
    [aCoder encodeObject:_blocks forKey:@"blocks"];
    [aCoder encodeObject:_images forKey:@"images"];
    [aCoder encodeObject:_videos forKey:@"videos"];
    [aCoder encodeObject:_documents forKey:@"documents"];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TGInstantPage class]]) {
        return false;
    }
    TGInstantPage *other = object;
    if (_blocks.count != other->_blocks.count) {
        return false;
    }
    return true;
}

@end
