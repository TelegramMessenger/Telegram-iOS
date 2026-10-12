//
//   Copyright 2014 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//
#ifndef OPENSUBDIV3_VTR_QUAD_REFINEMENT_H
#define OPENSUBDIV3_VTR_QUAD_REFINEMENT_H

#include "../version.h"

#include "../vtr/refinement.h"


namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Vtr {
namespace internal {

//
//  QuadRefinement:
//      A QuadRefinement is a subclass of Refinement that splits all faces into quads.
//  It provides the configuration of parent-to-child components and the population of
//  all required topological relations in order to complete a valid Refinement.
//
class QuadRefinement : public Refinement {

public:
    QuadRefinement(Level const & parent, Level & child, Sdc::Options const & options);
    ~QuadRefinement();

protected:
    //
    //  Virtual methods to complete the configuration of the parent-to-child mapping:
    //
    virtual void allocateParentChildIndices();

    virtual void markSparseFaceChildren();

    //
    //  Virtual methods to populate the six topological relations:
    //
    virtual void populateFaceVertexRelation();
    virtual void populateFaceEdgeRelation();
    virtual void populateEdgeVertexRelation();
    virtual void populateEdgeFaceRelation();
    virtual void populateVertexFaceRelation();
    virtual void populateVertexEdgeRelation();

    //
    //  Internal helper methods for populating the topology:
    //
    void populateFaceVertexCountsAndOffsets();
    void populateFaceVerticesFromParentFaces();

    void populateFaceEdgesFromParentFaces();

    void populateEdgeVerticesFromParentFaces();
    void populateEdgeVerticesFromParentEdges();

    void populateEdgeFacesFromParentFaces();
    void populateEdgeFacesFromParentEdges();

    void populateVertexFacesFromParentFaces();
    void populateVertexFacesFromParentEdges();
    void populateVertexFacesFromParentVertices();

    void populateVertexEdgesFromParentFaces();
    void populateVertexEdgesFromParentEdges();
    void populateVertexEdgesFromParentVertices();

private:
    //
    //  Data members -- currently none
    //
};

} // end namespace internal
} // end namespace Vtr

} // end namespace OPENSUBDIV_VERSION
using namespace OPENSUBDIV_VERSION;
} // end namespace OpenSubdiv

#endif /* OPENSUBDIV3_VTR_REFINEMENT_H */
