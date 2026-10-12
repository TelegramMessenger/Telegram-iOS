//
//   Copyright 2018 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//

#include "../far/bilinearPatchBuilder.h"

#include <cassert>
#include <cstdio>

namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

using Vtr::internal::Level;
using Vtr::internal::FVarLevel;
using Vtr::internal::Refinement;

namespace Far {

namespace {

    //
    //  The patch type associated with each basis for Bilinear -- quickly indexed
    //  from an array.  The patch type here is essentially the quad form of each
    //  basis.
    //
    PatchDescriptor::Type patchTypeFromBasisArray[] = {
            PatchDescriptor::NON_PATCH,      // undefined
            PatchDescriptor::QUADS,          // regular
            PatchDescriptor::GREGORY_BASIS,  // Gregory
            PatchDescriptor::QUADS,          // linear
            PatchDescriptor::NON_PATCH };    // Bezier -- for future use
};

BilinearPatchBuilder::BilinearPatchBuilder(
    TopologyRefiner const& refiner, Options const& options) :
        PatchBuilder(refiner, options) {

    _regPatchType   = patchTypeFromBasisArray[_options.regBasisType];
    _irregPatchType = (_options.irregBasisType == BASIS_UNSPECIFIED)
                    ? _regPatchType
                    : patchTypeFromBasisArray[_options.irregBasisType];

    _nativePatchType = PatchDescriptor::QUADS;
    _linearPatchType = PatchDescriptor::QUADS;
}

BilinearPatchBuilder::~BilinearPatchBuilder() {
}

PatchDescriptor::Type
BilinearPatchBuilder::patchTypeFromBasis(BasisType basis) const {

    return patchTypeFromBasisArray[(int)basis];
}

template <typename REAL>
int
BilinearPatchBuilder::convertSourcePatch(SourcePatch const &   sourcePatch,
                                         PatchDescriptor::Type patchType,
                                         SparseMatrix<REAL> &  matrix) const {

    assert("Conversion from Bilinear patches to other bases not yet supported" == 0);

    //  For suppressing warnings until implemented...
    if (sourcePatch.GetNumSourcePoints() == 0) return -1;
    if (patchType == PatchDescriptor::NON_PATCH) return -1;
    if (matrix.GetNumRows() <= 0) return -1;
    return -1;
}

int
BilinearPatchBuilder::convertToPatchType(SourcePatch const &   sourcePatch,
                                         PatchDescriptor::Type patchType,
                                         SparseMatrix<float> & matrix) const {
    return convertSourcePatch(sourcePatch, patchType, matrix);
}
int
BilinearPatchBuilder::convertToPatchType(SourcePatch const &    sourcePatch,
                                         PatchDescriptor::Type  patchType,
                                         SparseMatrix<double> & matrix) const {
    return convertSourcePatch(sourcePatch, patchType, matrix);
}

} // end namespace Far

} // end namespace OPENSUBDIV_VERSION
} // end namespace OpenSubdiv
