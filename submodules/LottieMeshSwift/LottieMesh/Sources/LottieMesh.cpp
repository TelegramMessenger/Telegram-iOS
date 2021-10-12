#include <LottieMesh/LottieMesh.h>

#include "GenerateContours.h"
#include <LottieMesh/Point.h>
#include "Triangulation.h"

namespace MeshGenerator {

std::unique_ptr<Mesh> generateMesh(std::vector<Path> const &paths, std::unique_ptr<Fill> fill, std::unique_ptr<Stroke> stroke) {
    std::unique_ptr<PlanarStraightLineGraph> graph;
    std::unique_ptr<std::vector<Path>> updatedPaths;

    bool isNonZero = false;
    if (stroke) {
        MeshGenerator::LineJoin mappedLineJoin = LineJoin::Round;
        switch (stroke->lineJoin) {
            case Stroke::LineJoin::Bevel:
                mappedLineJoin = LineJoin::Bevel;
                break;
            case Stroke::LineJoin::Miter:
                mappedLineJoin = LineJoin::Miter;
                break;
            case Stroke::LineJoin::Round:
                mappedLineJoin = LineJoin::Round;
                break;
            default:
                break;
        }
        LineCap mappedLineCap = LineCap::Round;
        switch (stroke->lineCap) {
            case Stroke::LineCap::Butt:
                mappedLineCap = LineCap::Butt;
                break;
            case Stroke::LineCap::Round:
                mappedLineCap = LineCap::Round;
                break;
            case Stroke::LineCap::Square:
                mappedLineCap = LineCap::Square;
                break;
            default:
                break;
        }
        auto strokePaths = generateStroke(paths, stroke->lineWidth, stroke->miterLimit, mappedLineJoin, mappedLineCap);
        graph = makePlanarStraightLineGraph(strokePaths);
        updatedPaths = std::make_unique<std::vector<Path>>(std::move(strokePaths));
        isNonZero = true;
    } else if (fill) {
        graph = makePlanarStraightLineGraph(paths);
        switch (fill->rule) {
            case Fill::Rule::EvenOdd:
                break;
            case Fill::Rule::NonZero:
                isNonZero = true;
                break;
            default:
                break;
        }
    } else {
        return nullptr;
    }

    if (!graph) {
        return nullptr;
    }

    std::unique_ptr<Mesh> resultMesh = std::make_unique<Mesh>();
    for (const auto &vertex : graph->points) {
        resultMesh->vertices.push_back(vertex);
    }

    auto faces = findFaces(*graph);

    for (int iFace = (int)faces.size() - 1; iFace >= 0; iFace--) {
        const auto &face = faces[iFace];

        float edgeSum = 0.0f;
        for (int i = 0; i < face.vertices.size(); i++) {
            MeshGenerator::Point nextVertex(0.0f, 0.0f);
            if (i == face.vertices.size() - 1) {
                nextVertex = graph->points[face.vertices[0]];
            } else {
                nextVertex = graph->points[face.vertices[i + 1]];
            }
            MeshGenerator::Point vertex = graph->points[face.vertices[i]];

            edgeSum += (nextVertex.x - vertex.x) * (nextVertex.y + vertex.y);
        }

        if (edgeSum < 0.0f) {
            faces.erase(faces.begin() + iFace);
        }
    }

    for (int iFace = 0; iFace < faces.size(); iFace++) {
        const auto &face = faces[iFace];

        std::vector<int> faceIndices;
        for (const auto &point : face.vertices) {
            faceIndices.push_back(point);
        }

        std::vector<std::vector<int>> holeIndices;
        for (int iOtherFace = 0; iOtherFace < faces.size(); iOtherFace++) {
            if (iFace == iOtherFace) {
                continue;
            }
            if (faceInsideFace(*graph, face, faces[iOtherFace])) {
                std::vector<int> otherFaceIndices;
                for (const auto &point : faces[iOtherFace].vertices) {
                    otherFaceIndices.push_back(point);
                }
                holeIndices.push_back(std::move(otherFaceIndices));
            }
        }

        auto triangleIndices = triangulatePolygon(graph->points, faceIndices, holeIndices);
        if (triangleIndices.empty()) {
            continue;
        }

        float largestTriangleArea = 0.0f;
        int largestTriangleIndex = -1;
        for (int i = 0; i < (int)(triangleIndices.size() / 3); i++) {
            float area = MeshGenerator::triangleArea(graph->points[triangleIndices[i * 3 + 0]], graph->points[triangleIndices[i * 3 + 1]], graph->points[triangleIndices[i * 3 + 2]]);
            if (largestTriangleIndex == -1 || largestTriangleArea < area) {
                largestTriangleIndex = i / 3;
                largestTriangleArea = area;
            }
        }

        MeshGenerator::Point triangleCenter(0.0f, 0.0f);
        for (int i = 0; i < 3; i++) {
            triangleCenter.x += graph->points[triangleIndices[largestTriangleIndex * 3 + i]].x;
            triangleCenter.y += graph->points[triangleIndices[largestTriangleIndex * 3 + i]].y;
        }
        triangleCenter.x /= 3.0f;
        triangleCenter.y /= 3.0f;
        if (!MeshGenerator::traceRay(updatedPaths == nullptr ? paths : *updatedPaths, triangleCenter, isNonZero)) {
            continue;
        }

        for (auto index : triangleIndices) {
            resultMesh->triangles.push_back(index);
        }
    }

    return resultMesh;
}

}
