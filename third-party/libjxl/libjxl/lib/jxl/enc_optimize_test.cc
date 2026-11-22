// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_optimize.h"

#include <stdio.h>

#include "lib/jxl/testing.h"

namespace jxl {
namespace optimize {
namespace {

// The maximum number of iterations for the test.
static const size_t kMaxTestIter = 100000;

// F(w) = (w - w_min)^2.
struct SimpleQuadraticFunction {
  typedef Array<double, 2> ArrayType;
  explicit SimpleQuadraticFunction(const ArrayType& w0) : w_min(w0) {}

  double Compute(const ArrayType& w, ArrayType* df) const {
    ArrayType dw = w - w_min;
    *df = -2.0 * dw;
    return dw * dw;
  }

  ArrayType w_min;
};

// F(alpha, beta, gamma| x,y) = \sum_i(y_i - (alpha x_i ^ gamma + beta))^2.
struct PowerFunction {
  explicit PowerFunction(const std::vector<double>& x0,
                         const std::vector<double>& y0)
      : x(x0), y(y0) {}

  typedef Array<double, 3> ArrayType;
  double Compute(const ArrayType& w, ArrayType* df) const {
    double loss_function = 0;
    (*df)[0] = 0;
    (*df)[1] = 0;
    (*df)[2] = 0;
    for (size_t ind = 0; ind < y.size(); ++ind) {
      if (x[ind] != 0) {
        double l_f = y[ind] - (w[0] * pow(x[ind], w[1]) + w[2]);
        (*df)[0] += 2.0 * l_f * pow(x[ind], w[1]);
        (*df)[1] += 2.0 * l_f * w[0] * pow(x[ind], w[1]) * log(x[ind]);
        (*df)[2] += 2.0 * l_f * 1;
        loss_function += l_f * l_f;
      }
    }
    return loss_function;
  }

  std::vector<double> x;
  std::vector<double> y;
};

TEST(OptimizeTest, SimpleQuadraticFunction) {
  SimpleQuadraticFunction::ArrayType w_min;
  w_min[0] = 1.0;
  w_min[1] = 2.0;
  SimpleQuadraticFunction f(w_min);
  SimpleQuadraticFunction::ArrayType w(0.);
  static const double kPrecision = 1e-8;
  w = optimize::OptimizeWithScaledConjugateGradientMethod(f, w, kPrecision,
                                                          kMaxTestIter);
  EXPECT_NEAR(w[0], 1.0, kPrecision);
  EXPECT_NEAR(w[1], 2.0, kPrecision);
}

TEST(OptimizeTest, PowerFunction) {
  std::vector<double> x(10);
  std::vector<double> y(10);
  for (int ind = 0; ind < 10; ++ind) {
    x[ind] = 1. * ind;
    y[ind] = 2. * pow(x[ind], 3) + 5.;
  }
  PowerFunction f(x, y);
  PowerFunction::ArrayType w(0.);

  static const double kPrecision = 0.01;
  w = optimize::OptimizeWithScaledConjugateGradientMethod(f, w, kPrecision,
                                                          kMaxTestIter);
  EXPECT_NEAR(w[0], 2.0, kPrecision);
  EXPECT_NEAR(w[1], 3.0, kPrecision);
  EXPECT_NEAR(w[2], 5.0, kPrecision);
}

TEST(OptimizeTest, SimplexOptTest) {
  auto f = [](const std::vector<double>& x) -> double {
    double t1 = x[0] - 1.0;
    double t2 = x[1] + 1.5;
    return 2.0 + t1 * t1 + t2 * t2;
  };
  auto opt = RunSimplex(2, 0.01, 100, f);
  EXPECT_EQ(opt.size(), 3u);

  static const double kPrecision = 0.01;
  EXPECT_NEAR(opt[0], 2.0, kPrecision);
  EXPECT_NEAR(opt[1], 1.0, kPrecision);
  EXPECT_NEAR(opt[2], -1.5, kPrecision);
}

}  // namespace
}  // namespace optimize
}  // namespace jxl
