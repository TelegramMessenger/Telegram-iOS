#ifndef BezierPath_hpp
#define BezierPath_hpp

#include "Lottie/Private/Utility/Primitives/CurveVertex.hpp"
#include "Lottie/Private/Utility/Primitives/PathElement.hpp"
#include "Lottie/Private/Parsing/JsonParsing.hpp"
#include "Lottie/Public/Primitives/CGPath.hpp"

#include <vector>

namespace lottie {

struct BezierTrimPathPosition {
    double start;
    double end;
    
    explicit BezierTrimPathPosition(double start_, double end_) :
    start(start_),
    end(end_) {
    }
};

class BezierPathContents: public std::enable_shared_from_this<BezierPathContents> {
public:
    /// Initializes a new Bezier Path.
    explicit BezierPathContents(CurveVertex const &startPoint) :
    elements({ PathElement(startPoint) }) {
    }
    
    BezierPathContents() :
    elements({}),
    closed(false) {
    }
    
    explicit BezierPathContents(json11::Json const &jsonAny) noexcept(false) :
    elements({}) {
        json11::Json::object const *json = nullptr;
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
        Vector2D firstPoint(vertexContainer[0]);
        Vector2D firstInPoint(inPointsContainer[0]);
        Vector2D firstOutPoint(outPointsContainer[0]);
        CurveVertex firstVertex = CurveVertex::relative(
            firstPoint,
            firstInPoint,
            firstOutPoint
        );
        PathElement previousElement(firstVertex);
        elements.push_back(previousElement);
        
        for (size_t i = 1; i < vertexContainer.size(); i++) {
            Vector2D point(vertexContainer[i]);
            Vector2D inPoint(inPointsContainer[i]);
            Vector2D outPoint(outPointsContainer[i]);
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
    
    BezierPathContents(const BezierPathContents&) = delete;
    BezierPathContents& operator=(BezierPathContents&) = delete;
    
    json11::Json toJson() const {
        json11::Json::object result;
        
        json11::Json::array vertices;
        json11::Json::array inPoints;
        json11::Json::array outPoints;
        
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
        
        return json11::Json(result);
    }
    
    std::shared_ptr<CGPath> cgPath() const {
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
    
public:
    std::vector<PathElement> elements;
    std::optional<bool> closed;
    
    double length() {
        if (_length.has_value()) {
            return _length.value();
        } else {
            double result = 0.0;
            for (size_t i = 1; i < elements.size(); i++) {
                result += elements[i].length(elements[i - 1]);
            }
            _length = result;
            return result;
        }
    }
    
private:
    std::optional<double> _length;
    
public:
    void moveToStartPoint(CurveVertex const &vertex) {
        elements = { PathElement(vertex) };
        _length = std::nullopt;
    }
    
    void addVertex(CurveVertex const &vertex) {
        addElement(PathElement(vertex));
    }
    
    void reserveCapacity(size_t capacity) {
        elements.reserve(capacity);
    }
    
    void setElementCount(size_t count) {
        elements.resize(count, PathElement(CurveVertex::absolute(Vector2D(0.0, 0.0), Vector2D(0.0, 0.0), Vector2D(0.0, 0.0))));
    }
    
    void invalidateLength() {
        _length.reset();
    }
    
    void addCurve(Vector2D const &toPoint, Vector2D const &outTangent, Vector2D const &inTangent) {
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
    
    void addLine(Vector2D const &toPoint) {
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
    
    void close() {
        closed = true;
    }
    
    void addElement(PathElement const &pathElement) {
        elements.push_back(pathElement);
    }
    
    void updateVertex(CurveVertex const &vertex, int atIndex, bool remeasure) {
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
    
    /// Trims a path fromLength toLength with an offset.
    ///
    /// Length and offset are defined in the length coordinate space.
    /// If any argument is outside the range of this path, then it will be looped over the path from finish to start.
    ///
    /// Cutting the curve when fromLength is less than toLength
    /// x                    x                                 x                          x
    /// ~~~~~~~~~~~~~~~ooooooooooooooooooooooooooooooooooooooooooooooooo-------------------
    /// |Offset        |fromLength                             toLength|                  |
    ///
    /// Cutting the curve when from Length is greater than toLength
    /// x                x                    x               x                           x
    /// oooooooooooooooooo--------------------~~~~~~~~~~~~~~~~ooooooooooooooooooooooooooooo
    /// |        toLength|                    |Offset         |fromLength                 |
    ///
    std::vector<std::shared_ptr<BezierPathContents>> trim(double fromLength, double toLength, double offsetLength) {
        if (elements.size() <= 1) {
            return {};
        }
        
        if (fromLength == toLength) {
            return {};
        }
        
        double lengthValue = length();
            
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
    
    std::vector<std::shared_ptr<BezierPathContents>> trimPathAtLengths(std::vector<BezierTrimPathPosition> const &positions) {
        if (positions.empty()) {
            return {};
        }
        auto remainingPositions = positions;
        
        auto trim = remainingPositions[0];
        remainingPositions.erase(remainingPositions.begin());
        
        std::vector<std::shared_ptr<BezierPathContents>> paths;
        
        double runningLength = 0.0;
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
            double elementLength = 0.0;
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
};

class BezierPath {
public:
    /// Initializes a new Bezier Path.
    explicit BezierPath(CurveVertex const &startPoint) :
    _contents(std::make_shared<BezierPathContents>(startPoint)) {
    }
    
    BezierPath() :
    _contents(std::make_shared<BezierPathContents>()) {
    }
    
    explicit BezierPath(json11::Json const &jsonAny) noexcept(false) :
    _contents(std::make_shared<BezierPathContents>(jsonAny)) {
    }
    
    json11::Json toJson() const {
        return _contents->toJson();
    }
    
    double length() {
        return _contents->length();
    }

    void moveToStartPoint(CurveVertex const &vertex) {
        _contents->moveToStartPoint(vertex);
    }
    
    void addVertex(CurveVertex const &vertex) {
        _contents->addVertex(vertex);
    }
    
    void reserveCapacity(size_t capacity) {
        _contents->reserveCapacity(capacity);
    }
    
    void setElementCount(size_t count) {
        _contents->setElementCount(count);
    }
    
    void invalidateLength() {
        _contents->invalidateLength();
    }
    
    void addCurve(Vector2D const &toPoint, Vector2D const &outTangent, Vector2D const &inTangent) {
        _contents->addCurve(toPoint, outTangent, inTangent);
    }
    
    void addLine(Vector2D const &toPoint) {
        _contents->addLine(toPoint);
    }
    
    void close() {
        _contents->close();
    }
    
    void addElement(PathElement const &pathElement) {
        _contents->addElement(pathElement);
    }
    
    void updateVertex(CurveVertex const &vertex, int atIndex, bool remeasure) {
        _contents->updateVertex(vertex, atIndex, remeasure);
    }
    
    /// Trims a path fromLength toLength with an offset.
    ///
    /// Length and offset are defined in the length coordinate space.
    /// If any argument is outside the range of this path, then it will be looped over the path from finish to start.
    ///
    /// Cutting the curve when fromLength is less than toLength
    /// x                    x                                 x                          x
    /// ~~~~~~~~~~~~~~~ooooooooooooooooooooooooooooooooooooooooooooooooo-------------------
    /// |Offset        |fromLength                             toLength|                  |
    ///
    /// Cutting the curve when from Length is greater than toLength
    /// x                x                    x               x                           x
    /// oooooooooooooooooo--------------------~~~~~~~~~~~~~~~~ooooooooooooooooooooooooooooo
    /// |        toLength|                    |Offset         |fromLength                 |
    ///
    std::vector<BezierPath> trim(double fromLength, double toLength, double offsetLength) {
        std::vector<BezierPath> result;
        
        auto resultContents = _contents->trim(fromLength, toLength, offsetLength);
        for (const auto &resultContent : resultContents) {
            result.emplace_back(resultContent);
        }
        
        return result;
    }
    
    // MARK: Private
    
    std::vector<PathElement> const &elements() const {
        return _contents->elements;
    }
    
    std::vector<PathElement> &mutableElements() {
        return _contents->elements;
    }
    
    std::optional<bool> const &closed() const {
        return _contents->closed;
    }
    void setClosed(std::optional<bool> const &closed) {
        _contents->closed = closed;
    }
    
    std::shared_ptr<CGPath> cgPath() const {
        return _contents->cgPath();
    }
    
    BezierPath copyUsingTransform(CATransform3D const &transform) const {
        if (transform == CATransform3D::identity()) {
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
    
public:
    BezierPath(std::shared_ptr<BezierPathContents> contents) :
    _contents(contents) {
    }
    
private:
    std::shared_ptr<BezierPathContents> _contents;
};

class BezierPathsBoundingBoxContext {
public:
    BezierPathsBoundingBoxContext() :
    pointsX((float *)malloc(1024 * 4)),
    pointsY((float *)malloc(1024 * 4)),
    pointsSize(1024) {
    }
    
    ~BezierPathsBoundingBoxContext() {
        free(pointsX);
        free(pointsY);
    }
    
public:
    float *pointsX = nullptr;
    float *pointsY = nullptr;
    int pointsSize = 0;
};

CGRect bezierPathsBoundingBox(std::vector<BezierPath> const &paths);
CGRect bezierPathsBoundingBoxParallel(BezierPathsBoundingBoxContext &context, std::vector<BezierPath> const &paths);
CGRect calculateBoundingRectOpt(float const *pointsX, float const *pointsY, int count);

}

#endif /* BezierPath_hpp */
