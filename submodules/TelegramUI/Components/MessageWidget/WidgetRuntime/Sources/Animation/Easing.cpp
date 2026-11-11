#include "Sources/Animation/Easing.h"

#include <algorithm>
#include <cmath>
#include <optional>
#include <vector>

#include "Sources/Animation/CSSText.h"

namespace wr::animation {

namespace {

bool isDigit(char c) { return c >= '0' && c <= '9'; }

/// twidget's `bezier_at`: y at `x` in [0, 1] (Newton–Raphson, then bisection).
double bezierAt(double x1, double y1, double x2, double y2, double x) {
    if (x <= 0) {
        return 0;
    }
    if (x >= 1) {
        return 1;
    }
    const double cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
    const double cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
    auto sampleX = [&](double t) { return ((ax * t + bx) * t + cx) * t; };
    auto sampleY = [&](double t) { return ((ay * t + by) * t + cy) * t; };
    auto derivativeX = [&](double t) { return (3 * ax * t + 2 * bx) * t + cx; };
    double t = x;
    for (int i = 0; i < 8; i++) {
        const double error = sampleX(t) - x;
        if (std::fabs(error) < 1e-6) {
            return sampleY(t);
        }
        const double d = derivativeX(t);
        if (std::fabs(d) < 1e-6) {
            break;
        }
        t -= error / d;
    }
    double lo = 0, hi = 1;
    t = x;
    for (int i = 0; i < 30; i++) {
        const double value = sampleX(t);
        if (std::fabs(value - x) < 1e-6) {
            break;
        }
        if (value < x) {
            lo = t;
        } else {
            hi = t;
        }
        t = (lo + hi) / 2;
    }
    return sampleY(t);
}

/// The reference's number: `[+-]?(\d+\.?\d*|\.\d+)(e[+-]?\d+)?`, finite; no units, no calc().
std::optional<double> plainNumber(std::string_view raw) {
    const std::string t = trimmed(raw);
    size_t i = 0;
    const size_t n = t.size();
    if (i < n && (t[i] == '+' || t[i] == '-')) {
        i++;
    }
    const size_t integerStart = i;
    while (i < n && isDigit(t[i])) {
        i++;
    }
    if (i > integerStart) {
        if (i < n && t[i] == '.') {
            i++;
            while (i < n && isDigit(t[i])) {
                i++;
            }
        }
    } else {
        if (i >= n || t[i] != '.') {
            return std::nullopt;
        }
        i++;
        const size_t fractionStart = i;
        while (i < n && isDigit(t[i])) {
            i++;
        }
        if (i == fractionStart) {
            return std::nullopt;
        }
    }
    if (i < n && (t[i] == 'e' || t[i] == 'E')) {
        i++;
        if (i < n && (t[i] == '+' || t[i] == '-')) {
            i++;
        }
        const size_t exponentStart = i;
        while (i < n && isDigit(t[i])) {
            i++;
        }
        if (i == exponentStart) {
            return std::nullopt;
        }
    }
    if (i != n) {
        return std::nullopt;
    }
    return parseNumber(t);
}

/// JavaScript's String(number), through the engine (no script runs).
std::string jsNumber(JSContext* ctx, double v) {
    JSValue number = JS_NewFloat64(ctx, v);
    const char* text = JS_ToCString(ctx, number);
    JS_FreeValue(ctx, number);
    if (!text) {
        JS_FreeValue(ctx, JS_GetException(ctx));
        throw std::bad_alloc();
    }
    std::string out = text;
    JS_FreeCString(ctx, text);
    return out;
}

/// twidget's `linear_function` with the reference's bounds: 2..256 items, inputs only as percentages.
bool parseLinear(std::string_view body, Easing& out) {
    struct Point {
        double output;
        std::optional<double> input;
    };
    std::vector<Point> points;
    const std::vector<std::string> items = splitTopLevel(body, ',');
    if (items.size() < 2 || items.size() > 256) {
        return false;
    }
    for (const std::string& item : items) {
        std::vector<std::string> parts;
        for (const std::string& p : splitTopLevel(item, ' ')) {
            if (!trimmed(p).empty()) {
                parts.push_back(trimmed(p));
            }
        }
        if (parts.empty() || parts.size() > 3) {
            return false;
        }
        const std::optional<double> output = plainNumber(parts[0]);
        if (!output) {
            return false;
        }
        if (parts.size() == 1) {
            points.push_back({*output, std::nullopt});
        }
        for (size_t i = 1; i < parts.size(); i++) {
            if (parts[i].size() < 2 || parts[i].back() != '%') {
                return false;
            }
            const std::optional<double> input = plainNumber(std::string_view(parts[i]).substr(0, parts[i].size() - 1));
            if (!input) {
                return false;
            }
            points.push_back({*output, *input / 100});
        }
    }
    if (!points[0].input) {
        points[0].input = 0;
    }
    if (!points.back().input) {
        double largest = 1;
        for (const Point& p : points) {
            if (p.input) {
                largest = std::max(largest, *p.input);
            }
        }
        points.back().input = largest;
    }
    double largest = *points[0].input;
    for (Point& p : points) {
        if (p.input) {
            largest = std::max(largest, *p.input);
            p.input = largest;
        }
    }
    for (size_t i = 0; i < points.size(); i++) {
        if (points[i].input) {
            continue;
        }
        const size_t start = i - 1;
        size_t end = i;
        while (!points[end].input) {
            end++;
        }
        const double from = *points[start].input, to = *points[end].input;
        for (size_t k = start + 1; k < end; k++) {
            points[k].input = from + (to - from) * double(k - start) / double(end - start);
        }
        i = end;
    }
    out.kind = Easing::Kind::Points;
    for (const Point& p : points) {
        out.points.emplace_back(*p.input, p.output);
    }
    return true;
}

} // namespace

double Easing::css(double x) const {
    switch (kind) {
    case Kind::Linear:
        return x;
    case Kind::Bezier:
        return bezierAt(x1, y1, x2, y2, x);
    case Kind::Steps: {
        const double n = steps;
        const double step = jump == Jump::Start ? std::ceil(x * n) : std::floor(x * n);
        return std::clamp(step / n, 0.0, 1.0);
    }
    case Kind::Points: {
        const auto& p = points;
        auto segment = [&](size_t a, size_t b) {
            if (p[b].first == p[a].first) {
                return x <= p[a].first ? p[a].second : p[b].second;
            }
            return p[a].second + (p[b].second - p[a].second) * (x - p[a].first) / (p[b].first - p[a].first);
        };
        if (x <= p[0].first) {
            return p[1].first == p[0].first ? p[0].second : segment(0, 1);
        }
        for (size_t k = 1; k < p.size(); k++) {
            if (x <= p[k].first) {
                return p[k].first == p[k - 1].first ? p[k].second : segment(k - 1, k);
            }
        }
        const size_t n = p.size();
        return p[n - 1].first == p[n - 2].first ? p[n - 1].second : segment(n - 2, n - 1);
    }
    }
    return x;
}

double Easing::web(double x, bool before) const {
    if (kind == Kind::Steps) {
        const double n = steps;
        double step = std::floor(x * n);
        if (jump == Jump::Start || jump == Jump::Both) {
            step += 1;
        }
        if (before && std::fmod(x * n, 1.0) == 0) {
            step -= 1;
        }
        if (x >= 0 && step < 0) {
            step = 0;
        }
        const double jumps = jump == Jump::Both ? n + 1 : jump == Jump::None ? n - 1 : n;
        if (x <= 1 && step > jumps) {
            step = jumps;
        }
        return step / jumps;
    }
    if (kind == Kind::Bezier) {
        // Outside [0, 1] a cubic-bézier continues along its end tangents.
        if (x < 0) {
            const double slope = x1 > 0 ? y1 / x1 : (y1 == 0 && x2 > 0 ? y2 / x2 : 0);
            return slope * x;
        }
        if (x > 1) {
            const double slope = x2 < 1 ? (y2 - 1) / (x2 - 1) : (y2 == 1 && x1 < 1 ? (y1 - 1) / (x1 - 1) : 0);
            return 1 + slope * (x - 1);
        }
    }
    return css(x);
}

std::shared_ptr<const Easing> parseEasing(JSContext* ctx, std::string_view raw) {
    if (raw.size() > kMaxEasingText) {
        return nullptr;
    }
    const std::string t = lowered(trimmed(raw));
    JSRuntime* rt = JS_GetRuntime(ctx);
    std::shared_ptr<Easing> easing = std::allocate_shared<Easing>(JSAllocator<Easing>(rt), rt);
    Easing& e = *easing;
    auto bezier = [&](double a, double b, double c, double d) {
        e.kind = Easing::Kind::Bezier;
        e.x1 = a;
        e.y1 = b;
        e.x2 = c;
        e.y2 = d;
    };
    auto inside = [&](std::string_view name) -> std::optional<std::string_view> {
        if (t.size() < name.size() + 2 || t.compare(0, name.size(), name) != 0 || t[name.size()] != '(' || t.back() != ')') {
            return std::nullopt;
        }
        const std::string_view body = std::string_view(t).substr(name.size() + 1, t.size() - name.size() - 2);
        if (body.find('(') != std::string_view::npos || body.find(')') != std::string_view::npos) {
            return std::nullopt;
        }
        return body;
    };
    if (t == "linear") {
        e.canonical.assign(t);
    } else if (t == "ease" || t == "ease-in" || t == "ease-out" || t == "ease-in-out") {
        if (t == "ease") {
            bezier(0.25, 0.1, 0.25, 1);
        } else if (t == "ease-in") {
            bezier(0.42, 0, 1, 1);
        } else if (t == "ease-out") {
            bezier(0, 0, 0.58, 1);
        } else {
            bezier(0.42, 0, 0.58, 1);
        }
        e.canonical.assign(t);
    } else if (t == "step-start" || t == "step-end") {
        e.kind = Easing::Kind::Steps;
        e.steps = 1;
        e.jump = t == "step-start" ? Easing::Jump::Start : Easing::Jump::End;
        e.canonical.assign(t == "step-start" ? "steps(1, start)" : "steps(1)");
    } else if (auto body = inside("cubic-bezier")) {
        const std::vector<std::string> parts = splitTopLevel(*body, ',');
        if (parts.size() != 4) {
            return nullptr;
        }
        double v[4];
        for (int i = 0; i < 4; i++) {
            const std::optional<double> n = plainNumber(parts[size_t(i)]);
            if (!n) {
                return nullptr;
            }
            v[i] = *n;
        }
        if (v[0] < 0 || v[0] > 1 || v[2] < 0 || v[2] > 1) {
            return nullptr;
        }
        bezier(v[0], v[1], v[2], v[3]);
        std::string text = "cubic-bezier(";
        for (int i = 0; i < 4; i++) {
            text += (i ? ", " : "") + jsNumber(ctx, v[i]);
        }
        text += ")";
        e.canonical.assign(text);
    } else if (auto body = inside("steps")) {
        const std::vector<std::string> parts = splitTopLevel(*body, ',');
        if (parts.empty() || parts.size() > 2) {
            return nullptr;
        }
        const std::string count = trimmed(parts[0]);
        if (count.empty() || count.size() > 6 || !std::all_of(count.begin(), count.end(), isDigit)) {
            return nullptr;
        }
        const int n = std::stoi(count);
        if (n < 1 || n > 100000) {
            return nullptr;
        }
        const std::string position = parts.size() > 1 ? trimmed(parts[1]) : "end";
        e.kind = Easing::Kind::Steps;
        e.steps = n;
        if (position == "start" || position == "jump-start") {
            e.jump = Easing::Jump::Start;
        } else if (position == "end" || position == "jump-end") {
            e.jump = Easing::Jump::End;
        } else if (position == "jump-both") {
            e.jump = Easing::Jump::Both;
        } else if (position == "jump-none" && n >= 2) {
            e.jump = Easing::Jump::None;
        } else {
            return nullptr;
        }
        e.canonical.assign(e.jump == Easing::Jump::End ? "steps(" + std::to_string(n) + ")"
                                                       : "steps(" + std::to_string(n) + ", " + position + ")");
    } else if (auto body = inside("linear")) {
        if (!parseLinear(*body, e)) {
            return nullptr;
        }
        std::string text = "linear(";
        for (size_t i = 0; i < e.points.size(); i++) {
            const double percent = std::round(e.points[i].first * 100 * 1e6) / 1e6;
            text += (i ? ", " : "") + jsNumber(ctx, e.points[i].second) + " " + jsNumber(ctx, percent) + "%";
        }
        text += ")";
        e.canonical.assign(text);
    } else {
        return nullptr;
    }
    return easing;
}

std::shared_ptr<const Easing> linearEasing(JSContext* ctx) { return parseEasing(ctx, "linear"); }

} // namespace wr::animation
