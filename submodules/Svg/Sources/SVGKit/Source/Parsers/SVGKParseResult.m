#import "SVGKParseResult.h"

@implementation SVGKParseResult

@synthesize libXMLFailed;
@synthesize parsedDocument, rootOfSVGTree, namespacesEncountered;
@synthesize warnings, errorsRecoverable, errorsFatal;

#if ENABLE_PARSER_EXTENSIONS_CUSTOM_DATA
@synthesize extensionsData;
#endif


- (id)init
{
    self = [super init];
    if (self) {
        self.warnings = [NSMutableArray array];
		self.errorsRecoverable = [NSMutableArray array];
		self.errorsFatal = [NSMutableArray array];
		
		self.namespacesEncountered = [NSMutableDictionary dictionary];
		
		#if ENABLE_PARSER_EXTENSIONS_CUSTOM_DATA
		self.extensionsData = [NSMutableDictionary dictionary];
#endif
    }
    return self;
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"[Parse result: %lu warnings, %lu errors(recoverable), %lu errors (fatal). %@%@", (unsigned long)self.warnings.count, (unsigned long)self.errorsRecoverable.count, (unsigned long)self.errorsFatal.count, (self.errorsFatal.count > 0)?@"First fatal error: ":@"Last recoverable error: ", self.errorsFatal.count > 0 ? [self.errorsFatal firstObject] : self.errorsRecoverable.count > 0 ? [self.errorsRecoverable lastObject] : @"(n/a)"];
}

-(void) addSourceError:(NSError*) fatalError
{
	SVGKitLogError(@"[%@] SVG ERROR: %@", [self class], fatalError);
	[self.errorsRecoverable addObject:fatalError];
}

-(void) addParseWarning:(NSError*) warning
{
	SVGKitLogWarn(@"[%@] SVG WARNING: %@", [self class], warning);
	[self.warnings addObject:warning];
}

-(void) addParseErrorRecoverable:(NSError*) recoverableError
{
	SVGKitLogWarn(@"[%@] SVG WARNING (recoverable): %@", [self class], recoverableError);
	[self.errorsRecoverable addObject:recoverableError];
}

-(void) addParseErrorFatal:(NSError*) fatalError
{
	SVGKitLogError(@"[%@] SVG ERROR: %@", [self class], fatalError);
	[self.errorsFatal addObject:fatalError];
}

-(void) addSAXError:(NSError*) saxError
{
	SVGKitLogWarn(@"[%@] SVG ERROR: %@", [self class], [saxError localizedDescription]);
	[self.errorsFatal addObject:saxError];
}

#if ENABLE_PARSER_EXTENSIONS_CUSTOM_DATA
-(NSMutableDictionary*) dictionaryForParserExtension:(NSObject<SVGKParserExtension>*) extension
{
	NSMutableDictionary* d = [self.extensionsData objectForKey:[extension class]];
	if( d == nil )
	{
		d = [NSMutableDictionary dictionary];
		[self.extensionsData setObject:d forKey:[extension class]];
	}
	
	return d;
}
#endif

@end
