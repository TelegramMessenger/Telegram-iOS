/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include <iostream>
#include <iomanip>
#include <string>
#include <cstring>

#include "crypto/ellcurve/Ed25519.h"

static void my_assert_impl(bool cond, const char* str, const char* file, int line) {
  if (!cond) {
    std::cerr << "Failed " << str << " in " << file << " at " << line << ".\n";
  }
}
#define my_assert(x) my_assert_impl(x, #x, __FILE__, __LINE__)

void print_buffer(const unsigned char buffer[32]) {
  for (int i = 0; i < 32; i++) {
    char buff[4];
    sprintf(buff, "%02x", buffer[i]);
    std::cout << buff;
  }
}

std::string buffer_to_hex(const unsigned char* buffer, std::size_t size = 32) {
  const char* hex = "0123456789ABCDEF";
  std::string res(2 * size, '\0');
  for (std::size_t i = 0; i < size; i++) {
    auto c = buffer[i];
    res[2 * i] = hex[c & 15];
    res[2 * i + 1] = hex[c >> 4];
  }
  return res;
}

// export of (17/12)G on twisted Edwards curve
unsigned char test_vector1[32] = {0xfc, 0xb7, 0x42, 0x1e, 0x26, 0xad, 0x1b, 0x17, 0xf6, 0xb1, 0x52,
                                  0x0c, 0xdb, 0x8a, 0x64, 0x7d, 0x28, 0xa7, 0x56, 0x69, 0xd4, 0xb6,
                                  0x0c, 0xec, 0x63, 0x72, 0x5e, 0xe6, 0x32, 0x4d, 0xf7, 0xe6};

unsigned char rfc7748_output[32] = {
    0x95, 0xcb, 0xde, 0x94, 0x76, 0xe8, 0x90, 0x7d, 0x7a, 0xad, 0xe4, 0x5c, 0xb4, 0xb8, 0x73, 0xf8,
    0x8b, 0x59, 0x5a, 0x68, 0x79, 0x9f, 0xa1, 0x52, 0xe6, 0xf8, 0xf7, 0x64, 0x7a, 0xac, 0x79, 0x57,
};

