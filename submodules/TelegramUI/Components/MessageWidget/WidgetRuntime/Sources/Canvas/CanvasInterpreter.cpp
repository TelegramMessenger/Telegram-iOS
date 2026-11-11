#include "Sources/Canvas/CanvasInterpreter.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <initializer_list>
#include <utility>

namespace wr::canvas {

namespace {

constexpr double kPi = 3.14159265358979323846;

bool finite(std::initializer_list<double> values) {
    for (double v : values) {
        if (!std::isfinite(v)) {
            return false;
        }
    }
    return true;
}

/// An elliptical arc as cubic Béziers of at most a quarter turn each (twidget's arc_segments). Angles in radians, y
/// down, clockwise positive.
template <class Emit>
void arcSegments(double cx, double cy, double rx, double ry, double rotation, double start, double sweep, Emit emit) {
    const int segments = std::max(1, int(std::ceil(std::fabs(sweep) / (kPi / 2) - 1e-9)));
    const double step = sweep / segments;
    const double k = 4.0 / 3.0 * std::tan(step / 4);
    const double cr = std::cos(rotation), sr = std::sin(rotation);
    auto point = [&](double x, double y, double& ox, double& oy) {
        ox = cx + rx * x * cr - ry * y * sr;
        oy = cy + rx * x * sr + ry * y * cr;
    };
    double a = start;
    for (int i = 0; i < segments; i++) {
        const double b = a + step;
        const double ca = std::cos(a), sa = std::sin(a), cb = std::cos(b), sb = std::sin(b);
        double p1x, p1y, p2x, p2y, p3x, p3y;
        point(ca - k * sa, sa + k * ca, p1x, p1y);
        point(cb + k * sb, sb - k * cb, p2x, p2y);
        point(cb, sb, p3x, p3y);
        emit(p1x, p1y, p2x, p2y, p3x, p3y);
        a = b;
    }
}

int arcSegmentCount(double sweep) { return std::max(1, int(std::ceil(std::fabs(sweep) / (kPi / 2) - 1e-9))); }

/// HTML's arc sweep: a full turn when the angles span one in the drawing direction, else the difference reduced into
/// one turn of that direction.
double sweepOf(double start, double end, bool counterclockwise) {
    double sweep = end - start;
    if (!counterclockwise) {
        if (sweep >= 2 * kPi) {
            return 2 * kPi;
        }
        sweep = std::fmod(sweep, 2 * kPi);
        if (sweep < 0) {
            sweep += 2 * kPi;
        }
    } else {
        if (-sweep >= 2 * kPi) {
            return -2 * kPi;
        }
        sweep = std::fmod(sweep, 2 * kPi);
        if (sweep > 0) {
            sweep -= 2 * kPi;
        }
    }
    return sweep;
}

size_t pointsOf(PathVerb verb) {
    switch (verb) {
    case PathVerb::Move:
    case PathVerb::Line:
        return 1;
    case PathVerb::Quad:
        return 2;
    case PathVerb::Cubic:
        return 3;
    case PathVerb::Close:
        return 0;
    }
    return 0;
}

/// How many dashes and gaps a stroke of `o` makes with `dash` (whose entries sum to more than 0) from `offset` (V5d fix-wave
/// 2 review, C-1). Measured where the backend dashes: CanvasBitmap.mm strokes the device path through the inverse of the
/// op's float matrix, and nothing when that matrix is singular to it. A curve counts as its control polygon, which is no
/// shorter. Each subpath reaches the entry at the phase and every entry that starts by its end; the count is the larger of
/// that sum (the pattern restarting at each subpath) and the whole path's (it running on), so it bounds either. Infinite
/// when a length is not finite.
double dashSegments(const CanvasOp& o, std::span<const float> dash, double offset) {
    const double a = o.matrix[0], b = o.matrix[1], c = o.matrix[2], d = o.matrix[3], e = o.matrix[4], f = o.matrix[5];
    const double det = a * d - b * c;
    // CanvasBitmap's `invertible`.
    if (std::fabs(det) < 1e-12) {
        return 0;
    }
    const double ia = d / det, ib = -b / det, ic = -c / det, id = a / det;
    const double ie = (c * f - d * e) / det, jf = (b * e - a * f) / det;
    std::vector<double> starts;
    starts.reserve(dash.size());
    double period = 0;
    for (float v : dash) {
        starts.push_back(period);
        period += v;
    }
    const double entries = double(dash.size());
    // Entry starts in [0, x), or [0, x] when `inclusive`.
    auto startsBefore = [&](double x, bool inclusive) {
        const double periods = std::floor(x / period);
        const double r = std::clamp(x - periods * period, 0.0, period);
        const auto it = inclusive ? std::upper_bound(starts.begin(), starts.end(), r) : std::lower_bound(starts.begin(), starts.end(), r);
        return periods * entries + double(it - starts.begin());
    };
    double phase = std::fmod(offset, period);
    if (phase < 0) {
        phase += period;
    }
    auto reached = [&](double length) { return startsBefore(phase + length, true) - startsBefore(phase, false) + 1; };
    const std::vector<float>& p = o.path.points;
    auto user = [&](size_t i, double& x, double& y) {
        const double px = p[i], py = p[i + 1];
        x = ia * px + ic * py + ie;
        y = ib * px + id * py + jf;
    };
    double perSubpath = 0, total = 0, length = 0;
    bool drawn = false;
    auto endSubpath = [&] {
        if (drawn) {
            perSubpath += reached(length);
            total += length;
        }
        length = 0;
        drawn = false;
    };
    size_t point = 0;
    double sx = 0, sy = 0, cx = 0, cy = 0;
    for (PathVerb verb : o.path.verbs) {
        const size_t count = pointsOf(verb);
        if (verb == PathVerb::Move) {
            endSubpath();
            if (point + 1 < p.size()) {
                user(point, sx, sy);
                cx = sx;
                cy = sy;
            }
        } else if (verb == PathVerb::Close) {
            length += std::hypot(sx - cx, sy - cy);
            cx = sx;
            cy = sy;
            drawn = true;
            endSubpath();
        } else {
            for (size_t k = 0; k < count && point + 2 * k + 1 < p.size(); k++) {
                double x, y;
                user(point + 2 * k, x, y);
                length += std::hypot(x - cx, y - cy);
                cx = x;
                cy = y;
            }
            drawn = true;
        }
        point += 2 * count;
    }
    endSubpath();
    if (!std::isfinite(total) || !std::isfinite(perSubpath)) {
        return INFINITY;
    }
    return std::max(perSubpath, total > 0 ? reached(total) : 0.0);
}

using Polyline = std::vector<std::pair<double, double>>;

/// A geometry's subpaths as polylines, curves flattened to 16 segments each.
std::vector<Polyline> flatten(GeometryView g) {
    std::vector<Polyline> out;
    const float* p = g.points.data();
    const size_t n = g.points.size();
    size_t i = 0;
    double cx = 0, cy = 0, sx = 0, sy = 0;
    auto line = [&](double x, double y) {
        if (out.empty()) {
            out.push_back({{cx, cy}});
        }
        out.back().emplace_back(x, y);
        cx = x;
        cy = y;
    };
    for (PathVerb verb : g.verbs) {
        const size_t need = 2 * pointsOf(verb);
        if (i + need > n) {
            break;
        }
        switch (verb) {
        case PathVerb::Move:
            out.push_back({{p[i], p[i + 1]}});
            cx = sx = p[i];
            cy = sy = p[i + 1];
            break;
        case PathVerb::Line:
            line(p[i], p[i + 1]);
            break;
        case PathVerb::Quad: {
            const double x0 = cx, y0 = cy;
            for (int s = 1; s <= 16; s++) {
                const double t = s / 16.0, u = 1 - t;
                line(u * u * x0 + 2 * u * t * p[i] + t * t * p[i + 2], u * u * y0 + 2 * u * t * p[i + 1] + t * t * p[i + 3]);
            }
            break;
        }
        case PathVerb::Cubic: {
            const double x0 = cx, y0 = cy;
            for (int s = 1; s <= 16; s++) {
                const double t = s / 16.0, u = 1 - t;
                const double a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
                line(a * x0 + b * p[i] + c * p[i + 2] + d * p[i + 4], a * y0 + b * p[i + 1] + c * p[i + 3] + d * p[i + 5]);
            }
            break;
        }
        case PathVerb::Close:
            line(sx, sy);
            break;
        }
        i += need;
    }
    return out;
}

bool nearStroke(GeometryView g, double x, double y, double half) {
    for (const Polyline& poly : flatten(g)) {
        for (size_t k = 0; k + 1 < poly.size(); k++) {
            auto [x0, y0] = poly[k];
            auto [x1, y1] = poly[k + 1];
            const double dx = x1 - x0, dy = y1 - y0, len = dx * dx + dy * dy;
            const double t = len > 0 ? std::clamp(((x - x0) * dx + (y - y0) * dy) / len, 0.0, 1.0) : 0;
            if (std::hypot(x - (x0 + t * dx), y - (y0 + t * dy)) <= half) {
                return true;
            }
        }
    }
    return false;
}

Geometry transformed(GeometryView g, const Matrix& m) {
    Geometry out;
    out.verbs.assign(g.verbs.begin(), g.verbs.end());
    out.points.resize(g.points.size());
    for (size_t i = 0; i + 1 < g.points.size(); i += 2) {
        double x, y;
        m.apply(g.points[i], g.points[i + 1], x, y);
        out.points[i] = float(x);
        out.points[i + 1] = float(y);
    }
    return out;
}

/// A transient copy of a view, for an op.
Geometry toGeometry(GeometryView g) {
    Geometry out;
    out.verbs.assign(g.verbs.begin(), g.verbs.end());
    out.points.assign(g.points.begin(), g.points.end());
    return out;
}

/// Builds onto one path through one transform (twidget's path_method, split into calls).
class Builder {
public:
    Builder(PathData& p, const Matrix& m) : m_p(p), m_m(m) {}

