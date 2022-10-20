#include "Triangulation.h"

#include <map>
#include <array>

#include "earcut.hpp"

namespace MeshGenerator {

std::vector<uint32_t> triangulatePolygon(std::vector<Point> const &points, std::vector<int> &indices, std::vector<std::vector<int>> const &holeIndices) {
    // The index type. Defaults to uint32_t, but you can also pass uint16_t if you know that your
    // data won't have more than 65536 vertices.
    using N = uint32_t;

    // Create array
    using EarPoint = std::array<float, 2>;
    std::vector<std::vector<EarPoint>> polygon;

    std::map<int, int> facePointMapping;
    int nextFacePointIndex = 0;

    std::vector<EarPoint> facePoints;
    for (auto index : indices) {
        facePointMapping[nextFacePointIndex] = index;
        nextFacePointIndex++;

        facePoints.push_back({ points[index].x, points[index].y });
    }
    polygon.push_back(std::move(facePoints));

    for (const auto &list : holeIndices) {
        std::vector<EarPoint> holePoints;
        for (auto index : list) {
            facePointMapping[nextFacePointIndex] = index;
            nextFacePointIndex++;

            holePoints.push_back({ points[index].x, points[index].y });
        }
        polygon.push_back(std::move(holePoints));
    }

    std::vector<N> triangleIndices = mapbox::earcut<N>(polygon);

    std::vector<uint32_t> mappedIndices;
    for (auto index : triangleIndices) {
        mappedIndices.push_back(facePointMapping[index]);
    }
    return mappedIndices;
}

}
