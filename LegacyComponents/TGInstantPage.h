#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGImageMediaAttachment;
@class TGVideoMediaAttachment;
@class TGDocumentMediaAttachment;
@class TGConversation;

@class TGInstantPageListItem;
@class TGInstantPageListOrderedItem;
@class TGInstantPageCaption;
@class TGInstantPageTableCell;
@class TGInstantPageTableRow;

@interface TGRichText : NSObject <NSCoding>

@end

@interface TGRichTextPlain : TGRichText

@property (nonatomic, strong, readonly) NSString *text;

- (instancetype)initWithText:(NSString *)text;

@end

@interface TGRichTextBold : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextItalic : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextUnderline : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextStrikethrough : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextFixed : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextUrl : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) int64_t webpageId;

- (instancetype)initWithText:(TGRichText *)text url:(NSString *)url webpageId:(int64_t)webpageId;

@end

@interface TGRichTextEmail: TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, strong) NSString *email;

- (instancetype)initWithText:(TGRichText *)text email:(NSString *)email;

@end

@interface TGRichTextCollection : TGRichText

@property (nonatomic, strong, readonly) NSArray<TGRichText *> *texts;

- (instancetype)initWithTexts:(NSArray<TGRichText *> *)texts;

@end

@interface TGRichTextSubscript : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextSuperscript : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextMarked : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGRichTextPhone : TGRichText

@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, strong, readonly) NSString *phone;

- (instancetype)initWithText:(TGRichText *)text phone:(NSString *)phone;

@end

@interface TGRichTextImage : TGRichText

@property (nonatomic, readonly) int64_t documentId;
@property (nonatomic, readonly) CGSize dimensions;

- (instancetype)initWithDocumentId:(int64_t)documentId dimensions:(CGSize)dimensions;

@end

@interface TGInstantPageBlock : NSObject <NSCoding>

@end

@interface TGInstantPageBlockCover : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGInstantPageBlock *block;

- (instancetype)initWithBlock:(TGInstantPageBlock *)block;

@end

@interface TGInstantPageBlockChannel : TGInstantPageBlock
    
@property (nonatomic, strong, readonly) TGConversation *channel;
    
- (instancetype)initWithChannel:(TGConversation *)channel;
    
@end

@interface TGInstantPageBlockTitle : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageBlockSubtitle : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageBlockAuthorAndDate : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *author;
@property (nonatomic, readonly) int32_t date;

- (instancetype)initWithAuthor:(TGRichText *)author date:(int32_t)date;

@end

@interface TGInstantPageBlockHeader : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageBlockSubheader : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageBlockParagraph : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageBlockPreFormatted : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, strong, readonly) NSString *language;

- (instancetype)initWithText:(TGRichText *)text language:(NSString *)language;

@end

@interface TGInstantPageBlockFooter : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageBlockDivider : TGInstantPageBlock

@end

@interface TGInstantPageBlockBlockQuote : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, strong, readonly) TGRichText *caption;

- (instancetype)initWithText:(TGRichText *)text caption:(TGRichText *)caption;

@end

@interface TGInstantPageBlockPullQuote : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, strong, readonly) TGRichText *caption;

- (instancetype)initWithText:(TGRichText *)text caption:(TGRichText *)caption;

@end

@interface TGInstantPageBlockPhoto : TGInstantPageBlock

@property (nonatomic, readonly) int64_t photoId;
@property (nonatomic, strong, readonly) TGInstantPageCaption *caption;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) int64_t webpageId;

- (instancetype)initWithPhotoId:(int64_t)photoId caption:(TGInstantPageCaption *)caption url:(NSString *)url webpageId:(int64_t)webpageId;

@end

@interface TGInstantPageBlockVideo : TGInstantPageBlock

@property (nonatomic, readonly) int64_t videoId;
@property (nonatomic, strong, readonly) TGInstantPageCaption *caption;
@property (nonatomic, readonly) bool autoplay;
@property (nonatomic, readonly) bool loop;

- (instancetype)initWithVideoId:(int64_t)videoId caption:(TGInstantPageCaption *)caption autoplay:(bool)autoplay loop:(bool)loop;

@end

@interface TGInstantPageBlockEmbed : TGInstantPageBlock

@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, strong, readonly) NSString *html;
@property (nonatomic, readonly) int64_t posterPhotoId;
@property (nonatomic, strong, readonly) TGInstantPageCaption *caption;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) bool fillWidth;
@property (nonatomic, readonly) bool enableScrolling;

- (instancetype)initWithUrl:(NSString *)url html:(NSString *)html posterPhotoId:(int64_t)posterPhotoId caption:(TGInstantPageCaption *)caption size:(CGSize)size fillWidth:(bool)fillWidth enableScrolling:(bool)enableScrolling;

@end

@interface TGInstantPageBlockSlideshow : TGInstantPageBlock

@property (nonatomic, strong, readonly) NSArray<TGInstantPageBlock *> *items;
@property (nonatomic, strong, readonly) TGInstantPageCaption *caption;

- (instancetype)initWithItems:(NSArray<TGInstantPageBlock *> *)items caption:(TGInstantPageCaption *)caption;

@end

@interface TGInstantPageBlockCollage : TGInstantPageBlock

@property (nonatomic, strong, readonly) NSArray<TGInstantPageBlock *> *items;
@property (nonatomic, strong, readonly) TGInstantPageCaption *caption;

