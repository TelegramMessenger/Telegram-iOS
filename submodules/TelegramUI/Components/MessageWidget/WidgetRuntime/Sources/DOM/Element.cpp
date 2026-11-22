#include "Sources/DOM/Element.h"

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

Element::Element(JSContext* ctx, Document& document, Namespace ns, JSAtom localName, JSAtom prefix, JSAtom otherNamespace)
    : Node(ctx, NodeType::Element, &document), m_ns(ns), m_attributes(JSAllocator<Attribute>(JS_GetRuntime(ctx))) {
    m_localName.atom = JS_DupAtom(ctx, localName);
    if (prefix != JS_ATOM_NULL) {
        m_prefix.atom = JS_DupAtom(ctx, prefix);
    }
    if (otherNamespace != JS_ATOM_NULL) {
        m_otherNamespace.atom = JS_DupAtom(ctx, otherNamespace);
    }
}

std::optional<String> Element::prefix(JSContext* ctx) {
    if (m_prefix.atom == JS_ATOM_NULL) {
        return std::nullopt;
    }
    return String::fromAtom(ctx, m_prefix.atom);
}

String Element::tagName(JSContext* ctx) {
    String qualified = String::fromAtom(ctx, m_localName.atom);
    if (m_prefix.atom != JS_ATOM_NULL) {
        qualified = String::fromAtom(ctx, m_prefix.atom).concat(ctx, String::fromUTF8(ctx, ":")).concat(ctx, qualified);
    }
    if (m_ns == Namespace::HTML && this->nodeDocument().isHTMLDocument()) {
        return asciiUppercase(ctx, qualified);
    }
    return qualified;
}

// The DOM's attribute algorithms (https://dom.spec.whatwg.org/#concept-element-attributes).

static String valueOf(JSContext* ctx, const Held& value) {
    return String::adopt(ctx, JS_DupValue(ctx, value.value));
}

static Attr* attrOf(const Attribute& a) {
    return a.node.isUndefined() ? nullptr : static_cast<Attr*>(payloadOfKnown(a.node.value));
}

static void releaseAttribute(JSRuntime* rt, Attribute& a) {
    a.localName.clear(rt);
    a.otherNamespace.clear(rt);
    a.prefix.clear(rt);
    a.value.clear(rt);
    a.node.clear(rt);
}

/// DOM "handle attribute changes": the document's listeners (M1b's mutation records, M1c's render tree), then the DOM
/// state's attribute listeners, which hear every document's (HTML's event handler content attributes).
static void noteAttributeChange(JSContext* ctx, Element& element, JSAtom localName, Namespace ns, uint64_t& stamp) {
    // limit.batch (widget-sandbox v0.3.0): one operation per attribute per batch once the element was inserted in an
    // earlier one (Node::countsChange); before, its attributes travel with its making, as upstream's shim sends them.
    Runtime& runtime = Runtime::from(ctx);
    if (element.countsChange(runtime.batchSerial(), stamp)) {
        runtime.addOps(1);
    }
    Document& document = element.nodeDocument();
    document.noteMutation();
    document.forEachMutationListener([&](MutationListener& listener) { listener.attributeChanged(element, localName, ns); });
    DOMState::of(ctx).forEachAttributeListener([&](MutationListener& listener) { listener.attributeChanged(element, localName, ns); });
}

int Element::findByNamespace(JSContext* ctx, Namespace ns, JSAtom otherNamespace, JSAtom localName) const {
    for (size_t i = 0; i < m_attributes.size(); i++) {
        const Attribute& a = m_attributes[i];
        if (a.localName.atom == localName && a.ns == ns && (ns != Namespace::Other || a.otherNamespace.atom == otherNamespace)) {
            return int(i);
        }
    }
    return -1;
}

