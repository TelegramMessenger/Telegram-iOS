// Host tests of Telegram's gumbo fork (VENDOR.md, "Changes").
#include <pthread.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <string>
#include <vector>

#include "tree_dump.h"

static int failures = 0;

#define CHECK_TRUE(condition)                                                                   \
    do {                                                                                        \
        if (!(condition)) {                                                                     \
            std::fprintf(stderr, "%s:%d: CHECK_TRUE(%s) failed\n", __FILE__, __LINE__, #condition); \
            failures++;                                                                         \
        }                                                                                       \
    } while (0)

namespace {

class Parsed {
public:
    explicit Parsed(const std::string& html, GumboOptions options = kGumboDefaultOptions) : m_options(options) {
        m_output = gumbo_parse_with_options(&m_options, html.data(), html.size());
    }
    ~Parsed() { gumbo_destroy_output(&m_options, m_output); }
    Parsed(const Parsed&) = delete;
    Parsed& operator=(const Parsed&) = delete;

    const GumboOutput* output() const { return m_output; }
    const GumboNode* body() const {
        const GumboVector& children = m_output->root->v.element.children;
        return static_cast<const GumboNode*>(children.data[children.length - 1]);
    }
    std::string tree() const { return gumbo_test::dumpTree(m_output, m_options.fragment_context != GUMBO_TAG_LAST); }

private:
    GumboOptions m_options;
    GumboOutput* m_output;
};

std::string repeat(const std::string& unit, size_t bytes) {
    std::string out;
    while (out.size() < bytes) {
        out += unit;
    }
    return out;
}

const GumboNode* firstElementChild(const GumboNode* node) {
    const GumboVector& children = node->v.element.children;
    for (unsigned int i = 0; i < children.length; i++) {
        const auto* child = static_cast<const GumboNode*>(children.data[i]);
        if (child->type == GUMBO_NODE_ELEMENT || child->type == GUMBO_NODE_TEMPLATE) {
            return child;
        }
    }
    return nullptr;
}

const GumboNode* lastElementChild(const GumboNode* node) {
    const GumboVector& children = node->v.element.children;
    for (unsigned int i = children.length; i-- > 0;) {
        const auto* child = static_cast<const GumboNode*>(children.data[i]);
        if (child->type == GUMBO_NODE_ELEMENT || child->type == GUMBO_NODE_TEMPLATE) {
            return child;
        }
    }
    return nullptr;
}

// How many elements nest below `node` along last element children (where the newest content goes), and the
// innermost of them.
size_t chainBelow(const GumboNode* node, const GumboNode** innermost = nullptr) {
    size_t depth = 0;
    while (const GumboNode* child = lastElementChild(node)) {
        node = child;
        depth++;
    }
    if (innermost) {
        *innermost = node;
    }
    return depth;
}

std::string text(const GumboNode* node) {
    std::string out;
    const GumboVector& children = node->v.element.children;
    for (unsigned int i = 0; i < children.length; i++) {
        const auto* child = static_cast<const GumboNode*>(children.data[i]);
        if (gumbo_test::isText(child)) {
            out += child->v.text.text;
        }
    }
    return out;
}

size_t countNodes(const GumboNode* root, bool* anyOpen = nullptr) {
    size_t count = 0;
    std::vector<const GumboNode*> stack = {root};
    while (!stack.empty()) {
        const GumboNode* node = stack.back();
        stack.pop_back();
        count++;
        const GumboVector* children = nullptr;
        if (node->type == GUMBO_NODE_DOCUMENT) {
            children = &node->v.document.children;
        } else if (node->type == GUMBO_NODE_ELEMENT || node->type == GUMBO_NODE_TEMPLATE) {
            children = &node->v.element.children;
            if (anyOpen && node->v.element.is_open) {
                *anyOpen = true;
            }
        }
        if (children) {
            for (unsigned int i = 0; i < children->length; i++) {
                stack.push_back(static_cast<const GumboNode*>(children->data[i]));
            }
        }
    }
    return count;
}

// Change 2: the adoption agency replaces an element on the stack with its clone. html5lib tests1.dat:18.
void testOpenElementsAreTrackedThroughTheAdoptionAgency() {
    Parsed parsed("<b>1<i>2<p>3</b>4");
    CHECK_TRUE(parsed.tree() ==
               "| <html>\n"
               "|   <head>\n"
               "|   <body>\n"
               "|     <b>\n"
               "|       \"1\"\n"
               "|       <i>\n"
               "|         \"2\"\n"
               "|     <i>\n"
               "|       <p>\n"
               "|         <b>\n"
               "|           \"3\"\n"
               "|         \"4\"\n");
    bool anyOpen = false;
    countNodes(parsed.output()->document, &anyOpen);
    CHECK_TRUE(!anyOpen);
}

// Change 3: past 512 open elements a start tag is ignored, and the end tags it leaves unmatched are ignored too.
void testDepthLimit() {
    {
        Parsed parsed(repeat("<div>", 600 * 5) + "x");
        const GumboNode* innermost = nullptr;
        // html and body hold two of the 512.
        CHECK_TRUE(chainBelow(parsed.body(), &innermost) == 510);
        CHECK_TRUE(text(innermost) == "x");
    }
    {
        Parsed parsed(repeat("<div>", 600 * 5) + repeat("</div>", 600 * 6) + "<p>after");
        const GumboNode* last = static_cast<const GumboNode*>(parsed.body()->v.element.children.data[parsed.body()->v.element.children.length - 1]);
        CHECK_TRUE(last->v.element.tag == GUMBO_TAG_P && text(last) == "after");
    }
    {
        GumboOptions unlimited = kGumboDefaultOptions;
        unlimited.max_tree_depth = -1;
        Parsed parsed(repeat("<div>", 600 * 5) + "x", unlimited);
        CHECK_TRUE(chainBelow(parsed.body()) == 600);
    }
}

// Change 3: reconstructing the active formatting elements stops at the limit. 500 distinct <b>s are closed by
// </div>, 100 nested <div>s (a <div> start tag reconstructs nothing) open after it, and "x" then reconstructs
// the <b>s inside the innermost <div> until html, body, the 100 <div>s and the clones fill the 512.
void testReconstructionStopsAtTheDepthLimit() {
    std::string html = "<div>";
    for (int i = 0; i < 500; i++) {
        html += "<b a=" + std::to_string(i) + ">";
    }
    html += "</div>" + repeat("<div>", 100 * 5) + "x";
    {
        Parsed parsed(html);
        const GumboNode* innermost = nullptr;
        CHECK_TRUE(chainBelow(parsed.body(), &innermost) == 100 + 410);
        CHECK_TRUE(innermost->v.element.tag == GUMBO_TAG_B && text(innermost) == "x");
    }
    {
        GumboOptions unlimited = kGumboDefaultOptions;
        unlimited.max_tree_depth = -1;
        Parsed parsed(html, unlimited);
        CHECK_TRUE(chainBelow(parsed.body()) == 100 + 500);
    }
}

// Change 4: attributes past 256 are dropped; duplicates are still dropped before that.
void testAttributeLimit() {
    std::string html = "<p";
    for (int i = 0; i < 300; i++) {
        html += " a" + std::to_string(i) + "=v";
    }
    html += ">";
    {
        Parsed parsed(html);
        const GumboNode* p = firstElementChild(parsed.body());
        const GumboVector& attributes = p->v.element.attributes;
        CHECK_TRUE(attributes.length == 256);
        CHECK_TRUE(std::strcmp(static_cast<const GumboAttribute*>(attributes.data[255])->name, "a255") == 0);
    }
    {
        GumboOptions unlimited = kGumboDefaultOptions;
        unlimited.max_attributes = -1;
        Parsed parsed(html, unlimited);
        CHECK_TRUE(firstElementChild(parsed.body())->v.element.attributes.length == 300);
    }
    {
        Parsed parsed("<p a=1 a=2 b=3 a=4>");
        CHECK_TRUE(parsed.tree() ==
                   "| <html>\n"
                   "|   <head>\n"
                   "|   <body>\n"
                   "|     <p>\n"
                   "|       a=\"1\"\n"
                   "|       b=\"3\"\n");
    }
}

// Change 5: the Noah's Ark clause (at most three identical formatting elements) still treats attribute sets as
// equal in any order, and as different when one value differs.
void testNoahsArkClause() {
    {
        Parsed parsed("<p><b x=1 y=2><b y=2 x=1><b x=1 y=2><b y=2 x=1></p><p>z");
        const GumboVector& children = parsed.body()->v.element.children;
        const GumboNode* innermost = nullptr;
        CHECK_TRUE(chainBelow(static_cast<const GumboNode*>(children.data[1]), &innermost) == 3);
        CHECK_TRUE(text(innermost) == "z");
    }
    {
        Parsed parsed("<p><b z=1><b z=2><b z=3><b z=4></p><p>z");
        const GumboVector& children = parsed.body()->v.element.children;
        CHECK_TRUE(chainBelow(static_cast<const GumboNode*>(children.data[1])) == 4);
    }
}

// Change 6: parsing stops at 100,000 nodes. Each "<div><b a=N></div>" reconstructs every <b> before it (up to
// the depth limit), so 16 KiB of it makes ~290,000 nodes without the node limit.
void testNodeLimit() {
    std::string html;
    for (int i = 0; html.size() < 16 * 1024; i++) {
        html += "<div><b a=" + std::to_string(i) + "></div>";
    }
    {
        Parsed parsed(html);
        CHECK_TRUE(parsed.output()->stopped_at_node_limit);
        // One token makes at most a reconstruction's worth past the limit.
        CHECK_TRUE(countNodes(parsed.output()->document) <= 100000 + 1024);
    }
    {
        GumboOptions unlimited = kGumboDefaultOptions;
        unlimited.max_nodes = -1;
        Parsed parsed(html, unlimited);
        CHECK_TRUE(!parsed.output()->stopped_at_node_limit);
        CHECK_TRUE(countNodes(parsed.output()->document) > 200000);
    }
    {
        Parsed parsed(repeat("<p>text</p>", 64 * 1024));
        CHECK_TRUE(!parsed.output()->stopped_at_node_limit);
    }
}

// How many attributes `root`'s elements hold in all.
size_t countAttributes(const GumboNode* root) {
    size_t count = 0;
    std::vector<const GumboNode*> stack = {root};
    while (!stack.empty()) {
        const GumboNode* node = stack.back();
        stack.pop_back();
        const GumboVector* children = nullptr;
        if (node->type == GUMBO_NODE_DOCUMENT) {
            children = &node->v.document.children;
        } else if (node->type == GUMBO_NODE_ELEMENT || node->type == GUMBO_NODE_TEMPLATE) {
            children = &node->v.element.children;
            count += node->v.element.attributes.length;
        }
        if (children) {
            for (unsigned int i = 0; i < children->length; i++) {
                stack.push_back(static_cast<const GumboNode*>(children->data[i]));
            }
        }
    }
    return count;
}

// Change 12: parsing stops once the elements gumbo keeps hold max_total_attributes attributes in all (off by default,
// -1). Attributes are not nodes, so max_nodes does not bound them: "<p" + 256 attributes + ">" repeated grows the
// tree's attribute count without bound while its node count stays tiny (one <p> per token).
void testTotalAttributeLimit() {
    std::string html;
    for (int p = 0; p < 1000; p++) {
        html += "<p";
        for (int a = 0; a < 256; a++) {
            html += " a" + std::to_string(a) + "=v";
        }
        html += ">";
    }
    {
        GumboOptions limited = kGumboDefaultOptions;
        limited.max_total_attributes = 100000;
        Parsed parsed(html, limited);
        CHECK_TRUE(parsed.output()->stopped_at_attribute_limit);
        CHECK_TRUE(!parsed.output()->stopped_at_node_limit);
        // One token keeps at most one element's worth of attributes (256) past the limit; a <p> never reconstructs.
        CHECK_TRUE(countAttributes(parsed.output()->document) <= 100000 + 256);
    }
    {
        // The default (-1) keeps every attribute: 1000 x 256 survive.
        Parsed parsed(html);
        CHECK_TRUE(!parsed.output()->stopped_at_attribute_limit);
        CHECK_TRUE(countAttributes(parsed.output()->document) == 256000);
    }
    {
        // A benign document is nowhere near the limit.
        GumboOptions limited = kGumboDefaultOptions;
        limited.max_total_attributes = 100000;
        Parsed parsed("<p a=1 b=2><span class=x id=y>text</span></p>", limited);
        CHECK_TRUE(!parsed.output()->stopped_at_attribute_limit);
    }
}

// The bytes gumbo allocates for `root`'s attribute strings: each name and value copy, NUL included.
size_t countAttributeBytes(const GumboNode* root) {
    size_t bytes = 0;
    std::vector<const GumboNode*> stack = {root};
    while (!stack.empty()) {
        const GumboNode* node = stack.back();
        stack.pop_back();
        const GumboVector* children = nullptr;
        if (node->type == GUMBO_NODE_DOCUMENT) {
            children = &node->v.document.children;
        } else if (node->type == GUMBO_NODE_ELEMENT || node->type == GUMBO_NODE_TEMPLATE) {
            children = &node->v.element.children;
            const GumboVector& attributes = node->v.element.attributes;
            for (unsigned int i = 0; i < attributes.length; i++) {
                const auto* a = static_cast<const GumboAttribute*>(attributes.data[i]);
                bytes += std::strlen(a->name) + 1 + std::strlen(a->value) + 1;
            }
        }
        if (children) {
            for (unsigned int i = 0; i < children->length; i++) {
                stack.push_back(static_cast<const GumboNode*>(children->data[i]));
            }
        }
    }
    return bytes;
}

// Change 13: parsing stops once the attribute strings the tree keeps hold max_total_attribute_bytes bytes (off by
// default, -1). Reconstruction deep-copies a formatting element's attributes, so one long-valued <b> left in the
// active formatting list is copied once per "<p>x</p>": the attribute count grows by one per repeat while the bytes
// grow by the value's length (16 KiB x 1,000 repeats is 16 MB of copies from 24 KB of markup).
void testTotalAttributeBytesLimit() {
    const size_t valueBytes = 16 * 1024;
    std::string html = "<div><b a=\"" + std::string(valueBytes, 'v') + "\"></div>";
    for (int i = 0; i < 1000; i++) {
        html += "<p>x</p>";
    }
    const size_t perCopy = std::strlen("a") + 1 + valueBytes + 1;
    {
        GumboOptions limited = kGumboDefaultOptions;
        limited.max_total_attribute_bytes = 1 << 20;
        Parsed parsed(html, limited);
        // It shares change 12's flag.
        CHECK_TRUE(parsed.output()->stopped_at_attribute_limit);
        CHECK_TRUE(!parsed.output()->stopped_at_node_limit);
        // One token copies the <b> at most once past the limit here.
        size_t bytes = countAttributeBytes(parsed.output()->document);
        CHECK_TRUE(bytes >= (1u << 20) && bytes <= (1u << 20) + perCopy);
    }
    {
        // The default (-1) keeps every copy: the original and 1,000 reconstructions.
        Parsed parsed(html);
        CHECK_TRUE(!parsed.output()->stopped_at_attribute_limit);
        CHECK_TRUE(countAttributeBytes(parsed.output()->document) == 1001 * perCopy);
    }
    {
        // A benign document is nowhere near the limit.
        GumboOptions limited = kGumboDefaultOptions;
        limited.max_total_attribute_bytes = 1 << 20;
        Parsed parsed("<p a=1 b=2><svg viewBox='0 0 1 1'><use xlink:href=#x /></svg></p><b c=d>x</b><p>y</p>", limited);
        CHECK_TRUE(!parsed.output()->stopped_at_attribute_limit);
    }
}

// Change 8: parse errors are not recorded unless asked for. Each one copied the whole stack of open elements, so
// 256 KiB of "<ul><li>" (65,282 errors) took 277 MB.
void testParseErrorsAreNotRecordedByDefault() {
    {
        Parsed parsed(repeat("<ul><li>", 64 * 1024));
        CHECK_TRUE(parsed.output()->errors.length == 0);
    }
    {
        GumboOptions recording = kGumboDefaultOptions;
        recording.max_errors = -1;
        Parsed parsed("<p></b>", recording);
        CHECK_TRUE(parsed.output()->errors.length > 0);
    }
}

void* dirtyAllocate(void*, size_t size) {
    void* memory = std::malloc(size);
    std::memset(memory, 0xab, size);
    return memory;
}

void dirtyDeallocate(void*, void* memory) { std::free(memory); }

// Change 7: a fragment's document has a quirks mode even though the fragment parser never sets one. Memory comes
// from an allocator that fills it, so a field left unset cannot read as zero by luck.
void testFragmentDocumentHasAQuirksMode() {
    GumboOptions options = kGumboDefaultOptions;
    options.allocator = dirtyAllocate;
    options.deallocator = dirtyDeallocate;
    options.fragment_context = GUMBO_TAG_DIV;
    Parsed parsed("<p>x", options);
    CHECK_TRUE(parsed.output()->document->v.document.doc_type_quirks_mode == GUMBO_DOCTYPE_NO_QUIRKS);
}

// Change 9: a name without a value that is dropped (a duplicate, or past the limit) leaves the tag buffer empty,
// whether or not errors are recorded. The next name used to be appended to it: `<p a a b>` made "a" and "ab".
std::string attributeNames(const GumboNode* element) {
    std::string out;
    const GumboVector& attributes = element->v.element.attributes;
    for (unsigned int i = 0; i < attributes.length; i++) {
        const auto* attribute = static_cast<const GumboAttribute*>(attributes.data[i]);
        out += std::string(i ? "," : "") + attribute->name;
        if (attribute->value[0]) {
            out += std::string("=") + attribute->value;
        }
    }
    return out;
}

void testDroppedNamesDoNotLeakIntoTheNextAttribute() {
    const std::pair<const char*, const char*> cases[] = {
        {"<p a a b>", "a,b"},
        {"<p h h ref=x>", "h,ref=x"},
        {"<p o o nclick=y>", "o,nclick=y"},
        {"<p disabled disabled class=c>", "disabled,class=c"},
    };
    for (int errors : {0, -1}) {
        GumboOptions options = kGumboDefaultOptions;
        options.max_errors = errors;
        for (const auto& c : cases) {
            Parsed parsed(c.first, options);
            std::string names = attributeNames(firstElementChild(parsed.body()));
            if (names != c.second) {
                std::fprintf(stderr, "%s (max_errors %d): %s\n", c.first, errors, names.c_str());
            }
            CHECK_TRUE(names == c.second);
        }
    }
    std::string html = "<p";
    for (int i = 0; i < 256; i++) {
        html += " a" + std::to_string(i);
    }
    html += " x y=1>";
    Parsed parsed(html);
    const GumboNode* p = firstElementChild(parsed.body());
    CHECK_TRUE(p->v.element.attributes.length == 256);
    CHECK_TRUE(gumbo_get_attribute(&p->v.element.attributes, "xy") == nullptr);
    CHECK_TRUE(gumbo_get_attribute(&p->v.element.attributes, "x") == nullptr);
    CHECK_TRUE(gumbo_get_attribute(&p->v.element.attributes, "y") == nullptr);
}

// Change 10: after the last marker the list of active formatting elements keeps the newest max_formatting_elements.
void testFormattingListLimit() {
    std::string html = "<p>";
    for (int i = 0; i < 10; i++) {
        html += "<b a=" + std::to_string(i) + ">";
    }
    html += "</p><p>z";
    {
        GumboOptions options = kGumboDefaultOptions;
        options.max_formatting_elements = 4;
        Parsed parsed(html, options);
        const GumboVector& children = parsed.body()->v.element.children;
        const GumboNode* second = static_cast<const GumboNode*>(children.data[1]);
        const GumboNode* innermost = nullptr;
        CHECK_TRUE(chainBelow(second, &innermost) == 4);
        CHECK_TRUE(text(innermost) == "z");
        CHECK_TRUE(std::strcmp(gumbo_get_attribute(&innermost->v.element.attributes, "a")->value, "9") == 0);
        CHECK_TRUE(std::strcmp(gumbo_get_attribute(&firstElementChild(second)->v.element.attributes, "a")->value, "6") == 0);
    }
    for (int limit : {-1, 512}) {
        GumboOptions options = kGumboDefaultOptions;
        options.max_formatting_elements = limit;
        Parsed parsed(html, options);
        const GumboVector& children = parsed.body()->v.element.children;
        CHECK_TRUE(chainBelow(static_cast<const GumboNode*>(children.data[1])) == 10);
    }
}

double secondsToParse(const std::string& html) {
    double best = 1e9;
    for (int run = 0; run < 3; run++) {
        auto start = std::chrono::steady_clock::now();
        GumboOutput* output = gumbo_parse_with_options(&kGumboDefaultOptions, html.data(), html.size());
        best = std::min(best, std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count());
        gumbo_destroy_output(&kGumboDefaultOptions, output);
    }
    return best;
}

// Changes 2-6 together. Every input class here was quadratic before the fork (measured on the pristine copy: 4x
// the input took 12-20x the time), or is linear under the depth limit only with a constant ~70x a plain
// document's (the last class, without change 2). Each is parsed at 64 KiB and 256 KiB: 4x the input must take
// at most 8x the time, and 256 KiB at most 25x what 256 KiB of plain paragraphs takes.
void testPathologicalInputsParseInLinearTime() {
    const double plain = secondsToParse(repeat("<p>text</p>", 256 * 1024));
    std::vector<std::pair<const char*, std::function<std::string(size_t)>>> classes = {
        {"nested div", [](size_t n) { return repeat("<div>", n); }},
        {"nested li", [](size_t n) { return repeat("<ul><li>", n); }},
        {"nested dd", [](size_t n) { return repeat("<dl><dd>", n); }},
        {"div under p and button", [](size_t n) { return "<p><button>" + repeat("<div>", n); }},
        {"formatting", [](size_t n) { return repeat("<b><i>x", n); }},
        {"foster-parented formatting", [](size_t n) { return "<table>" + repeat("<b>x", n); }},
        {"reconstruction", [](size_t n) {
             std::string s;
             for (int i = 0; s.size() < n; i++) {
                 s += "<div><b a=" + std::to_string(i) + "></div>";
             }
             return s;
         }},
        {"distinct formatting", [](size_t n) {
             std::string s;
             for (int i = 0; s.size() < n; i++) {
                 s += "<b a=" + std::to_string(i) + ">";
             }
             return s;
         }},
        {"formatting with 256 attributes", [](size_t n) {
             std::string s;
             for (int i = 0; s.size() < n; i++) {
                 s += "<b";
                 for (int a = 0; a < 255; a++) {
                     s += " a" + std::to_string(a);
                 }
                 s += " z=" + std::to_string(i) + ">";
             }
             return s;
         }},
        {"many attributes", [](size_t n) {
             std::string s = "<p";
             for (int i = 0; s.size() < n; i++) {
                 s += " a" + std::to_string(i);
             }
             return s + ">";
         }},
        // 500 closed <b>s wait to be reconstructed while the stack sits one below the limit: every "x" walks back
        // over all 500, asking of each whether it is open.
        {"reconstruction at the depth limit", [](size_t n) {
             std::string s = "<div>";
             for (int i = 0; i < 500; i++) {
                 s += "<b a=" + std::to_string(i) + ">";
             }
             s += "</div>" + repeat("<div>", 508 * 5);
             return s + repeat("<div>x</div>", n - s.size());
         }},
        // Distinct formatting elements closed by </div> pile up in the list while the stack stays near the limit.
        {"growing list of formatting elements", [](size_t n) {
             std::string s = repeat("<div>", 509 * 5);
             for (int i = 0; s.size() < n; i++) {
                 s += "<b a=" + std::to_string(i) + "></div><div>";
             }
             return s;
         }},
    };
    for (const auto& c : classes) {
        double small = secondsToParse(c.second(64 * 1024));
        double large = secondsToParse(c.second(256 * 1024));
        bool linear = large <= 8 * small + 0.005 && large <= 25 * plain + 0.005;
        if (!linear) {
            std::fprintf(stderr, "%s: 64 KiB %.4f s, 256 KiB %.4f s (plain 256 KiB %.4f s)\n", c.first, small, large, plain);
        }
        CHECK_TRUE(linear);
    }
}

void* parseAndFreeDeepTree(void*) {
    GumboOptions unlimited = kGumboDefaultOptions;
    unlimited.max_tree_depth = -1;
    unlimited.max_nodes = -1;
    std::string html = repeat("<span>", 100000 * 6);
    GumboOutput* output = gumbo_parse_with_options(&unlimited, html.data(), html.size());
    gumbo_destroy_output(&unlimited, output);
    return nullptr;
}

// Change 1: freeing a tree 100,000 elements deep (no limits) on a 512 KiB stack. Before the fork destroy_node
// recursed once per level and this crashed the test process. Last, so a crash does not hide the other results.
void testDeepTreeIsFreedWithoutRecursion() {
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    CHECK_TRUE(pthread_create(&thread, &attributes, parseAndFreeDeepTree, nullptr) == 0);
    pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
}

// Change 11: a start tag's name read back from its source text ends at a CR, as the tokenizer's tag name does (it
// reads CR as LF). Markup with CRLF line ends and an attribute on the next line kept the CR in the name, so a foreign
// element's end tag did not match it: `</svg>` left a CRLF `<svg>` open and what followed went inside.
void testTagNamesFromSourceTextEndAtCR() {
    const char source[] = "<svg\r\n width=1>";
    GumboStringPiece piece = {source, sizeof(source) - 1};
    gumbo_tag_from_original_text(&piece);
    CHECK_TRUE(std::string(piece.data, piece.length) == "svg");
    // The trees point into their sources (original_tag), which must outlive them.
    const std::string crlfSource = "<svg\r\n width=16><path\r\n d='M0'/></svg>after";
    const std::string lfSource = "<svg\n width=16><path\n d='M0'/></svg>after";
    Parsed crlf(crlfSource);
    Parsed lf(lfSource);
    CHECK_TRUE(crlf.tree() == lf.tree());
    const GumboVector& children = crlf.body()->v.element.children;
    CHECK_TRUE(children.length == 2 && gumbo_test::isText(static_cast<const GumboNode*>(children.data[1])));
}

// Change 11, end tags: an end tag's name read back from its source text ends where the end tag name state ends it
// (whitespace, '/'). The helper took everything between `</` and `>`, so a foreign end tag with a line break before
// its `>` did not match its element: `</g\n>` left the <g> open and what followed went inside it.
void testEndTagNamesFromSourceTextEndAtWhitespace() {
    const std::string reference = "<svg><g></g>x</svg>after";
    Parsed expected(reference);
    for (const char* source : {"<svg><g></g\n>x</svg>after", "<svg><g></g\r\n>x</svg>after"}) {
        // The trees point into their sources (original_tag), which must outlive them.
        const std::string html = source;
        Parsed parsed(html);
        CHECK_TRUE(parsed.tree() == expected.tree());
        const GumboNode* svg = firstElementChild(parsed.body());
        const GumboVector& children = svg->v.element.children;
        CHECK_TRUE(children.length == 2 && gumbo_test::isText(static_cast<const GumboNode*>(children.data[1])));
        CHECK_TRUE(firstElementChild(svg)->v.element.children.length == 0);
    }
    const char source[] = "</g\r\n>";
    GumboStringPiece piece = {source, sizeof(source) - 1};
    gumbo_tag_from_original_text(&piece);
    CHECK_TRUE(std::string(piece.data, piece.length) == "g");
}

} // namespace

int main() {
    testOpenElementsAreTrackedThroughTheAdoptionAgency();
    testDepthLimit();
    testReconstructionStopsAtTheDepthLimit();
    testAttributeLimit();
    testNoahsArkClause();
    testNodeLimit();
    testTotalAttributeLimit();
    testTotalAttributeBytesLimit();
    testParseErrorsAreNotRecordedByDefault();
    testFragmentDocumentHasAQuirksMode();
    testDroppedNamesDoNotLeakIntoTheNextAttribute();
    testFormattingListLimit();
    testPathologicalInputsParseInLinearTime();
    testDeepTreeIsFreedWithoutRecursion();
    testTagNamesFromSourceTextEndAtCR();
    testEndTagNamesFromSourceTextEndAtWhitespace();
    if (failures) {
        std::fprintf(stderr, "%d failure(s)\n", failures);
        return 1;
    }
    std::printf("gumbo fork: all tests passed\n");
    return 0;
}