    /// Whether `points` more points fit under kMaxPathPoints.
    bool room(size_t points) const { return m_p.geometry.points.size() / 2 + points <= path::kMaxPathPoints; }

    void move(double x, double y) {
        if (!room(1)) {
            return;
        }
        m_p.geometry.verbs.push_back(PathVerb::Move);
        auto [px, py] = point(x, y);
        m_p.sx = m_p.cx = px;
        m_p.sy = m_p.cy = py;
        m_p.open = m_p.hasPoint = true;
    }
    /// A segment with no current point starts its subpath at its own first point; after closePath, at the closed
    /// subpath's start. False when the start does not fit.
    bool ensure(double x, double y) {
        if (m_p.open) {
            return true;
        }
        if (!m_p.hasPoint) {
            move(x, y);
            return m_p.open;
        }
        if (!room(1)) {
            return false;
        }
        m_p.geometry.verbs.push_back(PathVerb::Move);
        m_p.geometry.points.push_back(m_p.cx);
        m_p.geometry.points.push_back(m_p.cy);
        m_p.sx = m_p.cx;
        m_p.sy = m_p.cy;
        m_p.open = true;
        return true;
    }
    void close() {
        if (!m_p.open) {
            return;
        }
        m_p.geometry.verbs.push_back(PathVerb::Close);
        m_p.cx = m_p.sx;
        m_p.cy = m_p.sy;
        m_p.open = false;
    }
    /// Room for `points` more and the subpath's start if one has to be opened, and the start opened.
    bool begin(size_t points, double x, double y) { return room(points + (m_p.open ? 0 : 1)) && ensure(x, y); }
    void line(double x, double y) {
        if (!begin(1, x, y)) {
            return;
        }
        m_p.geometry.verbs.push_back(PathVerb::Line);
        auto [px, py] = point(x, y);
        m_p.cx = px;
        m_p.cy = py;
    }
    void quad(double x1, double y1, double x, double y) {
        if (!begin(2, x1, y1)) {
            return;
        }
        m_p.geometry.verbs.push_back(PathVerb::Quad);
        point(x1, y1);
        auto [px, py] = point(x, y);
        m_p.cx = px;
        m_p.cy = py;
    }
    void cubic(double x1, double y1, double x2, double y2, double x, double y) {
        if (!room(3)) {
            return;
        }
        m_p.geometry.verbs.push_back(PathVerb::Cubic);
        point(x1, y1);
        point(x2, y2);
        auto [px, py] = point(x, y);
        m_p.cx = px;
        m_p.cy = py;
    }
    /// The arc of (rx, ry) about (cx, cy) from `start` through `sweep`, joined to the path by a line (or starting it).
    void arc(double cx, double cy, double rx, double ry, double rotation, double start, double sweep) {
        // The whole arc or none of it: its start, and three points per quarter turn.
        if (!room(2 + 3 * size_t(arcSegmentCount(sweep)))) {
            return;
        }
        const double cr = std::cos(rotation), sr = std::sin(rotation);
        const double x0 = cx + rx * std::cos(start) * cr - ry * std::sin(start) * sr;
        const double y0 = cy + rx * std::cos(start) * sr + ry * std::sin(start) * cr;
        if (m_p.hasPoint) {
            line(x0, y0);
        } else {
            move(x0, y0);
        }
        if (sweep == 0) {
            return;
        }
        arcSegments(cx, cy, rx, ry, rotation, start, sweep, [&](double a1, double b1, double a2, double b2, double a3, double b3) {
            cubic(a1, b1, a2, b2, a3, b3);
        });
    }
    /// The current point in the path's own space.
    bool current(double& x, double& y) const {
        Matrix inverse;
        if (!m_m.invert(inverse)) {
            return false;
        }
        inverse.apply(m_p.cx, m_p.cy, x, y);
        return true;
    }
    void setCurrent(double x, double y) {
        double px, py;
        m_m.apply(x, y, px, py);
        m_p.cx = float(px);
        m_p.cy = float(py);
        m_p.hasPoint = true;
    }

private:
    std::pair<float, float> point(double x, double y) {
        double px, py;
        m_m.apply(x, y, px, py);
        m_p.geometry.points.push_back(float(px));
        m_p.geometry.points.push_back(float(py));
        return {float(px), float(py)};
    }