int Element::findQualified(JSContext* ctx, const String& qualifiedName) const {
    Atom asAtom = Atom::fromString(ctx, qualifiedName);
    // Only a name with a colon can be a prefixed attribute's qualified name.
    JSStringView v = qualifiedName.view();
    uint32_t scanned = 0;
    while (scanned < v.length && (v.latin1 ? v.latin1[scanned] : v.utf16[scanned]) != ':') {
        scanned++;
    }
    bool hasColon = scanned < v.length;
    for (size_t i = 0; i < m_attributes.size(); i++) {
        const Attribute& a = m_attributes[i];
        if (a.prefix.atom == JS_ATOM_NULL ? a.localName.atom == asAtom.get() : hasColon && qualifiedNameIs(ctx, a.prefix.atom, a.localName.atom, qualifiedName)) {
            return int(i);
        }
    }
    return -1;
}

String Element::attributeNameCase(JSContext* ctx, const String& name) const {
    return this->isHTMLElement() && this->nodeDocument().isHTMLDocument() ? asciiLowercase(ctx, name) : name;
}

int Element::findByQualifiedName(JSContext* ctx, const String& qualifiedName) const {
    return this->findQualified(ctx, this->attributeNameCase(ctx, qualifiedName));
}

int Element::indexOfAttr(JSContext* ctx, const Attr& attr) const {
    if (attr.owner() != this) {
        return -1;
    }
    for (size_t i = 0; i < m_attributes.size(); i++) {
        if (attrOf(m_attributes[i]) == &attr) {
            return int(i);
        }
    }
    return -1;
}

std::optional<String> Element::attributeValue(JSContext* ctx, JSAtom localName) const {
    int i = this->findByNamespace(ctx, Namespace::None, JS_ATOM_NULL, localName);
    if (i < 0) {
        return std::nullopt;
    }
    return valueOf(ctx, m_attributes[size_t(i)].value);
}

void Element::setAttributeValue(JSContext* ctx, JSAtom localName, const String& value) {
    int i = this->findByNamespace(ctx, Namespace::None, JS_ATOM_NULL, localName);
    if (i < 0) {
        this->appendAttribute(ctx, Namespace::None, JS_ATOM_NULL, JS_ATOM_NULL, localName, value, nullptr);
    } else {
        this->changeAttribute(ctx, size_t(i), value);
    }
}

void Element::removeAttributeAtom(JSContext* ctx, JSAtom localName) {
    int i = this->findByNamespace(ctx, Namespace::None, JS_ATOM_NULL, localName);
    if (i >= 0) {
        this->removeAttributeAt(ctx, size_t(i));
    }
}

String Element::qualifiedNameOf(JSContext* ctx, const Attribute& attribute) const {
    String local = String::fromAtom(ctx, attribute.localName.atom);
    if (attribute.prefix.atom == JS_ATOM_NULL) {
        return local;
    }
    return String::fromAtom(ctx, attribute.prefix.atom).concat(ctx, String::fromUTF8(ctx, ":")).concat(ctx, local);
}

Attr* Element::attrAt(JSContext* ctx, size_t index) {
    if (m_attributes[index].node.isUndefined()) {
        const Attribute& a = m_attributes[index];
        // Its value stays in the entry (attachTo). Nothing that runs meanwhile edits this list: creating allocates,
        // and a collection that starts only releases.
        Ref<Attr> attr = create<Attr>(ctx, idl::kAttr, ctx, this->nodeDocument(), a.ns, a.otherNamespace.atom, a.prefix.atom, a.localName.atom, String());
        attr->attachTo(ctx, *this);
        m_attributes[index].node.value = attr.release();
    }
    return attrOf(m_attributes[index]);
}

void Element::changeAttribute(JSContext* ctx, size_t index, const String& value) {
    m_attributes[index].value.set(JS_GetRuntime(ctx), value.toJS(ctx));
    noteAttributeChange(ctx, *this, m_attributes[index].localName.atom, m_attributes[index].ns, m_attributes[index].opBatch);
}

