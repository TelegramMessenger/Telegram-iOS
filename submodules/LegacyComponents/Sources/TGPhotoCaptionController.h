#import "TGPhotoEditorTabController.h"

#import <LegacyComponents/LegacyComponentsContext.h>

@class PGPhotoEditor;
@class TGSuggestionContext;
@class TGPhotoEditorPreviewView;

@interface TGPhotoCaptionController : TGPhotoEditorTabController

@property (nonatomic, copy) void (^captionSet)(NSString *caption, NSArray *entities);

@property (nonatomic, strong) TGSuggestionContext *suggestionContext;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView caption:(NSString *)caption;

@end
