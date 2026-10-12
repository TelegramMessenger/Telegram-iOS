//
//   Copyright 2014 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//
#include "../vtr/sparseSelector.h"
#include "../vtr/level.h"
#include "../vtr/refinement.h"

#include <cassert>


namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Vtr {
namespace internal {

//
//  Component selection methods:
//      Marking of selection is retained in the SparseTags of the Refinement.  The
//  selection simply marks the parent components -- not any child components that may
//  be derived from them.  That is done later when we need to additionally identify
//  all of the "neighboring" child components that must exist at the next subdivision
//  level in order to fully define supported further refinement of selected components.
//
inline void
SparseSelector::initializeSelection() {

    if (!_selected) {
        _refine->initializeSparseSelectionTags();
        _selected = true;
    }
}

void
SparseSelector::selectVertex(Index parentVertex) {

    initializeSelection();

    //  Don't bother to test-and-set here, just set
    markVertexSelected(parentVertex);
}

void
SparseSelector::selectEdge(Index parentEdge) {

    initializeSelection();

    if (!wasEdgeSelected(parentEdge)) {
        markEdgeSelected(parentEdge);

        //  Mark the two end vertices:
        ConstIndexArray eVerts = _refine->parent().getEdgeVertices(parentEdge);
        markVertexSelected(eVerts[0]);
        markVertexSelected(eVerts[1]);
    }
}

void
SparseSelector::selectFace(Index parentFace) {

    initializeSelection();

    if (!wasFaceSelected(parentFace)) {
        markFaceSelected(parentFace);

        //  Mark the face's incident verts and edges as selected:
        ConstIndexArray fEdges = _refine->parent().getFaceEdges(parentFace),
                        fVerts = _refine->parent().getFaceVertices(parentFace);

        for (int i = 0; i < fVerts.size(); ++i) {
            markEdgeSelected(fEdges[i]);
            markVertexSelected(fVerts[i]);
        }
    }
}

} // end namespace internal
} // end namespace Vtr

} // end namespace OPENSUBDIV_VERSION
} // end namespace OpenSubdiv