void Element::appendAttribute(JSContext* ctx, Namespace ns, JSAtom otherNamespace, JSAtom prefix, JSAtom localName, const String& value, Attr* node) {
    // The entry first: growing the list can fail at the memory limit (JSAllocator throws bad_alloc), and then nothing
    // is held yet. The references are taken once it is in.
    m_attributes.emplace_back();
    Attribute& a = m_attributes.back();
    a.localName.atom = JS_DupAtom(ctx, localName);
    a.ns = ns;
    if (otherNamespace != JS_ATOM_NULL) {
        a.otherNamespace.atom = JS_DupAtom(ctx, otherNamespace);
    }
    if (prefix != JS_ATOM_NULL) {
        a.prefix.atom = JS_DupAtom(ctx, prefix);
    }
    a.value.value = value.toJS(ctx);
    a.addedBatch = Runtime::from(ctx).batchSerial();
    if (node) {
        a.node.value = JS_DupValue(ctx, node->object());
        node->attachTo(ctx, *this);
    }
    noteAttributeChange(ctx, *this, localName, ns, a.opBatch);
}

namespace {

/// Owns a removed entry's references until the end of the scope.
struct RemovedAttribute {
    JSRuntime* rt;
    Attribute entry;
    ~RemovedAttribute() { releaseAttribute(rt, entry); }
};

} // namespace

void Element::removeAttributeAt(JSContext* ctx, size_t index) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    // The later entries move up one.
    RemovedAttribute removed{rt, m_attributes[index]};
    m_attributes.erase(m_attributes.begin() + ptrdiff_t(index));
    if (Attr* attr = attrOf(removed.entry)) {
        // The Attr takes the value over; the entry's reference to the Attr goes with the entry.
        attr->detach(rt, removed.entry.value.value);
        removed.entry.value.value = JS_UNDEFINED;
    }
    noteAttributeChange(ctx, *this, removed.entry.localName.atom, removed.entry.ns, removed.entry.opBatch);
}

void Element::replaceAttributeAt(JSContext* ctx, size_t index, Attr& attr) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    Attribute& a = m_attributes[index];
    JSValue value = attr.currentValue(ctx).toJS(ctx);
    if (Attr* old = attrOf(a)) {
        old->detach(rt, a.value.value);
    } else {
        JS_FreeValueRT(rt, a.value.value);
    }
    a.value.value = value;
    a.prefix.set(rt, attr.prefixAtom() == JS_ATOM_NULL ? JS_ATOM_NULL : JS_DupAtom(ctx, attr.prefixAtom()));
    // Releases the old Attr: the caller holds it.
    a.node.set(rt, JS_DupValue(ctx, attr.object()));
    attr.attachTo(ctx, *this);
    noteAttributeChange(ctx, *this, a.localName.atom, a.ns, a.opBatch);
}

void Element::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (const Attribute& a : m_attributes) {
        a.node.mark(rt, mark);
    }
    m_classList.mark(rt, mark);
    m_attributeMap.mark(rt, mark);
    m_dataset.mark(rt, mark);
    m_style.mark(rt, mark);
    Node::trace(rt, mark);
}

void Element::dispose(JSRuntime* rt) {
    for (Attribute& a : m_attributes) {
        releaseAttribute(rt, a);
    }
    m_attributes.clear();
    m_classList.clear(rt);
    m_attributeMap.clear(rt);
    m_dataset.clear(rt);
    m_style.clear(rt);
    m_localName.clear(rt);
    m_prefix.clear(rt);
    m_otherNamespace.clear(rt);
    Node::dispose(rt);
}

void Element::adoptedInto(JSContext* ctx, Document& document) {
    for (Attribute& a : m_attributes) {
        if (Attr* attr = attrOf(a)) {
            attr->setNodeDocument(ctx, document);
        }
    }
    Node::adoptedInto(ctx, document);
}

