/*
 SVG DOM, cf:
 
 http://www.w3.org/TR/SVG11/struct.html#InterfaceSVGDocument
 
 interface SVGDocument : Document,
 DocumentEvent {
 readonly attribute DOMString title;
 readonly attribute DOMString referrer;
 readonly attribute DOMString domain;
 readonly attribute DOMString URL;
 readonly attribute SVGSVGElement rootElement;
 };
 */

#import <Foundation/Foundation.h>

#import "Document.h"
#import "SVGSVGElement.h"

@interface SVGDocument : Document

@property (nonatomic, strong, readonly) NSString* title;
@property (nonatomic, strong, readonly) NSString* referrer;
@property (nonatomic, strong, readonly) NSString* domain;
@property (nonatomic, strong, readonly) NSString* URL;
@property (nonatomic, strong, readonly) SVGSVGElement* rootElement;

#pragma mark - Objective-C init methods (not part of DOM spec, but necessary!)

- (id)init;

#pragma mark - Serialization methods that we think ought to be part of the SVG spec, as they are needed for a good implementation, but we can't find in the main Spec

/**
 Recursively goes through the document finding all declared namespaces in-use by any tag or attribute.
 
 @return a dictionary mapping "namespace" to "ARRAY of prefix-strings"
 */
-(NSMutableDictionary*) allPrefixesByNamespace;

/**
 As per allPrefixesByNamespace, but takes the output and guarantees that:
 
 1. There is AT MOST ONE namespace with no prefix
 2. The "prefixless" namespace is the SVG namespace (if possible. This should always be possible for an SVG doc!)
 3. All other namespaces have EXACTLY ONE prefix (if there are multiple, it discards excess ones)
 4. All prefixes are UNIQUE (not used by more than one Namespace)
 
 This is critically important when writing-out an SVG file to disk - As far as I can tell, it's a major ommission from
 the XML Spec (which SVG sits on top of). Without this info, you can't construct the appropriate/correct "xmlns" directives
 at the start of a file.
 
 USAGE INSTRUCTIONS:
 
 1. Call this method to get the complete list of namespaces, including any prefixes used
 2. Invoke Node's "appendXMLToString:..." method, passing-in this output, so it can correctly output prefixes for all nodes and subnodes
 
 @return a dictionary mapping "namespace" to "prefix-string or empty-string for the default namespace"
 */
-(NSMutableDictionary*) allPrefixesByNamespaceNormalized;

@end
