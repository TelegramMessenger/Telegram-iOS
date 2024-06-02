#include <LottieCpp/BezierPath.h>

#include <simd/simd.h>
#include <Accelerate/Accelerate.h>

#include "Lottie/Private/Parsing/JsonParsing.hpp"

namespace lottie {

BezierTrimPathPosition::BezierTrimPathPosition(float start_, float end_) :
start(start_),
end(end_) {
}

BezierPathContents::BezierPathContents(CurveVertex const &startPoint) :
elements({ PathElement(startPoint) }) {
}
    
BezierPathContents::BezierPathContents() :
elements({}),
closed(false) {
}

BezierPathContents::BezierPathContents(lottiejson11::Json const &jsonAny) noexcept(false) :
elements({}) {
    lottiejson11::Json::object const *json = nullptr;
    if (jsonAny.is_object()) {
        json = &jsonAny.object_items();
    } else if (jsonAny.is_array()) {
        if (jsonAny.array_items().empty()) {
            throw LottieParsingException();
        }
        if (!jsonAny.array_items()[0].is_object()) {
            throw LottieParsingException();
        }
        json = &jsonAny.array_items()[0].object_items();
    }
    
    if (const auto closedData = getOptionalBool(*json, "c")) {
        closed = closedData.value();
    }
    
    auto vertexContainer = getAnyArray(*json, "v");
    auto inPointsContainer = getAnyArray(*json, "i");
    auto outPointsContainer = getAnyArray(*json, "o");
    
    if (vertexContainer.size() != inPointsContainer.size() || inPointsContainer.size() != outPointsContainer.size()) {
        throw LottieParsingException();
    }
    if (vertexContainer.empty()) {
        return;
    }
    
    /// Create first point
    Vector2D firstPoint = Vector2D(vertexContainer[0]);
    Vector2D firstInPoint = Vector2D(inPointsContainer[0]);
    Vector2D firstOutPoint = Vector2D(outPointsContainer[0]);
    CurveVertex firstVertex = CurveVertex::relative(
        firstPoint,
        firstInPoint,
        firstOutPoint
    );
    PathElement previousElement(firstVertex);
    elements.push_back(previousElement);
    
    for (size_t i = 1; i < vertexContainer.size(); i++) {
        Vector2D point = Vector2D(vertexContainer[i]);
        Vector2D inPoint = Vector2D(inPointsContainer[i]);
        Vector2D outPoint = Vector2D(outPointsContainer[i]);
        CurveVertex vertex = CurveVertex::relative(
            point,
            inPoint,
            outPoint
        );
        auto pathElement = previousElement.pathElementTo(vertex);
        elements.push_back(pathElement);
        previousElement = pathElement;
    }
    
    if (closed.value_or(false)) {
        auto closeElement = previousElement.pathElementTo(firstVertex);
        elements.push_back(closeElement);
    }
}

lottiejson11::Json BezierPathContents::toJson() const {
    lottiejson11::Json::object result;
    
    lottiejson11::Json::array vertices;
    lottiejson11::Json::array inPoints;
    lottiejson11::Json::array outPoints;
    
    for (const auto &element : elements) {
        vertices.push_back(element.vertex.point.toJson());
        inPoints.push_back(element.vertex.inTangentRelative().toJson());
        outPoints.push_back(element.vertex.outTangentRelative().toJson());
    }
    
    result.insert(std::make_pair("v", vertices));
    result.insert(std::make_pair("i", inPoints));
    result.insert(std::make_pair("o", outPoints));
    
    if (closed.has_value()) {
        result.insert(std::make_pair("c", closed.value()));
    }
    
    return lottiejson11::Json(result);
}

std::shared_ptr<CGPath> BezierPathContents::cgPath() const {
    auto cgPath = CGPath::makePath();
    
    std::optional<PathElement> previousElement;
    for (const auto &element : elements) {
        if (previousElement.has_value()) {
            if (previousElement->vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                cgPath->addLineTo(element.vertex.point);
            } else {
                cgPath->addCurveTo(element.vertex.point, previousElement->vertex.outTangent, element.vertex.inTangent);
            }
        } else {
            cgPath->moveTo(element.vertex.point);
        }
        previousElement = element;
    }
    if (closed.value_or(true)) {
        cgPath->closeSubpath();
    }
    return cgPath;
}

float BezierPathContents::length() {
    if (_length.has_value()) {
        return _length.value();
    } else {
        float result = 0.0;
        for (size_t i = 1; i < elements.size(); i++) {
            result += elements[i].length(elements[i - 1]);
        }
        _length = result;
        return result;
    }
}

void BezierPathContents::moveToStartPoint(CurveVertex const &vertex) {
    elements = { PathElement(vertex) };
    _length = std::nullopt;
}

void BezierPathContents::addVertex(CurveVertex const &vertex) {
    addElement(PathElement(vertex));
}

void BezierPathContents::reserveCapacity(size_t capacity) {
    elements.reserve(capacity);
}

void BezierPathContents::setElementCount(size_t count) {
    elements.resize(count, PathElement(CurveVertex::absolute(Vector2D(0.0, 0.0), Vector2D(0.0, 0.0), Vector2D(0.0, 0.0))));
}

void BezierPathContents::invalidateLength() {
    _length.reset();
}

void BezierPathContents::addCurve(Vector2D const &toPoint, Vector2D const &outTangent, Vector2D const &inTangent) {
    if (elements.empty()) {
        return;
    }
    auto previous = elements[elements.size() - 1];
    auto newVertex = CurveVertex::absolute(toPoint, inTangent, toPoint);
    updateVertex(
        CurveVertex::absolute(previous.vertex.point, previous.vertex.inTangent, outTangent),
        (int)elements.size() - 1,
        false
    );
    addVertex(newVertex);
}

void BezierPathContents::addLine(Vector2D const &toPoint) {
    if (elements.empty()) {
        return;
    }
    auto previous = elements[elements.size() - 1];
    auto newVertex = CurveVertex::relative(toPoint, Vector2D::Zero(), Vector2D::Zero());
    updateVertex(
        CurveVertex::absolute(previous.vertex.point, previous.vertex.inTangent, previous.vertex.point),
        (int)elements.size() - 1,
        false
    );
    addVertex(newVertex);
}

void BezierPathContents::close() {
    closed = true;
}

void BezierPathContents::addElement(PathElement const &pathElement) {
    elements.push_back(pathElement);
}

void BezierPathContents::updateVertex(CurveVertex const &vertex, int atIndex, bool remeasure) {
    if (remeasure) {
        PathElement newElement(CurveVertex::absolute(Vector2D::Zero(), Vector2D::Zero(), Vector2D::Zero()));
        if (atIndex > 0) {
            auto previousElement = elements[atIndex - 1];
            newElement = previousElement.pathElementTo(vertex);
        } else {
            newElement = PathElement(vertex);
        }
        elements[atIndex] = newElement;
        
        if (atIndex + 1 < elements.size()) {
            auto nextElement = elements[atIndex + 1];
            elements[atIndex + 1] = newElement.pathElementTo(nextElement.vertex);
        }
        
    } else {
        auto oldElement = elements[atIndex];
        elements[atIndex] = oldElement.updateVertex(vertex);
    }
}

std::vector<std::shared_ptr<BezierPathContents>> BezierPathContents::trim(float fromLength, float toLength, float offsetLength) {
    if (elements.size() <= 1) {
        return {};
    }
    
    if (fromLength == toLength) {
        return {};
    }
    
    float lengthValue = length();
        
    /// Normalize lengths to the curve length.
    auto start = fmod(fromLength + offsetLength, lengthValue);
    auto end = fmod(toLength + offsetLength, lengthValue);
    
    if (start < 0.0) {
        start = lengthValue + start;
    }
    
    if (end < 0.0) {
        end = lengthValue + end;
    }
    
    if (start == lengthValue) {
        start = 0.0;
    }
    if (end == 0.0) {
        end = lengthValue;
    }
    
    if (
        (start == 0.0 && end == lengthValue) ||
        start == end ||
        (start == lengthValue && end == 0.0)
    ) {
        /// The trim encompasses the entire path. Return.
        return { shared_from_this() };
    }
    
    if (start > end) {
        // Start is greater than end. Two paths are returned.
        return trimPathAtLengths({
            BezierTrimPathPosition(0.0, end),
            BezierTrimPathPosition(start, lengthValue)
        });
    }
    
    return trimPathAtLengths({ BezierTrimPathPosition(start, end) });
}

// MARK: Private

std::vector<std::shared_ptr<BezierPathContents>> BezierPathContents::trimPathAtLengths(std::vector<BezierTrimPathPosition> const &positions) {
    if (positions.empty()) {
        return {};
    }
    auto remainingPositions = positions;
    
    auto trim = remainingPositions[0];
    remainingPositions.erase(remainingPositions.begin());
    
    std::vector<std::shared_ptr<BezierPathContents>> paths;
    
    float runningLength = 0.0;
    bool finishedTrimming = false;
    auto pathElements = elements;
    
    auto currentPath = std::make_shared<BezierPathContents>();
    int i = 0;
    
    while (!finishedTrimming) {
        if (pathElements.size() <= i) {
            /// Do this for rounding errors
            paths.push_back(currentPath);
            finishedTrimming = true;
            continue;
        }
        /// Loop through and add elements within start->end range.
        /// Get current element
        auto element = pathElements[i];
        float elementLength = 0.0;
        if (i != 0) {
            elementLength = element.length(pathElements[i - 1]);
        }
        
        /// Calculate new running length.
        auto newLength = runningLength + elementLength;
        
        if (newLength < trim.start) {
            /// Element is not included in the trim, continue.
            runningLength = newLength;
            i = i + 1;
            /// Increment index, we are done with this element.
            continue;
        }
        
        if (newLength == trim.start) {
            /// Current element IS the start element.
            /// For start we want to add a zero length element.
            currentPath->moveToStartPoint(element.vertex);
            runningLength = newLength;
            i = i + 1;
            /// Increment index, we are done with this element.
            continue;
        }
        
        if (runningLength < trim.start && trim.start < newLength && currentPath->elements.size() == 0) {
            /// The start of the trim is between this element and the previous, trim.
            /// Get previous element.
            auto previousElement = pathElements[i - 1];
            /// Trim it
            auto trimLength = trim.start - runningLength;
            auto trimResults = element.splitElementAtPosition(previousElement, trimLength);
            /// Add the right span start.
            currentPath->moveToStartPoint(trimResults.rightSpan.start.vertex);
            
            pathElements[i] = trimResults.rightSpan.end;
            pathElements[i - 1] = trimResults.rightSpan.start;
            runningLength = runningLength + trimResults.leftSpan.end.length(trimResults.leftSpan.start);
            /// Dont increment index or the current length, the end of this path can be within this span.
            continue;
        }
        
        if (trim.start < newLength && newLength < trim.end) {
            /// Element lies within the trim span.
            currentPath->addElement(element);
            runningLength = newLength;
            i = i + 1;
            continue;
        }
        
        if (newLength == trim.end) {
            /// Element is the end element.
            /// The element could have a new length if it's added right after the start node.
            currentPath->addElement(element);
            /// We are done with this span.
            runningLength = newLength;
            i = i + 1;
            /// Allow the path to be finalized.
            /// Fall through to finalize path and move to next position
        }
        
        if (runningLength < trim.end && trim.end < newLength) {
            /// New element must be cut for end.
            /// Get previous element.
            auto previousElement = pathElements[i - 1];
            /// Trim it
            auto trimLength = trim.end - runningLength;
            auto trimResults = element.splitElementAtPosition(previousElement, trimLength);
            /// Add the left span end.
            
            currentPath->updateVertex(trimResults.leftSpan.start.vertex, (int)currentPath->elements.size() - 1, false);
            currentPath->addElement(trimResults.leftSpan.end);
            
            pathElements[i] = trimResults.rightSpan.end;
            pathElements[i - 1] = trimResults.rightSpan.start;
            runningLength = runningLength + trimResults.leftSpan.end.length(trimResults.leftSpan.start);
            /// Dont increment index or the current length, the start of the next path can be within this span.
            /// We are done with this span.
            /// Allow the path to be finalized.
            /// Fall through to finalize path and move to next position
        }
        
        paths.push_back(currentPath);
        currentPath = std::make_shared<BezierPathContents>();
        if (remainingPositions.size() > 0) {
            trim = remainingPositions[0];
            remainingPositions.erase(remainingPositions.begin());
        } else {
            finishedTrimming = true;
        }
    }
    return paths;
}

BezierPath::BezierPath(CurveVertex const &startPoint) :
_contents(std::make_shared<BezierPathContents>(startPoint)) {
}

BezierPath::BezierPath() :
_contents(std::make_shared<BezierPathContents>()) {
}

BezierPath::BezierPath(lottiejson11::Json const &jsonAny) noexcept(false) :
_contents(std::make_shared<BezierPathContents>(jsonAny)) {
}

lottiejson11::Json BezierPath::toJson() const {
    return _contents->toJson();
}

float BezierPath::length() {
    return _contents->length();
}

void BezierPath::moveToStartPoint(CurveVertex const &vertex) {
    _contents->moveToStartPoint(vertex);
}

void BezierPath::addVertex(CurveVertex const &vertex) {
    _contents->addVertex(vertex);
}

void BezierPath::reserveCapacity(size_t capacity) {
    _contents->reserveCapacity(capacity);
}

void BezierPath::setElementCount(size_t count) {
    _contents->setElementCount(count);
}

void BezierPath::invalidateLength() {
    _contents->invalidateLength();
}

void BezierPath::addCurve(Vector2D const &toPoint, Vector2D const &outTangent, Vector2D const &inTangent) {
    _contents->addCurve(toPoint, outTangent, inTangent);
}

void BezierPath::addLine(Vector2D const &toPoint) {
    _contents->addLine(toPoint);
}

void BezierPath::close() {
    _contents->close();
}

void BezierPath::addElement(PathElement const &pathElement) {
    _contents->addElement(pathElement);
}

void BezierPath::updateVertex(CurveVertex const &vertex, int atIndex, bool remeasure) {
    _contents->updateVertex(vertex, atIndex, remeasure);
}

std::vector<BezierPath> BezierPath::trim(float fromLength, float toLength, float offsetLength) {
    std::vector<BezierPath> result;
    
    auto resultContents = _contents->trim(fromLength, toLength, offsetLength);
    for (const auto &resultContent : resultContents) {
        result.emplace_back(resultContent);
    }
    
    return result;
}

std::vector<PathElement> const &BezierPath::elements() const {
    return _contents->elements;
}

std::vector<PathElement> &BezierPath::mutableElements() {
    return _contents->elements;
}

std::optional<bool> const &BezierPath::closed() const {
    return _contents->closed;
}
void BezierPath::setClosed(std::optional<bool> const &closed) {
    _contents->closed = closed;
}

std::shared_ptr<CGPath> BezierPath::cgPath() const {
    return _contents->cgPath();
}

BezierPath BezierPath::copyUsingTransform(Transform2D const &transform) const {
    if (transform == Transform2D::identity()) {
        return (*this);
    }
    BezierPath result;
    result._contents->closed = _contents->closed;
    result.reserveCapacity(_contents->elements.size());
    for (const auto &element : _contents->elements) {
        result._contents->elements.emplace_back(element.vertex.transformed(transform));
    }
    return result;
}

BezierPath::BezierPath(std::shared_ptr<BezierPathContents> contents) :
_contents(contents) {
}

BezierPathsBoundingBoxContext::BezierPathsBoundingBoxContext() :
pointsX((float *)malloc(1024 * 4)),
pointsY((float *)malloc(1024 * 4)),
pointsSize(1024) {
}
    
BezierPathsBoundingBoxContext::~BezierPathsBoundingBoxContext() {
    free(pointsX);
    free(pointsY);
}

static CGRect calculateBoundingRectOpt(float const *pointsX, float const *pointsY, int count) {
    float minX = 0.0;
    float maxX = 0.0;
    vDSP_minv(pointsX, 1, &minX, count);
    vDSP_maxv(pointsX, 1, &maxX, count);
    
    float minY = 0.0;
    float maxY = 0.0;
    vDSP_minv(pointsY, 1, &minY, count);
    vDSP_maxv(pointsY, 1, &maxY, count);
    
    return CGRect(minX, minY, maxX - minX, maxY - minY);
}

CGRect bezierPathsBoundingBoxParallel(BezierPathsBoundingBoxContext &context, std::vector<BezierPath> const &paths) {
    int pointCount = 0;
    
    float *pointsX = context.pointsX;
    float *pointsY = context.pointsY;
    int pointsSize = context.pointsSize;
    
    for (const auto &path : paths) {
        PathElement const *pathElements = path.elements().data();
        int pathElementCount = (int)path.elements().size();
        
        for (int i = 0; i < pathElementCount; i++) {
            const auto &element = pathElements[i];
            
            if (pointsSize < pointCount + 1) {
                pointsSize = (pointCount + 1) * 2;
                pointsX = (float *)realloc(pointsX, pointsSize * 4);
                pointsY = (float *)realloc(pointsY, pointsSize * 4);
            }
            pointsX[pointCount] = (float)element.vertex.point.x;
            pointsY[pointCount] = (float)element.vertex.point.y;
            pointCount++;
            
            if (i != 0) {
                const auto &previousElement = pathElements[i - 1];
                if (previousElement.vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                } else {
                    if (pointsSize < pointCount + 1) {
                        pointsSize = (pointCount + 2) * 2;
                        pointsX = (float *)realloc(pointsX, pointsSize * 4);
                        pointsY = (float *)realloc(pointsY, pointsSize * 4);
                    }
                    pointsX[pointCount] = (float)previousElement.vertex.outTangent.x;
                    pointsY[pointCount] = (float)previousElement.vertex.outTangent.y;
                    pointCount++;
                    pointsX[pointCount] = (float)element.vertex.inTangent.x;
                    pointsY[pointCount] = (float)element.vertex.inTangent.y;
                    pointCount++;
                }
            }
        }
    }
    
    context.pointsX = pointsX;
    context.pointsY = pointsY;
    context.pointsSize = pointsSize;
    
    if (pointCount == 0) {
        return CGRect(0.0, 0.0, 0.0, 0.0);
    }
    
    return calculateBoundingRectOpt(pointsX, pointsY, pointCount);
}

CGRect bezierPathsBoundingBoxParallel(BezierPathsBoundingBoxContext &context, BezierPath const &path) {
    int pointCount = 0;
    
    float *pointsX = context.pointsX;
    float *pointsY = context.pointsY;
    int pointsSize = context.pointsSize;
    
    PathElement const *pathElements = path.elements().data();
    int pathElementCount = (int)path.elements().size();
    
    for (int i = 0; i < pathElementCount; i++) {
        const auto &element = pathElements[i];
        
        if (pointsSize < pointCount + 1) {
            pointsSize = (pointCount + 1) * 2;
            pointsX = (float *)realloc(pointsX, pointsSize * 4);
            pointsY = (float *)realloc(pointsY, pointsSize * 4);
        }
        pointsX[pointCount] = (float)element.vertex.point.x;
        pointsY[pointCount] = (float)element.vertex.point.y;
        pointCount++;
        
        if (i != 0) {
            const auto &previousElement = pathElements[i - 1];
            if (previousElement.vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
            } else {
                if (pointsSize < pointCount + 1) {
                    pointsSize = (pointCount + 2) * 2;
                    pointsX = (float *)realloc(pointsX, pointsSize * 4);
                    pointsY = (float *)realloc(pointsY, pointsSize * 4);
                }
                pointsX[pointCount] = (float)previousElement.vertex.outTangent.x;
                pointsY[pointCount] = (float)previousElement.vertex.outTangent.y;
                pointCount++;
                pointsX[pointCount] = (float)element.vertex.inTangent.x;
                pointsY[pointCount] = (float)element.vertex.inTangent.y;
                pointCount++;
            }
        }
    }
    
    context.pointsX = pointsX;
    context.pointsY = pointsY;
    context.pointsSize = pointsSize;
    
    if (pointCount == 0) {
        return CGRect(0.0, 0.0, 0.0, 0.0);
    }
    
    return calculateBoundingRectOpt(pointsX, pointsY, pointCount);
}

CGRect bezierPathsBoundingBox(std::vector<BezierPath> const &paths) {
    int pointCount = 0;
    
    float *pointsX = (float *)malloc(128 * 4);
    float *pointsY = (float *)malloc(128 * 4);
    int pointsSize = 128;
    
    for (const auto &path : paths) {
        PathElement const *pathElements = path.elements().data();
        int pathElementCount = (int)path.elements().size();
        
        for (int i = 0; i < pathElementCount; i++) {
            const auto &element = pathElements[i];
            
            if (pointsSize < pointCount + 1) {
                pointsSize = (pointCount + 1) * 2;
                pointsX = (float *)realloc(pointsX, pointsSize * 4);
                pointsY = (float *)realloc(pointsY, pointsSize * 4);
            }
            pointsX[pointCount] = (float)element.vertex.point.x;
            pointsY[pointCount] = (float)element.vertex.point.y;
            pointCount++;
            
            if (i != 0) {
                const auto &previousElement = pathElements[i - 1];
                if (previousElement.vertex.outTangentRelative().isZero() && element.vertex.inTangentRelative().isZero()) {
                } else {
                    if (pointsSize < pointCount + 1) {
                        pointsSize = (pointCount + 2) * 2;
                        pointsX = (float *)realloc(pointsX, pointsSize * 4);
                        pointsY = (float *)realloc(pointsY, pointsSize * 4);
                    }
                    pointsX[pointCount] = (float)previousElement.vertex.outTangent.x;
                    pointsY[pointCount] = (float)previousElement.vertex.outTangent.y;
                    pointCount++;
                    pointsX[pointCount] = (float)element.vertex.inTangent.x;
                    pointsY[pointCount] = (float)element.vertex.inTangent.y;
                    pointCount++;
                }
            }
        }
    }
    
    free(pointsX);
    free(pointsY);
    
    if (pointCount == 0) {
        return CGRect(0.0, 0.0, 0.0, 0.0);
    }
    
    return calculateBoundingRectOpt(pointsX, pointsY, pointCount);
}

PathContents::PathContents(BezierPathContents const &bezierPath) {
    std::optional<PathElement> previousElement;
    for (const auto &element : bezierPath.elements) {
        if (previousElement.has_value()) {
            _elements.emplace_back(element.vertex.point, previousElement->vertex.outTangent, element.vertex.inTangent);
        } else {
            _elements.emplace_back(element.vertex.point, Vector2D(0.0, 0.0), Vector2D(0.0, 0.0));
        }
        previousElement = element;
    }
    
    if (bezierPath.closed.value_or(true)) {
        _isClosed = true;
    } else {
        _isClosed = false;
    }
}

PathContents::~PathContents() {
}
    
std::shared_ptr<BezierPathContents> PathContents::bezierPath() const {
    auto result = std::make_shared<BezierPathContents>();
    
    bool isFirst = true;
    for (const auto &element : _elements) {
        if (isFirst) {
            isFirst = false;
        } else {
            result->elements.push_back(PathElement(CurveVertex::absolute(
                element.point,
                element.cp1,
                element.cp2
            )));
        }
    }
    
    result->closed = _isClosed;
    
    return result;
}

}
