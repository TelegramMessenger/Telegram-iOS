//
//   Copyright 2014 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//
#ifndef OPENSUBDIV3_SDC_TYPES_H
#define OPENSUBDIV3_SDC_TYPES_H

#include "../version.h"

namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Sdc {

///
///  \brief Enumerated type for all subdivision schemes supported by OpenSubdiv
///
enum SchemeType {
    SCHEME_BILINEAR,
    SCHEME_CATMARK,
    SCHEME_LOOP
};


///
///  \brief Enumerated type for all face splitting schemes
///
enum Split {
    SPLIT_TO_QUADS,  ///< Used by Catmark and Bilinear
    SPLIT_TO_TRIS,   ///< Used by Loop
    SPLIT_HYBRID     ///< Not currently used (potential future extension)
};

///
///  \brief Traits associated with the types of all subdivision schemes -- parameterized by
///  the scheme type.  All traits are also defined in the scheme itself.
///
struct SchemeTypeTraits {

    static SchemeType GetType(SchemeType schemeType) { return schemeType; }

    static Split GetTopologicalSplitType(SchemeType schemeType);
    static int   GetRegularFaceSize(SchemeType schemeType);
    static int   GetRegularVertexValence(SchemeType schemeType);
    static int   GetLocalNeighborhoodSize(SchemeType schemeType);

    static char const* GetName(SchemeType schemeType);
};


} // end namespace sdc

} // end namespace OPENSUBDIV_VERSION
using namespace OPENSUBDIV_VERSION;
} // end namespace OpenSubdiv

#endif /* OPENSUBDIV3_SDC_TYPES_H */
