---
title: ASTextNode
layout: docs
permalink: /docs/text-node.html
prevPage: button-node.html
nextPage: image-node.html
---

`ASTextNode` is Texture's main text node and can be used any time you would normally use a `UILabel`.  It includes full rich text support and is a subclass of `ASControlNode` meaning it can be used any time you would normally create a UIButton with just its titleLabel set.

### Basic Usage
`ASTextNode`'s interface should be familiar to anyone who's used a `UILabel`.   The first difference you may notice, is that text node's only use attributed strings instead of having the option of using a plain string.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
NSDictionary *attrs = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:12.0f] };
NSAttributedString *string = [[NSAttributedString alloc] initWithString:@"Hey, here's some text." attributes:attrs];

_node = [[ASTextNode alloc] init];
_node.attributedText = string;
</pre>

<pre lang="swift" class = "swiftCode hidden">
let attrs = [NSFontAttributeName: UIFont(name: "HelveticaNeue", size: 12.0)]
let string = NSAttributedString(string: "Hey, here's some text.", attributes: attrs)

node = ASTextNode()
node.attributedText = string
</pre>
</div>
</div>

As you can see, to create a basic text node, all you need to do is use a standard alloc-init and then set up the attributed string for the text you wish to display.

### Truncation

In any case where you need your text node to fit into a space that is smaller than what would be necessary to display all the text it contains, as much as possible will be shown, and whatever is cut off will be replaced with a truncation string.


<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
_textNode = [[ASTextNode alloc] init];
_textNode.attributedText = string;
_textNode.truncationAttributedText = [[NSAttributedString alloc]
												initWithString:@"¶¶¶"];
</pre>

<pre lang="swift" class = "swiftCode hidden">
textNode = ASTextNode()
textNode.attributedText = string
textNode.truncationAttributedText = NSAttributedString(string: "¶¶¶")
</pre>
</div>
</div>

This results in something like:

<img width = "300" src = "/static/images/textNodeTruncation.png"/>

By default, the truncation string will be "…" so you don't need to set it if that's all you need.


### Link Attributes

In order to designate chunks of your text as a link, you first need to set the `linkAttributes` array to an array of strings which will be used as keys of links in your attributed string.  Then, when setting up the attributes of your string, you can use these keys to point to appropriate `NSURL`s.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
_textNode.linkAttributeNames = @[ kLinkAttributeName ];

NSString *blurb = @"kittens courtesy placekitten.com \U0001F638";
NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:blurb];
[string addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Light" size:16.0f] range:NSMakeRange(0, blurb.length)];
[string addAttributes:@{
                      kLinkAttributeName: [NSURL URLWithString:@"http://placekitten.com/"],
                      NSForegroundColorAttributeName: [UIColor grayColor],
                      NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle | NSUnderlinePatternDot),
                      }
              range:[blurb rangeOfString:@"placekitten.com"]];
_textNode.attributedText = string;
_textNode.userInteractionEnabled = YES;
</pre>

<pre lang="swift" class = "swiftCode hidden">
textNode.linkAttributeNames = [kLinkAttributeName]

let blurb: NSString = "kittens courtesy placekitten.com 😸"
let attributedString = NSMutableAttributedString(string: blurb as String)

attributedString.addAttribute(NSFontAttributeName, value: UIFont(name: "HelveticaNeue-Light", size: 16.0)!, range: NSRange(location: 0, length: blurb.length))

attributedString.addAttributes([kLinkAttributeName: NSURL(string: "http://placekitten.com/")!,
                      NSForegroundColorAttributeName: UIColor.gray,
                      NSUnderlineStyleAttributeName: (NSUnderlineStyle.styleSingle.rawValue | NSUnderlineStyle.patternDashDot.rawValue)],
                     range: blurb.range(of: "placekitten.com"))
textNode.attributedText = attributedString
textNode.isUserInteractionEnabled = true
</pre>
</div>
</div>

Which results in a light gray link with a dash-dot style underline!

<img width = "300" src = "/static/images/kittenLink.png"/>

As you can see, it's relatively convenient to apply various styles to each link given its range in the attributed string.

### ASTextNodeDelegate

Conforming to `ASTextNodeDelegate` allows your class to react to various events associated with a text node.  For example, if you want to react to one of your links being tapped:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (void)textNode:(ASTextNode *)richTextNode tappedLinkAttribute:(NSString *)attribute value:(NSURL *)URL atPoint:(CGPoint)point textRange:(NSRange)textRange
{
  // the link was tapped, open it
  [[UIApplication sharedApplication] openURL:URL];
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
func textNode(_ textNode: ASTextNode, tappedLinkAttribute attribute: String, value: Any, at point: CGPoint, textRange: NSRange) {
    guard let url = value as? URL else { return }

    // the link was tapped, open it
    UIApplication.shared.openURL(url)
}
</pre>
</div>
</div>

In a similar way, you can react to long presses and highlighting with the following methods:

`– textNode:longPressedLinkAttribute:value:atPoint:textRange:`

`– textNode:shouldHighlightLinkAttribute:value:atPoint:`

`– textNode:shouldLongPressLinkAttribute:value:atPoint:`


### Incorrect maximum number of lines with line spacing

Using a `NSParagraphStyle` with a non-default `lineSpacing` can cause problems if multiline text with a maximum number of lines is wanted. For example see the following code:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// ...
NSString *someLongString = @"...";

NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
paragraphStyle.lineSpacing = 10.0;

UIFont *font = [UIFont fontWithName:@"SomeFontName" size:15];

NSDictionary *attributes = @{
	NSFontAttributeName : font,
	NSParagraphStyleAttributeName: paragraphStyle
};

ASTextNode *textNode = [[ASTextNode alloc] init];
textNode.maximumNumberOfLines = 4;
textNode.attributedText = [[NSAttributedString	alloc] initWithString:someLongString
																												   attributes:attributes];
// ...
</pre>

<pre lang="swift" class = "swiftCode hidden">
let someLongString = "..."

let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.lineSpacing = 10.0

let font = UIFont(name: "SomeFontName", size: 15.0)

let attributes = [
    NSFontAttributeName: font,
    NSParagraphStyleAttributeName: paragraphStyle
]

let textNode = ASTextNode()
textNode.maximumNumberOfLines = 4
textNode.attributedText = NSAttributedString(string: someLongString, attributes: attributes)
</pre>
</div>
</div>

`ASTextNode` uses Text Kit internally to calculate the amount to shrink needed to result in the specified maximum number of lines. Unfortunately, in certain cases this will result in the text shrinking too much in the above example; Instead of 4 lines of text, 3 lines of text and a weird gap at the bottom will show up. To get around this issue for now, you have to set the `truncationMode` explicitly to `NSLineBreakByTruncatingTail` on the text node:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// ...
ASTextNode *textNode = [[ASTextNode alloc] init];
textNode.maximumNumberOfLines = 4;
textNode.truncationMode = NSLineBreakByTruncatingTail;
textNode.attributedText = [[NSAttributedString	alloc] initWithString:someLongString
																												   attributes:attributes];
// ...
</pre>

<pre lang="swift" class = "swiftCode hidden">
// ...
let textNode = ASTextNode()
textNode.maximumNumberOfLines = 4
textNode.truncationMode = NSLineBreakByTruncatingTail
textNode.attributedText = NSAttributedString(string: someLongString, attributes: attributes)
//...
</pre>
</div>
</div>
```
