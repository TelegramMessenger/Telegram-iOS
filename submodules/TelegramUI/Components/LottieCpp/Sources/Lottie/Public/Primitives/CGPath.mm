#include <LottieCpp/CGPath.h>

#include <LottieCpp/CGPathCocoa.h>
#import <QuartzCore/QuartzCore.h>

namespace {

void addPointToBoundingRect(bool *isFirst, CGRect *rect, CGPoint *point) {
    if (*isFirst) {
        *isFirst = false;
        
        rect->origin.x = point->x;
        rect->origin.y = point->y;
        rect->size.width = 0.0;
        rect->size.height = 0.0;
        
        return;
    }
    if (point->x > rect->origin.x + rect->size.width) {
        rect->size.width = point->x - rect->origin.x;
    }
    if (point->y > rect->origin.y + rect->size.height) {
        rect->size.height = point->y - rect->origin.y;
    }
    if (point->x < rect->origin.x) {
        rect->size.width += rect->origin.x - point->x;
        rect->origin.x = point->x;
    }
    if (point->y < rect->origin.y) {
        rect->size.height += rect->origin.y - point->y;
        rect->origin.y = point->y;
    }
}

}

CGRect calculatePathBoundingBox(CGPathRef path) {
    __block CGRect result = CGRectMake(0.0, 0.0, 0.0, 0.0);
    __block bool isFirst = true;
    
    CGPathApplyWithBlock(path, ^(const CGPathElement * _Nonnull element) {
        switch (element->type) {
            case kCGPathElementMoveToPoint: {
                addPointToBoundingRect(&isFirst, &result, &element->points[0]);
                break;
            }
            case kCGPathElementAddLineToPoint: {
                addPointToBoundingRect(&isFirst, &result, &element->points[0]);
                break;
            }
            case kCGPathElementAddCurveToPoint: {
                addPointToBoundingRect(&isFirst, &result, &element->points[0]);
                addPointToBoundingRect(&isFirst, &result, &element->points[1]);
                addPointToBoundingRect(&isFirst, &result, &element->points[2]);
                break;
            }
            case kCGPathElementAddQuadCurveToPoint: {
                addPointToBoundingRect(&isFirst, &result, &element->points[0]);
                addPointToBoundingRect(&isFirst, &result, &element->points[1]);
                break;
            }
            case kCGPathElementCloseSubpath: {
                break;
            }
        }
    });
    
    return result;
}

