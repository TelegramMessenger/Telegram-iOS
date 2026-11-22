#import <XCTest/XCTest.h>
#import "LHDocument.h"

#include <functional>
#include <random>
#include <string>
#include <vector>

@interface TextLayoutPatchTests : XCTestCase
@end

@implementation TextLayoutPatchTests

static NSString *const PaintSheet = @"body{margin:4px;font:12px -apple-system}.up{color:#34c759}.down{color:#ff3b30}.hot{background:#fee;border-color:#f00}"
                                     ".glow{opacity:.6;box-shadow:0 0 3px #000}.wide{padding:0 6px;font-size:15px}.bold{font-weight:bold}"
                                     ".tag::before{content:\"#\"}.gone{display:none}.flt{float:left;width:30%}.abs{position:absolute;right:2px;top:2px}"
                                     ".rel{position:relative;left:3px}.ib{display:inline-block;min-width:20px}.pre{white-space:pre}.caps{text-transform:uppercase}"
                                     "table{border-collapse:collapse;width:100%}td{padding:1px 3px;text-align:right;font-variant-numeric:tabular-nums}"
                                     ".fixed{table-layout:fixed}.row{display:flex;gap:4px}.row>*{flex:1 1 auto}.box{border:1px solid #888;margin:2px}";
static NSString *const IdSheet = @"#c3{color:#00f}[id=\"c5\"]{font-size:16px}.box:not(#c7) .up{background:#eef}";
static NSString *const ReachSheet = @".hot .up{font-size:18px}.up+.down{margin-left:4px}";

struct TextNode
{
    std::string              tag;
    int                      id = 0;
    std::string              dom_id;
    std::vector<std::string> classes;
    std::string              style;
    std::string              text;
    std::vector<TextNode>    children;
};

static void Escape(const std::string &text, std::string &out)
{
    for(char c : text)
    {
        if(c == '<')
            out += "&lt;";
        else if(c == '&')
            out += "&amp;";
        else
            out += c;
    }
}

static void Write(const TextNode &node, std::string &out)
{
    if(node.tag.empty())
    {
        Escape(node.text, out);
        return;
    }
    out += "<" + node.tag + " data-lh-id=\"" + std::to_string(node.id) + "\"";
    if(!node.dom_id.empty())
        out += " id=\"" + node.dom_id + "\"";
    if(!node.classes.empty())
    {
        out += " class=\"";
        for(size_t i = 0; i < node.classes.size(); i++)
            out += (i ? " " : "") + node.classes[i];
        out += "\"";
    }
    if(!node.style.empty())
        out += " style=\"" + node.style + "\"";
    out += ">";
    for(const auto &child : node.children)
        Write(child, out);
    out += "</" + node.tag + ">";
}

static void Gather(TextNode &node, std::vector<TextNode *> &texts, std::vector<TextNode *> &elements)
{
    if(node.tag.empty())
        texts.push_back(&node);
    else
        elements.push_back(&node);
    for(auto &child : node.children)
        Gather(child, texts, elements);
}

static NSData *Image(LHDocument *document, CGFloat width)
{
    CGSize     size  = [document layoutWithMaxWidth:width preferredWidth:width];
    CGImageRef image = [document copyImageWithMaxWidth:width rect:CGRectMake(0, 0, width, MAX(1, ceil(size.height))) scale:2];
    if(!image)
        return [NSData data];
    NSData *data = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(image));
    CGImageRelease(image);
    return data;
}

static NSString *Page(NSString *css, const std::string &body)
{
    return [NSString stringWithFormat:@"<!DOCTYPE html><html data-lh-id=\"1\"><head data-lh-id=\"2\"><style data-lh-id=\"3\">%@</style></head>"
                                       "<body data-lh-id=\"4\">%@</body></html>",
                                       css, @(body.c_str())];
}

- (void)expect:(LHDocument *)patched like:(LHDocument *)fresh width:(CGFloat)width label:(NSString *)label
{
    NSData *a = Image(patched, width), *b = Image(fresh, width);
    XCTAssertEqualObjects(patched.layoutSignature, fresh.layoutSignature, @"bounds %@", label);
    XCTAssertEqual(patched.size.height, fresh.size.height, @"height %@", label);
    XCTAssertEqualObjects(a, b, @"pixels %@", label);
    XCTAssertEqualObjects([patched parentsByAttribute:@"data-lh-id"], [fresh parentsByAttribute:@"data-lh-id"], @"tree %@", label);
}

- (void)testRelayoutOfAKeptTreeMatchesAFreshLayout
{
    NSArray<NSString *> *bodies = @[
        @"<p data-lh-id=\"5\"><b data-lh-id=\"6\" style=\"position:relative;left:3px;top:2px\">shifted</b> text</p>",
        @"<p data-lh-id=\"5\">a <span data-lh-id=\"6\" style=\"position:relative;right:4px;padding:0 6px\">long run of words <i data-lh-id=\"7\" style=\"position:relative;top:-3px\">nested</i> that wraps over several lines</span> end</p>",
        @"<div data-lh-id=\"5\"><span data-lh-id=\"6\" class=\"rel wide\">split <p data-lh-id=\"7\">block</p> inline</span></div>",
    ];
    for(NSString *body in bodies)
    {
        NSString   *html  = Page(PaintSheet, body.UTF8String);
        LHDocument *again = [[LHDocument alloc] initWithHTML:html css:nil];
        [again layoutWithMaxWidth:120 preferredWidth:120];
        [again layoutWithMaxWidth:300 preferredWidth:300];
        [again layoutWithMaxWidth:200 preferredWidth:200];
        LHDocument *fresh = [[LHDocument alloc] initWithHTML:html css:nil];
        [fresh layoutWithMaxWidth:200 preferredWidth:200];
        XCTAssertEqualObjects(again.layoutSignature, fresh.layoutSignature, @"%@", body);
        XCTAssertEqualObjects(Image(again, 200), Image(fresh, 200), @"%@", body);
    }
}

@end
