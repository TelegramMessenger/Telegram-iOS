#include "GenerateContours.h"

#include <optional>

#include <boost/graph/adjacency_list.hpp>
#include <boost/graph/properties.hpp>
#include <boost/graph/graph_traits.hpp>
#include <boost/property_map/property_map.hpp>
#include <boost/ref.hpp>
#include <vector>
#include <iostream>

#include <boost/graph/planar_face_traversal.hpp>

#include <boost/geometry.hpp>
#include <boost/geometry/geometries/point_xy.hpp>
#include <boost/geometry/geometries/polygon.hpp>
#include <boost/geometry/geometries/geometries.hpp>

namespace MeshGenerator {

namespace {

struct output_visitor : public boost::planar_face_traversal_visitor {
    void begin_face() {
        //std::cout << "New face: ";
    }
    void end_face() {
        //std::cout << std::endl;
    }
};

struct vertex_output_visitor : public boost::planar_face_traversal_visitor {
    std::function<void(std::vector<int>)> _onFace;
    std::vector<int> _currentFace;

    vertex_output_visitor(std::function<void(std::vector<int> const &)> &&onFace) :
    _onFace(std::move(onFace)) {
    }

    template <typename Vertex>
    void next_vertex(Vertex v) {
        _currentFace.push_back((int)v);
    }

    void begin_face() {
        _currentFace.clear();
    }
    void end_face() {
        _onFace(_currentFace);
        _currentFace.clear();
    }
};

bool get_line_intersection(float p0_x, float p0_y, float p1_x, float p1_y,
    float p2_x, float p2_y, float p3_x, float p3_y, float *i_x, float *i_y)
{
    typedef double coordinate_type;
    typedef boost::geometry::model::d2::point_xy<coordinate_type> point;
    typedef boost::geometry::model::segment<point> Segment;
    Segment s0(point(p0_x, p0_y), point(p1_x, p1_y));
    Segment s1(point(p2_x, p2_y), point(p3_x, p3_y));

    std::vector<point> output;
    boost::geometry::intersection(s0, s1, output);
    if (output.empty()) {
        return false;
    }
    if (i_x) {
        *i_x = output[0].x();
    }
    if (i_y) {
        *i_y = output[0].y();
    }
    return true;
}

int addPoint(std::vector<Point> &points, std::map<Point, int> &pointIndex, Point const &point) {
    auto currentIndex = pointIndex.find(point);
    if (currentIndex != pointIndex.end()) {
        return currentIndex->second;
    }

    int index = (int)points.size();
    pointIndex.insert(std::make_pair(point, index));
    points.push_back(point);
    return index;
}

struct TempEdge {
    int index;
    Point v0;
    Point v1;

