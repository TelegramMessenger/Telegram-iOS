#import <Foundation/Foundation.h>

// MTProto quick acknowledgements (https://core.telegram.org/mtproto/mtproto-transports#quick-ack).
//
// The token is the first 32 bits of msg_key_large = SHA256(auth_key[88+x..+32] ‖ plaintext),
// read little-endian, with the most significant bit set so it cannot be mistaken for a
// packet length. The client remembers the token without that bit and matches it against
// what the server echoes back:
//
// - intermediate / padded intermediate: the 4 token bytes are sent as-is (little-endian);
// - abridged: the 4 bytes are byte-swapped so the flag bit lands in the first byte on the wire.
//
// These helpers keep the three places that touch the token in agreement and testable.

// Token (flag bit cleared) for a message whose msg_key_large starts at msgKeyLarge.
int32_t MTQuickAckTokenFromMsgKeyLarge(const uint8_t * _Nonnull msgKeyLarge);

// Token (flag bit cleared) from the 4-byte little-endian word an intermediate-framed server
// sent, either as a standalone packet or after the 0xffffffff marker inside a padded packet.
int32_t MTQuickAckTokenFromIntermediateWord(int32_t word);

// Token (flag bit cleared) from the 4 bytes an abridged-framed server sent, in wire order.
int32_t MTQuickAckTokenFromAbridgedBytes(const uint8_t * _Nonnull bytes);
