//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/DhCallback.h"
#include "td/mtproto/DhHandshake.h"

#include "td/utils/base64.h"
#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"

#include <map>

#if TD_LINUX || TD_ANDROID || TD_TIZEN
#include <semaphore.h>
#endif

static td::int32 g = 3;
static td::string prime_base64 =
    "xxyuucaxyQSObFIvcPE_c5gNQCOOPiHBSTTQN1Y9kw9IGYoKp8FAWCKUk9IlMPTb-jNvbgrJJROVQ67UTM58NyD9UfaUWHBaxozU_mtrE6vcl0ZRKW"
    "kyhFTxj6-MWV9kJHf-lrsqlB1bzR1KyMxJiAcI-ps3jjxPOpBgvuZ8-aSkppWBEFGQfhYnU7VrD2tBDbp02KhLKhSzFE4O8ShHVP0X7ZUNWWW0ud1G"
    "WC2xF40WnGvEZbDW_5yjko_vW5rk5Bj8Feg-vqD4f6n_Xu1wBQ3tKEn0e_lZ2VaFDOkphR8NgRX2NbEF7i5OFdBLJFS_b0-t8DSxBAMRnNjjuS_MW"
    "w";

class HandshakeBench final : public td::Benchmark {
  td::string get_description() const final {
    return "Handshake";
  }

  class FakeDhCallback final : public td::mtproto::DhCallback {
   public:
    int is_good_prime(td::Slice prime_str) const final {
      auto it = cache.find(prime_str.str());
      if (it == cache.end()) {
        return -1;
      }
      return it->second;
    }
    void add_good_prime(td::Slice prime_str) const final {
      cache[prime_str.str()] = 1;
    }
    void add_bad_prime(td::Slice prime_str) const final {
      cache[prime_str.str()] = 0;
    }
    mutable std::map<td::string, int> cache;
  } dh_callback;

  void run(int n) final {
    td::mtproto::DhHandshake a;
    td::mtproto::DhHandshake b;
    auto prime = td::base64url_decode(prime_base64).move_as_ok();
    td::mtproto::DhHandshake::check_config(g, prime, &dh_callback).ensure();
    for (int i = 0; i < n; i += 2) {
      a.set_config(g, prime);
      b.set_config(g, prime);
      b.set_g_a(a.get_g_b());
      a.set_g_a(b.get_g_b());
      a.run_checks(true, &dh_callback).ensure();
      b.run_checks(true, &dh_callback).ensure();
      auto a_key = a.gen_key();
      auto b_key = b.gen_key();
      CHECK(a_key.first == b_key.first);
    }
  }
};

int main() {
  td::bench(HandshakeBench());
}
