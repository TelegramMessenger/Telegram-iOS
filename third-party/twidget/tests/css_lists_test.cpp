// Host test of twidget edit 15 (VENDOR.md): list-valued CSS is capped at parse. Background layers and shadows keep
// 8 entries; filter and transform functions keep 8; gradient colour stops and clip-path points keep 32.
#include "test_container.h"

#include <cstdio>
#include <malloc/malloc.h>
#include <string>

static int failures = 0;

static std::string joined(const std::string& item, int n, const char* sep = ",") {
    std::string r;
    for (int i = 0; i < n; i++) { if (i) r += sep; r += item; }
    return r;
}

static litehtml::element::ptr div(const litehtml::document::ptr& doc) { return doc->root()->select_one("div"); }

static litehtml::element::ptr styled(litehtml_test::TestContainer& c, litehtml::document::ptr& doc, const std::string& style) {
    doc = litehtml_test::layout(c, "<div style=\"" + style + "\">x</div>");
    return div(doc);
}

static const size_t kLayers = 8, kFunctions = 8, kList = 32;

static void testListsAreCapped() {
    litehtml_test::TestContainer c;
    litehtml::document::ptr d;
    // Box and text shadows.
    auto e = styled(c, d, "box-shadow:" + joined("1px 1px 2px red", 100));
    CHECK(e && e->css().get_box_shadows().size() == kLayers);
    e = styled(c, d, "text-shadow:" + joined("1px 1px 2px red", 100));
    CHECK(e && e->css().get_text_shadows().size() == kLayers);
    // Background layers, by longhand and shorthand.
    e = styled(c, d, "background-image:" + joined("linear-gradient(red,blue)", 100));
    CHECK(e && e->css().get_bg().m_image.size() == kLayers);
    e = styled(c, d, "background:" + joined("linear-gradient(red,blue) 1px 1px/10px 10px no-repeat", 100));
    CHECK(e && e->css().get_bg().m_image.size() == kLayers);
    CHECK(e && e->css().get_bg().m_position_x.size() == kLayers && e->css().get_bg().m_size.size() == kLayers);
    CHECK(e && e->css().get_bg().m_repeat.size() == kLayers && e->css().get_bg().m_clip.size() == kLayers);
    e = styled(c, d, "background-position:" + joined("1px 2px", 100) + ";background-size:" + joined("10px 10px", 100) +
                     ";background-repeat:" + joined("no-repeat", 100) + ";background-clip:" + joined("padding-box", 100));
    CHECK(e && e->css().get_bg().m_position_x.size() == kLayers && e->css().get_bg().m_position_y.size() == kLayers);
    CHECK(e && e->css().get_bg().m_size.size() == kLayers && e->css().get_bg().m_repeat.size() == kLayers);
    CHECK(e && e->css().get_bg().m_clip.size() == kLayers);
    // Filter, backdrop-filter and transform functions.
    e = styled(c, d, "filter:" + joined("blur(1px)", 100, " "));
    CHECK(e && e->css().get_filter().size() == kFunctions);
    e = styled(c, d, "backdrop-filter:" + joined("blur(1px)", 100, " "));
    CHECK(e && e->css().get_backdrop_filter().size() == kFunctions);
    e = styled(c, d, "transform:" + joined("translate(1px,1px)", 100, " "));
    CHECK(e && e->css().get_transform().size() == kFunctions);
    // Gradient colour stops.
    e = styled(c, d, "background-image:linear-gradient(" + joined("red", 100) + ")");
    CHECK(e && e->css().get_bg().m_image.size() == 1 && e->css().get_bg().m_image[0].m_gradient.m_colors.size() == kList);
    e = styled(c, d, "background-image:radial-gradient(" + joined("red 10px", 100) + ")");
    CHECK(e && e->css().get_bg().m_image[0].m_gradient.m_colors.size() == kList);
    e = styled(c, d, "background-image:conic-gradient(" + joined("red 10deg", 100) + ")");
    CHECK(e && e->css().get_bg().m_image[0].m_gradient.m_colors.size() == kList);
    // Clip-path polygon points: two lengths per point.
    e = styled(c, d, "clip-path:polygon(" + joined("1px 2px", 100) + ")");
    CHECK(e && e->css().get_clip_path().kind == litehtml::clip_path_shape::polygon && e->css().get_clip_path().values.size() == 2 * kList);
}

static void testFirstEntriesAreKept() {
    litehtml_test::TestContainer c;
    litehtml::document::ptr d;
    std::string shadows;
    for (int i = 0; i < 20; i++) { if (i) shadows += ","; shadows += std::to_string(i) + "px 0 red"; }
    auto e = styled(c, d, "box-shadow:" + shadows);
    CHECK(e && e->css().get_box_shadows().size() == kLayers);
    if (e && e->css().get_box_shadows().size() == kLayers)
        for (int i = 0; i < (int) kLayers; i++) CHECK(e->css().get_box_shadows()[i].x.val() == (float) i);
    // The declaration stays valid: the property is set, and the next declaration still applies.
    e = styled(c, d, "box-shadow:" + joined("1px 1px red", 100) + ";width:40px");
    CHECK(e && !e->css().get_box_shadows().empty() && e->css().get_width().val() == 40.0f);
}

