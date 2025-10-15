#include "CGPath.hpp"

#include <cassert>

namespace lottie {

namespace {

void addPointToBoundingRect(bool *isFirst, CGRect *rect, Vector2D const *point) {
    if (*isFirst) {
        *isFirst = false;
        
        rect->x = point->x;
        rect->y = point->y;
        rect->width = 0.0;
        rect->height = 0.0;
        
        return;
    }
    if (point->x > rect->x + rect->width) {
        rect->width = point->x - rect->x;
    }
    if (point->y > rect->y + rect->height) {
        rect->height = point->y - rect->y;
    }
    if (point->x < rect->x) {
        rect->width += rect->x - point->x;
        rect->x = point->x;
    }
    if (point->y < rect->y) {
        rect->height += rect->y - point->y;
        rect->y = point->y;
    }
}

}

Vector2D transformVector(Vector2D const &v, CATransform3D const &m) {
    return Vector2D(
        m.m11 * v.x + m.m21 * v.y + m.m41 * 1.0,
        m.m12 * v.x + m.m22 * v.y + m.m42 * 1.0
    );
}

class CGPathImpl: public CGPath {
public:
    CGPathImpl();
    virtual ~CGPathImpl();
    
    virtual CGRect boundingBox() const override;
    
    virtual bool empty() const override;
    
    virtual std::shared_ptr<CGPath> copyUsingTransform(CATransform3D const &transform) const override;
    
    virtual void addLineTo(Vector2D const &point) override;
    virtual void addCurveTo(Vector2D const &point, Vector2D const &control1, Vector2D const &control2) override;
    virtual void moveTo(Vector2D const &point) override;
    virtual void closeSubpath() override;
    virtual void addRect(CGRect const &rect) override;
    virtual void addPath(std::shared_ptr<CGPath> const &path) override;
    virtual bool isEqual(CGPath *other) const override;
    virtual void enumerate(std::function<void(CGPathItem const &)>) override;
    
private:
    std::vector<CGPathItem> _items;
};

CGPathImpl::CGPathImpl() {
}

CGPathImpl::~CGPathImpl() {
}

CGRect CGPathImpl::boundingBox() const {
    bool isFirst = true;
    CGRect result(0.0, 0.0, 0.0, 0.0);
    
    for (const auto &item : _items) {
        switch (item.type) {
            case CGPathItem::Type::MoveTo: {
                addPointToBoundingRect(&isFirst, &result, &item.points[0]);
                break;
            }
            case CGPathItem::Type::LineTo: {
                addPointToBoundingRect(&isFirst, &result, &item.points[0]);
                break;
            }
            case CGPathItem::Type::CurveTo: {
                addPointToBoundingRect(&isFirst, &result, &item.points[0]);
                addPointToBoundingRect(&isFirst, &result, &item.points[1]);
                addPointToBoundingRect(&isFirst, &result, &item.points[2]);
                break;
            }
            case CGPathItem::Type::Close: {
                break;
            }
            default: {
                break;
            }
        }
    }
    
    return result;
}

bool CGPathImpl::empty() const {
    return _items.empty();
}

std::shared_ptr<CGPath> CGPathImpl::copyUsingTransform(CATransform3D const &transform) const {
    auto result = std::make_shared<CGPathImpl>();
    
    if (transform == CATransform3D::identity()) {
        result->_items = _items;
        return result;
    }
    
    result->_items.reserve(_items.capacity());
    for (auto &sourceItem : _items) {
        CGPathItem &item = result->_items.emplace_back(sourceItem.type);
        item.points[0] = transformVector(sourceItem.points[0], transform);
        item.points[1] = transformVector(sourceItem.points[1], transform);
        item.points[2] = transformVector(sourceItem.points[2], transform);
    }
    
    return result;
}

void CGPathImpl::addLineTo(Vector2D const &point) {
    CGPathItem &item = _items.emplace_back(CGPathItem::Type::LineTo);
    item.points[0] = point;
}

void CGPathImpl::addCurveTo(Vector2D const &point, Vector2D const &control1, Vector2D const &control2) {
    CGPathItem &item = _items.emplace_back(CGPathItem::Type::CurveTo);
    item.points[0] = control1;
    item.points[1] = control2;
    item.points[2] = point;
}

void CGPathImpl::moveTo(Vector2D const &point) {
    CGPathItem &item = _items.emplace_back(CGPathItem::Type::MoveTo);
    item.points[0] = point;
}

void CGPathImpl::closeSubpath() {
    _items.emplace_back(CGPathItem::Type::Close);
}

void CGPathImpl::addRect(CGRect const &rect) {
    assert(false);
    //CGPathAddRect(_path, nil, ::CGRectMake(rect.x, rect.y, rect.width, rect.height));
}

void CGPathImpl::addPath(std::shared_ptr<CGPath> const &path) {
    if (_items.size() == 0) {
        _items = std::static_pointer_cast<CGPathImpl>(path)->_items;
    } else {
        size_t totalItemCount = _items.size() + std::static_pointer_cast<CGPathImpl>(path)->_items.size();
        if (_items.capacity() < totalItemCount) {
            _items.reserve(totalItemCount);
        }
        for (const auto &item : std::static_pointer_cast<CGPathImpl>(path)->_items) {
            _items.push_back(item);
        }
    }
}

bool CGPathImpl::isEqual(CGPath *other) const {
    if (_items.size() != ((CGPathImpl *)other)->_items.size()) {
        return false;
    }
    
    for (size_t i = 0; i < _items.size(); i++) {
        if (_items[i] != ((CGPathImpl *)other)->_items[i]) {
            return false;
        }
    }
    
    return true;
}

void CGPathImpl::enumerate(std::function<void(CGPathItem const &)> f) {
    for (const auto &item : _items) {
        f(item);
    }
}

std::shared_ptr<CGPath> CGPath::makePath() {
    return std::static_pointer_cast<CGPath>(std::make_shared<CGPathImpl>());
}

}
