#import <Foundation/Foundation.h>

void __tgvoip_call_tglog(char* format, ...){
	va_list args;
	va_start(args, format);
	TGLog([[[NSString alloc] initWithFormat:[NSString stringWithCString:format encoding:NSUTF8StringEncoding] arguments:args] stringByReplacingOccurrencesOfString:@"%" withString:@"%%"]);
	va_end(args);
}