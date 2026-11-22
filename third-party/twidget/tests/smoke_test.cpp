#include "test_container.h"

#include <cstdio>

static int failures = 0;

int main() {
    litehtml_test::TestContainer c;
    auto doc = litehtml_test::layout(c,
        "<body style='margin:0'><div style='display:flex;gap:10px'><div style='width:50px;height:20px;flex:none'></div>"
        "<div style='width:50px;height:30px;flex:none'></div></div></body>");
    CHECK(doc != nullptr);
    // pixel_t == int is ambiguous at C++17 (pixel_float_t converts to both float and int).
    CHECK(doc && float(doc->height()) == 30.0f);
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("twidget litehtml smoke: OK\n");
    return 0;
}
