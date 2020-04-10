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
#include "td/utils/tests.h"

#include "td/utils/BigNum.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"

#include <algorithm>
#include <limits>
#include <utility>

REGISTER_TESTS(pq)

using namespace td;

#if TD_HAVE_OPENSSL
static bool is_prime(uint64 x) {
  for (uint64 d = 2; d < x && d * d <= x; d++) {
    if (x % d == 0) {
      return false;
    }
  }
  return true;
}

static std::vector<uint64> gen_primes(uint64 L, uint64 R, int limit = 0) {
  std::vector<uint64> res;
  for (auto x = L; x <= R && (limit <= 0 || res.size() < static_cast<std::size_t>(limit)); x++) {
    if (is_prime(x)) {
      res.push_back(x);
    }
  }
  return res;
}

static std::vector<uint64> gen_primes() {
  std::vector<uint64> result;
  append(result, gen_primes(1, 100));
  append(result, gen_primes((1ull << 31) - 500000, std::numeric_limits<uint64>::max(), 5));
  append(result, gen_primes((1ull << 32) - 500000, std::numeric_limits<uint64>::max(), 5));
  append(result, gen_primes((1ull << 39) - 500000, std::numeric_limits<uint64>::max(), 1));
  return result;
}

using PqQuery = std::pair<uint64, uint64>;
static bool cmp(const PqQuery &a, const PqQuery &b) {
  return a.first * a.second < b.first * b.second;
}
static std::vector<PqQuery> gen_pq_queries() {
  std::vector<PqQuery> res;
  auto primes = gen_primes();
  for (auto q : primes) {
    for (auto p : primes) {
      if (p > q) {
        break;
      }
      res.emplace_back(p, q);
    }
  }
  std::sort(res.begin(), res.end(), cmp);
  return res;
}

static void test_pq(uint64 first, uint64 second) {
  BigNum p = BigNum::from_decimal(PSLICE() << first).move_as_ok();
  BigNum q = BigNum::from_decimal(PSLICE() << second).move_as_ok();

  BigNum pq;
  BigNumContext context;
  BigNum::mul(pq, p, q, context);
  std::string pq_str = pq.to_binary();

  std::string p_str, q_str;
  int err = td::pq_factorize(pq_str, &p_str, &q_str);
  LOG_CHECK(err == 0) << first << " * " << second;

  BigNum p_res = BigNum::from_binary(p_str);
  BigNum q_res = BigNum::from_binary(q_str);

  LOG_CHECK(p_str == p.to_binary()) << td::tag("got", p_res.to_decimal()) << td::tag("expected", first);
  LOG_CHECK(q_str == q.to_binary()) << td::tag("got", q_res.to_decimal()) << td::tag("expected", second);
}
#endif

TEST(CryptoPQ, hands) {
  ASSERT_EQ(1ull, td::pq_factorize(0));
  ASSERT_EQ(1ull, td::pq_factorize(1));
  ASSERT_EQ(1ull, td::pq_factorize(2));
  ASSERT_EQ(1ull, td::pq_factorize(3));
  ASSERT_EQ(2ull, td::pq_factorize(4));
  ASSERT_EQ(1ull, td::pq_factorize(5));
  ASSERT_EQ(3ull, td::pq_factorize(7 * 3));
  ASSERT_EQ(179424611ull, td::pq_factorize(179424611ull * 179424673ull));

#if TD_HAVE_OPENSSL
  test_pq(4294467311, 4294467449);
#endif
}

#if TD_HAVE_OPENSSL
TEST(CryptoPQ, generated_slow) {
  for (int i = 0; i < 100000; i++) {
    test_pq(2, 2);
  }
  auto queries = gen_pq_queries();
  for (auto query : queries) {
    test_pq(query.first, query.second);
  }
}
#endif
