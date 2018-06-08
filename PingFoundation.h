#import <Foundation/Foundation.h>

#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
#import <CFNetwork/CFNetwork.h>
#else
#import <CoreServices/CoreServices.h>
#endif

#include <AssertMacros.h>

#pragma mark * PingFoundation

@protocol PingFoundationDelegate;

typedef NS_ENUM(NSInteger, PingFoundationAddressStyle) {
    PingFoundationAddressStyleAny,          ///< Use the first IPv4 or IPv6 address found; the default.
    PingFoundationAddressStyleICMPv4,       ///< Use the first IPv4 address found.
    PingFoundationAddressStyleICMPv6        ///< Use the first IPv6 address found.
};

@interface PingFoundation : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*! Initialise the object to ping the specified host.
 *  \param hostName The DNS name of the host to ping; an IPv4 or IPv6 address in string form will
 *      work here.
 *  \returns The initialised object.
 */

- (instancetype)initWithHostName:(NSString *)hostName NS_DESIGNATED_INITIALIZER;

/*! A copy of the value passed to `-initWithHostName:`.
 */

@property (nonatomic, copy, readonly) NSString * hostName;

/*! The delegate for this object.
 *  \details Delegate callbacks are schedule in the default run loop mode of the run loop of the
 *      thread that calls `-start`.
 */

@property (nonatomic, weak, readwrite) id<PingFoundationDelegate> delegate;

/*! Controls the IP address version used by the object.
 *  \details You should set this value before starting the object.
 */

@property (nonatomic, assign, readwrite) PingFoundationAddressStyle addressStyle;

/*! The address being pinged.
 *  \details The contents of the NSData is a (struct sockaddr) of some form.  The
 *      value is nil while the object is stopped and remains nil on start until
 *      `-pingFoundation:didStartWithAddress:` is called.
 */

@property (nonatomic, copy, readonly) NSData * hostAddress;

/*! The address family for `hostAddress`, or `AF_UNSPEC` if that's nil.
 */

@property (nonatomic, assign, readonly) sa_family_t hostAddressFamily;

/*! The identifier used by pings by this object.
 *  \details When you create an instance of this object it generates a random identifier
 *      that it uses to identify its own pings.
 */

@property (nonatomic, assign, readonly) uint16_t identifier;

/*! The next sequence number to be used by this object.
 *  \details This value starts at zero and increments each time you send a ping (safely
 *      wrapping back to zero if necessary).  The sequence number is included in the ping,
 *      allowing you to match up requests and responses, and thus calculate ping times and
 *      so on.
 */

@property (nonatomic, assign, readonly) uint16_t nextSequenceNumber;

- (void)start;
// Starts the pinger object pinging.  You should call this after
// you've setup the delegate and any ping parameters.

- (void)sendPingWithData:(NSData *)data;
// Sends an actual ping.  Pass nil for data to use a standard 56 byte payload (resulting in a
// standard 64 byte ping).  Otherwise pass a non-nil value and it will be appended to the
// ICMP header.
//
// Do not try to send a ping before you receive the -PingFoundation:didStartWithAddress: delegate
// callback.

- (void)stop;
// Stops the pinger object.  You should call this when you're done
// pinging.

@end

@protocol PingFoundationDelegate <NSObject>

@optional

/*! A PingFoundation delegate callback, called once the object has started up.
 *  \details This is called shortly after you start the object to tell you that the
 *      object has successfully started.  On receiving this callback, you can call
 *      `-sendPingWithData:` to send pings.
 *
 *      If the object didn't start, `-pingFoundation:didFailWithError:` is called instead.
 *  \param pinger The object issuing the callback.
 *  \param address The address that's being pinged; at the time this delegate callback
 *      is made, this will have the same value as the `hostAddress` property.
 */

- (void)pingFoundation:(PingFoundation *)pinger didStartWithAddress:(NSData *)address;

/*! A PingFoundation delegate callback, called if the object fails to start up.
 *  \details This is called shortly after you start the object to tell you that the
 *      object has failed to start.  The most likely cause of failure is a problem
 *      resolving `hostName`.
 *
 *      By the time this callback is called, the object has stopped (that is, you don't
 *      need to call `-stop` yourself).
 *  \param pinger The object issuing the callback.
 *  \param error Describes the failure.
 */

- (void)pingFoundation:(PingFoundation *)pinger didFailWithError:(NSError *)error;

