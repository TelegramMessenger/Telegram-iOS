/**
 SVGDocument
 
 SVG spec defines this as part of the DOM version of SVG:
 
 http://www.w3.org/TR/SVG11/struct.html#InterfaceSVGDocument
 */

#import "Document+Mutable.h"

#import "SVGDocument.h"
#import "SVGDocument_Mutable.h"

#import "NamedNodeMap_Iterable.h" // needed for the allPrefixesByNamespace implementation

@implementation SVGDocument


@synthesize title;
@synthesize referrer;
@synthesize domain;
@synthesize URL;
@synthesize rootElement=_rootElement;



- (id)init
{
    self = [super initType:DOMNodeType_DOCUMENT_NODE name:@"#document"];
    if (self) {
        
    }
    return self;
}

-(void)setRootElement:(SVGSVGElement *)rootElement
{
	_rootElement = rootElement;
	
	/*! SVG spec has two variables with same name, because DOM was written to support
	 weak programming languages that don't provide full OOP polymorphism.
	 
	 So, we'd better keep the two variables in sync!
	 */
	super.documentElement = rootElement;
}

-(void)setDocumentElement:(Element *)newDocumentElement
{
	NSAssert( [newDocumentElement isKindOfClass:[SVGSVGElement class]], @"Cannot set the documentElement property on an SVG doc unless it's of type SVGSVGDocument" );
	
	super.documentElement = newDocumentElement;
	
	/*! SVG spec has two variables with same name, because DOM was written to support
	 weak programming languages that don't provide full OOP polymorphism.
	 
	 So, we'd better keep the two variables in sync!
	 */
	self.rootElement = (SVGSVGElement*) self.documentElement;
}

#pragma mark - Serialization methods that we think ought to be part of the SVG spec, as they are needed for a good implementation, but we can't find in the main Spec

/**
 Recursively goes through the document finding all declared namespaces in-use by any tag or attribute.
 
 @return a dictionary mapping "namespace" to "ARRAY of prefix-strings"
 */
-(NSMutableDictionary*) allPrefixesByNamespace
{
	NSMutableDictionary* result = [NSMutableDictionary dictionary];
	
	[SVGDocument accumulateNamespacesForNode:self.rootElement intoDictionary:result];
	
	return result;
}

/** implementation of allPrefixesByNamespace - stores "namespace string" : "ARRAY of prefix strings"
 */
+(void) accumulateNamespacesForNode:(Node*) node intoDictionary:(NSMutableDictionary*) output
{
	/**
	 First, find all the attributes that declare a new Namespace at this point */
	NSDictionary* nodeMapsByNamespace = [node.attributes allNodesUnsortedDOM2];
	
	NSString* xmlnsNamespace = @"http://www.w3.org/2000/xmlns/";
	NSDictionary* xmlnsNodemap = [nodeMapsByNamespace objectForKey:xmlnsNamespace];
	
	for( NSString* xmlnsNodeName in xmlnsNodemap )
	{
		Node* namespaceDeclaration = [xmlnsNodemap objectForKey:xmlnsNodeName];
		
		NSMutableArray* prefixesForNamespace = [output objectForKey:namespaceDeclaration.nodeValue];
		if( prefixesForNamespace == nil )
		{
			prefixesForNamespace = [NSMutableArray array];
			[output setObject:prefixesForNamespace forKey:namespaceDeclaration.nodeValue];
		}
		
		if( ! [prefixesForNamespace containsObject:namespaceDeclaration.nodeName])
			[prefixesForNamespace addObject:namespaceDeclaration.localName];
	}
	
	for( Node* childNode in node.childNodes )
	{
		[self accumulateNamespacesForNode:childNode intoDictionary:output];
	}
}

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
-(NSMutableDictionary*) allPrefixesByNamespaceNormalized
{
	NSMutableDictionary* prefixArraysByNamespace = [self allPrefixesByNamespace];
	NSMutableDictionary* normalizedPrefixesByNamespace = [NSMutableDictionary dictionary];
	
	for( NSString* namespace in prefixArraysByNamespace )
	{
		NSArray* prefixes = [prefixArraysByNamespace objectForKey:namespace];
		
		BOOL exportedAUniquePrefix = FALSE;
		for( NSString* nextPrefix in prefixes )
		{
			if( ! [normalizedPrefixesByNamespace.allValues containsObject:nextPrefix])
			{
				[normalizedPrefixesByNamespace setObject:nextPrefix forKey:namespace];
				exportedAUniquePrefix = TRUE;
				break;
			}
		}
		
		/** If that failed to find a unique prefix, we need to either generate one, or use the default prefix */
		if( ! exportedAUniquePrefix )
		{
			if( [namespace isEqualToString:@"http://w3.org/2000/svg"])
			{
				[normalizedPrefixesByNamespace setObject:@"" forKey:namespace];
			}
			else
			{
				/** Generate a new shortname that will OVERRIDE AND REPLACE whatever prefixes this attribute has */
				int suffix = 1;
				NSString* newPrefix = [namespace lastPathComponent];
				while( [normalizedPrefixesByNamespace.allValues containsObject:newPrefix])
				{
					suffix++;
					
					newPrefix = [NSString stringWithFormat:@"%@-%i", [namespace lastPathComponent], suffix];
				}
				
				[normalizedPrefixesByNamespace setObject:newPrefix forKey:namespace];
			}
		}
	}
	
	SVGKitLogVerbose(@"Normalized prefixes:\n%@", normalizedPrefixesByNamespace );
	return normalizedPrefixesByNamespace;
}

@end
