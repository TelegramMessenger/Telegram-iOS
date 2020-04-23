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

    Copyright 2020 Telegram Systems LLP
*/
#include <iostream>
#include "td/utils/Random.h"
#include "td/utils/misc.h"
#include "block/block.h"
#include <getopt.h>

const int MAX_N = 1000, MAX_K = 100, DEFAULT_K = 7;

int verbosity;
int N, K = DEFAULT_K;
long long iterations = 1000000;

td::uint64 TWL, WL[MAX_N];
double W[MAX_N], CW[MAX_N + 1], RW[MAX_N], R0;
int A[MAX_N], C[MAX_N];
long long TC;

void gen_vset() {
  static std::pair<double, double> H[MAX_N];
  double total_wt = 1.;
  int hc = 0;
  for (int i = 0; i < K; i++) {
    CHECK(total_wt > 0);
    double inv_wt = 1. / total_wt;
    R0 += inv_wt;  // advanced mtcarlo stats
    for (int j = 0; j < i; j++) {
      RW[A[j]] -= inv_wt;  // advanced mtcarlo stats
    }
    // double p = drand48() * total_wt;
    double p = (double)td::Random::fast_uint64() * total_wt / (1. * (1LL << 32) * (1LL << 32));
    for (int h = 0; h < hc; h++) {
      if (p < H[h].first) {
        break;
      }
      p += H[h].second;
    }
    int a = -1, b = N, c;
    while (b - a > 1) {
      c = ((a + b) >> 1);
      if (CW[c] <= p) {
        a = c;
      } else {
        b = c;
      }
    }
    CHECK(a >= 0 && a < N);
    CHECK(total_wt >= W[a]);
    total_wt -= W[a];
    double x = CW[a];
    c = hc++;
    while (c > 0 && H[c - 1].first > x) {
      H[c] = H[c - 1];
      --c;
    }
    H[c].first = x;
    H[c].second = W[a];
    A[i] = a;
    C[a]++;  // simple mtcarlo stats
    // std::cout << a << ' ';
  }
  // std::cout << std::endl;
  ++TC;  // simple mtcarlo stats
}

void mt_carlo() {
  for (int i = 0; i < N; i++) {
    C[i] = 0;
    RW[i] = 0.;
  }
  TC = 0;
  R0 = 0.;
  std::cout << "running " << iterations << " steps of Monte Carlo simulation\n";
  for (long long it = 0; it < iterations; ++it) {
    gen_vset();
  }
  for (int i = 0; i < N; i++) {
    RW[i] = W[i] * (RW[i] + R0) / (double)iterations;
  }
}

double B[MAX_N];

void compute_bad_approx() {
  static double S[MAX_K + 1];
  S[0] = 1.;
  for (int i = 1; i <= K; i++) {
    S[i] = 0.;
  }
  for (int i = 0; i < N; i++) {
    double p = W[i];
    for (int j = K; j > 0; j--) {
      S[j] += p * S[j - 1];
    }
  }
  double Sk = S[K];
  for (int i = 0; i < N; i++) {
    double t = 1., p = W[i];
    for (int j = 1; j <= K; j++) {
      t = S[j] - p * t;
    }
    B[i] = 1. - t / Sk;
  }
}

void usage() {
  std::cout
      << "usage: test-weight-distr [-k<shard-val-num>][-m<iterations>][-s<rand-seed>]\nReads the set of validator "
         "weights from stdin and emulates validator shard distribution load\n\t-k <shard-val-num>\tSets the number of "
         "validators generating each shard\n\t-m <iterations>\tMonte Carlo simulation steps\n";
  std::exit(2);
}

int main(int argc, char* const argv[]) {
  int i;
  int new_verbosity_level = VERBOSITY_NAME(INFO);
  // long seed = 0;
  while ((i = getopt(argc, argv, "hs:k:m:v:")) != -1) {
    switch (i) {
      case 'k':
        K = td::to_integer<int>(td::Slice(optarg));
        CHECK(K > 0 && K <= 100);
        break;
      case 'm':
        iterations = td::to_integer<long long>(td::Slice(optarg));
        CHECK(iterations > 0);
        break;
      case 's':
        // seed = td::to_integer<long>(td::Slice(optarg));
        // srand48(seed);
        break;
      case 'v':
        new_verbosity_level = VERBOSITY_NAME(FATAL) + (verbosity = td::to_integer<int>(td::Slice(optarg)));
        break;
      case 'h':
        usage();
        std::exit(2);
      default:
        usage();
        std::exit(2);
    }
  }
  SET_VERBOSITY_LEVEL(new_verbosity_level);
  for (N = 0; N < MAX_N && (std::cin >> WL[N]); N++) {
    CHECK(WL[N] > 0);
    TWL += WL[N];
  }
  CHECK(std::cin.eof());
  CHECK(N > 0 && TWL > 0 && N <= MAX_N);
  K = std::min(K, N);
  CHECK(K > 0 && K <= MAX_K);
  double acc = 0.;
  for (i = 0; i < N; i++) {
    CW[i] = acc;
    acc += W[i] = (double)WL[i] / (double)TWL;
    std::cout << "#" << i << ":\t" << W[i] << std::endl;
  }
  compute_bad_approx();
  mt_carlo();
  std::cout << "result of Monte Carlo simulation (" << iterations << " iterations):" << std::endl;
  std::cout << "idx\tweight\tmtcarlo1\tmtcarlo2\tapprox\n";
  for (i = 0; i < N; i++) {
    std::cout << "#" << i << ":\t" << W[i] << '\t' << (double)C[i] / (double)iterations << '\t' << RW[i] << '\t' << B[i]
              << std::endl;
  }
  // same computation, but using a MtCarloComputeShare object
  block::MtCarloComputeShare MT(K, N, W, iterations);
  std::cout << "-----------------------\n";
  for (i = 0; i < N; i++) {
    std::cout << '#' << i << ":\t" << MT.weight(i) << '\t' << MT.share(i) << std::endl;
  }
  return 0;
}
