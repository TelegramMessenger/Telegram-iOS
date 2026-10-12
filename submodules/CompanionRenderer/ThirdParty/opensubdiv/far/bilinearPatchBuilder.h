//
//   Copyright 2017 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//

#ifndef OPENSUBDIV3_FAR_BILINEAR_PATCH_BUILDER_H
#define OPENSUBDIV3_FAR_BILINEAR_PATCH_BUILDER_H

#include "../version.h"

#include "../far/patchBuilder.h"


namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Far {

//
//  BilinearPatchBuilder
//
//  Declaration of PatchBuilder subclass supporting Sdc::SCHEME_BILINEAR.
//  Required virtual methods are included, along with any customizations
//  local to their implementation.
//
class BilinearPatchBuilder : public PatchBuilder {
public:
    BilinearPatchBuilder(TopologyRefiner const& refiner, Options const& options);
    virtual ~BilinearPatchBuilder();

protected:
    virtual PatchDescriptor::Type patchTypeFromBasis(BasisType basis) const;

    virtual int convertToPatchType(SourcePatch const &   sourcePatch,
                                   PatchDescriptor::Type patchType,
                                   SparseMatrix<float> & matrix) const;
    virtual int convertToPatchType(SourcePatch const &    sourcePatch,
                                   PatchDescriptor::Type  patchType,
                                   SparseMatrix<double> & matrix) const;
private:
    template <typename REAL>
    int convertSourcePatch(SourcePatch const &   sourcePatch,
                           PatchDescriptor::Type patchType,
                           SparseMatrix<REAL> &  matrix) const;
};

} // end namespace Far

} // end namespace OPENSUBDIV_VERSION
using namespace OPENSUBDIV_VERSION;

} // end namespace OpenSubdiv

#endif /* OPENSUBDIV3_FAR_BILINEAR_PATCH_BUILDER_H */
