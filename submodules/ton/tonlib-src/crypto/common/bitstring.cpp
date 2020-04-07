/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "common/bitstring.h"
#include <cstring>
#include <limits>
#include "td/utils/as.h"
#include "td/utils/bits.h"
#include "td/utils/misc.h"
#include "crypto/openssl/digest.hpp"

namespace td {

template class Ref<BitString>;

BitString::BitString(const BitSlice& bs, unsigned reserve_bits) {
  if (!bs.size() && !reserve_bits) {
    ptr = 0;
    offs = len = bytes_alloc = 0;
  } else {
    offs = bs.get_offs();
    len = bs.size();
    bytes_alloc = (bs.get_offs() + bs.size() + reserve_bits + 7) >> 3;
    ptr = static_cast<unsigned char*>(std::malloc(bytes_alloc));
    CHECK(ptr);
    if (bs.size()) {
      std::memcpy(ptr, bs.get_ptr(), bs.byte_size());
    }
  }
}

BitString::BitString(unsigned reserve_bits) {
  if (!reserve_bits) {
    ptr = 0;
    offs = len = bytes_alloc = 0;
  } else {
    bytes_alloc = (reserve_bits + 7) >> 3;
    ptr = static_cast<unsigned char*>(std::malloc(bytes_alloc));
    CHECK(ptr);
    offs = len = 0;
  }
}

BitString::operator BitSlice() const {
  return BitSlice(BitStringRef{this}, ptr, offs, len);
}

BitString* BitString::make_copy() const {
  if (!ptr) {
    return new BitString(64);  // reserve 64 bits
  } else {
    return new BitString(operator BitSlice(), 64);
  }
}

BitString& BitString::reserve_bits(unsigned req_bits) {
  req_bits += offs + len;
  if (req_bits > bytes_alloc * 8) {
    bytes_alloc = (req_bits + 7) >> 3;
    ptr = (unsigned char*)std::realloc(ptr, bytes_alloc);
    CHECK(ptr);
  }
  return *this;
}

BitSliceWrite BitString::reserve_bitslice(unsigned req_bits) {
  reserve_bits(req_bits);
  unsigned pos = offs + len;
  len += req_bits;
  return BitSliceWrite(Ref<BitString>(this), ptr, pos, req_bits);
}

BitString& BitString::append(const BitSlice& bs) {
  reserve_bitslice(bs.size()) = bs;
  return *this;
}

BitSlice BitString::subslice(unsigned from, unsigned bits) const {
  return BitSlice{BitStringRef{this}, ptr, static_cast<int>(offs + from), bits};
}

BitSliceWrite BitString::subslice_write(unsigned from, unsigned bits) {
  return BitSliceWrite{BitStringRef{this}, ptr, offs + from, bits};
}

const BitSliceWrite& BitSliceWrite::operator=(const BitSlice& bs) const {
  if (size() != bs.size()) {
    throw LengthMismatch();
  }
  bitstring::bits_memcpy(get_ptr(), get_offs(), bs.get_ptr(), bs.get_offs(), size());
  return *this;
}

const BitSliceWrite& BitSliceWrite::operator=(bool val) const {
  bitstring::bits_memset(get_ptr(), get_offs(), val, size());
  return *this;
}

std::ostream& operator<<(std::ostream& os, const BitString& bs) {
  return os << bs.to_hex();
}

std::ostream& operator<<(std::ostream& os, Ref<BitString> bs_ref) {
  return os << (bs_ref.is_null() ? "(null-bs)" : bs_ref->to_hex());
}

namespace bitstring {

void bits_memcpy(unsigned char* to, int to_offs, const unsigned char* from, int from_offs, std::size_t bit_count) {
  if (bit_count <= 0) {
    return;
  }
  from += (from_offs >> 3);
  to += (to_offs >> 3);
  from_offs &= 7;
  to_offs &= 7;
  //fprintf(stderr, "bits_memcpy: from=%p (%02x) to=%p (%02x) from_offs=%d to_offs=%d count=%lu\n", from, *from, to, *to, from_offs, to_offs, bit_count);
  int sz = (int)bit_count;
  bit_count += from_offs;
  if (from_offs == to_offs) {
    if (bit_count < 8) {
      int mask = (-0x100 >> bit_count) & (0xff >> to_offs);
      *to = (unsigned char)((*to & ~mask) | (*from & mask));
      return;
    }
    std::size_t l = (bit_count >> 3);
    if (!to_offs) {
      std::memcpy(to, from, l);
    } else {
      int mask = (0xff >> to_offs);
      *to = (unsigned char)((*to & ~mask) | (*from & mask));
      std::memcpy(to + 1, from + 1, l - 1);
    }
    if ((bit_count &= 7) != 0) {
      int mask = (-0x100 >> bit_count);
      to[l] = (unsigned char)((to[l] & ~mask) | (from[l] & mask));
    }
  } else {
    int b = (int)to_offs;
    unsigned long long acc = (b ? *to >> (8 - b) : 0);
    if (bit_count < 8) {
      acc <<= sz;
      acc |= ((*from & (0xff >> from_offs)) >> (8 - bit_count));
      b += sz;
    } else {
      unsigned ld = 8 - from_offs;
      acc <<= ld;
      acc |= (*from++ & (0xff >> from_offs));
      b += ld;
      bit_count -= 8;
      // b <= 15 here
      while (bit_count >= 32) {
        acc <<= 32;
        acc |= td::bswap32(as<unsigned>(from));
        from += 4;
        as<unsigned>(to) = td::bswap32((unsigned)(acc >> b));
        to += 4;
        bit_count -= 32;
      }
      // bit_count <= 31, b <= 15
      while (bit_count >= 8) {
        acc <<= 8;
        acc |= *from++;
        bit_count -= 8;
        b += 8;
      }
      // b + bit_count = const <= 46
      if (bit_count > 0) {
        acc <<= bit_count;
        acc |= (*from >> (8 - bit_count));
        b += (int)bit_count;
      }
    }
    while (b >= 8) {
      b -= 8;
      *to++ = (unsigned char)(acc >> b);
    }
    if (b > 0) {
      *to = (unsigned char)((*to & (0xff >> b)) | ((int)acc << (8 - b)));
    }
  }
}

void bits_memcpy(BitPtr to, ConstBitPtr from, std::size_t bit_count) {
  bits_memcpy(to.ptr, to.offs, from.ptr, from.offs, bit_count);
}

void bits_memset(unsigned char* to, int to_offs, bool val, std::size_t bit_count) {
  if (bit_count <= 0) {
    return;
  }
  to += (to_offs >> 3);
  to_offs &= 7;
  int sz = (int)bit_count;
  bit_count += to_offs;
  int c = *to;
  if (bit_count <= 8) {
    int mask = (((-0x100 >> sz) & 0xff) >> to_offs);
    if (val) {
      *to = (unsigned char)(c | mask);
    } else {
      *to = (unsigned char)(c & ~mask);
    }
    return;
  }
  if (val) {
    *to = (unsigned char)(c | (0xff >> to_offs));
  } else {
    *to = (unsigned char)(c & (-0x100 >> to_offs));
  }
  std::size_t l = (bit_count >> 3);
  std::memset(to + 1, val ? 0xff : 0, l - 1);
  if ((bit_count &= 7) != 0) {
    if (val) {
      to[l] = (unsigned char)(to[l] | (-0x100 >> bit_count));
    } else {
      to[l] = (unsigned char)(to[l] & (0xff >> bit_count));
    }
  }
}

void bits_memset(BitPtr to, bool val, std::size_t bit_count) {
  bits_memset(to.ptr, to.offs, val, bit_count);
}

std::size_t bits_memscan_rev(const unsigned char* ptr, int offs, std::size_t bit_count, bool cmp_to) {
  if (!bit_count) {
    return 0;
  }
  int xor_val = (cmp_to ? -1 : 0);
  ptr += ((offs + bit_count) >> 3);
  offs = (int)((offs + bit_count) & 7);
  std::size_t res = offs;
  if (offs) {
    unsigned v = (*ptr >> (8 - offs)) ^ xor_val;
    unsigned c = td::count_trailing_zeroes32(v);
    if (c < (unsigned)offs || res >= bit_count) {
      return std::min(c, (unsigned)bit_count);
    }
  }
  bit_count -= res;
  while (bit_count >= 32) {
    ptr -= 4;
    unsigned v = td::bswap32(as<unsigned>(ptr)) ^ xor_val;
    if (v) {
      return td::count_trailing_zeroes_non_zero32(v) + res;
    }
    res += 32;
    bit_count -= 32;
  }
  xor_val &= 0xff;
  while (bit_count >= 8) {
    unsigned v = *--ptr ^ xor_val;
    if (v) {
      return td::count_trailing_zeroes_non_zero32(v) + res;
    }
    res += 8;
    bit_count -= 8;
  }
  if (bit_count > 0) {
    unsigned v = *--ptr ^ xor_val;
    return std::min((unsigned)td::count_trailing_zeroes32(v), (unsigned)bit_count) + res;
  } else {
    return res;
  }
}

std::size_t bits_memscan(const unsigned char* ptr, int offs, std::size_t bit_count, bool cmp_to) {
  if (!bit_count) {
    return 0;
  }
  int xor_val = -static_cast<int>(cmp_to);
  ptr += (offs >> 3);
  offs &= 7;
  std::size_t rem = bit_count;
  unsigned v, c;
  if (offs) {
    v = ((unsigned)(ptr[0] ^ xor_val) << (24 + offs));
    // std::cerr << "[A] rem=" << rem << " ptr=" << (const void*)ptr << " v=" << std::hex << v << std::dec << std::endl;
    c = td::count_leading_zeroes32(v);
    unsigned l = (unsigned)(8 - offs);
    if (c < l || bit_count <= l) {
      return std::min<std::size_t>(c, bit_count);
    }
    rem -= l;
    ptr++;
  }
  while (rem >= 8 && !td::is_aligned_pointer<8>(ptr)) {
    v = ((*ptr++ ^ xor_val) << 24);
    // std::cerr << "[B] rem=" << rem << " ptr=" << (const void*)(ptr - 1) << " v=" << std::hex << v << std::dec << std::endl;
    if (v) {
      return bit_count - rem + td::count_leading_zeroes_non_zero32(v);
    }
    rem -= 8;
  }
  td::uint64 xor_val_l = (cmp_to ? ~0LL : 0LL);
  while (rem >= 64) {
    td::uint64 z = td::bswap64(as<td::uint64>(ptr)) ^ xor_val_l;
    // std::cerr << "[C] rem=" << rem << " ptr=" << (const void*)ptr << " z=" << std::hex << z << std::dec << std::endl;
    if (z) {
      return bit_count - rem + td::count_leading_zeroes_non_zero64(z);
    }
    ptr += 8;
    rem -= 64;
  }
  while (rem >= 8) {
    v = ((*ptr++ ^ xor_val) << 24);
    // std::cerr << "[D] rem=" << rem << " ptr=" << (const void*)(ptr - 1) << " v=" << std::hex << v << std::dec << std::endl;
    if (v) {
      return bit_count - rem + td::count_leading_zeroes_non_zero32(v);
    }
    rem -= 8;
  }
  if (rem > 0) {
    v = ((*ptr ^ xor_val) << 24);
    // std::cerr << "[E] rem=" << rem << " ptr=" << (const void*)ptr << " v=" << std::hex << v << std::dec << std::endl;
    c = td::count_leading_zeroes32(v);
    return c < rem ? bit_count - rem + c : bit_count;
  } else {
    return bit_count;
  }
}

std::size_t bits_memscan(ConstBitPtr bs, std::size_t bit_count, bool cmp_to) {
  return bits_memscan(bs.ptr, bs.offs, bit_count, cmp_to);
}

std::size_t bits_memscan_rev(ConstBitPtr bs, std::size_t bit_count, bool cmp_to) {
  return bits_memscan_rev(bs.ptr, bs.offs, bit_count, cmp_to);
}

int bits_memcmp(const unsigned char* bs1, int bs1_offs, const unsigned char* bs2, int bs2_offs, std::size_t bit_count,
                std::size_t* same_upto) {
  if (!bit_count) {
    return 0;
  }
  bs1 += (bs1_offs >> 3);
  bs2 += (bs2_offs >> 3);
  bs1_offs &= 7;
  bs2_offs &= 7;
  //fprintf(stderr, "bits_memcmp: bs1=%02x%02x offs=%d bs2=%02x%02x offs=%d cnt=%lu\n", bs1[0], bs1[1], bs1_offs, bs2[0], bs2[1], bs2_offs, bit_count);
  unsigned long long acc1 = (((unsigned long long)*bs1++) << (56 + bs1_offs));
  int z1 = 8 - bs1_offs;
  unsigned long long acc2 = (((unsigned long long)*bs2++) << (56 + bs2_offs));
  int z2 = 8 - bs2_offs;
  std::size_t processed = 0;
  while (bit_count >= 40) {
    acc1 |= ((unsigned long long)td::bswap32(as<unsigned>(bs1)) << (32 - z1));
    bs1 += 4;
    acc2 |= ((unsigned long long)td::bswap32(as<unsigned>(bs2)) << (32 - z2));
    bs2 += 4;
    if ((acc1 ^ acc2) & (~0ULL << 32)) {
      if (same_upto) {
        *same_upto = processed + td::count_leading_zeroes64(acc1 ^ acc2);
      }
      return acc1 < acc2 ? -1 : 1;
    }
    acc1 <<= 32;
    acc2 <<= 32;
    processed += 32;
    bit_count -= 32;
  }
  // now 0 <= bit_count <= 39

  bs1_offs += (int)bit_count - 8;  // = bit_count - z1, bits to load from bs1
  while (bs1_offs >= 8) {
    acc1 |= ((unsigned long long)(*bs1++) << (56 - z1));
    z1 += 8;
    bs1_offs -= 8;
  }
  if (bs1_offs > 0) {
    acc1 |= ((unsigned long long)(*bs1) << (56 - z1));
  }
  z1 += bs1_offs;  // NB: bs1_offs may be negative

  bs2_offs += (int)bit_count - 8;  // bits to load from bs2
  while (bs2_offs >= 8) {
    acc2 |= ((unsigned long long)(*bs2++) << (56 - z2));
    z2 += 8;
    bs2_offs -= 8;
  }
  if (bs2_offs > 0) {
    acc2 |= ((unsigned long long)(*bs2) << (56 - z2));
  }
  z2 += bs2_offs;

  CHECK(z1 == z2);
  CHECK(z1 < 64);
  //fprintf(stderr, "acc1=%016llx acc2=%016llx z1=z2=%d\n", acc1, acc2, z1);
  if (z1) {
    if ((acc1 ^ acc2) & (~0ULL << (64 - z1))) {
      if (same_upto) {
        *same_upto = processed + td::count_leading_zeroes64(acc1 ^ acc2);
      }
      return acc1 < acc2 ? -1 : 1;
    }
  }
  if (same_upto) {
    *same_upto = processed + bit_count;
  }
  return 0;
}

int bits_memcmp(ConstBitPtr bs1, ConstBitPtr bs2, std::size_t bit_count, std::size_t* same_upto) {
  return bits_memcmp(bs1.ptr, bs1.offs, bs2.ptr, bs2.offs, bit_count, same_upto);
}

int bits_lexcmp(const unsigned char* bs1, int bs1_offs, std::size_t bs1_bit_count, const unsigned char* bs2,
                int bs2_offs, std::size_t bs2_bit_count) {
  int res = bits_memcmp(bs1, bs1_offs, bs2, bs2_offs, std::min(bs1_bit_count, bs2_bit_count), 0);
  if (res || bs1_bit_count == bs2_bit_count) {
    return res;
  }
  return bs1_bit_count < bs2_bit_count ? -1 : 1;
}

int bits_lexcmp(ConstBitPtr bs1, std::size_t bs1_bit_count, ConstBitPtr bs2, std::size_t bs2_bit_count) {
  return bits_lexcmp(bs1.ptr, bs1.offs, bs1_bit_count, bs2.ptr, bs2.offs, bs2_bit_count);
}

void bits_store_long_top(unsigned char* to, int to_offs, unsigned long long val, unsigned top_bits) {
  CHECK(top_bits <= 64);
  if (top_bits <= 0) {
    return;
  }
  to += (to_offs >> 3);
  to_offs &= 7;
  if (!to_offs && !(top_bits & 7)) {
    // good only on little-endian machines!
    unsigned long long tmp = td::bswap64(val);
    std::memcpy(to, &tmp, top_bits >> 3);
    return;
  }
  unsigned long long z = (unsigned long long)(*to & (-0x100 >> to_offs)) << 56;
  z |= (val >> to_offs);
  top_bits += to_offs;
  if (top_bits > 64) {
    as<unsigned long long>(to) = td::bswap64(z);
    z = (val << (8 - to_offs));
    int mask = (0xff >> (top_bits - 64));
    to[8] = (unsigned char)((to[8] & mask) | ((int)z & ~mask));
  } else {
    int p = 56, q = 64 - top_bits;
    if (q <= 32) {
      as<unsigned>(to) = td::bswap32((unsigned)(z >> 32));
      to += 4;
      p -= 32;
    }
    while (p >= q) {
      *to++ = (unsigned char)(z >> p);
      p -= 8;
    }
    top_bits = p + 8 - q;
    if (top_bits > 0) {
      int mask = (0xff >> top_bits);
      *to = (unsigned char)((*to & mask) | ((z >> p) & ~mask));
    }
  }
}

void bits_store_long_top(BitPtr to, unsigned long long val, unsigned top_bits) {
  bits_store_long_top(to.ptr, to.offs, val, top_bits);
}

void bits_store_long(BitPtr to, unsigned long long val, unsigned bits) {
  bits_store_long_top(to, val << (64 - bits), bits);
}

unsigned long long bits_load_long_top(const unsigned char* from, int from_offs, unsigned top_bits) {
  CHECK(top_bits <= 64);
  if (!top_bits) {
    return 0;
  }
  from += (from_offs >> 3);
  from_offs &= 7;
  if ((unsigned)from_offs + top_bits <= 64) {
    unsigned long long tmp;
    std::memcpy(&tmp, from, (from_offs + top_bits + 7) >> 3);
    return (td::bswap64(tmp) << from_offs) & (std::numeric_limits<td::uint64>::max() << (64 - top_bits));
  } else {
    unsigned long long z = td::bswap64(as<unsigned long long>(from));
    z <<= from_offs;
    z |= (from[8] >> (8 - from_offs));
    return z & (std::numeric_limits<td::uint64>::max() << (64 - top_bits));
  }
}

unsigned long long bits_load_long_top(ConstBitPtr from, unsigned top_bits) {
  return bits_load_long_top(from.ptr, from.offs, top_bits);
}

unsigned long long bits_load_ulong(ConstBitPtr from, unsigned bits) {
  return bits_load_long_top(from, bits) >> (64 - bits);
}

long long bits_load_long(ConstBitPtr from, unsigned bits) {
  return (long long)bits_load_long_top(from, bits) >> (64 - bits);
}

std::string bits_to_binary(const unsigned char* ptr, int offs, std::size_t len) {
  if (!len) {
    return "";
  }
  std::string s;
  s.reserve(len);
  ptr += (offs >> 3);
  unsigned mask = (0x80 >> (offs & 7));
  unsigned value = *ptr++;
  do {
    s.push_back(value & mask ? '1' : '0');
    if (!(mask >>= 1)) {
      value = *ptr++;
      mask = 0x80;
    }
  } while (--len > 0);
  return s;
}

std::string bits_to_binary(ConstBitPtr bs, std::size_t len) {
  return bits_to_binary(bs.ptr, bs.offs, len);
}

static const char hex_digits[] = "0123456789ABCDEF";

std::string bits_to_hex(const unsigned char* ptr, int offs, std::size_t len) {
  if (!len) {
    return "";
  }
  std::string s;
  s.reserve((len + 7) >> 2);
  ptr += (offs >> 3);
  offs &= 7;
  unsigned long long acc = *ptr++ & (0xff >> offs);
  unsigned bits = 8 - offs;
  if (bits > len) {
    acc >>= bits - (unsigned)len;
    bits = (unsigned)len;
  } else {
    len -= bits;
    while (len >= 8) {
      while (len >= 8 && bits <= 56) {
        acc <<= 8;
        acc |= *ptr++;
        bits += 8;
        len -= 8;
      }
      while (bits >= 4) {
        bits -= 4;
        s.push_back(hex_digits[(acc >> bits) & 15]);
      }
    }
    if (len > 0) {
      acc <<= len;
      acc |= (*ptr >> (8 - len));
      bits += (unsigned)len;
    }
  }
  int f = bits & 3;
  if (f) {
    acc = (2 * acc + 1) << (3 - f);
    bits += 4 - f;
  }
  while (bits >= 4) {
    bits -= 4;
    s.push_back(hex_digits[(acc >> bits) & 15]);
  }
  CHECK(!bits);
  if (f) {
    s.push_back('_');
  }
  return s;
}

std::string bits_to_hex(ConstBitPtr bs, std::size_t len) {
  return bits_to_hex(bs.ptr, bs.offs, len);
}

long parse_bitstring_hex_literal(unsigned char* buff, std::size_t buff_size, const char* str, const char* str_end) {
  std::size_t hex_digits_count = 0;
  bool cmpl = false;
  unsigned char* ptr = buff;
  const char* rptr = str;
  while (rptr < str_end) {
    int c = *rptr++;
    if (c == ' ' || c == '\t') {
      continue;
    }
    if (cmpl) {
      return td::narrow_cast<long>(str - rptr);
    }
    if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
      int val = (c <= '9') ? c - '0' : ((c | 0x20) - 'a' + 10);
      if (hex_digits_count >= 2 * buff_size) {
        return td::narrow_cast<long>(str - rptr);
      }
      if (!(hex_digits_count & 1)) {
        *ptr = (unsigned char)(val << 4);
      } else {
        *ptr = (unsigned char)(*ptr | val);
        ptr++;
      }
      hex_digits_count++;
      continue;
    }
    if (c == '_') {
      cmpl = true;
    } else {
      return td::narrow_cast<long>(str - rptr);
    }
  }
  std::size_t bits = 4 * hex_digits_count;
  if (cmpl && bits) {
    int t = (hex_digits_count & 1) ? (0x100 + *ptr) >> 4 : (0x100 + *--ptr);
    while (bits > 0) {
      --bits;
      if (t & 1) {
        break;
      }
      t >>= 1;
      if (t == 1) {
        t = 0x100 + *--ptr;
      }
    }
  }
  return bits;
}

long parse_bitstring_binary_literal(BitPtr buff, std::size_t buff_size, const char* str, const char* str_end) {
  const char* ptr = str;
  while (ptr < str_end && buff_size && (*ptr == '0' || *ptr == '1')) {
    *buff++ = (bool)(*ptr++ & 1);
    --buff_size;
  }
  return td::narrow_cast<long>(ptr == str_end ? ptr - str : str - ptr - 1);
}

void bits_sha256(BitPtr to, ConstBitPtr from, std::size_t size) {
  if (from.byte_aligned() && !(size & 7)) {
    if (to.byte_aligned()) {
      digest::hash_str<digest::SHA256>(to.get_byte_ptr(), from.get_byte_ptr(), size >> 3);
    } else {
      unsigned char buffer[32];
      digest::hash_str<digest::SHA256>(buffer, from.get_byte_ptr(), size >> 3);
      to.copy_from(BitPtr{buffer}, 256);
    }
  } else {
    throw BitstringError{};
  }
}

}  // namespace bitstring

}  // namespace td