    explicit TempEdge(int index_, Point v0_, Point v1_) :
    index(index_), v0(v0_), v1(v1_) {
    }
};

void enumerateEdges(Path const &path, std::function<void(TempEdge const &)> f) {
    TempEdge edge(0, Point(0.0f, 0.0f), Point(0.0f, 0.0f));
    for (int i = 1; i < path.points.size(); i++) {
        edge.index = i - 1;
        edge.v0 = path.points[i - 1];
        edge.v1 = path.points[i];
        f(edge);
    }
}

}

std::vector<Path> generateStroke(std::vector<Path> const &paths, float lineWidth, float miterLimit, LineJoin lineJoin, LineCap lineCap) {
    namespace bg = boost::geometry;

    typedef double coordinate_type;
    typedef boost::geometry::model::d2::point_xy<coordinate_type> point;
    typedef boost::geometry::model::polygon<point> polygon;

    // Declare strategies
    const double buffer_distance = lineWidth / 2.0f;
    const int points_per_circle = 20;
    boost::geometry::strategy::buffer::distance_symmetric<coordinate_type> distance_strategy(buffer_distance);

    boost::geometry::strategy::buffer::join_round join_round(points_per_circle);
    boost::geometry::strategy::buffer::join_miter join_miter(miterLimit);

    boost::geometry::strategy::buffer::end_round end_round(points_per_circle);
    boost::geometry::strategy::buffer::end_flat end_flat;
    boost::geometry::strategy::buffer::point_circle circle_strategy(points_per_circle);
    boost::geometry::strategy::buffer::side_straight side_strategy;

    boost::geometry::model::multi_polygon<polygon> results;

    for (const auto &path : paths) {
        // Declare output
        boost::geometry::model::multi_polygon<polygon> result;

        // Declare/fill a linestring
        boost::geometry::model::linestring<point> ls;

        std::vector<point> points;
        for (auto p : path.points) {
            points.emplace_back(p.x, p.y);
        }
        boost::geometry::assign_points(ls, points);

        // Create the buffer of a linestring
        boost::geometry::buffer(ls, result,
                                distance_strategy, side_strategy,
                                join_round, end_round, circle_strategy);

        for (auto &it : result) {
            results.push_back(std::move(it));
        }
    }

    std::vector<Path> resultPaths;

    boost::geometry::model::multi_polygon<polygon> border;   // the unioned polygons
    boost::geometry::model::multi_polygon<polygon> tmp_poly; // a temporary variable

    for (const polygon &p : results) {
        // add another polygon each iteration
        bg::union_(border, p, tmp_poly);
        border = tmp_poly;
        boost::geometry::clear(tmp_poly);
    }

    assert(boost::geometry::is_valid(border));

    for (const auto &poly : border) {
        Path path;
        for (const auto &p : poly.outer()) {
            path.points.emplace_back((float)p.x(), (float)p.y());
        }
        resultPaths.push_back(std::move(path));

        for (const auto &inner : poly.inners()) {
            Path path;
            for (const auto &p : inner) {
                path.points.emplace_back((float)p.x(), (float)p.y());
            }
            resultPaths.push_back(std::move(path));
        }
    }

    return resultPaths;
}

std::unique_ptr<PlanarStraightLineGraph> makePlanarStraightLineGraph(std::vector<Path> const &paths) {
    std::unique_ptr<PlanarStraightLineGraph> result = std::make_unique<PlanarStraightLineGraph>();
    std::map<Point, int> pointIndex;

    namespace bg = boost::geometry;
    typedef bg::model::d2::point_xy<double> point_type;
    typedef bg::model::polygon<point_type> polygon;
    typedef bg::model::multi_polygon<polygon> multi_polygon;

    multi_polygon sourcePoly;
    for (const auto &path : paths) {
        polygon poly;
        std::vector<point_type> points;
        for (auto point : path.points) {
            points.emplace_back(point.x, point.y);
        }
        boost::geometry::assign_points(poly, points);
        sourcePoly.push_back(std::move(poly));
    }

    boost::geometry::validity_failure_type failure;
    if (boost::geometry::is_valid(sourcePoly, failure)) {
        for (int iPath = 0; iPath < paths.size(); iPath++) {
            enumerateEdges(paths[iPath], [&](const TempEdge &pathEdge) {
                int startingPointIndex = addPoint(result->points, pointIndex, pathEdge.v0);

                int endPointIndex = addPoint(result->points, pointIndex, pathEdge.v1);
                if (endPointIndex != startingPointIndex) {
                    result->edges.push_back(PlanarStraightLineGraph::Edge(startingPointIndex, endPointIndex));
                }
            });
        }
    } else {
        for (int iPath = 0; iPath < paths.size(); iPath++) {
            enumerateEdges(paths[iPath], [&](const TempEdge &pathEdge) {
                int startingPointIndex = addPoint(result->points, pointIndex, pathEdge.v0);

                std::vector<Point> intersections;

                for (int iOtherPath = 0; iOtherPath < paths.size(); iOtherPath++) {
                    enumerateEdges(paths[iOtherPath], [&](const TempEdge &otherPathEdge) {
                        if (iPath == iOtherPath) {
                            if (pathEdge.index == otherPathEdge.index) {
                                return;
                            }
                            if (otherPathEdge.v0.isEqual(pathEdge.v0) ||
                                otherPathEdge.v0.isEqual(pathEdge.v1) ||
                                otherPathEdge.v1.isEqual(pathEdge.v0) ||
                                otherPathEdge.v1.isEqual(pathEdge.v1)) {
                                return;
                            }
                        }

                        Point intersectionPoint(0.0f, 0.0f);
                        if (get_line_intersection(pathEdge.v0.x, pathEdge.v0.y, pathEdge.v1.x, pathEdge.v1.y, otherPathEdge.v0.x, otherPathEdge.v0.y, otherPathEdge.v1.x, otherPathEdge.v1.y, &intersectionPoint.x, &intersectionPoint.y)) {
                            intersections.push_back(intersectionPoint);
                        }
                    });
                }

                std::sort(intersections.begin(), intersections.end(), [&](Point const &lhs, Point const &rhs) {
                    float lhsDistance = pathEdge.v0.distance(lhs);
                    float rhsDistance = pathEdge.v0.distance(rhs);
                    return lhsDistance < rhsDistance;
                });

                for (const auto &intersectionPoint : intersections) {
                    int intersectionPointIndex = addPoint(result->points, pointIndex, intersectionPoint);
                    if (intersectionPointIndex != startingPointIndex) {
                        result->edges.push_back(PlanarStraightLineGraph::Edge(startingPointIndex, intersectionPointIndex));
                    }

                    startingPointIndex = intersectionPointIndex;
                }

                int endPointIndex = addPoint(result->points, pointIndex, pathEdge.v1);
                if (endPointIndex != startingPointIndex) {
                    result->edges.push_back(PlanarStraightLineGraph::Edge(startingPointIndex, endPointIndex));
                }
            });
        }
    }

    return result;
}

std::vector<Face> findFaces(PlanarStraightLineGraph const &graph) {
    using namespace boost;

    typedef adjacency_list
        < vecS,
          vecS,
          undirectedS,
          property<vertex_index_t, int>,
          property<edge_index_t, int>
        >
        ParsedGraph;

    ParsedGraph parsedGraph(graph.points.size());
    for (const auto &edge : graph.edges) {
        add_edge(edge.v0, edge.v1, parsedGraph);
    }

    // Initialize the interior edge index
    property_map<ParsedGraph, edge_index_t>::type e_index = get(edge_index, parsedGraph);
    graph_traits<ParsedGraph>::edges_size_type edge_count = 0;
    graph_traits<ParsedGraph>::edge_iterator ei, ei_end;
    std::map<int, std::vector<int>> vertexToEdges;
    std::vector<graph_traits<ParsedGraph>::edge_descriptor> allEdges;
    for (tie(ei, ei_end) = edges(parsedGraph); ei != ei_end; ++ei) {
        int edgeIndex = edge_count++;

        bool sourceFound = false;
        for (auto index : vertexToEdges[ei->m_source]) {
            if (index == edgeIndex) {
                sourceFound = true;
                break;
            }
        }
        if (!sourceFound) {
            vertexToEdges[ei->m_source].push_back(edgeIndex);
        }

        bool targetFound = false;
        for (auto index : vertexToEdges[ei->m_target]) {
            if (index == edgeIndex) {
                targetFound = true;
                break;
            }
        }
        if (!targetFound) {
            vertexToEdges[ei->m_target].push_back(edgeIndex);
        }

        allEdges.push_back(*ei);
        put(e_index, *ei, edgeIndex);
    }

    typedef std::vector<graph_traits<ParsedGraph>::edge_descriptor> vec_t;
    std::vector<vec_t> embedding(num_vertices(parsedGraph));

    std::function<float(int, graph_traits<ParsedGraph>::edge_descriptor const &)> getVectorAngle = [&](int vertexIndex, graph_traits<ParsedGraph>::edge_descriptor const &edge) {
        Point vertex = graph.points[vertexIndex];
        Point otherVertex(0.0f, 0.0f);
        if (edge.m_source == vertexIndex) {
            otherVertex = graph.points[edge.m_target];
        } else {
            otherVertex = graph.points[edge.m_source];
        }
        Point vector(otherVertex.x - vertex.x, otherVertex.y - vertex.y);
        Point upVector(0.0f, 1.0f);

        float dot = upVector.x * vector.x + upVector.y * vector.y;
        float det = upVector.x * vector.y - upVector.y * vector.x;
        float angle = atan2(det, dot);

        return angle;
    };

    for (int i = 0; i < graph.points.size(); i++) {
        std::vector<graph_traits<ParsedGraph>::edge_descriptor> vertexEdgeIndices;

        for (auto edgeIndex : vertexToEdges[i]) {
            vertexEdgeIndices.push_back(allEdges[edgeIndex]);
        }

        /*for (tie(ei, ei_end) = edges(parsedGraph); ei != ei_end; ++ei) {
            if (ei->m_source == i || ei->m_target == i) {
                vertexEdgeIndices.push_back(*ei);
            }
        }*/
        
        std::sort(vertexEdgeIndices.begin(), vertexEdgeIndices.end(), [&](graph_traits<ParsedGraph>::edge_descriptor const &lhs, graph_traits<ParsedGraph>::edge_descriptor const &rhs) {
            auto lhsAngle = getVectorAngle(i, lhs);
            auto rhsAngle = getVectorAngle(i, rhs);
            return lhsAngle < rhsAngle;
        });
        for (const auto &it : vertexEdgeIndices) {
            embedding[i].push_back(it);
        }
    }

    std::vector<Face> faces;

    //std::cout << std::endl << "Vertices on the faces: " << std::endl;
    vertex_output_visitor v_vis([&](std::vector<int> vertices) {
        Face face;
        for (auto index : vertices) {
            face.vertices.push_back(index);
        }
        faces.push_back(std::move(face));
    });
    planar_face_traversal(parsedGraph, &embedding[0], v_vis);

    return faces;
}

bool faceInsideFace(PlanarStraightLineGraph const &graph, Face const &face, Face const &otherFace) {
    typedef boost::geometry::model::d2::point_xy<float> point_type;
    typedef boost::geometry::model::polygon<point_type> polygon_type;

    polygon_type poly1;
    std::vector<point_type> points1;
    for (auto index : face.vertices) {
        points1.emplace_back(graph.points[index].x, graph.points[index].y);
    }
    boost::geometry::assign_points(poly1, points1);

    point_type poly2(graph.points[otherFace.vertices[0]].x, graph.points[otherFace.vertices[0]].y);

    bool result = boost::geometry::within(poly2, poly1);

    return result;
}

float triangleArea(Point const &v1, Point const &v2, Point const &v3) {
    return v1.x * (v2.y - v3.y) + v2.x * (v3.y - v1.y) + v3.x * (v1.y - v2.y);
}

bool traceRay(std::vector<Path> const &paths, Point const &sourcePoint, bool isNonZero) {
    int intersectionCount = 0;
    int intersectionValue = 0;
    for (const auto &path : paths) {
        enumerateEdges(path, [&](const TempEdge &edge) {
            if (get_line_intersection(sourcePoint.x, sourcePoint.y, sourcePoint.x + 10000.0f, sourcePoint.y, edge.v0.x, edge.v0.y, edge.v1.x, edge.v1.y, nullptr, nullptr)) {
                intersectionCount++;

                int addValue = 0;
                if (edge.v0.y < edge.v1.y) {
                    addValue = 1;
                } else {
                    addValue = -1;
                }
                intersectionValue += addValue;
            }
        });
    }
    if (isNonZero) {
        return intersectionValue != 0;
    } else {
        return intersectionCount % 2 != 0;
    }
}

}
