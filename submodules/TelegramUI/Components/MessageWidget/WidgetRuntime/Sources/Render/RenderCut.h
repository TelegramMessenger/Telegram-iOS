// The caps' cut in tree order. A build hands every cap out in tree order (Builder.h): W's 10,000 elements and 256 form
// controls, the render byte budget and the 64 KiB of `<style>` text (Ruling 7), profile 1's text budgets and node cap,
// and litehtml's depth, 20,000 elements and 10,000 text pieces for the document's own content. RenderCut is that
// state and the checks each node asks of it; the build's walk asks them, and so does a dry walk of the same code that
// decides as the build does and makes nothing (renderCutDiff), for a patch that must find where a fresh build of the
// DOM as it now is would cut.
#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>

#include "Sources/Render/Builder.h"

namespace wr {

class Node;
class WidgetContainer;

/// What the walk decided for a node: rendered; left out whatever the caps say (Ruling 4, or its parent's own append
/// refuses it: twidget edit 83); cut by a cap, the walk going on; or past the byte budget's or the node cap's stop.
enum class RenderFate : uint8_t { Rendered, Unrendered, Cut, Stopped };

/// One node the walk decided, with the state before it. What it counted: an element's attributes' bytes and units, a
/// Text's bytes and units. A Text's pieces are all of them, or a prefix up to the piece cap; a `<style>`'s, its sheet's
/// one piece when the sheet is applied.
struct RenderCutNode {
    Node* node = nullptr;
    RenderFate fate = RenderFate::Rendered;
    RenderCutState before;
    size_t bytes = 0;
    TextUnits units;
    uint32_t pieces = 0;
    /// Whether its fate, pieces, bytes or units differ from the published entry.
    bool differs = false;
};

/// The caps' state and the checks a walk asks, in the order it asks them, noting each limit kind once in the order first
/// hit, by Ruling 7's names.
class RenderCut {
public:
    RenderCut() = default;
    explicit RenderCut(const RenderCutState& start) : m_state(start) {}

    const RenderCutState& state() const { return m_state; }
    const std::vector<std::string>& limits() const { return m_limits; }
    void note(std::string_view kind);

    /// Adds `count` nodes (RB §7.1 MAX_NODES); false once past kMaxRenderNodes.
    bool addNodes(size_t count);
    /// The limit an element here would hit, or null: W's elements (E9), the form controls (E6), litehtml's depth, and,
    /// when `countsLitehtml` (a build's walk: a subtree's elements are counted by the fork's predicate), its 20,000.
    const char* elementLimit(bool formControl, int depth, bool countsLitehtml) const;
    void addElement(bool formControl, bool countsLitehtml);
    /// The empty `<html>` a build makes when nothing of the DOM is rendered (Ruling 11), which litehtml counts.
    void addLitehtmlElement() { m_state.litehtmlElements++; }
    size_t remainingBytes() const { return kMaxRenderBytes - m_state.bytes; }
    void add(size_t bytes, TextUnits units) {
        m_state.bytes += bytes;
        m_state.units += units;
    }
    void addUnits(TextUnits units) { m_state.units += units; }
    size_t cssRoom() const { return kMaxStyleText - m_state.cssBytes; }
    void addCss(size_t bytes) { m_state.cssBytes += bytes; }
    /// How many of `count` pieces litehtml's piece cap keeps here (twidget edit 10: one is made while fewer than
    /// max_text_elements are alive), counting them; past the cap it notes `text-pieces`.
    uint32_t keepPieces(uint32_t count);
    /// Counts pieces made without asking the cap (a build's, which asked it piece by piece; a subtree's, which the fork's
    /// predicate counts).
    void addPieces(size_t count) { m_state.pieces += int(count); }
    void stop() { m_state.stopped = true; }

private:
    RenderCutState m_state;
    std::vector<std::string> m_limits;
};

/// The dry walk's answer, against a published build.
struct RenderCutDiff {
    explicit RenderCutDiff(JSRuntime* rt) : nodes(JSAllocator<RenderCutNode>(rt)) {}
    /// Every node whose fate, pieces, bytes or units differ from `published`'s entries, and every node of `wanted` (every
    /// node visited, with `all`), in tree order; then the published entries the walk did not reach (past a stop, or out of
    /// the document) that hold an element, pieces or a place in the render input, Stopped, with the end state as theirs.
    std::vector<RenderCutNode, JSAllocator<RenderCutNode>> nodes;
    /// The limits a build of the DOM as it now is would post during its walk, in the order first hit.
    std::vector<std::string> limits;
    RenderCutState end;
};

/// The DOM walked from its document element as buildDocument walks it (Builder.cpp: the same walk, in its dry mode),
/// deciding and making nothing. An entry differs when a Rendered node has none, an entry with an element, pieces or a
/// place in the render input is not Rendered, or a Rendered node's pieces, bytes or units are not its entry's. Throws
/// Thrown (a conversion at the memory limit), std::bad_alloc or Aborted (a strict cap).
RenderCutDiff renderCutDiff(JSContext* ctx, WidgetContainer& container, const RenderBuild& published,
                            const std::unordered_set<const Node*>& wanted, bool all = false);

} // namespace wr
