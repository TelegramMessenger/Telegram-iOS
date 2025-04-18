/*
 * Loki Random Number Generator
 * Copyright (c) 2017 Youssef Victor All rights reserved.
 *
 *      Function                        Result
 *      ------------------------------------------------------------------
 *
 *      TausStep                        Combined Tausworthe Generator or
 *                                      Linear Feedback Shift Register (LFSR)
 *                                      random number generator. This is a
 *                                      helper method for rng, which uses
 *                                      a hybrid approach combining LFSR with
 *                                      a Linear Congruential Generator (LCG)
 *                                      in order to produce random numbers with
 *                                      periods of well over 2^121
 *
 *      rand                            A pseudo-random number based on the
 *                                      method outlined in "Efficient
 *                                      pseudo-random number generation
 *                                      for monte-carlo simulations using
 *                                      graphic processors" by Siddhant
 *                                      Mohanty et al 2012.
 *
 */

#include <metal_stdlib>
using namespace metal;

#ifndef LOKI
#define LOKI


class Loki {
private:
    thread float seed;
    unsigned TausStep(const unsigned z, const int s1, const int s2, const int s3, const unsigned M);

public:
    thread Loki(const unsigned seed1, const unsigned seed2 = 1, const unsigned seed3 = 1);

    thread float rand();
};

#endif