static void testShortListsAreUnchanged() {
    litehtml_test::TestContainer c;
    litehtml::document::ptr d;
    auto e = styled(c, d, "box-shadow:" + joined("1px 1px 2px red", kLayers));
    CHECK(e && e->css().get_box_shadows().size() == kLayers);
    e = styled(c, d, "text-shadow:" + joined("1px 1px 2px red", kLayers));
    CHECK(e && e->css().get_text_shadows().size() == kLayers);
    e = styled(c, d, "background:" + joined("linear-gradient(red,blue) no-repeat", kLayers));
    CHECK(e && e->css().get_bg().m_image.size() == kLayers);
    e = styled(c, d, "filter:" + joined("blur(1px)", kFunctions, " "));
    CHECK(e && e->css().get_filter().size() == kFunctions);
    e = styled(c, d, "transform:" + joined("rotate(1deg)", kFunctions, " "));
    CHECK(e && e->css().get_transform().size() == kFunctions);
    e = styled(c, d, "background-image:linear-gradient(" + joined("red", kList) + ")");
    CHECK(e && e->css().get_bg().m_image[0].m_gradient.m_colors.size() == kList);
    e = styled(c, d, "clip-path:polygon(" + joined("1px 2px", kList) + ")");
    CHECK(e && e->css().get_clip_path().values.size() == 2 * kList);
    // The corpus maxima: 6 background layers, the last carrying the colour; 1 shadow; 2 filter functions.
    e = styled(c, d, "background:" + joined("linear-gradient(red,blue) 0 0/10px 10px", 5) + ",#112233");
    CHECK(e && e->css().get_bg().m_image.size() == 6);
    CHECK(e && e->css().get_bg().m_color.red == 0x11 && e->css().get_bg().m_color.blue == 0x33);
    e = styled(c, d, "box-shadow:0 1px 2px rgba(0,0,0,.5)");
    CHECK(e && e->css().get_box_shadows().size() == 1);
    e = styled(c, d, "filter:blur(2px) brightness(1.2)");
    CHECK(e && e->css().get_filter().size() == 2);
}

static void testListAmplificationIsBounded() {
    litehtml_test::TestContainer c;
    std::string html = "<style>div{box-shadow:" + joined("1px 1px 2px red", 100) + "}</style>";
    for (int i = 0; i < 1000; i++) html += "<div>x</div>";
    malloc_statistics_t before, after;
    malloc_zone_statistics(nullptr, &before);
    auto doc = litehtml_test::layout(c, html);
    malloc_zone_statistics(nullptr, &after);
    double mb = (double) ((long long) after.size_in_use - (long long) before.size_in_use) / (1024.0 * 1024.0);
    std::printf("heap growth, 100 shadows x 1000 divs: %.2f MB\n", mb);
    CHECK(doc != nullptr);
    CHECK(mb < 25.0);
}

// The other list-valued properties bound the same amplification (the raw declaration copy included).
static void testOtherListAmplificationIsBounded() {
    const char* declarations[] = {
        "background:linear-gradient(%s)",
        "background:%s",
        "filter:%s",
        "transform:%s",
        "clip-path:polygon(%s)",
        "color:%s",
    };
    for (int k = 0; k < 6; k++) {
        std::string list;
        switch (k) {
            case 0: list = joined("red 10px", 100); break;
            case 1: list = joined("linear-gradient(red,blue) 1px 1px/10px 10px no-repeat", 100); break;
            case 2: list = joined("blur(1px)", 100, " "); break;
            case 3: list = joined("translate(1px,1px)", 100, " "); break;
            case 4: list = joined("1px 2px", 100); break;
            default: list = "red"; break;  // no list at all: what 1000 divs cost by themselves
        }
        char buffer[8192];
        std::snprintf(buffer, sizeof buffer, declarations[k], list.c_str());
        litehtml_test::TestContainer c;
        std::string html = std::string("<style>div{") + buffer + "}</style>";
        for (int i = 0; i < 1000; i++) html += "<div>x</div>";
        malloc_statistics_t before, after;
        malloc_zone_statistics(nullptr, &before);
        auto doc = litehtml_test::layout(c, html);
        malloc_zone_statistics(nullptr, &after);
        double mb = (double) ((long long) after.size_in_use - (long long) before.size_in_use) / (1024.0 * 1024.0);
        std::printf("heap growth, %.20s... x 1000 divs: %.2f MB\n", buffer, mb);
        CHECK(doc != nullptr);
        // 8 filter functions measure 9.7 MB and 8 transform functions 13.2 MB.
        CHECK(mb < (k == 2 || k == 3 ? 16.0 : 25.0));
    }
}

int main(int argc, char** argv) {
    auto want = [&](const char* name) { return argc < 2 || std::string(argv[1]) == name; };
    if (want("capped")) testListsAreCapped();
    if (want("first")) testFirstEntriesAreKept();
    if (want("short")) testShortListsAreUnchanged();
    if (want("heap")) testListAmplificationIsBounded();
    if (want("heap2")) testOtherListAmplificationIsBounded();
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("twidget css lists: OK\n");
    return 0;
}
