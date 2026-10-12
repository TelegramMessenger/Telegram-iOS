//
//   Copyright 2014 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//
#ifndef OPENSUBDIV3_VTR_COMPONENT_INTERFACES_H
#define OPENSUBDIV3_VTR_COMPONENT_INTERFACES_H

#include "../version.h"

#include "../sdc/types.h"
#include "../sdc/crease.h"
#include "../vtr/types.h"
#include "../vtr/stackBuffer.h"

#include <vector>


namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Vtr {
namespace internal {

//
//  Simple classes supporting the interfaces required of generic topological
//  types in the Scheme mask queries, e.g. <typename FACE, VERTEX, etc.>
//
//  These are not used with Vtr but arguably belong with it as the details to
//  write these efficiently depends very much on intimate details of Vtr's
//  implementation, e.g. the use of tag bits, subdivision Rules, etc.
//


//
//  For <typename FACE>, which provides information in the neighborhood of a face:
//
class FaceInterface {
public:
    FaceInterface() { }
    FaceInterface(int vertCount) : _vertCount(vertCount) { }
    ~FaceInterface() { }

public:  //  Generic interface expected of <typename FACE>:
    int GetNumVertices() const { return _vertCount; }

private:
    int _vertCount;
};


//
//  For <typename EDGE>, which provides information in the neighborhood of an edge:
//
class EdgeInterface {
public:
    EdgeInterface() { }
    EdgeInterface(Level const& level) : _level(&level) { }
    ~EdgeInterface() { }

    void SetIndex(int edgeIndex) { _eIndex = edgeIndex; }

public:  //  Generic interface expected of <typename EDGE>:
    int   GetNumFaces() const { return _level->getEdgeFaces(_eIndex).size(); }
    float GetSharpness() const { return _level->getEdgeSharpness(_eIndex); }

    void GetChildSharpnesses(Sdc::Crease const&, float s[2]) const {
        //  Need to use the Refinement here to identify the two child edges:
        s[0] = s[1] = GetSharpness() - 1.0f;
    }

    void GetNumVerticesPerFace(int vertsPerFace[]) const {
        ConstIndexArray eFaces = _level->getEdgeFaces(_eIndex);
        for (int i = 0; i < eFaces.size(); ++i) {
            vertsPerFace[i] = _level->getFaceVertices(eFaces[i]).size();
        }
    }

private:
    const Level* _level;

    int _eIndex;
};


//
//  For <typename VERTEX>, which provides information in the neighborhood of a vertex:
//
class VertexInterface {
public:
    VertexInterface() { }
    VertexInterface(Level const& parent, Level const& child) : _parent(&parent), _child(&child) { }
    ~VertexInterface() { }

    void SetIndex(int parentIndex, int childIndex) {
        _pIndex = parentIndex;
        _cIndex = childIndex;
        _eCount = _parent->getVertexEdges(_pIndex).size();
        _fCount = _parent->getVertexFaces(_pIndex).size();
    }

public:  //  Generic interface expected of <typename VERT>:
    int GetNumEdges() const { return _eCount; }
    int GetNumFaces() const { return _fCount; }

    float  GetSharpness() const { return _parent->getVertexSharpness(_pIndex); }
    float* GetSharpnessPerEdge(float pSharpness[]) const {
        ConstIndexArray pEdges = _parent->getVertexEdges(_pIndex);
        for (int i = 0; i < _eCount; ++i) {
            pSharpness[i] = _parent->getEdgeSharpness(pEdges[i]);
        }
        return pSharpness;
    }

    float  GetChildSharpness(Sdc::Crease const&) const { return _child->getVertexSharpness(_cIndex); }
    float* GetChildSharpnessPerEdge(Sdc::Crease const& crease, float cSharpness[]) const {
        internal::StackBuffer<float,16> pSharpness(_eCount);
        GetSharpnessPerEdge(pSharpness);
        crease.SubdivideEdgeSharpnessesAroundVertex(_eCount, pSharpness, cSharpness);
        return cSharpness;
    }

private:
    const Level* _parent;
    const Level* _child;

    int _pIndex;
    int _cIndex;
    int _eCount;
    int _fCount;
};

} // end namespace internal
} // end namespace Vtr

} // end namespace OPENSUBDIV_VERSION
using namespace OPENSUBDIV_VERSION;
} // end namespace OpenSubdiv

#endif /* OPENSUBDIV3_VTR_COMPONENT_INTERFACES_H */