bool test_ed25519_impl(void) {
  std::cout << "************** Testing Curve25519 / Ed25519 operations ************\n";
  auto& E = ellcurve::Curve25519();
  auto& Edw = ellcurve::Ed25519();
  arith::Bignum L = E.get_ell();
  my_assert(arith::is_prime(L));
  my_assert(L == Edw.get_ell());
  arith::ResidueRing Fl(L);
  arith::Bignum s = Fl.frac(17, 12).extract();
  arith::Bignum t = Fl.frac(12, 17).extract();
  std::cout << "l = " << L << std::endl;
  std::cout << "s = 17/12 mod l = " << s << std::endl;
  std::cout << "t = 12/17 mod l = " << t << std::endl;
  auto sG = E.power_gen_xz(s);
  auto u_sG = sG.get_u();
  std::cout << "Curve25519 u(sG) = " << sG.get_u().extract() << std::endl;
  std::cout << "Curve25519 y(sG) = " << sG.get_y().extract() << std::endl;
  auto sG1 = Edw.power_gen(s);
  std::cout << "Ed25519 u(sG) = " << sG1.get_u().extract() << std::endl;
  std::cout << "Ed25519 y(sG) = " << sG1.get_y().extract() << std::endl;
  std::cout << "Ed25519 x(sG) = " << sG1.get_x().extract() << std::endl;
  my_assert(sG1.get_x().extract() != sG1.get_y().extract());
  my_assert(sG.get_u() == sG1.get_u());
  my_assert(sG.get_y() == sG1.get_y());

  my_assert(
      sG1.get_x().extract() ==
      arith::Bignum(arith::dec_string{"9227429025021714590777223519505276506601225973596506606120015751301699519597"}));
  my_assert(sG1.get_y().extract() ==
            arith::Bignum(
                arith::dec_string{"46572854587220149033453000581008590225032365765275643343836649812808016508924"}));

  auto sG2 = Edw.power_gen(s, true);
  my_assert(sG1.get_u() == sG2.get_u());
  my_assert(sG1.get_y() == sG2.get_y());
  unsigned char buff[32];
  std::memset(buff, 0, 32);
  my_assert(sG1.export_point(buff));
  std::cout << "sG export = " << buffer_to_hex(buff) << std::endl;
  bool ok;
  auto sG3 = Edw.import_point(buff, ok);
  my_assert(ok);
  my_assert(!std::memcmp(buff, test_vector1, 32));
  my_assert(sG3.get_u() == sG1.get_u());
  my_assert(sG2.get_x() == sG2.get_x());
  my_assert(sG2.get_y() == sG2.get_y());

  auto stG = E.power_xz(u_sG, t);
  std::cout << "Curve25519 u(stG) = " << stG.get_u().extract() << std::endl;
  my_assert(stG.get_u().extract() == 9);
  auto stG1 = Edw.power_point(sG1, t);
  std::cout << "Ed25519 u(stG) = " << stG1.get_u().extract() << std::endl;
  my_assert(stG1.get_u().extract() == 9);
  stG1.normalize();
  my_assert(stG1.XY == Edw.get_base_point().XY);
  my_assert(stG1.X == Edw.get_base_point().X);
  my_assert(stG1.Y == Edw.get_base_point().Y);
  my_assert(stG1.Z == Edw.get_base_point().Z);
  auto stG2 = Edw.power_point(sG2, t, true);
  my_assert(stG2.get_u().extract() == 9);
  stG2.normalize();
  my_assert(stG2.XY == stG1.XY && stG2.X == stG1.X && stG2.Y == stG1.Y);
  auto stG3 = Edw.power_point(sG3, t).normalize();
  auto stG4 = Edw.power_point(sG3, t, true).normalize();
  my_assert(stG3.XY == stG1.XY && stG3.X == stG1.X && stG3.Y == stG1.Y);
  my_assert(stG4.XY == stG1.XY && stG4.X == stG1.X && stG4.Y == stG1.Y);

  // RFC7748 test vector
  auto u =
      arith::Bignum(arith::dec_string{"8883857351183929894090759386610649319417338800022198945255395922347792736741"});
  //u[255] = 0;
  auto n =
      arith::Bignum(arith::dec_string{"35156891815674817266734212754503633747128614016119564763269015315466259359304"});
  //n[255] = 0; n[254] = 1;
  //n[0] = n[1] = n[2] = 0;
  auto umodp = arith::Residue(u, E.get_base_ring());
  auto nP = E.power_xz(umodp, n);
  std::cout << "u(P) = " << u.to_hex() << std::endl;
  std::cout << "n = " << n.to_hex() << std::endl;
  std::cout << "u(nP) = " << nP.get_u().extract().to_hex() << std::endl;
  unsigned char buffer[32];
  std::memset(buffer, 0, 32);
  nP.export_point_u(buffer);
  std::cout << "u(nP) export = " << buffer_to_hex(buffer) << std::endl;
  my_assert(!std::memcmp(buffer, rfc7748_output, 32));

  std::cout << "********* ok\n\n";
  return true;
}

unsigned char fixed_privkey[32] = "abacabadabacabaeabacabadabacaba";
unsigned char fixed_pubkey[32] = {0x6f, 0x9e, 0x5b, 0xde, 0xce, 0x87, 0x21, 0xeb, 0x57, 0x37, 0xfb,
                                  0xb5, 0x92, 0x28, 0xba, 0x07, 0xf7, 0x88, 0x0f, 0x73, 0xce, 0x5b,
                                  0xfa, 0xa1, 0xb7, 0x15, 0x73, 0x03, 0xd4, 0x20, 0x1e, 0x74};

unsigned char rfc8032_secret_key1[32] = {0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60, 0xba, 0x84, 0x4a,
                                         0xf4, 0x92, 0xec, 0x2c, 0xc4, 0x44, 0x49, 0xc5, 0x69, 0x7b, 0x32,
                                         0x69, 0x19, 0x70, 0x3b, 0xac, 0x03, 0x1c, 0xae, 0x7f, 0x60};

unsigned char rfc8032_public_key1[32] = {0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7, 0xd5, 0x4b, 0xfe,
                                         0xd3, 0xc9, 0x64, 0x07, 0x3a, 0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6,
                                         0x23, 0x25, 0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a};

