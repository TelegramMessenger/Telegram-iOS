/*
//  Node.h
*
 http://www.w3.org/TR/DOM-Level-2-Core/core.html#ID-1950641247
 
 interface Node {
 
 // NodeType
 const unsigned short      ELEMENT_NODE                   = 1;
 const unsigned short      ATTRIBUTE_NODE                 = 2;
 const unsigned short      TEXT_NODE                      = 3;
 const unsigned short      CDATA_SECTION_NODE             = 4;
 const unsigned short      ENTITY_REFERENCE_NODE          = 5;
 const unsigned short      ENTITY_NODE                    = 6;
 const unsigned short      PROCESSING_INSTRUCTION_NODE    = 7;
 const unsigned short      COMMENT_NODE                   = 8;
 const unsigned short      DOCUMENT_NODE                  = 9;
 const unsigned short      DOCUMENT_TYPE_NODE             = 10;
 const unsigned short      DOCUMENT_FRAGMENT_NODE         = 11;
 const unsigned short      NOTATION_NODE                  = 12;
 
 readonly attribute DOMString        nodeName;
 attribute DOMString        nodeValue;
 // raises(DOMException) on setting
 // raises(DOMException) on retrieval
 
 readonly attribute unsigned short   nodeType;
 readonly attribute Node             parentNode;
 readonly attribute NodeList         childNodes;
 readonly attribute Node             firstChild;
 readonly attribute Node             lastChild;
 readonly attribute Node             previousSibling;
 readonly attribute Node             nextSibling;
 readonly attribute NamedNodeMap     attributes;
 // Modified in DOM Level 2:
 readonly attribute Document         ownerDocument;
 Node               insertBefore(in Node newChild, 
 in Node refChild)
 raises(DOMException);
 Node               replaceChild(in Node newChild, 
 in Node oldChild)
 raises(DOMException);
 Node               removeChild(in Node oldChild)
 raises(DOMException);
 Node               appendChild(in Node newChild)
 raises(DOMException);
 boolean            hasChildNodes();
 Node               cloneNode(in boolean deep);
 // Modified in DOM Level 2:
 void               normalize();
 // Introduced in DOM Level 2:
 boolean            isSupported(in DOMString feature, 
 in DOMString version);
 // Introduced in DOM Level 2:
 readonly attribute DOMString        namespaceURI;
 // Introduced in DOM Level 2:
 attribute DOMString        prefix;
 // raises(DOMException) on setting
 
 // Introduced in DOM Level 2:
 readonly attribute DOMString        localName;
 // Introduced in DOM Level 2:
 boolean            hasAttributes();
 };

 -------------------------------
 
 // DOM Level 3 that we *need*, partly because SVG Spec makes one brief reference to it: http://www.w3.org/TR/SVG/text.html#InterfaceSVGTextContentElement
 
 http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html#Node3-textContent
 
 // Introduced in DOM Level 3:
 attribute DOMString       textContent;
 
*/

#import <Foundation/Foundation.h>

@class Document;
/** objc won't allow this: #import "Document.h"*/
@class NodeList;
/** objc won't allow this: #import "NodeList.h"*/
@class NamedNodeMap;
/** objc won't allow this: #import "NamedNodeMap.h"*/

typedef enum DOMNodeType
{
	DOMNodeType_ELEMENT_NODE                   = 1,
	DOMNodeType_ATTRIBUTE_NODE                 = 2,
	DOMNodeType_TEXT_NODE                      = 3,
	DOMNodeType_CDATA_SECTION_NODE             = 4,
	DOMNodeType_ENTITY_REFERENCE_NODE          = 5,
	DOMNodeType_ENTITY_NODE                    = 6,
	DOMNodeType_PROCESSING_INSTRUCTION_NODE    = 7,
	DOMNodeType_COMMENT_NODE                   = 8,
	DOMNodeType_DOCUMENT_NODE                  = 9,
	DOMNodeType_DOCUMENT_TYPE_NODE             = 10,
	DOMNodeType_DOCUMENT_FRAGMENT_NODE         = 11,
	DOMNodeType_NOTATION_NODE                  = 12
} DOMNodeType;

@interface Node : NSObject

@property(nonatomic,strong,readonly) NSString* nodeName;
@property(nonatomic,strong,readonly) NSString* nodeValue;
	