Ref<Node> Element::cloneShallow(JSContext* ctx, Document& document) {
    Ref<Element> copy = createElementNode(ctx, document, m_ns, m_localName.atom, m_prefix.atom, m_otherNamespace.atom);
    for (const Attribute& a : m_attributes) {
        copy->appendAttribute(ctx, a.ns, a.otherNamespace.atom, a.prefix.atom, a.localName.atom, valueOf(ctx, a.value), nullptr);
    }
    return copy;
}

bool Element::equalsShallow(JSContext* ctx, Node& other) {
    auto& o = static_cast<Element&>(other);
    if (m_ns != o.m_ns || m_localName.atom != o.m_localName.atom || m_prefix.atom != o.m_prefix.atom || m_otherNamespace.atom != o.m_otherNamespace.atom || m_attributes.size() != o.m_attributes.size()) {
        return false;
    }
    for (const Attribute& a : m_attributes) {
        int j = o.findByNamespace(ctx, a.ns, a.otherNamespace.atom, a.localName.atom);
        if (j < 0 || !valueOf(ctx, a.value).equals(ctx, valueOf(ctx, o.m_attributes[size_t(j)].value))) {
            return false;
        }
    }
    return true;
}

// Element's IDL members.

String Element::id(JSContext* ctx) {
    return this->attributeValue(ctx, DOMState::of(ctx).name(Name::id)).value_or(String());
}

void Element::setId(JSContext* ctx, String value) {
    this->setAttributeValue(ctx, DOMState::of(ctx).name(Name::id), value);
}

String Element::className(JSContext* ctx) {
    return this->attributeValue(ctx, DOMState::of(ctx).name(Name::class_)).value_or(String());
}

void Element::setClassName(JSContext* ctx, String value) {
    this->setAttributeValue(ctx, DOMState::of(ctx).name(Name::class_), value);
}

String Element::slot(JSContext* ctx) {
    return this->attributeValue(ctx, DOMState::of(ctx).name(Name::slot)).value_or(String());
}

void Element::setSlot(JSContext* ctx, String value) {
    this->setAttributeValue(ctx, DOMState::of(ctx).name(Name::slot), value);
}

DOMTokenList* Element::classList(JSContext* ctx) {
    if (m_classList.isUndefined()) {
        m_classList.value = create<DOMTokenList>(ctx, idl::kDOMTokenList, ctx, *this, DOMState::of(ctx).name(Name::class_)).release();
    }
    return static_cast<DOMTokenList*>(payloadOfKnown(m_classList.value));
}

NamedNodeMap* Element::attributes(JSContext* ctx) {
    if (m_attributeMap.isUndefined()) {
        m_attributeMap.value = create<NamedNodeMap>(ctx, idl::kNamedNodeMap, ctx, *this).release();
    }
    return static_cast<NamedNodeMap*>(payloadOfKnown(m_attributeMap.value));
}

DOMStringMap* Element::dataset(JSContext* ctx) {
    if (m_dataset.isUndefined()) {
        m_dataset.value = create<DOMStringMap>(ctx, idl::kDOMStringMap, ctx, *this).release();
    }
    return static_cast<DOMStringMap*>(payloadOfKnown(m_dataset.value));
}

CSSStyleDeclaration* Element::style(JSContext* ctx) {
    if (m_style.isUndefined()) {
        m_style.value = create<CSSStyleDeclaration>(ctx, idl::kCSSStyleDeclaration, ctx, *this).release();
    }
    return static_cast<CSSStyleDeclaration*>(payloadOfKnown(m_style.value));
}

std::vector<String> Element::getAttributeNames(JSContext* ctx) {
    std::vector<String> names;
    names.reserve(m_attributes.size());
    for (const Attribute& a : m_attributes) {
        names.push_back(this->qualifiedNameOf(ctx, a));
    }
    return names;
}

