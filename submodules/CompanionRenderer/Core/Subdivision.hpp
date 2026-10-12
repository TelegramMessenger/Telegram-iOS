#pragma once
#include "GiftModel.hpp"

namespace gift {
struct SubdivisionCage {
    int level=1;
    std::vector<int> faceSizes,faceIndices,uvIndices;
    std::vector<Vec2> uvValues;
};
// Build the immutable mesh once, then release temporary surface patches.
void applySubdivision(Primitive&,const SubdivisionCage&);
// Preserve control positions/morphs; expand face-varying UV corners and
// triangulate only for drawing. No surface refinement or patch preparation.
void useControlCage(Primitive&,const SubdivisionCage&);
}