- (instancetype)initWithItems:(NSArray<TGInstantPageBlock *> *)items caption:(TGInstantPageCaption *)caption;

@end

@interface TGInstantPageBlockAnchor : TGInstantPageBlock

@property (nonatomic, strong, readonly) NSString *name;

- (instancetype)initWithName:(NSString *)name;

@end

@interface TGInstantPageBlockEmbedPost : TGInstantPageBlock

@property (nonatomic, strong, readonly) NSString *author;
@property (nonatomic, readonly) int32_t date;
@property (nonatomic, strong, readonly) TGInstantPageCaption *caption;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, readonly) int64_t webpageId;
@property (nonatomic, strong, readonly) NSArray<TGInstantPageBlock *> *blocks;
@property (nonatomic, readonly) int64_t authorPhotoId;

- (instancetype)initWithAuthor:(NSString *)author date:(int32_t)date caption:(TGInstantPageCaption *)caption url:(NSString *)url webpageId:(int64_t)webpageId blocks:(NSArray<TGInstantPageBlock *> *)blocks authorPhotoId:(int64_t)authorPhotoId;

@end

@interface TGInstantPageBlockAudio : TGInstantPageBlock

@property (nonatomic, readonly) int64_t audioId;
@property (nonatomic, strong, readonly) TGInstantPageCaption *caption;

- (instancetype)initWithAudioId:(int64_t)audioId caption:(TGInstantPageCaption *)caption;

@end

@interface TGInstantPageBlockKicker : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageBlockTable : TGInstantPageBlock

@property (nonatomic, strong, readonly) TGRichText *caption;
@property (nonatomic, strong, readonly) NSArray<TGInstantPageTableRow *> *rows;

- (instancetype)initWithCaption:(TGRichText *)caption rows:(NSArray<TGInstantPageTableRow *> *)rows;

@end

@interface TGInstantPageListItem : NSObject <NSCoding>

@end

@interface TGInstantPageListItemText : TGInstantPageListItem

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithText:(TGRichText *)text;

@end

@interface TGInstantPageListItemBlocks : TGInstantPageListItem

@property (nonatomic, strong, readonly) NSArray<TGInstantPageBlock *> *blocks;

- (instancetype)initWithBlocks:(NSArray<TGInstantPageBlock *> *)blocks;

@end

@interface TGInstantPageBlockList : TGInstantPageBlock

@property (nonatomic, strong, readonly) NSArray<TGInstantPageListItem *> *items;

- (instancetype)initWithItems:(NSArray<TGInstantPageListItem *> *)items;

@end

@interface TGInstantPageListOrderedItem : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *num;

@end

@interface TGInstantPageListOrderedItemText : TGInstantPageListOrderedItem

@property (nonatomic, strong, readonly) TGRichText *text;

- (instancetype)initWithNum:(NSString *)num text:(TGRichText *)text;

@end

@interface TGInstantPageListOrderedItemBlocks : TGInstantPageListOrderedItem

@property (nonatomic, strong, readonly) NSArray<TGInstantPageBlock *> *blocks;

- (instancetype)initWithNum:(NSString *)num blocks:(NSArray<TGInstantPageBlock *> *)blocks;

@end

@interface TGInstantPageBlockOrderedList : TGInstantPageBlock

@property (nonatomic, strong, readonly) NSArray<TGInstantPageListOrderedItem *> *items;

- (instancetype)initWithItems:(NSArray<TGInstantPageListOrderedItem *> *)items;

@end

@interface TGInstantPageTableCell : NSObject <NSCoding>

@property (nonatomic, readonly) bool header;
@property (nonatomic, readonly) NSTextAlignment alignment;
@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, readonly) int32_t colspan;
@property (nonatomic, readonly) int32_t rowspan;

- (instancetype)initWithHeader:(bool)header alignment:(NSTextAlignment)alignment text:(TGRichText *)text colspan:(int32_t)colspan rowspan:(int32_t)rowspan;

@end

@interface TGInstantPageTableRow : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSArray<TGInstantPageTableCell *> *cells;

- (instancetype)initWithCells:(NSArray<TGInstantPageTableCell *> *)cells;

@end

@interface TGInstantPageCaption : NSObject <NSCoding>

@property (nonatomic, strong, readonly) TGRichText *text;
@property (nonatomic, strong, readonly) TGRichText *credit;

- (instancetype)initWithText:(TGRichText *)text credit:(TGRichText *)credit;

@end

@interface TGInstantPage : NSObject <NSCoding>

@property (nonatomic, readonly) bool isPartial;
@property (nonatomic, strong, readonly) NSArray<TGInstantPageBlock *> *blocks;
@property (nonatomic, strong, readonly) NSDictionary<NSNumber *, TGImageMediaAttachment *> *images;
@property (nonatomic, strong, readonly) NSDictionary<NSNumber *, TGVideoMediaAttachment *> *videos;
@property (nonatomic, strong, readonly) NSDictionary<NSNumber *, TGDocumentMediaAttachment *> *documents;

- (instancetype)initWithIsPartial:(bool)isPartial blocks:(NSArray<TGInstantPageBlock *> *)blocks images:(NSDictionary<NSNumber *, TGImageMediaAttachment *> *)images videos:(NSDictionary<NSNumber *, TGVideoMediaAttachment *> *)videos documents:(NSDictionary<NSNumber *, TGDocumentMediaAttachment *> *)documents;

@end
