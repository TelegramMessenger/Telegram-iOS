#import <LottieMeshBinding/LottieMeshBinding.h>

#import <LottieMesh/LottieMesh.h>

namespace {

MeshGenerator::Point bezierQuadraticPointAt(MeshGenerator::Point const &p0, MeshGenerator::Point const &p1, MeshGenerator::Point const &p2, float t) {
    float x = powf((1.0 - t), 2.0) * p0.x + 2.0 * (1.0 - t) * t * p1.x + powf(t, 2.0) * p2.x;
    float y = powf((1.0 - t), 2.0) * p0.y + 2.0 * (1.0 - t) * t * p1.y + powf(t, 2.0) * p2.y;
    return MeshGenerator::Point(x, y);
}

MeshGenerator::Point bezierQubicPointAt(MeshGenerator::Point const &p0, MeshGenerator::Point const &p1, MeshGenerator::Point const &p2, MeshGenerator::Point const &p3, float t) {
    float x = powf((1.0 - t), 3.0) * p0.x + 3.0 * powf((1.0 - t), 2.0) * t * p1.x + 3.0 * (1.0 - t) * powf(t, 2.0) * p2.x + powf(t, 3.0) * p3.x;
    float y = powf((1.0 - t), 3.0) * p0.y + 3.0 * powf((1.0 - t), 2.0) * t * p1.y + 3.0 * (1.0 - t) * powf(t, 2.0) * p2.y + powf(t, 3.0) * p3.y;
    return MeshGenerator::Point(x, y);
}

float approximateBezierQuadraticLength(MeshGenerator::Point const &p0, MeshGenerator::Point const &p1, MeshGenerator::Point const &p2) {
    float length = 0.0f;
    float t = 0.1;
    MeshGenerator::Point last = p0;
    while (t < 1.01) {
        auto point = bezierQuadraticPointAt(p0, p1, p2, t);
        length += last.distance(point);
        last = point;
        t += 0.1;
    }
    return length;
}

float approximateBezierQubicLength(MeshGenerator::Point const &p0, MeshGenerator::Point const &p1, MeshGenerator::Point const &p2, MeshGenerator::Point const &p3) {
    float length = 0.0f;
    float t = 0.1;
    MeshGenerator::Point last = p0;
    while (t < 1.01) {
        auto point = bezierQubicPointAt(p0, p1, p2, p3, t);
        length += last.distance(point);
        last = point;
        t += 0.1;
    }
    return length;
}

}

@interface LottieMeshData () {
    std::unique_ptr<MeshGenerator::Mesh> _mesh;
}

- (instancetype _Nonnull)initWithMesh:(std::unique_ptr<MeshGenerator::Mesh> &&)mesh;

@end

@implementation LottieMeshData

- (instancetype _Nonnull)initWithMesh:(std::unique_ptr<MeshGenerator::Mesh> &&)mesh {
    self = [super init];
    if (self != nil) {
        _mesh = std::move(mesh);
    }
    return self;
}

- (NSInteger)vertexCount {
    return (NSInteger)_mesh->vertices.size();
}

- (void)getVertexAt:(NSInteger)index x:(float * _Nullable)x y:(float * _Nullable)y {
    MeshGenerator::Point const &point = _mesh->vertices[index];
    if (x) {
        *x = point.x;
    }
    if (y) {
        *y = point.y;
    }
}

- (NSInteger)triangleCount {
    return (NSInteger)(_mesh->triangles.size() / 3);
}

- (void)getTriangleAt:(NSInteger)index v0:(NSInteger * _Nullable)v0 v1:(NSInteger * _Nullable)v1 v2:(NSInteger * _Nullable)v2 {
    if (v0) {
        *v0 = (NSInteger)_mesh->triangles[index * 3 + 0];
    }
    if (v1) {
        *v1 = (NSInteger)_mesh->triangles[index * 3 + 1];
    }
    if (v2) {
        *v2 = (NSInteger)_mesh->triangles[index * 3 + 2];
    }
}

