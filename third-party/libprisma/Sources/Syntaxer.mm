//
//  SyntaxHighligher.m
//  CodeSyntax
//
//  Created by Mike Renoir on 26.10.2023.
//

#import <libprisma/Syntaxer.h>
#import "SyntaxHighlighter.h"
#import "TokenList.h"

UIColor * color(UInt32 rgb, UInt32 alpha) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green: ((rgb >> 8) & 0xff) / 255.0 blue: (rgb & 0xff) / 255.0 alpha: alpha];
}



NSDictionary<NSString *, UIColor *> *light = @{
    @"comment": color(0x708090, 1.0), 
    @"block-comment": color(0x708090, 1.0),
    @"prolog": color(0x708090, 1.0),
    @"doctype": color(0x708090, 1.0),
    @"cdata": color(0x708090, 1.0),
    @"punctuation": color(0x999999, 1.0),
    @"property": color(0x990055, 1.0),
    @"tag": color(0x990055, 1.0),
    @"boolean": color(0x990055, 1.0),
    @"number": color(0x990055, 1.0),
    @"constant": color(0x990055, 1.0),
    @"symbol": color(0x990055, 1.0),
    @"deleted": color(0x990055, 1.0),
    @"selector": color(0x669900, 1.0),
    @"attr-name": color(0x669900, 1.0),
    @"string": color(0x669900, 1.0),
    @"char": color(0x669900, 1.0),
    @"builtin": color(0x669900, 1.0),
    @"inserted": color(0x669900, 1.0),
    @"operator": color(0x9AAE6C, 1.0),
    @"entity": color(0x9AAE6C, 1.0),
    @"url": color(0x9AAE6C, 1.0),
    @"atrule": color(0x0077AA, 1.0),
    @"attr-value": color(0x0077AA, 1.0),
    @"keyword": color(0x0077AA, 1.0),
    @"function-definition": color(0x0077AA, 1.0),
    @"class-name": color(0xDD4A68, 1.0),
};

NSDictionary<NSString *, UIColor *> *dark = @{
    @"comment": color(0x999999, 1.0),
    @"block-comment": color(0x999999, 1.0),
    @"prolog": color(0x999999, 1.0),
    @"doctype": color(0x999999, 1.0),
    @"cdata": color(0x999999, 1.0),
    @"punctuation": color(0xcccccc, 1.0),
    @"property": color(0xf8c555, 1.0),
    @"tag": color(0xe2777a, 1.0),
    @"boolean": color(0xf08d49, 1.0),
    @"number": color(0xf08d49, 1.0),
    @"constant": color(0xf8c555, 1.0),
    @"symbol": color(0xf8c555, 1.0),
    @"deleted": color(0xe2777a, 1.0),
    @"selector": color(0xcc99cd, 1.0),
    @"attr-name": color(0xe2777a, 1.0),
    @"string": color(0x7ec699, 1.0),
    @"char": color(0x7ec699, 1.0),
    @"builtin": color(0xcc99cd, 1.0),
    @"inserted": color(0x669900, 1.0),
    @"operator": color(0x67cdcc, 1.0),
    @"entity": color(0x67cdcc, 1.0),
    @"url": color(0x67cdcc, 1.0),
    @"atrule": color(0xcc99cd, 1.0),
    @"attr-value": color(0x7ec699, 1.0),
    @"keyword": color(0xcc99cd, 1.0),
    @"function-definition": color(0xf08d49, 1.0),
    @"class-name": color(0xf8c555, 1.0),
};



std::string dataToString(NSData *nsData) {
    const void *dataBytes = [nsData bytes];
    NSUInteger dataLength = [nsData length];
    
    return std::string(static_cast<const char*>(dataBytes), dataLength);
}

NSString* stringViewToNSString(std::string_view sv) {
    std::string cppString(sv.data(), sv.length());
    return [NSString stringWithUTF8String:cppString.c_str()];
}

NSString* stringToNSString(const std::string& cppString) {
    return [NSString stringWithUTF8String:cppString.c_str()];
}

@implementation SyntaxterTheme

-(id)initWithDark:(BOOL)dark textColor:(UIColor *)textColor textFont:(UIFont *)textFont italicFont:(UIFont *)italicFont mediumFont:(UIFont *)mediumFont {
    if (self = [super init]) {
        _dark = dark;
        _textColor = textColor;
        _textFont = textFont;
        _italicFont = italicFont;
        _mediumFont = mediumFont;
    }
    return self;
}

