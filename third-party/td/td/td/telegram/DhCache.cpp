//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DhCache.h"

#include "td/telegram/Global.h"
#include "td/telegram/TdDb.h"

#include "td/utils/common.h"
#include "td/utils/misc.h"

namespace td {

static string good_prime_key(Slice prime_str) {
  string key("good_prime:");
  key.append(prime_str.data(), prime_str.size());
  return key;
}

int DhCache::is_good_prime(Slice prime_str) const {
  static string built_in_good_prime =
      hex_decode(
          "c71caeb9c6b1c9048e6c522f70f13f73980d40238e3e21c14934d037563d930f48198a0aa7c14058229493d22530f4dbfa336f6e0ac9"
          "25139543aed44cce7c3720fd51f69458705ac68cd4fe6b6b13abdc9746512969328454f18faf8c595f642477fe96bb2a941d5bcd1d4a"
          "c8cc49880708fa9b378e3c4f3a9060bee67cf9a4a4a695811051907e162753b56b0f6b410dba74d8a84b2a14b3144e0ef1284754fd17"
          "ed950d5965b4b9dd46582db1178d169c6bc465b0d6ff9ca3928fef5b9ae4e418fc15e83ebea0f87fa9ff5eed70050ded2849f47bf959"
          "d956850ce929851f0d8115f635b105ee2e4e15d04b2454bf6f4fadf034b10403119cd8e3b92fcc5b")
          .move_as_ok();
  if (prime_str == built_in_good_prime) {
    return 1;
  }

  string value = G()->td_db()->get_binlog_pmc()->get(good_prime_key(prime_str));
  if (value == "good") {
    return 1;
  }
  if (value == "bad") {
    return 0;
  }
  CHECK(value.empty());
  return -1;
}

void DhCache::add_good_prime(Slice prime_str) const {
  G()->td_db()->get_binlog_pmc()->set(good_prime_key(prime_str), "good");
}

void DhCache::add_bad_prime(Slice prime_str) const {
  G()->td_db()->get_binlog_pmc()->set(good_prime_key(prime_str), "bad");
}

}  // namespace td
