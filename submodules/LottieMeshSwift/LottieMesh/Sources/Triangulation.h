#ifndef Triangulation_h
#define Triangulation_h

#include <vector>

#include <LottieMesh/Point.h>

namespace MeshGenerator {

std::vector<uint32_t> triangulatePolygon(std::vector<Point> const &points, std::vector<int> &indices, std::vector<std::vector<int>> const &holeIndices);

}

#endif /* Triangulation_h */