@property(nonatomic,readonly) DOMNodeType nodeType;
@property(nonatomic,weak,readonly) Node* parentNode;
@property(nonatomic,strong,readonly) NodeList* childNodes;
@property(nonatomic,weak,readonly) Node* firstChild;
@property(nonatomic,weak,readonly) Node* lastChild;
@property(nonatomic,weak,readonly) Node* previousSibling;
@property(nonatomic,weak,readonly) Node* nextSibling;
@property(nonatomic,strong,readonly) NamedNodeMap* attributes; /**< NB: according to DOM Spec, this is null if the Node is NOT subclassed as an Element */

// Modified in DOM Level 2:
@property(nonatomic,weak,readonly) Document* ownerDocument;

-(Node*) insertBefore:(Node*) newChild refChild:(Node*) refChild;

-(Node*) replaceChild:(Node*) newChild oldChild:(Node*) oldChild;
-(Node*) removeChild:(Node*) oldChild;
-(Node*) appendChild:(Node*) newChild;

@property(nonatomic) BOOL hasChildNodes;

-(Node*) cloneNode:(BOOL) deep;

// Modified in DOM Level 2:
-(void) normalize;

// Introduced in DOM Level 2:
-(BOOL) isSupportedFeature:(NSString*) feature version:(NSString*) version;

// Introduced in DOM Level 2:
@property(nonatomic,strong,readonly) NSString* namespaceURI;

// Introduced in DOM Level 2:
@property(nonatomic,strong,readonly) NSString* prefix;

// Introduced in DOM Level 2:
@property(nonatomic,strong,readonly) NSString* localName;

// Introduced in DOM Level 2:
@property(nonatomic) BOOL hasAttributes;

// DOM Level 3 that we *need*, partly because SVG Spec makes one brief reference to it: http://www.w3.org/TR/SVG/text.html#InterfaceSVGTextContentElement

// Introduced in DOM Level 3: http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/core.html#Node3-textContent
@property(weak, nonatomic,readonly) NSString* textContent;

#pragma mark - Objective-C init methods (not in SVG Spec - you're supposed to use SVGDocument's createXXX methods instead)
/** Designated initializers - 2 pairs (one for DOM 1, no namespace, the other for DOM 2, with namespace) of 2 methods (one for nodes that REQUIRE a value, the other for nodes that MUST NOT have a value) */
- (id)initType:(DOMNodeType) nt name:(NSString*) n;
- (id)initType:(DOMNodeType) nt name:(NSString*) n value:(NSString*) v;
- (id)initType:(DOMNodeType) nt name:(NSString*) n inNamespace:(NSString*) nsURI;
- (id)initType:(DOMNodeType) nt name:(NSString*) n value:(NSString*) v inNamespace:(NSString*) nsURI;

#pragma mark - Objective-C serialization method to serialize a DOM tree back to XML (used heavily in SVGKit's output/conversion features)

/** EXPERIMENTAL: not fully implemented or tested - this correctly outputs most SVG files, but is missing esoteric
 features such as EntityReferences, currently they are simply ignored
 
 This method should be used hand-in-hand with the proprietary SVGDocument method "allNamespaces" and the SVGSVGElement method "
 
 @param outputString an empty MUTABLE string we can accumulate with output (NB: this method uses a lot of memory, needs to accumulate data)
 
 @param prefixesByKNOWNNamespace (required): a dictionary mapping "XML namespace URI" to "prefix to use inside the xml-tags", e.g. "http://w3.org/2000/svg" usually is mapped to "svg" (or to "", signifying it's the default namespace). This MUST include ALL NAMESPACES FOUND IN THE DOCUMENT (it's recommended you use SVGDocument's "allPrefixesByNamespace" method, and some post-processing, to get an accurate input here)
 
 @param prefixesByACTIVENamespace (required): a mutable dictionary listing which elements of the other dictionary are active in-scope - i.e. which namespaces have been output by this node or a higher node in the tree. You pass-in an empty dictionary to the root SVG node and it fills it in as required.
 */
-(void) appendXMLToString:(NSMutableString*) outputString availableNamespaces:(NSDictionary*) prefixesByKNOWNNamespace activeNamespaces:(NSMutableDictionary*) prefixesByACTIVENamespace;

@end