namespace lottie {

CGPathCocoaImpl::CGPathCocoaImpl() {
    _path = CGPathCreateMutable();
}

CGPathCocoaImpl::CGPathCocoaImpl(CGMutablePathRef path) {
    CFRetain(path);
    _path = path;
}

CGPathCocoaImpl::~CGPathCocoaImpl() {
    CGPathRelease(_path);
}

CGRect CGPathCocoaImpl::boundingBox() const {
    auto rect = calculatePathBoundingBox(_path);
    return CGRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

bool CGPathCocoaImpl::empty() const {
    return CGPathIsEmpty(_path);
}

std::shared_ptr<CGPath> CGPathCocoaImpl::copyUsingTransform(Transform2D const &transform) const {
    CGAffineTransform affineTransform = CGAffineTransformMake(
        transform.rows().columns[0][0], transform.rows().columns[0][1],
        transform.rows().columns[1][0], transform.rows().columns[1][1],
        transform.rows().columns[2][0], transform.rows().columns[2][1]
    );
    
    CGPathRef resultPath = CGPathCreateCopyByTransformingPath(_path, &affineTransform);
    if (resultPath == nil) {
        return nullptr;
    }
    
    CGMutablePathRef resultMutablePath = CGPathCreateMutableCopy(resultPath);
    CGPathRelease(resultPath);
    auto result = std::make_shared<CGPathCocoaImpl>(resultMutablePath);
    CGPathRelease(resultMutablePath);
    
    return result;
}

void CGPathCocoaImpl::addLineTo(Vector2D const &point) {
    CGPathAddLineToPoint(_path, nil, point.x, point.y);
}

void CGPathCocoaImpl::addCurveTo(Vector2D const &point, Vector2D const &control1, Vector2D const &control2) {
    CGPathAddCurveToPoint(_path, nil, control1.x, control1.y, control2.x, control2.y, point.x, point.y);
}

void CGPathCocoaImpl::moveTo(Vector2D const &point) {
    CGPathMoveToPoint(_path, nil, point.x, point.y);
}

void CGPathCocoaImpl::closeSubpath() {
    CGPathCloseSubpath(_path);
}

void CGPathCocoaImpl::addRect(CGRect const &rect) {
    CGPathAddRect(_path, nil, ::CGRectMake(rect.x, rect.y, rect.width, rect.height));
}

void CGPathCocoaImpl::addPath(std::shared_ptr<CGPath> const &path) {
    if (CGPathIsEmpty(_path)) {
        _path = CGPathCreateMutableCopy(std::static_pointer_cast<CGPathCocoaImpl>(path)->_path);
    } else {
        CGPathAddPath(_path, nil, std::static_pointer_cast<CGPathCocoaImpl>(path)->_path);
    }
}

CGPathRef CGPathCocoaImpl::nativePath() const {
    return _path;
}

bool CGPathCocoaImpl::isEqual(CGPath *other) const {
    CGPathCocoaImpl *otherImpl = (CGPathCocoaImpl *)other;
    return CGPathEqualToPath(_path, otherImpl->_path);
}

void CGPathCocoaImpl::enumerate(std::function<void(CGPathItem const &)> f) {
    CGPathApplyWithBlock(_path, ^(const CGPathElement * _Nonnull element) {
        CGPathItem item(CGPathItem::Type::MoveTo);
        
        switch (element->type) {
            case kCGPathElementMoveToPoint: {
                item.type = CGPathItem::Type::MoveTo;
                item.points[0] = Vector2D(element->points[0].x, element->points[0].y);
                f(item);
                break;
            }
            case kCGPathElementAddLineToPoint: {
                item.type = CGPathItem::Type::LineTo;
                item.points[0] = Vector2D(element->points[0].x, element->points[0].y);
                f(item);
                break;
            }
            case kCGPathElementAddCurveToPoint: {
                item.type = CGPathItem::Type::CurveTo;
                item.points[0] = Vector2D(element->points[0].x, element->points[0].y);
                item.points[1] = Vector2D(element->points[1].x, element->points[1].y);
                item.points[2] = Vector2D(element->points[2].x, element->points[2].y);
                f(item);
                break;
            }
            case kCGPathElementAddQuadCurveToPoint: {
                break;
            }
            case kCGPathElementCloseSubpath: {
                item.type = CGPathItem::Type::Close;
                f(item);
                break;
            }
        }
    });
}

void CGPathCocoaImpl::withNativePath(std::shared_ptr<CGPath> const &path, std::function<void(CGPathRef)> f) {
    CGMutablePathRef result = CGPathCreateMutable();
    
    path->enumerate([result](CGPathItem const &element) {
        switch (element.type) {
            case CGPathItem::Type::MoveTo: {
                CGPathMoveToPoint(result, nullptr, element.points[0].x, element.points[0].y);
                break;
            }
            case CGPathItem::Type::LineTo: {
                CGPathAddLineToPoint(result, nullptr, element.points[0].x, element.points[0].y);
                break;
            }
            case CGPathItem::Type::CurveTo: {
                CGPathAddCurveToPoint(result, nullptr, element.points[0].x, element.points[0].y, element.points[1].x, element.points[1].y, element.points[2].x, element.points[2].y);
                break;
            }
            case CGPathItem::Type::Close: {
                CGPathCloseSubpath(result);
                break;
            }
            default:
                break;
        }
    });
    
    f(result);
    CFRelease(result);
}

/*std::shared_ptr<CGPath> CGPath::makePath() {
    return std::static_pointer_cast<CGPath>(std::make_shared<CGPathCocoaImpl>());
}*/

}