unsigned char rfc8032_signature1[64] = {
    0xe5, 0x56, 0x43, 0x00, 0xc3, 0x60, 0xac, 0x72, 0x90, 0x86, 0xe2, 0xcc, 0x80, 0x6e, 0x82, 0x8a,
    0x84, 0x87, 0x7f, 0x1e, 0xb8, 0xe5, 0xd9, 0x74, 0xd8, 0x73, 0xe0, 0x65, 0x22, 0x49, 0x01, 0x55,
    0x5f, 0xb8, 0x82, 0x15, 0x90, 0xa3, 0x3b, 0xac, 0xc6, 0x1e, 0x39, 0x70, 0x1c, 0xf9, 0xb4, 0x6b,
    0xd2, 0x5b, 0xf5, 0xf0, 0x59, 0x5b, 0xbe, 0x24, 0x65, 0x51, 0x41, 0x43, 0x8e, 0x7a, 0x10, 0x0b,
};

unsigned char rfc8032_secret_key2[32] = {
    0xc5, 0xaa, 0x8d, 0xf4, 0x3f, 0x9f, 0x83, 0x7b, 0xed, 0xb7, 0x44, 0x2f, 0x31, 0xdc, 0xb7, 0xb1,
    0x66, 0xd3, 0x85, 0x35, 0x07, 0x6f, 0x09, 0x4b, 0x85, 0xce, 0x3a, 0x2e, 0x0b, 0x44, 0x58, 0xf7,
};

unsigned char rfc8032_public_key2[32] = {
    0xfc, 0x51, 0xcd, 0x8e, 0x62, 0x18, 0xa1, 0xa3, 0x8d, 0xa4, 0x7e, 0xd0, 0x02, 0x30, 0xf0, 0x58,
    0x08, 0x16, 0xed, 0x13, 0xba, 0x33, 0x03, 0xac, 0x5d, 0xeb, 0x91, 0x15, 0x48, 0x90, 0x80, 0x25,
};

unsigned char rfc8032_message2[2] = {0xaf, 0x82};

unsigned char rfc8032_signature2[64] = {
    0x62, 0x91, 0xd6, 0x57, 0xde, 0xec, 0x24, 0x02, 0x48, 0x27, 0xe6, 0x9c, 0x3a, 0xbe, 0x01, 0xa3,
    0x0c, 0xe5, 0x48, 0xa2, 0x84, 0x74, 0x3a, 0x44, 0x5e, 0x36, 0x80, 0xd7, 0xdb, 0x5a, 0xc3, 0xac,
    0x18, 0xff, 0x9b, 0x53, 0x8d, 0x16, 0xf2, 0x90, 0xae, 0x67, 0xf7, 0x60, 0x98, 0x4d, 0xc6, 0x59,
    0x4a, 0x7c, 0x15, 0xe9, 0x71, 0x6e, 0xd2, 0x8d, 0xc0, 0x27, 0xbe, 0xce, 0xea, 0x1e, 0xc4, 0x0a,
};

