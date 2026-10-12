//
//   Copyright 2014 DreamWorks Animation LLC.
//
//   Licensed under the terms set forth in the LICENSE.txt file available at
//   https://opensubdiv.org/license.
//

#ifndef OPENSUBDIV3_FAR_TYPES_H
#define OPENSUBDIV3_FAR_TYPES_H

#include "../version.h"

#include "../vtr/types.h"

namespace OpenSubdiv {
namespace OPENSUBDIV_VERSION {

namespace Far {

//
//  Typedefs for indices that are inherited from the Vtr level -- eventually
//  these primitive Vtr types may be declared at a lower, more public level.
//
typedef Vtr::Index       Index;
typedef Vtr::LocalIndex  LocalIndex;

typedef Vtr::IndexArray       IndexArray;
typedef Vtr::LocalIndexArray  LocalIndexArray;

typedef Vtr::ConstIndexArray       ConstIndexArray;
typedef Vtr::ConstLocalIndexArray  ConstLocalIndexArray;

inline bool IndexIsValid(Index index) { return Vtr::IndexIsValid(index); }

static const Index INDEX_INVALID = Vtr::INDEX_INVALID;
static const int   VALENCE_LIMIT = Vtr::VALENCE_LIMIT;

} // end namespace Far

} // end namespace OPENSUBDIV_VERSION
using namespace OPENSUBDIV_VERSION;
} // end namespace OpenSubdiv

#endif /* OPENSUBDIV3_FAR_TYPES_H */
