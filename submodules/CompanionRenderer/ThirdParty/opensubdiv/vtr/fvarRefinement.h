//
//   Copyright 2014 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//
#ifndef OPENSUBDIV3_VTR_FVAR_REFINEMENT_H
#define OPENSUBDIV3_VTR_FVAR_REFINEMENT_H

#include "../version.h"

#include "../sdc/types.h"
#include "../sdc/crease.h"
#include "../vtr/types.h"
#include "../vtr/refinement.h"
#include "../vtr/fvarLevel.h"

#include <vector>
#include <cassert>
#include <cstring>


namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Vtr {
namespace internal {

//
//  FVarRefinement:
//      A face-varying refinement contains data to support the refinement of a
//  particular face-varying "channel".  Just as Refinement maintains a mapping
//  between the components of a parent Level and its child, the face-varying
//  analog maintains a mapping between the face-varying values of a parent
//  FVarLevel and its child.
//
//  It turns out there is little data necessary here, so the class consists
//  mainly of methods that populate the child FVarLevel.  The mapping data in
//  the refinement between Levels serves most purposes and all that is required
//  in addition is a mapping from values in the child FVarLevel to the parent.
//
class FVarRefinement {
public:
    FVarRefinement(Refinement const& refinement, FVarLevel& parent, FVarLevel& child);
    ~FVarRefinement();

    int getChildValueParentSource(Index vIndex, int sibling) const {
        return _childValueParentSource[_childFVar.getVertexValueOffset(vIndex, (LocalIndex)sibling)];
    }

    float getFractionalWeight(Index pVert, LocalIndex pSibling,
                              Index cVert, LocalIndex cSibling) const;


    //  Modifiers supporting application of the refinement:
    void applyRefinement();

    void estimateAndAllocateChildValues();
    void populateChildValues();
    void populateChildValuesFromFaceVertices();
    void populateChildValuesFromEdgeVertices();
    int  populateChildValuesForEdgeVertex(Index cVert, Index pEdge);
    void populateChildValuesFromVertexVertices();
    int  populateChildValuesForVertexVertex(Index cVert, Index pVert);
    void trimAndFinalizeChildValues();

    void propagateEdgeTags();
    void propagateValueTags();
    void propagateValueCreases();
    void reclassifySemisharpValues();

private:
    //
    //  Identify the Refinement, its Levels and assigned FVarLevels for more
    //  immediate access -- child FVarLevel is non-const as it is to be assigned:
    //
    Refinement const & _refinement;

    Level const &     _parentLevel;
    FVarLevel const & _parentFVar;

    Level const & _childLevel;
    FVarLevel &   _childFVar;

    //  When refinement is sparse, we need a mapping between siblings of a vertex
    //  value in the parent and child -- and for some child values, there will not
    //  be a parent value, in which case the source of the parent component will
    //  be stored.  So we refer to the parent "source" rather than "sibling":
    //
    std::vector<LocalIndex> _childValueParentSource;
};

} // end namespace internal
} // end namespace Vtr

} // end namespace OPENSUBDIV_VERSION
using namespace OPENSUBDIV_VERSION;
} // end namespace OpenSubdiv

#endif /* OPENSUBDIV3_VTR_FVAR_REFINEMENT_H */
