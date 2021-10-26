#ifndef GenerateContours_h
#define GenerateContours_h

#include <memory>
#include <vector>

#include <LottieMesh/Point.h>
#include <LottieMesh/LottieMesh.h>

namespace MeshGenerator {

struct PlanarStraightLineGraph {
    struct Edge {
        int v0 = 0;
        int v1 = 0;

        explicit Edge(int v0_, int v1_) :
        v0(v0_), v1(v1_) {
        }
    };

    std::vector<Point> points;
    std::vector<Edge> edges;
};

struct Face {
    std::vector<int> vertices;
};

enum class LineJoin {
    Bevel,
    Miter,
    Round
};

enum class LineCap {
    Butt,
    Round,
    Square
};

std::vector<Path> generateStroke(std::vector<Path> const &paths, float lineWidth, float miterLimit, LineJoin lineJoin, LineCap lineCap);
std::unique_ptr<PlanarStraightLineGraph> makePlanarStraightLineGraph(std::vector<Path> const &paths);
std::vector<Face> findFaces(PlanarStraightLineGraph const &graph);
bool faceInsideFace(PlanarStraightLineGraph const &graph, Face const &face, Face const &otherFace);
float triangleArea(Point const &v1, Point const &v2, Point const &v3);
bool traceRay(std::vector<Path> const &paths, Point const &sourcePoint, bool isNonZero);

}

#endif /* GenerateContours_h */