@end


@interface Brush : NSObject
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *color;
@end

@implementation Brush

-(id)initWith:(UIFont *)font color:(UIColor *)color {
    if (self = [super init]) {
        _font = font;
        _color = color;
    }
    return self;
}

@end


void applyString(NSString * string, NSMutableAttributedString * attributed, Brush *brush) {
    if (string != nil) {
        NSMutableAttributedString *substring = [[NSMutableAttributedString alloc] initWithString: string];
        NSRange range = NSMakeRange(0, string.length);
        [substring addAttribute:NSForegroundColorAttributeName value: brush.color range:range];
        [substring addAttribute:NSFontAttributeName value:brush.font range:range];
        [attributed appendAttributedString:substring];
    }
}

Brush *makeBrush(std::string alias, std::string type, SyntaxterTheme * theme, Brush *previous) {
    NSString * aliasKey = stringToNSString(alias);
    NSString * typeKey = stringToNSString(type);
    
    
    
    NSDictionary<NSString *, UIColor *> *colors;
    if (theme.dark) {
        colors = dark;
    } else {
        colors = light;
    }
    
    UIColor *color = colors[aliasKey];
    UIFont *font = theme.textFont;
    
    if (color == nil) {
        color = colors[typeKey];
    }
    if (color == nil) {
        color = previous.color;
    }
    if (color == nil) {
        color = theme.textColor;
    }
    if ([typeKey isEqualToString:@"bold"]) {
        font = theme.mediumFont;
    }
    if ([typeKey isEqualToString:@"italic"]) {
        font = theme.italicFont;
    }
    
    if (previous != nil) {
        font = previous.font;
    }
    
    return [[Brush alloc] initWith:font color:color];
}

@interface Syntaxer ()
@property (atomic) std::shared_ptr<SyntaxHighlighter> m_highlighter;
@end

@implementation Syntaxer
-(id)init {
    if (self = [super init]) {
        NSString *path = [[[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"LibprismaBundle.bundle"] stringByAppendingPathComponent:@"grammars.dat"];
        NSData *grammar = [NSData dataWithContentsOfFile:path];
        if (grammar == nil) {
            return nil;
        }
        
        std::string text = dataToString(grammar);
        _m_highlighter = std::make_shared<SyntaxHighlighter>(text);
    }
    return self;
}

-(NSAttributedString *)syntax:(NSString *)code language: (NSString *)language theme: (SyntaxterTheme *) theme {
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
    std::string c_code = code.UTF8String;
    std::string c_language = language.UTF8String;

    TokenList tokens = _m_highlighter->tokenize(c_code, c_language);
    for (auto it = tokens.begin(); it != tokens.end(); ++it)
    {
        auto& node = *it;
        Brush *brush;
        if (node.isSyntax()) {
            const auto& child = dynamic_cast<const Syntax&>(node);
            brush = makeBrush(child.alias(), child.type(), theme, nil);
        } else {
            brush = makeBrush("", "", theme, nil);
        }
        [self paint:node string:string brush:brush theme: theme];
    }
    return string;
}


- (void) paint:(const TokenListNode &)node string: (NSMutableAttributedString *) string brush:(Brush *)upperBrash theme: (SyntaxterTheme *) theme {
    if (node.isSyntax())
    {
        const auto& child = dynamic_cast<const Syntax&>(node);
        
        for (auto j = child.begin(); j != child.end(); ++j)
        {
            auto& innerNode = *j;
            if (innerNode.isSyntax())
            {
                const auto& innerChild = dynamic_cast<const Syntax&>(innerNode);
                Brush *brush = makeBrush(innerChild.alias(), innerChild.type(), theme, upperBrash);
                [self paint:innerNode string:string brush:brush theme: theme];
            } else {
                const auto& innerChild = dynamic_cast<const Text&>(innerNode);
                applyString(stringViewToNSString(innerChild.value()), string, upperBrash);
            }
        }
    } else {
        const auto& child = dynamic_cast<const Text&>(node);
        applyString(stringViewToNSString(child.value()), string, upperBrash);
    }
}


@end