    PathData& m_p;
    const Matrix& m_m;
};

/// A number of SVG path data, the whole token.
bool svgNumber(const std::string& token, double& out) {
    if (token.empty()) {
        return false;
    }
    char* end = nullptr;
    out = std::strtod(token.c_str(), &end);
    return end == token.c_str() + token.size() && std::isfinite(out);
}

} // namespace

Matrix Matrix::then(const Matrix& m) const {
    return Matrix{a * m.a + b * m.c,     a * m.b + b * m.d,     c * m.a + d * m.c,
                  c * m.b + d * m.d,     e * m.a + f * m.c + m.e, e * m.b + f * m.d + m.f};
}

bool Matrix::invert(Matrix& out) const {
    const double det = a * d - b * c;
    if (det == 0 || !std::isfinite(det)) {
        return false;
    }
    out = Matrix{d / det, -b / det, -c / det, a / det, (c * f - d * e) / det, (b * e - a * f) / det};
    return true;
}

void GradientData::addStop(double offset, Color color) {
    if (stops.size() >= kMaxStops) {
        return;
    }
    const Stop stop{float(offset), color};
    stops.insert(std::upper_bound(stops.begin(), stops.end(), stop, [](const Stop& x, const Stop& y) { return x.offset < y.offset; }),
                 stop);
}

namespace path {

void moveTo(PathData& p, const Matrix& m, double x, double y) {
    if (finite({x, y})) {
        Builder(p, m).move(x, y);
    }
}

void lineTo(PathData& p, const Matrix& m, double x, double y) {
    if (finite({x, y})) {
        Builder(p, m).line(x, y);
    }
}

void closePath(PathData& p) {
    Matrix identity;
    Builder(p, identity).close();
}

void quadraticCurveTo(PathData& p, const Matrix& m, double cpx, double cpy, double x, double y) {
    if (finite({cpx, cpy, x, y})) {
        Builder(p, m).quad(cpx, cpy, x, y);
    }
}

void bezierCurveTo(PathData& p, const Matrix& m, double cp1x, double cp1y, double cp2x, double cp2y, double x, double y) {
    if (!finite({cp1x, cp1y, cp2x, cp2y, x, y})) {
        return;
    }
    Builder b(p, m);
    if (b.begin(3, cp1x, cp1y)) {
        b.cubic(cp1x, cp1y, cp2x, cp2y, x, y);
    }
}

void arcTo(PathData& p, const Matrix& m, double x1, double y1, double x2, double y2, double radius) {
    if (!finite({x1, y1, x2, y2, radius})) {
        return;
    }
    Builder b(p, m);
    if (!p.hasPoint) {
        b.move(x1, y1);
        return;
    }
    double x0, y0;
    if (!b.current(x0, y0)) {
        return;
    }
    const double ax = x0 - x1, ay = y0 - y1, bx = x2 - x1, by = y2 - y1;
    const double la = std::hypot(ax, ay), lb = std::hypot(bx, by);
    const double cross = ax * by - ay * bx;
    // HTML: a point repeated, a zero radius or the three points on a line: a straight line to (x1, y1).
    if (radius == 0 || la == 0 || lb == 0 || std::fabs(cross) < 1e-9 * la * lb) {
        b.line(x1, y1);
        return;
    }
    const double cosine = (ax * bx + ay * by) / (la * lb);
    const double angle = std::acos(std::clamp(cosine, -1.0, 1.0));
    const double tangent = radius / std::tan(angle / 2);
    const double t1x = x1 + ax / la * tangent, t1y = y1 + ay / la * tangent;
    const double t2x = x1 + bx / lb * tangent, t2y = y1 + by / lb * tangent;
    const double mx = ax / la + bx / lb, my = ay / la + by / lb, ml = std::hypot(mx, my);
    const double distance = radius / std::sin(angle / 2);
    const double cx = x1 + mx / ml * distance, cy = y1 + my / ml * distance;
    const double start = std::atan2(t1y - cy, t1x - cx), end = std::atan2(t2y - cy, t2x - cx);
    // The arc's own line joins the current point to its start, the first tangent point.
    b.arc(cx, cy, radius, radius, 0, start, sweepOf(start, end, cross > 0));
}

void rect(PathData& p, const Matrix& m, double x, double y, double w, double h) {
    if (!finite({x, y, w, h})) {
        return;
    }
    Builder b(p, m);
    if (!b.room(5)) {
        return;
    }
    b.move(x, y);
    b.line(x + w, y);
    b.line(x + w, y + h);
    b.line(x, y + h);
    b.close();
}

void roundRect(PathData& p, const Matrix& m, double x, double y, double w, double h, const std::array<double, 8>& radii) {
    if (!finite({x, y, w, h})) {
        return;
    }
    // Corners as (x, y): upper-left, upper-right, lower-right, lower-left.
    std::array<double, 8> r = radii;
    auto swapCorners = [&](int i, int j) {
        std::swap(r[2 * i], r[2 * j]);
        std::swap(r[2 * i + 1], r[2 * j + 1]);
    };
    // HTML: a negative width or height flips the rectangle, and its corners with it.
    if (w < 0) {
        x += w;
        w = -w;
        swapCorners(0, 1);
        swapCorners(3, 2);
    }
    if (h < 0) {
        y += h;
        h = -h;
        swapCorners(0, 3);
        swapCorners(1, 2);
    }
    // HTML: radii that overlap are scaled down together.
    const double top = r[0] + r[2], right = r[3] + r[5], bottom = r[4] + r[6], left = r[1] + r[7];
    double scale = 1;
    for (auto [side, sum] : {std::pair{w, top}, std::pair{h, right}, std::pair{w, bottom}, std::pair{h, left}}) {
        if (sum > 0) {
            scale = std::min(scale, side / sum);
        }
    }
    for (double& v : r) {
        v *= scale;
    }
    Builder b(p, m);
    if (!b.room(1 + 4 * 2 + 4 * 3)) {
        return;
    }
    auto corner = [&](double cx, double cy, double rx, double ry, double start, double cornerX, double cornerY) {
        if (rx > 0 && ry > 0) {
            arcSegments(cx, cy, rx, ry, 0, start, kPi / 2, [&](double a1, double b1, double a2, double b2, double a3, double b3) {
                b.cubic(a1, b1, a2, b2, a3, b3);
            });
        } else {
            b.line(cornerX, cornerY);
        }
    };
    b.move(x + r[0], y);
    b.line(x + w - r[2], y);
    corner(x + w - r[2], y + r[3], r[2], r[3], -kPi / 2, x + w, y);
    b.line(x + w, y + h - r[5]);
    corner(x + w - r[4], y + h - r[5], r[4], r[5], 0, x + w, y + h);
    b.line(x + r[6], y + h);
    corner(x + r[6], y + h - r[7], r[6], r[7], kPi / 2, x, y + h);
    b.line(x, y + r[1]);
    corner(x + r[0], y + r[1], r[0], r[1], kPi, x, y);
    b.close();
    // HTML: the next subpath starts at (x, y).
    b.setCurrent(x, y);
}

void arc(PathData& p, const Matrix& m, double x, double y, double radius, double start, double end, bool counterclockwise) {
    if (finite({x, y, radius, start, end})) {
        Builder(p, m).arc(x, y, radius, radius, 0, start, sweepOf(start, end, counterclockwise));
    }
}

void ellipse(PathData& p, const Matrix& m, double x, double y, double rx, double ry, double rotation, double start,
             double end, bool counterclockwise) {
    if (finite({x, y, rx, ry, rotation, start, end})) {
        Builder(p, m).arc(x, y, rx, ry, rotation, start, sweepOf(start, end, counterclockwise));
    }
}

void addPath(PathData& to, const PathData& from, const Matrix& transform) {
    if (&to == &from) {
        PathData copy = from;
        addPath(to, copy, transform);
        return;
    }
    if (to.geometry.points.size() / 2 + from.geometry.points.size() / 2 > kMaxPathPoints) {
        return;
    }
    const Geometry g = transformed(from.geometry.view(), transform);
    to.geometry.verbs.insert(to.geometry.verbs.end(), g.verbs.begin(), g.verbs.end());
    to.geometry.points.insert(to.geometry.points.end(), g.points.begin(), g.points.end());
    if (!g.verbs.empty()) {
        to.open = from.open;
        to.hasPoint = from.hasPoint;
        double x, y;
        transform.apply(from.cx, from.cy, x, y);
        to.cx = float(x);
        to.cy = float(y);
        transform.apply(from.sx, from.sy, x, y);
        to.sx = float(x);
        to.sy = float(y);
    }
}

void appendSVG(PathData& p, std::string_view d) {
    std::vector<std::string> tokens;
    std::string current;
    auto flush = [&] {
        if (!current.empty()) {
            tokens.push_back(std::move(current));
        }
        current.clear();
    };
    for (char ch : d) {
        const bool letter = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
        if (letter && ch != 'e' && ch != 'E') {
            flush();
            tokens.emplace_back(1, ch);
        } else if (ch == ',' || ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r' || ch == '\f') {
            flush();
        } else if (ch == '-' && !current.empty() && current.back() != 'e' && current.back() != 'E') {
            flush();
            current = "-";
        } else if (ch == '.' && current.find('.') != std::string::npos) {
            flush();
            current = ".";
        } else {
            current.push_back(ch);
        }
    }
    flush();
    Matrix identity;
    Builder b(p, identity);
    size_t i = 0;
    char command = 0;
    double px = 0, py = 0;
    if (p.hasPoint) {
        px = p.cx;
        py = p.cy;
    }
    bool hasControl = false;
    double lcx = 0, lcy = 0;
    auto next = [&](double& v) {
        if (i >= tokens.size() || !svgNumber(tokens[i], v)) {
            return false;
        }
        i++;
        return true;
    };
    while (i < tokens.size()) {
        const std::string& t = tokens[i];
        if (t.size() == 1 && ((t[0] >= 'a' && t[0] <= 'z') || (t[0] >= 'A' && t[0] <= 'Z'))) {
            command = t[0];
            i++;
            if (command == 'Z' || command == 'z') {
                b.close();
                px = p.cx;
                py = p.cy;
                hasControl = false;
                continue;
            }
        } else if (command == 0) {
            return; // SVG: path data starts with a command
        }
        const bool relative = command >= 'a' && command <= 'z';
        const double ox = relative ? px : 0, oy = relative ? py : 0;
        switch (command & ~0x20) {
        case 'M': {
            double x, y;
            if (!next(x) || !next(y)) {
                return;
            }
            px = ox + x;
            py = oy + y;
            b.move(px, py);
            command = relative ? 'l' : 'L';
            hasControl = false;
            break;
        }
        case 'L': {
            double x, y;
            if (!next(x) || !next(y)) {
                return;
            }
            px = ox + x;
            py = oy + y;
            b.line(px, py);
            hasControl = false;
            break;
        }
        case 'H': {
            double x;
            if (!next(x)) {
                return;
            }
            px = ox + x;
            b.line(px, py);
            hasControl = false;
            break;
        }
        case 'V': {
            double y;
            if (!next(y)) {
                return;
            }
            py = oy + y;
            b.line(px, py);
            hasControl = false;
            break;
        }
        case 'C': {
            double x1, y1, x2, y2, x, y;
            if (!next(x1) || !next(y1) || !next(x2) || !next(y2) || !next(x) || !next(y)) {
                return;
            }
            if (b.begin(3, px, py)) {
                b.cubic(ox + x1, oy + y1, ox + x2, oy + y2, ox + x, oy + y);
            }
            lcx = ox + x2;
            lcy = oy + y2;
            hasControl = true;
            px = ox + x;
            py = oy + y;
            break;
        }
        case 'S': {
            double x2, y2, x, y;
            if (!next(x2) || !next(y2) || !next(x) || !next(y)) {
                return;
            }
            const double c1x = hasControl ? 2 * px - lcx : px, c1y = hasControl ? 2 * py - lcy : py;
            if (b.begin(3, px, py)) {
                b.cubic(c1x, c1y, ox + x2, oy + y2, ox + x, oy + y);
            }
            lcx = ox + x2;
            lcy = oy + y2;
            hasControl = true;
            px = ox + x;
            py = oy + y;
            break;
        }
        case 'Q': {
            double x1, y1, x, y;
            if (!next(x1) || !next(y1) || !next(x) || !next(y)) {
                return;
            }
            b.quad(ox + x1, oy + y1, ox + x, oy + y);
            lcx = ox + x1;
            lcy = oy + y1;
            hasControl = true;
            px = ox + x;
            py = oy + y;
            break;
        }
        case 'T': {
            double x, y;
            if (!next(x) || !next(y)) {
                return;
            }
            const double cx = hasControl ? 2 * px - lcx : px, cy = hasControl ? 2 * py - lcy : py;
            b.quad(cx, cy, ox + x, oy + y);
            lcx = cx;
            lcy = cy;
            hasControl = true;
            px = ox + x;
            py = oy + y;
            break;
        }
        case 'A': {
            double rx, ry, rotation, large, sweepFlag, x, y;
            if (!next(rx) || !next(ry) || !next(rotation) || !next(large) || !next(sweepFlag) || !next(x) || !next(y)) {
                return;
            }
            const double x2 = ox + x, y2 = oy + y;
            rx = std::fabs(rx);
            ry = std::fabs(ry);
            if (rx == 0 || ry == 0 || (x2 == px && y2 == py)) {
                b.line(x2, y2);
            } else if (b.ensure(px, py)) {
                // SVG 1.1 F.6.5: endpoint to centre parameterization.
                const double phi = rotation * kPi / 180, c = std::cos(phi), s = std::sin(phi);
                const double dx = (px - x2) / 2, dy = (py - y2) / 2;
                const double x1p = c * dx + s * dy, y1p = -s * dx + c * dy;
                const double lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
                if (lambda > 1) {
                    rx *= std::sqrt(lambda);
                    ry *= std::sqrt(lambda);
                }
                const double num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
                const double den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
                const double k = std::sqrt(std::max(0.0, num / den)) * ((large != 0) == (sweepFlag != 0) ? -1 : 1);
                const double cxp = k * rx * y1p / ry, cyp = -k * ry * x1p / rx;
                const double cx = c * cxp - s * cyp + (px + x2) / 2, cy = s * cxp + c * cyp + (py + y2) / 2;
                auto angle = [](double ux, double uy, double vx, double vy) { return std::atan2(ux * vy - uy * vx, ux * vx + uy * vy); };
                const double theta = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
                double delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
                if (sweepFlag == 0 && delta > 0) {
                    delta -= 2 * kPi;
                } else if (sweepFlag != 0 && delta < 0) {
                    delta += 2 * kPi;
                }
                if (b.room(3 * size_t(arcSegmentCount(delta)))) {
                    arcSegments(cx, cy, rx, ry, phi, theta, delta, [&](double a1, double b1, double a2, double b2, double a3, double b3) {
                        b.cubic(a1, b1, a2, b2, a3, b3);
                    });
                }
            }
            px = x2;
            py = y2;
            hasControl = false;
            break;
        }
        default:
            return;
        }
    }
}

bool contains(GeometryView g, double x, double y, bool evenodd) {
    int winding = 0, crossings = 0;
    for (const Polyline& poly : flatten(g)) {
        if (poly.size() < 2) {
            continue;
        }
        // Subpaths fill as if closed.
        for (size_t k = 0; k < poly.size(); k++) {
            auto [x0, y0] = poly[k];
            auto [x1, y1] = poly[(k + 1) % poly.size()];
            if ((y0 <= y) != (y1 <= y)) {
                const double at = x0 + (y - y0) * (x1 - x0) / (y1 - y0);
                if (at > x) {
                    crossings++;
                    winding += y1 > y0 ? 1 : -1;
                }
            }
        }
    }
    return evenodd ? (crossings & 1) != 0 : winding != 0;
}

} // namespace path

// The interpreter.

void CanvasInterpreter::setSize(int width, int height) {
    m_width = std::max(0, width);
    m_height = std::max(0, height);
}

void CanvasInterpreter::reset(std::vector<CanvasOp>* out) {
    m_state = State();
    m_stack.clear();
    m_overflowedSaves = 0;
    m_path = PathData(m_rt);
    if (out && drawable()) {
        CanvasOp reset;
        reset.kind = CanvasOp::Kind::Reset;
        out->push_back(std::move(reset));
    }
}

void CanvasInterpreter::save() {
    if (m_stack.size() >= kMaxStack) {
        m_overflowedSaves++;
        return;
    }
    m_stack.push_back(m_state);
}

void CanvasInterpreter::restore() {
    if (m_overflowedSaves > 0) {
        m_overflowedSaves--;
        return;
    }
    if (!m_stack.empty()) {
        m_state = std::move(m_stack.back());
        m_stack.pop_back();
    }
}

void CanvasInterpreter::concat(const Matrix& m) { m_state.matrix = m.then(m_state.matrix); }

void CanvasInterpreter::scale(double x, double y) {
    if (finite({x, y})) {
        concat(Matrix{x, 0, 0, y, 0, 0});
    }
}

void CanvasInterpreter::rotate(double angle) {
    if (finite({angle})) {
        const double c = std::cos(angle), s = std::sin(angle);
        concat(Matrix{c, s, -s, c, 0, 0});
    }
}

void CanvasInterpreter::translate(double x, double y) {
    if (finite({x, y})) {
        concat(Matrix{1, 0, 0, 1, x, y});
    }
}

void CanvasInterpreter::transform(double a, double b, double c, double d, double e, double f) {
    if (finite({a, b, c, d, e, f})) {
        concat(Matrix{a, b, c, d, e, f});
    }
}

void CanvasInterpreter::setTransform(double a, double b, double c, double d, double e, double f) {
    if (finite({a, b, c, d, e, f})) {
        m_state.matrix = Matrix{a, b, c, d, e, f};
    }
}

void CanvasInterpreter::resetTransform() { m_state.matrix = Matrix(); }

void CanvasInterpreter::setFillColor(Color color) { m_state.fill = Style{false, color, nullptr}; }
void CanvasInterpreter::setStrokeColor(Color color) { m_state.stroke = Style{false, color, nullptr}; }
void CanvasInterpreter::setFillGradient(std::shared_ptr<const GradientData> gradient) {
    m_state.fill = Style{true, Color{}, std::move(gradient)};
}
void CanvasInterpreter::setStrokeGradient(std::shared_ptr<const GradientData> gradient) {
    m_state.stroke = Style{true, Color{}, std::move(gradient)};
}

void CanvasInterpreter::setLineWidth(double width) {
    if (std::isfinite(width) && width > 0) {
        m_state.lineWidth = float(width);
    }
}

void CanvasInterpreter::setLineCap(uint8_t cap) { m_state.lineCap = cap; }
void CanvasInterpreter::setLineJoin(uint8_t join) { m_state.lineJoin = join; }

void CanvasInterpreter::setMiterLimit(double limit) {
    if (std::isfinite(limit) && limit > 0) {
        m_state.miterLimit = float(limit);
    }
}

bool CanvasInterpreter::setLineDash(std::span<const double> segments) {
    if (segments.size() > kMaxDash) {
        return false;
    }
    for (double v : segments) {
        if (!std::isfinite(v) || v < 0) {
            return false;
        }
    }
    if (segments.empty()) {
        m_state.dash.reset();
        return true;
    }
    Vector<float> dash{JSAllocator<float>(m_rt)};
    dash.assign(segments.begin(), segments.end());
    if (segments.size() % 2 == 1) {
        dash.insert(dash.end(), segments.begin(), segments.end());
    }
    m_state.dash = std::allocate_shared<Vector<float>>(JSAllocator<Vector<float>>(m_rt), std::move(dash));
    return true;
}

std::vector<double> CanvasInterpreter::lineDash() const {
    const std::span<const float> d = dash();
    return std::vector<double>(d.begin(), d.end());
}

void CanvasInterpreter::setLineDashOffset(double offset) {
    if (std::isfinite(offset)) {
        m_state.dashOffset = float(offset);
    }
}

void CanvasInterpreter::setGlobalAlpha(double alpha) {
    if (std::isfinite(alpha) && alpha >= 0 && alpha <= 1) {
        m_state.alpha = float(alpha);
    }
}

CanvasOp CanvasInterpreter::op(CanvasOp::Kind kind) const {
    CanvasOp o;
    o.kind = kind;
    const Matrix& m = m_state.matrix;
    o.matrix[0] = float(m.a);
    o.matrix[1] = float(m.b);
    o.matrix[2] = float(m.c);
    o.matrix[3] = float(m.d);
    o.matrix[4] = float(m.e);
    o.matrix[5] = float(m.f);
    o.alpha = m_state.alpha;
    o.clip = m_state.clip;
    o.smoothing = m_state.smoothing;
    return o;
}

Paint CanvasInterpreter::paintOf(const Style& style) {
    Paint out;
    if (!style.gradient) {
        out.color = style.color;
        return out;
    }
    const Paint nothing{Paint::Kind::Solid, Color{0, 0, 0, 0}, {}, {}};
    const GradientData* g = style.data.get();
    if (!g || g->kind == GradientData::Kind::None || g->stops.empty()) {
        return nothing;
    }
    const double* a = g->args;
    // HTML: a linear gradient whose ends meet, or a radial one whose circles are the same, paints nothing.
    if (g->kind == GradientData::Kind::Linear && a[0] == a[2] && a[1] == a[3]) {
        return nothing;
    }
    if (g->kind == GradientData::Kind::Radial && a[0] == a[3] && a[1] == a[4] && a[2] == a[5]) {
        return nothing;
    }
    out.kind = g->kind == GradientData::Kind::Linear ? Paint::Kind::Linear : Paint::Kind::Radial;
    for (int i = 0; i < 6; i++) {
        out.args[i] = float(a[i]);
    }
    out.stops.assign(g->stops.begin(), g->stops.end());
    return out;
}

Geometry CanvasInterpreter::rectGeometry(double x, double y, double w, double h) const {
    // path::rect's subpath, built here: the op drops it within the call, so it stays out of the JS heap (V5d fix-wave
    // review, M-D).
    Geometry g;
    if (!finite({x, y, w, h})) {
        return g;
    }
    g.verbs = {PathVerb::Move, PathVerb::Line, PathVerb::Line, PathVerb::Line, PathVerb::Close};
    const double corners[4][2] = {{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}};
    g.points.reserve(8);
    for (const auto& corner : corners) {
        double px, py;
        m_state.matrix.apply(corner[0], corner[1], px, py);
        g.points.push_back(float(px));
        g.points.push_back(float(py));
    }
    return g;
}

void CanvasInterpreter::fillGeometry(Geometry path, bool evenodd, std::vector<CanvasOp>& out) {
    if (!drawable() || path.empty()) {
        return;
    }
    CanvasOp o = op(CanvasOp::Kind::Fill);
    o.paint = paintOf(m_state.fill);
    o.path = std::move(path);
    o.evenodd = evenodd;
    out.push_back(std::move(o));
}

void CanvasInterpreter::strokeGeometry(Geometry path, std::vector<CanvasOp>& out) {
    if (!drawable() || path.empty()) {
        return;
    }
    CanvasOp o = op(CanvasOp::Kind::Stroke);
    o.paint = paintOf(m_state.stroke);
    o.path = std::move(path);
    o.lineWidth = m_state.lineWidth;
    o.lineCap = m_state.lineCap;
    o.lineJoin = m_state.lineJoin;
    o.miterLimit = m_state.miterLimit;
    o.dashOffset = m_state.dashOffset;
    // The dashes the stroke makes; past kMaxDashSegments, or with a length that is not finite, it is solid.
    double pattern = 0;
    const std::span<const float> d = dash();
    for (float v : d) {
        pattern += v;
    }
    if (pattern > 0) {
        const double segments = dashSegments(o, d, m_state.dashOffset);
        if (!(segments <= double(kMaxDashSegments))) {
            o.dashDropped = true;
        } else {
            o.dashes.assign(d.begin(), d.end());
        }
    }
    out.push_back(std::move(o));
}

void CanvasInterpreter::clearRect(double x, double y, double w, double h, std::vector<CanvasOp>& out) {
    if (!drawable() || !finite({x, y, w, h}) || w == 0 || h == 0) {
        return;
    }
    CanvasOp o = op(CanvasOp::Kind::Clear);
    o.path = rectGeometry(x, y, w, h);
    out.push_back(std::move(o));
}

void CanvasInterpreter::fillRect(double x, double y, double w, double h, std::vector<CanvasOp>& out) {
    if (finite({x, y, w, h}) && w != 0 && h != 0) {
        fillGeometry(rectGeometry(x, y, w, h), false, out);
    }
}

void CanvasInterpreter::strokeRect(double x, double y, double w, double h, std::vector<CanvasOp>& out) {
    if (!finite({x, y, w, h}) || (w == 0 && h == 0)) {
        return;
    }
    strokeGeometry(rectGeometry(x, y, w, h), out);
}

void CanvasInterpreter::fill(const PathData* p, bool evenodd, std::vector<CanvasOp>& out) {
    fillGeometry(p ? transformed(p->geometry.view(), m_state.matrix) : toGeometry(m_path.geometry.view()), evenodd, out);
}

void CanvasInterpreter::stroke(const PathData* p, std::vector<CanvasOp>& out) {
    strokeGeometry(p ? transformed(p->geometry.view(), m_state.matrix) : toGeometry(m_path.geometry.view()), out);
}

bool CanvasInterpreter::clip(const PathData* p, bool evenodd) {
    if (m_state.clip && m_state.clip->depth >= kMaxClipDepth) {
        return false;
    }
    RetainedGeometry path(m_rt);
    if (p) {
        const Geometry device = transformed(p->geometry.view(), m_state.matrix);
        path.verbs.assign(device.verbs.begin(), device.verbs.end());
        path.points.assign(device.points.begin(), device.points.end());
    } else {
        path.verbs.assign(m_path.geometry.verbs.begin(), m_path.geometry.verbs.end());
        path.points.assign(m_path.geometry.points.begin(), m_path.geometry.points.end());
    }
    // One node on the chain, in the JS heap; an empty path clips everything away.
    m_state.clip = std::allocate_shared<ClipNode>(JSAllocator<ClipNode>(m_rt), std::move(path), evenodd, m_state.clip);
    return true;
}

bool CanvasInterpreter::isPointInPath(const PathData* p, double x, double y, bool evenodd) const {
    if (!finite({x, y})) {
        return false;
    }
    if (p) {
        const Geometry device = transformed(p->geometry.view(), m_state.matrix);
        return path::contains(device.view(), x, y, evenodd);
    }
    return path::contains(m_path.geometry.view(), x, y, evenodd);
}

bool CanvasInterpreter::isPointInStroke(const PathData* p, double x, double y) const {
    if (!finite({x, y})) {
        return false;
    }
    const Matrix& m = m_state.matrix;
    const double half = m_state.lineWidth * std::sqrt(std::fabs(m.a * m.d - m.b * m.c)) / 2;
    if (p) {
        const Geometry device = transformed(p->geometry.view(), m);
        return nearStroke(device.view(), x, y, half);
    }
    return nearStroke(m_path.geometry.view(), x, y, half);
}

void CanvasInterpreter::fillText(std::string_view text, double x, double y, std::optional<double> maxWidth,
                                 std::vector<CanvasOp>& out) {
    this->text(text, x, y, maxWidth, false, out);
}

void CanvasInterpreter::strokeText(std::string_view text, double x, double y, std::optional<double> maxWidth,
                                   std::vector<CanvasOp>& out) {
    this->text(text, x, y, maxWidth, true, out);
}

void CanvasInterpreter::text(std::string_view full, double x, double y, std::optional<double> maxWidth, bool stroke,
                             std::vector<CanvasOp>& out) {
    if (!drawable() || !finite({x, y}) || (maxWidth && (std::isnan(*maxWidth) || *maxWidth <= 0))) {
        return;
    }
    // Cut at a UTF-8 boundary; HTML replaces ASCII whitespace with spaces.
    size_t cut = std::min(full.size(), kMaxTextBytes);
    while (cut < full.size() && cut > 0 && (uint8_t(full[cut]) & 0xC0) == 0x80) {
        cut--;
    }
    std::string s(full.substr(0, cut));
    for (char& ch : s) {
        if (ch == '\t' || ch == '\n' || ch == '\f' || ch == '\r') {
            ch = ' ';
        }
    }
    std::optional<CanvasHost::Font> font = m_host.font(textOr(m_state.font, kDefaultFont));
    if (!font || !font->font || s.empty()) {
        return;
    }
    const double width = m_host.textWidth(*font->font, s);
    CanvasOp o = op(CanvasOp::Kind::Text);
    o.paint = paintOf(stroke ? m_state.stroke : m_state.fill);
    TextAlign align = m_state.align;
    if (align == TextAlign::Start) {
        align = m_state.rtl ? TextAlign::Right : TextAlign::Left;
    } else if (align == TextAlign::End) {
        align = m_state.rtl ? TextAlign::Left : TextAlign::Right;
    }
    o.textDx = float(align == TextAlign::Center ? -width / 2 : align == TextAlign::Right ? -width : 0);
    double shift = 0;
    switch (m_state.baseline) {
    case TextBaseline::Top:
        shift = font->ascent;
        break;
    case TextBaseline::Hanging:
        shift = 0.8 * font->ascent;
        break;
    case TextBaseline::Middle:
        shift = (font->ascent - font->descent) / 2;
        break;
    case TextBaseline::Alphabetic:
        break;
    case TextBaseline::Ideographic:
    case TextBaseline::Bottom:
        shift = -font->descent;
        break;
    }
    o.x = float(x);
    o.y = float(y + shift);
    if (maxWidth && std::isfinite(*maxWidth) && width > *maxWidth) {
        o.scaleX = float(*maxWidth / width);
    }
    o.font = std::move(font->font);
    o.text = std::move(s);
    o.strokeText = stroke;
    o.lineWidth = m_state.lineWidth;
    o.lineJoin = m_state.lineJoin;
    o.miterLimit = m_state.miterLimit;
    out.push_back(std::move(o));
}

void CanvasInterpreter::drawImage(std::shared_ptr<const HostImage> source, double sourceWidth, double sourceHeight,
                                  double sx, double sy, double sw, double sh, double dx, double dy, double dw, double dh,
                                  std::vector<CanvasOp>& out) {
    if (!drawable() || !finite({sx, sy, sw, sh, dx, dy, dw, dh}) || sourceWidth <= 0 || sourceHeight <= 0) {
        return;
    }
    // HTML: negative sizes flip their rect; a zero one paints nothing.
    if (sw < 0) {
        sx += sw;
        sw = -sw;
    }
    if (sh < 0) {
        sy += sh;
        sh = -sh;
    }
    if (dw < 0) {
        dx += dw;
        dw = -dw;
    }
    if (dh < 0) {
        dy += dh;
        dh = -dh;
    }
    if (sw == 0 || sh == 0 || dw == 0 || dh == 0) {
        return;
    }
    // The source rect clipped to the source, and the destination rect with it in proportion.
    const double scaleX = dw / sw, scaleY = dh / sh;
    const double x0 = std::max(sx, 0.0), y0 = std::max(sy, 0.0);
    const double x1 = std::min(sx + sw, sourceWidth), y1 = std::min(sy + sh, sourceHeight);
    if (x1 <= x0 || y1 <= y0) {
        return;
    }
    CanvasOp o = op(CanvasOp::Kind::Image);
    o.source = std::move(source);
    o.sourceWidth = float(sourceWidth);
    o.sourceHeight = float(sourceHeight);
    o.sx = float(x0);
    o.sy = float(y0);
    o.sw = float(x1 - x0);
    o.sh = float(y1 - y0);
    o.dx = float(dx + (x0 - sx) * scaleX);
    o.dy = float(dy + (y0 - sy) * scaleY);
    o.dw = float((x1 - x0) * scaleX);
    o.dh = float((y1 - y0) * scaleY);
    out.push_back(std::move(o));
}

} // namespace wr::canvas