/*! A PingFoundation delegate callback, called when the object has successfully sent a ping packet.
 *  \details Each call to `-sendPingWithData:` will result in either a
 *      `-pingFoundation:didSendPacket:sequenceNumber:` delegate callback or a
 *      `-pingFoundation:didFailToSendPacket:sequenceNumber:error:` delegate callback (unless you
 *      stop the object before you get the callback).  These callbacks are currently delivered
 *      synchronously from within `-sendPingWithData:`, but this synchronous behaviour is not
 *      considered API.
 *  \param pinger The object issuing the callback.
 *  \param packet The packet that was sent; this includes the ICMP header (`ICMPHeader`) and the
 *      data you passed to `-sendPingWithData:` but does not include any IP-level headers.
 *  \param sequenceNumber The ICMP sequence number of that packet.
 */

- (void)pingFoundation:(PingFoundation *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber;

/*! A PingFoundation delegate callback, called when the object fails to send a ping packet.
 *  \details Each call to `-sendPingWithData:` will result in either a
 *      `-pingFoundation:didSendPacket:sequenceNumber:` delegate callback or a
 *      `-pingFoundation:didFailToSendPacket:sequenceNumber:error:` delegate callback (unless you
 *      stop the object before you get the callback).  These callbacks are currently delivered
 *      synchronously from within `-sendPingWithData:`, but this synchronous behaviour is not
 *      considered API.
 *  \param pinger The object issuing the callback.
 *  \param packet The packet that was not sent; see `-pingFoundation:didSendPacket:sequenceNumber:`
 *      for details.
 *  \param sequenceNumber The ICMP sequence number of that packet.
 *  \param error Describes the failure.
 */

- (void)pingFoundation:(PingFoundation *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error;

/*! A PingFoundation delegate callback, called when the object receives a ping response.
 *  \details If the object receives an ping response that matches a ping request that it
 *      sent, it informs the delegate via this callback.  Matching is primarily done based on
 *      the ICMP identifier, although other criteria are used as well.
 *  \param pinger The object issuing the callback.
 *  \param packet The packet received; this includes the ICMP header (`ICMPHeader`) and any data that
 *      follows that in the ICMP message but does not include any IP-level headers.
 *  \param sequenceNumber The ICMP sequence number of that packet.
 */

- (void)pingFoundation:(PingFoundation *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber;

/*! A PingFoundation delegate callback, called when the object receives an unmatched ICMP message.
 *  \details If the object receives an ICMP message that does not match a ping request that it
 *      sent, it informs the delegate via this callback.  The nature of ICMP handling in a
 *      BSD kernel makes this a common event because, when an ICMP message arrives, it is
 *      delivered to all ICMP sockets.
 *
 *      IMPORTANT: This callback is especially common when using IPv6 because IPv6 uses ICMP
 *      for important network management functions.  For example, IPv6 routers periodically
 *      send out Router Advertisement (RA) packets via Neighbor Discovery Protocol (NDP), which
 *      is implemented on top of ICMP.
 *
 *      For more on matching, see the discussion associated with
 *      `-pingFoundation:didReceivePingResponsePacket:sequenceNumber:`.
 *  \param pinger The object issuing the callback.
 *  \param packet The packet received; this includes the ICMP header (`ICMPHeader`) and any data that
 *      follows that in the ICMP message but does not include any IP-level headers.
 */

- (void)pingFoundation:(PingFoundation *)pinger didReceiveUnexpectedPacket:(NSData *)packet;

@end

#pragma mark * IP and ICMP On-The-Wire Format

/*! Describes the on-the-wire header format for an ICMP ping.
 *  \details This defines the header structure of ping packets on the wire.  Both IPv4 and
 *      IPv6 use the same basic structure.
 *
 *      This is declared in the header because clients of PingFoundation might want to use
 *      it parse received ping packets.
 */

// ICMP type and code combinations:

enum {
    ICMPv4TypeEchoRequest = 8,          ///< The ICMP `type` for a ping request; in this case `code` is always 0.
    ICMPv4TypeEchoReply   = 0           ///< The ICMP `type` for a ping response; in this case `code` is always 0.
};

enum {
    ICMPv6TypeEchoRequest = 128,        ///< The ICMP `type` for a ping request; in this case `code` is always 0.
    ICMPv6TypeEchoReply   = 129         ///< The ICMP `type` for a ping response; in this case `code` is always 0.
};

// ICMP header structure:

struct ICMPHeader
{
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    sequenceNumber;
    // data...
};
typedef struct ICMPHeader ICMPHeader;

__Check_Compile_Time(sizeof(ICMPHeader) == 8);
__Check_Compile_Time(offsetof(ICMPHeader, type) == 0);
__Check_Compile_Time(offsetof(ICMPHeader, code) == 1);
__Check_Compile_Time(offsetof(ICMPHeader, checksum) == 2);
__Check_Compile_Time(offsetof(ICMPHeader, identifier) == 4);
__Check_Compile_Time(offsetof(ICMPHeader, sequenceNumber) == 6);