std::optional<String> Element::getAttribute(JSContext* ctx, String qualifiedName) {
    int i = this->findByQualifiedName(ctx, qualifiedName);
    if (i < 0) {
        return std::nullopt;
    }
    return valueOf(ctx, m_attributes[size_t(i)].value);
}

/// The atom of an Other namespace's URI (none for the namespaces the enum names).
static Atom otherNamespaceAtom(JSContext* ctx, Namespace ns, const std::optional<String>& uri) {
    return ns == Namespace::Other ? Atom::fromString(ctx, *uri) : Atom();
}

/// DOM "get an attribute by namespace and local name".
static int findByNamespaceURI(JSContext* ctx, const Element& element, const std::optional<String>& uri, const String& localName) {
    Namespace ns = namespaceOf(uri);
    Atom other = otherNamespaceAtom(ctx, ns, uri);
    Atom local = Atom::fromString(ctx, localName);
    return element.findByNamespace(ctx, ns, other.get(), local.get());
}

std::optional<String> Element::getAttributeNS(JSContext* ctx, std::optional<String> uri, String localName) {
    int i = findByNamespaceURI(ctx, *this, uri, localName);
    if (i < 0) {
        return std::nullopt;
    }
    return valueOf(ctx, m_attributes[size_t(i)].value);
}

[[noreturn]] static void invalidAttributeName(const String& name) {
    throw DOMError{"InvalidCharacterError", "'" + quotedForMessage(name) + "' is not a valid attribute name."};
}

void Element::setAttribute(JSContext* ctx, String qualifiedName, String value) {
    if (!isValidAttributeLocalName(ctx, qualifiedName)) {
        invalidAttributeName(qualifiedName);
    }
    String name = this->attributeNameCase(ctx, qualifiedName);
    int i = this->findQualified(ctx, name);
    if (i < 0) {
        Atom local = Atom::fromString(ctx, name);
        this->appendAttribute(ctx, Namespace::None, JS_ATOM_NULL, JS_ATOM_NULL, local.get(), value, nullptr);
    } else {
        this->changeAttribute(ctx, size_t(i), value);
    }
}

AttributeName validateAndExtractAttributeName(JSContext* ctx, const std::optional<String>& uri, const String& qualifiedName) {
    Namespace ns = namespaceOf(uri);
    std::optional<String> prefix;
    String localName = qualifiedName;
    // The colon is looked for once.
    for (uint32_t i = 0; i < qualifiedName.length(); i++) {
        if (qualifiedName.at(i) == ':') {
            prefix = qualifiedName.substring(ctx, 0, i);
            localName = qualifiedName.substring(ctx, i + 1, qualifiedName.length());
            if (!isValidNamespacePrefix(ctx, *prefix)) {
                throw DOMError{"InvalidCharacterError", "The qualified name provided ('" + quotedForMessage(qualifiedName) + "') has an invalid prefix."};
            }
            break;
        }
    }
    if (!isValidAttributeLocalName(ctx, localName)) {
        invalidAttributeName(qualifiedName);
    }
    if (prefix && ns == Namespace::None) {
        throw DOMError{"NamespaceError", "A prefix needs a namespace."};
    }
    if (prefix && prefix->equalsASCII("xml") && ns != Namespace::XML) {
        throw DOMError{"NamespaceError", "The prefix 'xml' needs the XML namespace."};
    }
    bool xmlnsName = qualifiedName.equalsASCII("xmlns") || (prefix && prefix->equalsASCII("xmlns"));
    if (xmlnsName != (ns == Namespace::XMLNS)) {
        throw DOMError{"NamespaceError", "'xmlns' and the XMLNS namespace go together."};
    }
    AttributeName name;
    name.ns = ns;
    name.otherNamespace = otherNamespaceAtom(ctx, ns, uri);
    if (prefix) {
        name.prefix = Atom::fromString(ctx, *prefix);
    }
    name.localName = Atom::fromString(ctx, localName);
    return name;
}

