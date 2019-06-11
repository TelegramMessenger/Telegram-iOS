

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTTransport.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTTransport.h>
#else
#   import <MtProtoKit/MTTransport.h>
#endif

@interface MTTcpTransport : MTTransport

@end
