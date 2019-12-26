@interface NamedNodeMap ()

/**
 DOM1 is very basic and ignores namespaces - dangerous! It's recommended to avoid DOM1 calls throughout your apps and code!
 
 @return an Array of "nodes from the nodemap (Node)"
 */
-(NSArray*) allNodesUnsortedDOM1;

/**
 DOM2 requires everything to have a namespace - much better than DOM1
 
 @return a Dictionary of "namespace (string)" mapped to "node from nodemap (Node)"
 */
 -(NSDictionary*) allNodesUnsortedDOM2;

@end
