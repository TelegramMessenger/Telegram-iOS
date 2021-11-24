#include <LottieMesh/LottieMesh.h>

#include <LottieMesh/Point.h>
#include "Triangulation.h"

#include "tesselator.h"
#include "Polyline2D.h"

namespace MeshGenerator {

std::unique_ptr<Mesh> generateMesh(std::vector<Path> const &paths, std::unique_ptr<Fill> fill, std::unique_ptr<Stroke> stroke) {
    if (stroke) {
        std::unique_ptr<Mesh> mesh = std::make_unique<Mesh>();
        
        for (const auto &path : paths) {
            crushedpixel::Polyline2D::JointStyle jointStyle = crushedpixel::Polyline2D::JointStyle::ROUND;
            crushedpixel::Polyline2D::EndCapStyle endCapStyle = crushedpixel::Polyline2D::EndCapStyle::SQUARE;
            switch (stroke->lineJoin) {
                case Stroke::LineJoin::Miter:
                    jointStyle = crushedpixel::Polyline2D::JointStyle::MITER;
                    break;
                case Stroke::LineJoin::Round:
                    jointStyle = crushedpixel::Polyline2D::JointStyle::ROUND;
                    break;
                case Stroke::LineJoin::Bevel:
                    jointStyle = crushedpixel::Polyline2D::JointStyle::BEVEL;
                    break;
                default: {
                    break;
                }
            }
            switch (stroke->lineCap) {
                case Stroke::LineCap::Round: {
                    endCapStyle = crushedpixel::Polyline2D::EndCapStyle::ROUND;
                    break;
                }
                case Stroke::LineCap::Square: {
                    endCapStyle = crushedpixel::Polyline2D::EndCapStyle::SQUARE;
                    break;
                }
                case Stroke::LineCap::Butt: {
                    endCapStyle = crushedpixel::Polyline2D::EndCapStyle::BUTT;
                    break;
                }
                default: {
                    break;
                }
            }
            
            auto vertices = crushedpixel::Polyline2D::create(path.points, stroke->lineWidth, jointStyle, endCapStyle);
            for (const auto &vertex : vertices) {
                mesh->triangles.push_back((int)mesh->vertices.size());
                mesh->vertices.push_back(vertex);
            }
        }
        
        assert(mesh->triangles.size() % 3 == 0);
        return mesh;
    } else if (fill) {
        TESStesselator *tessellator = tessNewTess(NULL);
        tessSetOption(tessellator, TESS_CONSTRAINED_DELAUNAY_TRIANGULATION, 1);
        for (const auto &path : paths) {
            tessAddContour(tessellator, 2, path.points.data(), sizeof(Point), (int)path.points.size());
        }
        
        switch (fill->rule) {
            case Fill::Rule::EvenOdd: {
                tessTesselate(tessellator, TESS_WINDING_ODD, TESS_POLYGONS, 3, 2, NULL);
                break;
            }
            default: {
                tessTesselate(tessellator, TESS_WINDING_NONZERO, TESS_POLYGONS, 3, 2, NULL);
                break;
            }
        }
        
        int vertexCount = tessGetVertexCount(tessellator);
        const TESSreal *vertices = tessGetVertices(tessellator);
        int indexCount = tessGetElementCount(tessellator) * 3;
        const TESSindex *indices = tessGetElements(tessellator);
        
        std::unique_ptr<Mesh> mesh = std::make_unique<Mesh>();
        for (int i = 0; i < vertexCount; i++) {
            mesh->vertices.push_back(Point(vertices[i * 2 + 0], vertices[i * 2 + 1]));
        }
        for (int i = 0; i < indexCount; i++) {
            mesh->triangles.push_back(indices[i]);
        }
        return mesh;
    } else {
        return nullptr;
    }
}

}
