//
//   Copyright 2013 Pixar
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//

#ifndef OPENSUBDIV3_FAR_PATCH_BASIS_H
#define OPENSUBDIV3_FAR_PATCH_BASIS_H

#include "../version.h"

#include "../far/patchParam.h"

namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Far {
namespace internal {

//
// XXXX barfowl:  These functions are being kept internal while more complete
// underlying support for all patch types is being worked out.  The set of
// bases supported here is actually larger than PatchDescriptor::Type -- with
// Bezier available for internal use.  A new and more complete set of types
// is warranted (without the non-patch types associated with PatchDescriptor)
// along with an interface to query properties associated with them.
//
// Note that with the high-level functions here that operate on all patch
// types, it is not strictly necessary to expose the low-level methods in
// currant usage.
//

//
// Low-level basis evaluation (normalized, unscaled) for quad patch types:
//
template <typename REAL>
int EvalBasisLinear(REAL s, REAL t,
    REAL wP[4], REAL wDs[4] = 0, REAL wDt[4] = 0, REAL wDss[4] = 0, REAL wDst[4] = 0, REAL wDtt[4] = 0);

template <typename REAL>
int EvalBasisBezier(REAL s, REAL t,
    REAL wP[16], REAL wDs[16] = 0, REAL wDt[16] = 0, REAL wDss[16] = 0, REAL wDst[16] = 0, REAL wDtt[16] = 0);

template <typename REAL>
int EvalBasisBSpline(REAL s, REAL t,
    REAL wP[16], REAL wDs[16] = 0, REAL wDt[16] = 0, REAL wDss[16] = 0, REAL wDst[16] = 0, REAL wDtt[16] = 0);

template <typename REAL>
int EvalBasisGregory(REAL s, REAL t,
    REAL wP[20], REAL wDs[20] = 0, REAL wDt[20] = 0, REAL wDss[20] = 0, REAL wDst[20] = 0, REAL wDtt[20] = 0);

//
// Low-level basis evaluation (normalized, unscaled) for triangular patch types:
//
template <typename REAL>
int EvalBasisLinearTri(REAL s, REAL t,
    REAL wP[3], REAL wDs[3] = 0, REAL wDt[3] = 0, REAL wDss[3] = 0, REAL wDst[3] = 0, REAL wDtt[3] = 0);

template <typename REAL>
int EvalBasisBezierTri(REAL s, REAL t,
    REAL wP[15], REAL wDs[15] = 0, REAL wDt[15] = 0, REAL wDss[15] = 0, REAL wDst[15] = 0, REAL wDtt[15] = 0);

template <typename REAL>
int EvalBasisBoxSplineTri(REAL s, REAL t,
    REAL wP[12], REAL wDs[12] = 0, REAL wDt[12] = 0, REAL wDss[12] = 0, REAL wDst[12] = 0, REAL wDtt[12] = 0);

template <typename REAL>
int EvalBasisGregoryTri(REAL s, REAL t,
    REAL wP[18], REAL wDs[18] = 0, REAL wDt[18] = 0, REAL wDss[18] = 0, REAL wDst[18] = 0, REAL wDtt[18] = 0);


//
// High-level basis evaluation for all types using PatchParam:
//
template <typename REAL>
int EvaluatePatchBasisNormalized(int patchType, PatchParam const & param, REAL s, REAL t,
    REAL wP[], REAL wDs[] = 0, REAL wDt[] = 0, REAL wDss[] = 0, REAL wDst[] = 0, REAL wDtt[] = 0);

template <typename REAL>
int EvaluatePatchBasis(int patchType, PatchParam const & param, REAL s, REAL t,
    REAL wP[], REAL wDs[] = 0, REAL wDt[] = 0, REAL wDss[] = 0, REAL wDst[] = 0, REAL wDtt[] = 0);


} // end namespace internal
} // end namespace Far

} // end namespace OPENSUBDIV_VERSION
using namespace OPENSUBDIV_VERSION;

} // end namespace OpenSubdiv

#endif /* OPENSUBDIV3_FAR_PATCH_BASIS_H */
