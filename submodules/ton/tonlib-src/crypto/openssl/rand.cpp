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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "openssl/rand.hpp"

#include "td/utils/common.h"

#include <openssl/rand.h>
#include <openssl/opensslv.h>

namespace prng {
int os_get_random_bytes(void *buf, int n);

bool RandomGen::ok() const {
  return RAND_status();
}

void RandomGen::seed_add(const void *data, std::size_t size, double entropy) {
  RAND_add(data, static_cast<int>(size), entropy > 0 ? entropy : static_cast<double>(size));
}

void RandomGen::randomize(bool force) {
  if (!force && ok()) {
    return;
  }
  unsigned char buffer[128];
  int n = os_get_random_bytes(buffer, 128);
  seed_add(buffer, n);
  assert(ok());
}

bool RandomGen::rand_bytes(void *data, std::size_t size, bool strong) {
#if OPENSSL_VERSION_NUMBER < 0x10101000L
  int res = (strong ? RAND_bytes : RAND_pseudo_bytes)((unsigned char *)data, static_cast<int>(size));
#else
  int res = RAND_bytes((unsigned char *)data, static_cast<int>(size));
#endif
  if (res != 0 && res != 1) {
    throw rand_error();
  }
  return res;
}

std::string RandomGen::rand_string(std::size_t size, bool strong) {
  std::string result(size, '\0');
  if (size > 0 && !rand_bytes(&result[0], size, strong)) {
    throw rand_error();
  }
  return result;
}

RandomGen &rand_gen() {
  // RandomGen is stateless, OpenSSL will handle concurrent access
  static RandomGen MainPRNG;
  return MainPRNG;
}
}  // namespace prng

//------------------------- move to separate OS-dependent file?
#if TD_WINDOWS
namespace prng {
int os_get_random_bytes(void *buf, int n) {
  return 0;
}
}  // namespace prng
#else
#include <fcntl.h>
#include <unistd.h>

namespace prng {

int os_get_random_bytes(void *buf, int n) {
  using namespace std;
  int r = 0;
  int h = open("/dev/random", O_RDONLY | O_NONBLOCK);
  if (h >= 0) {
    r = static_cast<int>(read(h, buf, n));
    if (r > 0) {
      //std::cerr << "added " << r << " bytes of real entropy to secure random numbers seed" << std::endl;
    } else {
      r = 0;
    }
    close(h);
  }

  if (r < n) {
    h = open("/dev/urandom", O_RDONLY);
    if (h < 0) {
      return r;
    }
    int s = static_cast<int>(read(h, (char *)buf + r, n - r));
    close(h);
    if (s < 0) {
      return r;
    }
    r += s;
  }

  if (r >= 8) {
    *(long *)buf ^= lrand48();
    srand48(*(long *)buf);
  }

  return r;
}
}  // namespace prng
#endif
