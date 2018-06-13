

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTTransport.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTTransport.h>
#else
#   import <MTProtoKit/MTTransport.h>
#endif

@interface MTHttpTransport : MTTransport

@end
