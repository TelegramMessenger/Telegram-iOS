// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_optimize.h"

#include <algorithm>

#include "lib/jxl/base/status.h"

namespace jxl {

namespace optimize {

namespace {

// simplex vector must be sorted by first element of its elements
std::vector<double> Midpoint(const std::vector<std::vector<double>>& simplex) {
  JXL_CHECK(!simplex.empty());
  JXL_CHECK(simplex.size() == simplex[0].size());
  int dim = simplex.size() - 1;
  std::vector<double> result(dim + 1, 0);
  for (int i = 0; i < dim; i++) {
    for (int k = 0; k < dim; k++) {
      result[i + 1] += simplex[k][i + 1];
    }
    result[i + 1] /= dim;
  }
  return result;
}

// first element ignored
std::vector<double> Subtract(const std::vector<double>& a,
                             const std::vector<double>& b) {
  JXL_CHECK(a.size() == b.size());
  std::vector<double> result(a.size());
  result[0] = 0;
  for (size_t i = 1; i < result.size(); i++) {
    result[i] = a[i] - b[i];
  }
  return result;
}

// first element ignored
std::vector<double> Add(const std::vector<double>& a,
                        const std::vector<double>& b) {
  JXL_CHECK(a.size() == b.size());
  std::vector<double> result(a.size());
  result[0] = 0;
  for (size_t i = 1; i < result.size(); i++) {
    result[i] = a[i] + b[i];
  }
  return result;
}

// first element ignored
std::vector<double> Average(const std::vector<double>& a,
                            const std::vector<double>& b) {
  JXL_CHECK(a.size() == b.size());
  std::vector<double> result(a.size());
  result[0] = 0;
  for (size_t i = 1; i < result.size(); i++) {
    result[i] = 0.5 * (a[i] + b[i]);
  }
  return result;
}

// vec: [0] will contain the objective function, [1:] will
//   contain the vector position for the objective function.
// fun: the function evaluates the value.
void Eval(std::vector<double>* vec,
          const std::function<double(const std::vector<double>&)>& fun) {
  std::vector<double> args(vec->begin() + 1, vec->end());
  (*vec)[0] = fun(args);
}

void Sort(std::vector<std::vector<double>>* simplex) {
  std::sort(simplex->begin(), simplex->end());
}

// Main iteration step of Nelder-Mead like optimization.
void Reflect(std::vector<std::vector<double>>* simplex,
             const std::function<double(const std::vector<double>&)>& fun) {
  Sort(simplex);
  const std::vector<double>& last = simplex->back();
  std::vector<double> mid = Midpoint(*simplex);
  std::vector<double> diff = Subtract(mid, last);
  std::vector<double> mirrored = Add(mid, diff);
  Eval(&mirrored, fun);
  if (mirrored[0] > (*simplex)[simplex->size() - 2][0]) {
    // Still the worst, shrink towards the best.
    std::vector<double> shrinking = Average(simplex->back(), (*simplex)[0]);
    Eval(&shrinking, fun);
    simplex->back() = shrinking;
  } else if (mirrored[0] < (*simplex)[0][0]) {
    // new best
    std::vector<double> even_further = Add(mirrored, diff);
    Eval(&even_further, fun);
    if (even_further[0] < mirrored[0]) {
      mirrored = even_further;
    }
    simplex->back() = mirrored;
  } else {
    // not a best, not a worst point
    simplex->back() = mirrored;
  }
}

// Initialize the simplex at origin.
std::vector<std::vector<double>> InitialSimplex(
    int dim, double amount, const std::vector<double>& init,
    const std::function<double(const std::vector<double>&)>& fun) {
  std::vector<double> best(1 + dim, 0);
  std::copy(init.begin(), init.end(), best.begin() + 1);
  Eval(&best, fun);
  std::vector<std::vector<double>> result{best};
  for (int i = 0; i < dim; i++) {
    best = result[0];
    best[i + 1] += amount;
    Eval(&best, fun);
    result.push_back(best);
    Sort(&result);
  }
  return result;
}

// For comparing the same with the python tool
/*void RunSimplexExternal(
    int dim, double amount, int max_iterations,
    const std::function<double((const vector<double>&))>& fun) {
  vector<double> vars;
  for (int i = 0; i < dim; i++) {
    vars.push_back(atof(getenv(StrCat("VAR", i).c_str())));
  }
  double result = fun(vars);
  std::cout << "Result=" << result;
}*/

}  // namespace

std::vector<double> RunSimplex(
    int dim, double amount, int max_iterations, const std::vector<double>& init,
    const std::function<double(const std::vector<double>&)>& fun) {
  std::vector<std::vector<double>> simplex =
      InitialSimplex(dim, amount, init, fun);
  for (int i = 0; i < max_iterations; i++) {
    Sort(&simplex);
    Reflect(&simplex, fun);
  }
  return simplex[0];
}

std::vector<double> RunSimplex(
    int dim, double amount, int max_iterations,
    const std::function<double(const std::vector<double>&)>& fun) {
  std::vector<double> init(dim, 0.0);
  return RunSimplex(dim, amount, max_iterations, init, fun);
}

}  // namespace optimize

}  // namespace jxl
