//
//   Copyright 2014 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//
#include "../sdc/types.h"

#include "../sdc/bilinearScheme.h"
#include "../sdc/catmarkScheme.h"
#include "../sdc/loopScheme.h"

namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Sdc {

struct TraitsEntry {
    char const * _name;

    Split _splitType;
    int   _regularFaceSize;
    int   _regularVertexValence;
    int   _localNeighborhood;
};

static const TraitsEntry staticTraitsTable[3] = {
    { "bilinear", Scheme<SCHEME_BILINEAR>::GetTopologicalSplitType(),
                  Scheme<SCHEME_BILINEAR>::GetRegularFaceSize(),
                  Scheme<SCHEME_BILINEAR>::GetRegularVertexValence(),
                  Scheme<SCHEME_BILINEAR>::GetLocalNeighborhoodSize() },
    { "catmark",  Scheme<SCHEME_CATMARK>::GetTopologicalSplitType(),
                  Scheme<SCHEME_CATMARK>::GetRegularFaceSize(),
                  Scheme<SCHEME_CATMARK>::GetRegularVertexValence(),
                  Scheme<SCHEME_CATMARK>::GetLocalNeighborhoodSize() },
    { "loop",     Scheme<SCHEME_LOOP>::GetTopologicalSplitType(),
                  Scheme<SCHEME_LOOP>::GetRegularFaceSize(),
                  Scheme<SCHEME_LOOP>::GetRegularVertexValence(),
                  Scheme<SCHEME_LOOP>::GetLocalNeighborhoodSize() }
};

//
//  Static methods for SchemeTypeTraits:
//
char const*
SchemeTypeTraits::GetName(SchemeType schemeType) {

    return staticTraitsTable[schemeType]._name;
}

Split
SchemeTypeTraits::GetTopologicalSplitType(SchemeType schemeType) {

    return staticTraitsTable[schemeType]._splitType;
}

int
SchemeTypeTraits::GetRegularFaceSize(SchemeType schemeType) {

    return staticTraitsTable[schemeType]._regularFaceSize;
}

int
SchemeTypeTraits::GetRegularVertexValence(SchemeType schemeType) {

    return staticTraitsTable[schemeType]._regularVertexValence;
}

int
SchemeTypeTraits::GetLocalNeighborhoodSize(SchemeType schemeType) {

    return staticTraitsTable[schemeType]._localNeighborhood;
}

} // end namespace sdc

} // end namespace OPENSUBDIV_VERSION
} // end namespace OpenSubdiv