+ (LottieMeshData * _Nullable)generateWithPath:(UIBezierPath * _Nonnull)path fill: (LottieMeshFill * _Nullable)fill stroke:(LottieMeshStroke * _Nullable)stroke {
    float scale = 1.0f;
    float flatness = 0.5;
    __block MeshGenerator::Point startingPoint(0.0f, 0.0f);
    __block bool hasStartingPoint = false;
    __block std::vector<MeshGenerator::Path> paths;
    paths.push_back(MeshGenerator::Path());

    CGPathApplyWithBlock(path.CGPath, ^(const CGPathElement * _Nonnull element) {
        switch (element->type) {
            case kCGPathElementMoveToPoint: {
                if (!paths[paths.size() - 1].points.empty()) {
                    if (!paths[paths.size() - 1].points[0].isEqual(paths[paths.size() - 1].points[paths[paths.size() - 1].points.size() - 1])) {
                        paths[paths.size() - 1].points.push_back(paths[paths.size() - 1].points[0]);
                    }
                    paths.push_back(MeshGenerator::Path());
                }

                startingPoint = MeshGenerator::Point((float)(element->points[0].x) * scale, (float)(element->points[0].y) * scale);
                hasStartingPoint = true;
                break;
            }
            case kCGPathElementAddLineToPoint: {
                bool canAddPoints = false;
                if (paths[paths.size() - 1].points.empty()) {
                    if (hasStartingPoint) {
                        paths[paths.size() - 1].points.push_back(startingPoint);
                        canAddPoints = true;
                    }
                } else {
                    canAddPoints = true;
                }
                if (canAddPoints) {
                    paths[paths.size() - 1].points.push_back(MeshGenerator::Point((float)(element->points[0].x) * scale, (float)(element->points[0].y) * scale));
                }
                break;
            }
            case kCGPathElementAddQuadCurveToPoint: {
                bool canAddPoints = false;
                if (paths[paths.size() - 1].points.empty()) {
                    if (hasStartingPoint) {
                        paths[paths.size() - 1].points.push_back(startingPoint);
                        canAddPoints = true;
                    }
                } else {
                    canAddPoints = true;
                }
                if (canAddPoints) {
                    float t = 0.001f;

                    MeshGenerator::Point p0 = paths[paths.size() - 1].points[paths[paths.size() - 1].points.size() - 1];
                    MeshGenerator::Point p1(element->points[0].x * scale, element->points[0].y * scale);
                    MeshGenerator::Point p2(element->points[1].x * scale, element->points[1].y * scale);

                    float step = 10.0f * flatness / approximateBezierQuadraticLength(p0, p1, p2);
                    while (t < 1.0f) {
                        auto point = bezierQuadraticPointAt(p0, p1, p2, t);
                        paths[paths.size() - 1].points.push_back(point);
                        t += step;
                    }
                    paths[paths.size() - 1].points.push_back(p2);
                }
                break;
            }
            case kCGPathElementAddCurveToPoint: {
                bool canAddPoints = false;
                if (paths[paths.size() - 1].points.empty()) {
                    if (hasStartingPoint) {
                        paths[paths.size() - 1].points.push_back(startingPoint);
                        canAddPoints = true;
                    }
                } else {
                    canAddPoints = true;
                }
                if (canAddPoints) {
                    float t = 0.001f;

                    MeshGenerator::Point p0 = paths[paths.size() - 1].points[paths[paths.size() - 1].points.size() - 1];
                    MeshGenerator::Point p1(element->points[0].x * scale, element->points[0].y * scale);
                    MeshGenerator::Point p2(element->points[1].x * scale, element->points[1].y * scale);
                    MeshGenerator::Point p3(element->points[2].x * scale, element->points[2].y * scale);

                    float step = 10.0f * flatness / approximateBezierQubicLength(p0, p1, p2, p3);
                    while (t < 1.0f) {
                        auto point = bezierQubicPointAt(p0, p1, p2, p3, t);
                        paths[paths.size() - 1].points.push_back(point);
                        t += step;
                    }
                    paths[paths.size() - 1].points.push_back(p3);
                }
                break;
            }
            case kCGPathElementCloseSubpath: {
                if (!paths[paths.size() - 1].points.empty()) {
                    if (!paths[paths.size() - 1].points[0].isEqual(paths[paths.size() - 1].points[paths[paths.size() - 1].points.size() - 1])) {
                        paths[paths.size() - 1].points.push_back(paths[paths.size() - 1].points[0]);
                    }

                    hasStartingPoint = true;
                    startingPoint = paths[paths.size() - 1].points[paths[paths.size() - 1].points.size() - 1];
                    paths.push_back(MeshGenerator::Path());
                }
            }
            default: {
                break;
            }
        }
    });

    if (!paths[paths.size() - 1].points.empty()) {
        if (stroke == nil && !paths[paths.size() - 1].points[0].isEqual(paths[paths.size() - 1].points[paths[paths.size() - 1].points.size() - 1])) {
            paths[paths.size() - 1].points.push_back(paths[paths.size() - 1].points[0]);
        }
    } else {
        paths.pop_back();
    }

    std::unique_ptr<MeshGenerator::Fill> mappedFill;
    if (fill) {
        mappedFill = std::make_unique<MeshGenerator::Fill>(fill.fillRule == LottieMeshFillRuleEvenOdd ? MeshGenerator::Fill::Rule::EvenOdd : MeshGenerator::Fill::Rule::NonZero);
    }

    std::unique_ptr<MeshGenerator::Stroke> mappedStroke;
    if (stroke) {
        MeshGenerator::Stroke::LineJoin lineJoin;
        switch (stroke.lineJoin) {
            case kCGLineJoinRound:
                lineJoin = MeshGenerator::Stroke::LineJoin::Round;
                break;
            case kCGLineJoinBevel:
                lineJoin = MeshGenerator::Stroke::LineJoin::Bevel;
                break;
            case kCGLineJoinMiter:
                lineJoin = MeshGenerator::Stroke::LineJoin::Miter;
                break;
            default:
                lineJoin = MeshGenerator::Stroke::LineJoin::Round;
                break;
        }

        MeshGenerator::Stroke::LineCap lineCap;
        switch (stroke.lineCap) {
            case kCGLineCapRound:
                lineCap = MeshGenerator::Stroke::LineCap::Round;
                break;
            case kCGLineCapButt:
                lineCap = MeshGenerator::Stroke::LineCap::Butt;
                break;
            case kCGLineCapSquare:
                lineCap = MeshGenerator::Stroke::LineCap::Square;
                break;
            default:
                lineCap = MeshGenerator::Stroke::LineCap::Round;
                break;
        }

        mappedStroke = std::make_unique<MeshGenerator::Stroke>((float)stroke.lineWidth, lineJoin, lineCap, (float)stroke.miterLimit);
    }

    std::unique_ptr<MeshGenerator::Mesh> resultMesh = MeshGenerator::generateMesh(paths, std::move(mappedFill), std::move(mappedStroke));
    if (resultMesh) {
        return [[LottieMeshData alloc] initWithMesh:std::move(resultMesh)];
    } else {
        return nil;
    }
}

@end

@implementation LottieMeshFill

- (instancetype _Nonnull)initWithFillRule:(LottieMeshFillRule)fillRule {
    self = [super init];
    if (self != nil) {
        _fillRule = fillRule;
    }
    return self;
}

@end

@implementation LottieMeshStroke

- (instancetype _Nonnull)initWithLineWidth:(CGFloat)lineWidth lineJoin:(CGLineJoin)lineJoin lineCap:(CGLineCap)lineCap miterLimit:(CGFloat)miterLimit {
    self = [super init];
    if (self != nil) {
        _lineWidth = lineWidth;
        _lineJoin = lineJoin;
        _lineCap = lineCap;
        _miterLimit = miterLimit;
    }
    return self;
}

@end