bool test_ed25519_crypto() {
  std::cout << "************** Testing Curve25519 / Ed25519 cryptographic primitives ************\n";
  crypto::Ed25519::PrivateKey PK1, PK2, PK3, PK4, PK5;
  PK1.random_private_key();
  PK2.import_private_key(fixed_privkey);
  unsigned char priv2_export[32];
  bool ok = PK1.export_private_key(priv2_export);
  std::cout << "PK1 = " << ok << " " << buffer_to_hex(priv2_export) << std::endl;
  my_assert(ok);
  ok = PK2.export_private_key(priv2_export);
  std::cout << "PK2 = " << ok << " " << buffer_to_hex(priv2_export) << std::endl;
  my_assert(ok);
  PK3.import_private_key(priv2_export);
  std::cout << "PK3 = " << PK3.ok() << std::endl;
  my_assert(PK3.ok());

  unsigned char pub_export[32];
  ok = PK1.export_public_key(pub_export);
  std::cout << "PubK1 = " << ok << " " << buffer_to_hex(pub_export) << std::endl;
  my_assert(ok);
  crypto::Ed25519::PublicKey PubK1(pub_export);
  ok = PK2.export_public_key(pub_export);
  std::cout << "PubK2 = " << ok << " " << buffer_to_hex(pub_export) << std::endl;
  my_assert(ok);
  my_assert(!std::memcmp(pub_export, fixed_pubkey, 32));
  crypto::Ed25519::PublicKey PubK2(pub_export);
  ok = PK3.export_public_key(pub_export);
  std::cout << "PubK3 = " << ok << " " << buffer_to_hex(pub_export) << std::endl;
  my_assert(ok);
  my_assert(!std::memcmp(pub_export, fixed_pubkey, 32));
  crypto::Ed25519::PublicKey PubK3(pub_export);
  ok = PubK1.export_public_key(pub_export);
  std::cout << "PubK1 = " << ok << " " << buffer_to_hex(pub_export) << std::endl;
  my_assert(ok);

  unsigned char secret22[32];
  ok = PK2.compute_shared_secret(secret22, PubK3);
  std::cout << "secret(PK2,PubK2)=" << ok << " " << buffer_to_hex(secret22) << std::endl;
  my_assert(ok);

  unsigned char secret12[32], secret21[32];
  ok = PK1.compute_shared_secret(secret12, PubK3);
  std::cout << "secret(PK1,PubK2)=" << ok << " " << buffer_to_hex(secret12) << std::endl;
  my_assert(ok);
  ok = PK2.compute_shared_secret(secret21, PubK1);
  std::cout << "secret(PK2,PubK1)=" << ok << " " << buffer_to_hex(secret21) << std::endl;
  my_assert(ok);
  my_assert(!std::memcmp(secret12, secret21, 32));

  //  for (int i = 0; i < 1000; i++) {
  //    ok = PK1.compute_shared_secret(secret12, PubK3);
  //    my_assert(ok);
  //    ok = PK2.compute_shared_secret(secret21, PubK1);
  //    my_assert(ok);
  //  }

  unsigned char signature[64];
  ok = PK1.sign_message(signature, (const unsigned char*)"abc", 3);
  std::cout << "PK1.signature=" << ok << " " << buffer_to_hex(signature, 64) << std::endl;
  my_assert(ok);

  // signature[63] ^= 1;
  ok = PubK1.check_message_signature(signature, (const unsigned char*)"abc", 3);
  std::cout << "PubK1.check_signature=" << ok << std::endl;
  my_assert(ok);

  PK4.import_private_key(rfc8032_secret_key1);
  PK4.export_public_key(pub_export);
  std::cout << "PK4.private_key = " << buffer_to_hex(rfc8032_secret_key1) << std::endl;
  std::cout << "PK4.public_key = " << buffer_to_hex(pub_export) << std::endl;
  my_assert(!std::memcmp(pub_export, rfc8032_public_key1, 32));
  ok = PK4.sign_message(signature, (const unsigned char*)"", 0);
  std::cout << "PK4.signature('') = " << buffer_to_hex(signature, 64) << std::endl;
  my_assert(ok);
  my_assert(!std::memcmp(signature, rfc8032_signature1, 32));

  PK5.import_private_key(rfc8032_secret_key2);
  PK5.export_public_key(pub_export);
  std::cout << "PK5.private_key = " << buffer_to_hex(rfc8032_secret_key2) << std::endl;
  std::cout << "PK5.public_key = " << buffer_to_hex(pub_export) << std::endl;
  my_assert(!std::memcmp(pub_export, rfc8032_public_key2, 32));
  ok = PK5.sign_message(signature, rfc8032_message2, 2);
  std::cout << "PK5.signature('') = " << buffer_to_hex(signature, 64) << std::endl;
  my_assert(ok);
  my_assert(!std::memcmp(signature, rfc8032_signature2, 32));
  crypto::Ed25519::PublicKey PubK5(pub_export);

  //  for (int i = 0; i < 10000; i++) {
  //    ok = PK5.sign_message (signature, rfc8032_message2, 2);
  //    my_assert (ok);
  //  }
  //  for (int i = 0; i < 10000; i++) {
  //    ok = PubK5.check_message_signature (signature, rfc8032_message2, 2);
  //    my_assert (ok);
  //  }

  unsigned char temp_pubkey[32];
  crypto::Ed25519::TempKeyGenerator TKG;  // use one generator a lot of times

  TKG.create_temp_shared_secret(temp_pubkey, secret12, PubK1, (const unsigned char*)"abc", 3);
  std::cout << "secret12=" << buffer_to_hex(secret12) << "; temp_pubkey=" << buffer_to_hex(temp_pubkey) << std::endl;

  PK1.compute_temp_shared_secret(secret21, temp_pubkey);
  std::cout << "secret21=" << buffer_to_hex(secret21) << std::endl;
  my_assert(!std::memcmp(secret12, secret21, 32));

  std::cout << "********* ok\n\n";
  return true;
}

int main(void) {
  test_ed25519_impl();
  test_ed25519_crypto();
  return 0;
}