void Element::setAttributeNS(JSContext* ctx, std::optional<String> uri, String qualifiedName, String value) {
    AttributeName name = validateAndExtractAttributeName(ctx, uri, qualifiedName);
    int i = this->findByNamespace(ctx, name.ns, name.otherNamespace.get(), name.localName.get());
    if (i < 0) {
        this->appendAttribute(ctx, name.ns, name.otherNamespace.get(), name.prefix.get(), name.localName.get(), value, nullptr);
    } else {
        this->changeAttribute(ctx, size_t(i), value);
    }
}

void Element::removeAttribute(JSContext* ctx, String qualifiedName) {
    int i = this->findByQualifiedName(ctx, qualifiedName);
    if (i >= 0) {
        this->removeAttributeAt(ctx, size_t(i));
    }
}

void Element::removeAttributeNS(JSContext* ctx, std::optional<String> uri, String localName) {
    int i = findByNamespaceURI(ctx, *this, uri, localName);
    if (i >= 0) {
        this->removeAttributeAt(ctx, size_t(i));
    }
}

bool Element::toggleAttribute(JSContext* ctx, String qualifiedName, std::optional<bool> force) {
    if (!isValidAttributeLocalName(ctx, qualifiedName)) {
        invalidAttributeName(qualifiedName);
    }
    String name = this->attributeNameCase(ctx, qualifiedName);
    int i = this->findQualified(ctx, name);
    if (i < 0) {
        if (!force || *force) {
            Atom local = Atom::fromString(ctx, name);
            this->appendAttribute(ctx, Namespace::None, JS_ATOM_NULL, JS_ATOM_NULL, local.get(), String(), nullptr);
            return true;
        }
        return false;
    }
    if (!force || !*force) {
        this->removeAttributeAt(ctx, size_t(i));
        return false;
    }
    return true;
}

bool Element::hasAttributeNS(JSContext* ctx, std::optional<String> uri, String localName) {
    return findByNamespaceURI(ctx, *this, uri, localName) >= 0;
}

Attr* Element::getAttributeNode(JSContext* ctx, String qualifiedName) {
    int i = this->findByQualifiedName(ctx, qualifiedName);
    return i < 0 ? nullptr : this->attrAt(ctx, size_t(i));
}

Attr* Element::getAttributeNodeNS(JSContext* ctx, std::optional<String> uri, String localName) {
    int i = findByNamespaceURI(ctx, *this, uri, localName);
    return i < 0 ? nullptr : this->attrAt(ctx, size_t(i));
}

// DOM "set an attribute".
Ref<Attr> Element::setAttributeNode(JSContext* ctx, Attr* attr) {
    if (attr->owner() && attr->owner() != this) {
        throw DOMError{"InUseAttributeError", "The attribute is in use by another element."};
    }
    int i = this->findByNamespace(ctx, attr->ns(), attr->otherNamespaceAtom(), attr->localNameAtom());
    if (i >= 0 && attrOf(m_attributes[size_t(i)]) == attr) {
        return Ref<Attr>::retain(ctx, attr);
    }
    if (i >= 0) {
        Ref<Attr> old = Ref<Attr>::retain(ctx, this->attrAt(ctx, size_t(i)));
        this->replaceAttributeAt(ctx, size_t(i), *attr);
        return old;
    }
    this->appendAttribute(ctx, attr->ns(), attr->otherNamespaceAtom(), attr->prefixAtom(), attr->localNameAtom(), attr->currentValue(ctx), attr);
    return Ref<Attr>();
}

Ref<Attr> Element::removeAttributeNode(JSContext* ctx, Attr* attr) {
    int i = this->indexOfAttr(ctx, *attr);
    if (i < 0) {
        throw DOMError{"NotFoundError", "The attribute is not an attribute of this element."};
    }
    Ref<Attr> keep = Ref<Attr>::retain(ctx, attr);
    this->removeAttributeAt(ctx, size_t(i));
    return keep;
}

} // namespace wr
