//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/tests.h"

#include "td/utils/algorithm.h"
#include "td/utils/BigNum.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"

#include <limits>
#include <utility>

static bool is_prime(td::uint64 x) {
  for (td::uint64 d = 2; d < x && d * d <= x; d++) {
    if (x % d == 0) {
      return false;
    }
  }
  return true;
}

static td::vector<td::uint64> gen_primes(td::uint64 L, td::uint64 R, std::size_t limit = 0) {
  td::vector<td::uint64> res;
  for (auto x = L; x <= R && (limit <= 0 || res.size() < limit); x++) {
    if (is_prime(x)) {
      res.push_back(x);
    }
  }
  return res;
}

static td::vector<td::uint64> gen_primes(int mode) {
  td::vector<td::uint64> result;
  if (mode == 1) {
    for (size_t i = 10; i <= 19; i++) {
      td::append(result, gen_primes(i * 100000000, (i + 1) * 100000000, 1));
    }
  } else {
    td::append(result, gen_primes(1, 100));
    td::append(result, gen_primes((1ull << 31) - 500000, std::numeric_limits<td::uint64>::max(), 5));
    td::append(result, gen_primes((1ull << 32) - 500000, std::numeric_limits<td::uint64>::max(), 2));
    td::append(result, gen_primes((1ull << 39) - 500000, std::numeric_limits<td::uint64>::max(), 1));
  }
  return result;
}

using PqQuery = std::pair<td::uint64, td::uint64>;

static td::vector<PqQuery> gen_pq_queries(int mode = 0) {
  td::vector<PqQuery> res;
  auto primes = gen_primes(mode);
  for (auto q : primes) {
    for (auto p : primes) {
      if (p > q) {
        break;
      }
      res.emplace_back(p, q);
    }
  }
  return res;
}

static td::string to_binary(td::uint64 x) {
  td::string result;
  do {
    result = static_cast<char>(x & 255) + result;
    x >>= 8;
  } while (x > 0);
  return result;
}

static void test_pq_fast(td::uint64 first, td::uint64 second) {
  if ((static_cast<td::uint64>(1) << 63) / first <= second) {
    return;
  }

  td::string p_str;
  td::string q_str;
  int err = td::pq_factorize(to_binary(first * second), &p_str, &q_str);
  ASSERT_EQ(err, 0);

  ASSERT_STREQ(p_str, to_binary(first));
  ASSERT_STREQ(q_str, to_binary(second));
}

#if TD_HAVE_OPENSSL
static void test_pq_slow(td::uint64 first, td::uint64 second) {
  if ((static_cast<td::uint64>(1) << 63) / first > second) {
    return;
  }

  td::BigNum p = td::BigNum::from_decimal(PSLICE() << first).move_as_ok();
  td::BigNum q = td::BigNum::from_decimal(PSLICE() << second).move_as_ok();

  td::BigNum pq;
  td::BigNumContext context;
  td::BigNum::mul(pq, p, q, context);
  td::string pq_str = pq.to_binary();

  td::string p_str;
  td::string q_str;
  int err = td::pq_factorize(pq_str, &p_str, &q_str);
  LOG_CHECK(err == 0) << first << " * " << second;

  td::BigNum p_res = td::BigNum::from_binary(p_str);
  td::BigNum q_res = td::BigNum::from_binary(q_str);

  LOG_CHECK(p_str == p.to_binary()) << td::tag("receive", p_res.to_decimal()) << td::tag("expected", first);
  LOG_CHECK(q_str == q.to_binary()) << td::tag("receive", q_res.to_decimal()) << td::tag("expected", second);
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
  test_pq_slow(4294467311, 4294467449);
#endif
}

TEST(CryptoPQ, four) {
  for (int i = 0; i < 100000; i++) {
    test_pq_fast(2, 2);
  }
}

TEST(CryptoPQ, generated_fast) {
  auto queries = gen_pq_queries();
  for (const auto &query : queries) {
    test_pq_fast(query.first, query.second);
  }
}

TEST(CryptoPQ, generated_server) {
  auto queries = gen_pq_queries(1);
  for (const auto &query : queries) {
    test_pq_fast(query.first, query.second);
  }
}

#if TD_HAVE_OPENSSL
TEST(CryptoPQ, generated_slow) {
  auto queries = gen_pq_queries();
  for (const auto &query : queries) {
    test_pq_slow(query.first, query.second);
  }
}
#endif
