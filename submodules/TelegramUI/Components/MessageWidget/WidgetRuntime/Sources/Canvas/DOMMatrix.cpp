#include "Sources/Canvas/DOMMatrix.h"

#include "Generated/Bindings.h"
#include "Sources/Host/Sequences.h"
#include "Sources/Support/Errors.h"

namespace wr {

Ref<DOMMatrix> DOMMatrix::construct(JSContext* ctx, std::optional<Value> init) {
    Ref<DOMMatrix> made = create<DOMMatrix>(ctx, idl::kDOMMatrix);
    if (!init) {
        return made;
    }
    // A string (a CSS transform list) needs the CSS parser on a window: not supported.
    std::optional<std::vector<Value>> items =
        JS_IsObject(init->get()) ? sequenceValues(ctx, init->get(), "DOMMatrix", 17) : std::nullopt;
    if (!items || (items->size() != 6 && items->size() != 16)) {
        throw TypeError{"DOMMatrix: the init is not a sequence of 6 or 16 numbers."};
    }
    std::vector<double> v;
    for (const Value& item : *items) {
        v.push_back(convert<Unrestricted>(ctx, item.get(), ArgInfo{"DOMMatrix", "constructor", 0}).value);
    }
    if (v.size() == 6) {
        made->m[0] = v[0];
        made->m[1] = v[1];
        made->m[4] = v[2];
        made->m[5] = v[3];
        made->m[12] = v[4];
        made->m[13] = v[5];
        return made;
    }
    for (size_t i = 0; i < 16; i++) {
        made->m[i] = v[i];
    }
    made->is2DFlag = v[2] == 0 && v[3] == 0 && v[6] == 0 && v[7] == 0 && v[8] == 0 && v[9] == 0 && v[10] == 1 &&
                     v[11] == 0 && v[14] == 0 && v[15] == 1;
    return made;
}

Ref<DOMMatrix> DOMMatrix::fromMatrix(JSContext* ctx, const canvas::Matrix& matrix) {
    Ref<DOMMatrix> made = create<DOMMatrix>(ctx, idl::kDOMMatrix);
    made->m[0] = matrix.a;
    made->m[1] = matrix.b;
    made->m[4] = matrix.c;
    made->m[5] = matrix.d;
    made->m[12] = matrix.e;
    made->m[13] = matrix.f;
    return made;
}

bool DOMMatrix::isIdentity(JSContext*) const {
    static constexpr double kIdentity[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
    for (size_t i = 0; i < 16; i++) {
        if (m[i] != kIdentity[i]) {
            return false;
        }
    }
    return true;
}

} // namespace wr
