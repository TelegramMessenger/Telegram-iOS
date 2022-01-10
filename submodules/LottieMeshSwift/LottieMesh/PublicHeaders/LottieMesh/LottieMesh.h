#ifndef LottieMesh_h
#define LottieMesh_h

#include <memory>
#include <vector>

#include "Point.h"

namespace MeshGenerator {

struct Path {
    std::vector<Point> points;
};

struct Fill {
    enum class Rule {
        EvenOdd,
        NonZero
    };

    Rule rule = Rule::EvenOdd;

    explicit Fill(Rule rule_) :
    rule(rule_) {
    }
};

struct Stroke {
    enum class LineJoin {
        Miter,
        Round,
        Bevel
    };

    enum class LineCap {
        Butt,
        Round,
        Square
    };

    float lineWidth = 0.0f;
    LineJoin lineJoin = LineJoin::Round;
    LineCap lineCap = LineCap::Round;
    float miterLimit = 10.0f;

    explicit Stroke(float lineWidth_, LineJoin lineJoin_, LineCap lineCap_, float miterLimit_) :
    lineWidth(lineWidth_), lineJoin(lineJoin_), lineCap(lineCap_), miterLimit(miterLimit_) {
    }
};

struct Mesh {
    std::vector<Point> vertices;
    std::vector<int> triangles;
};

std::unique_ptr<Mesh> generateMesh(std::vector<Path> const &paths, std::unique_ptr<Fill> fill, std::unique_ptr<Stroke> stroke);

}

#endif /* LottieMesh_h */
