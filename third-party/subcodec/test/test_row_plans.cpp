#include "mbs_mux_common.h"
#include <cstdio>
#include <vector>

using namespace subcodec::mux;

static int failures = 0;

#define CHECK_EQ(actual, expected, msg) do { \
    if ((actual) != (expected)) { \
        printf("FAIL: %s — got %d, expected %d (line %d)\n", \
               msg, (int)(actual), (int)(expected), __LINE__); \
        failures++; \
    } \
} while(0)

static void test_single_sprite() {
    printf("test_single_sprite...\n");

    // 1-slot grid: sprite_w=6, sprite_h=6, padding=1
    // slot_w = 6*2 - 1 = 11, stride_x = 10
    // total_w = 11, total_h = 6
    int sprite_w = 6, sprite_h = 6, padding = 1;
    int total_w = 11, total_h = 6;
    int max_slots = 1;
    bool active[] = {true};

    std::vector<CompositeRowPlan> plans;
    std::vector<RowOp> ops;
    build_row_plans(active, max_slots, sprite_w, sprite_h, padding,
                    total_w, total_h, plans, ops);

    CHECK_EQ((int)plans.size(), total_h, "plans.size");

    for (int cy = 0; cy < total_h; cy++) {
        auto& plan = plans[cy];
        CHECK_EQ(plan.ops_count, 1, "ops_count");
        CHECK_EQ(plan.trailing_skips, 0, "trailing_skips");

        auto& op = ops[plan.ops_offset];
        CHECK_EQ(op.slot_idx, 0, "slot_idx");
        CHECK_EQ(op.sprite_row, cy, "sprite_row");
        CHECK_EQ(op.pre_skip, 0, "pre_skip");
        CHECK_EQ(op.overlap, 0, "overlap");
    }

    printf("  single_sprite: %d failures\n", failures);
}

static void test_2x2_grid() {
    printf("test_2x2_grid...\n");
    int before = failures;

    // 4-slot grid: sprite_w=6, sprite_h=6, padding=1
    // slot_w = 11, stride_x = 10, stride_y = 5
    // cols=2, rows=2, total_w=21, total_h=11
    int sprite_w = 6, sprite_h = 6, padding = 1;
    int total_w = 21, total_h = 11;
    int max_slots = 4;
    bool active[] = {true, true, true, true};

    std::vector<CompositeRowPlan> plans;
    std::vector<RowOp> ops;
    build_row_plans(active, max_slots, sprite_w, sprite_h, padding,
                    total_w, total_h, plans, ops);

    CHECK_EQ((int)plans.size(), total_h, "plans.size");

    // Row 0: slot 0 (sprite_ox=0, end=11), slot 1 (sprite_ox=10, end=21)
    {
        auto& plan = plans[0];
        CHECK_EQ(plan.ops_count, 2, "row0 ops_count");
        CHECK_EQ(plan.trailing_skips, 0, "row0 trailing_skips");

        auto& op0 = ops[plan.ops_offset];
        CHECK_EQ(op0.slot_idx, 0, "row0 op0 slot_idx");
        CHECK_EQ(op0.sprite_row, 0, "row0 op0 sprite_row");
        CHECK_EQ(op0.pre_skip, 0, "row0 op0 pre_skip");
        CHECK_EQ(op0.overlap, 0, "row0 op0 overlap");

        auto& op1 = ops[plan.ops_offset + 1];
        CHECK_EQ(op1.slot_idx, 1, "row0 op1 slot_idx");
        CHECK_EQ(op1.sprite_row, 0, "row0 op1 sprite_row");
        CHECK_EQ(op1.pre_skip, 0, "row0 op1 pre_skip");
        CHECK_EQ(op1.overlap, 1, "row0 op1 overlap");
    }

    // Row 5: slot 2 (sprite_row=0, sprite_ox=0, end=11), slot 3 (sprite_row=0, sprite_ox=10, end=21)
    {
        auto& plan = plans[5];
        CHECK_EQ(plan.ops_count, 2, "row5 ops_count");
        CHECK_EQ(plan.trailing_skips, 0, "row5 trailing_skips");

        auto& op0 = ops[plan.ops_offset];
        CHECK_EQ(op0.slot_idx, 2, "row5 op0 slot_idx");
        CHECK_EQ(op0.sprite_row, 0, "row5 op0 sprite_row");
        CHECK_EQ(op0.pre_skip, 0, "row5 op0 pre_skip");
        CHECK_EQ(op0.overlap, 0, "row5 op0 overlap");

        auto& op1 = ops[plan.ops_offset + 1];
        CHECK_EQ(op1.slot_idx, 3, "row5 op1 slot_idx");
        CHECK_EQ(op1.sprite_row, 0, "row5 op1 sprite_row");
        CHECK_EQ(op1.pre_skip, 0, "row5 op1 pre_skip");
        CHECK_EQ(op1.overlap, 1, "row5 op1 overlap");
    }

    printf("  2x2_grid: %d new failures\n", failures - before);
}

static void test_partial_grid() {
    printf("test_partial_grid...\n");
    int before = failures;

    // 2x2 grid, slot 2 inactive
    // slot_w = 11, stride_x = 10, stride_y = 5
    // total_w = 21, total_h = 11
    int sprite_w = 6, sprite_h = 6, padding = 1;
    int total_w = 21, total_h = 11;
    int max_slots = 4;
    bool active[] = {true, true, false, true};

    std::vector<CompositeRowPlan> plans;
    std::vector<RowOp> ops;
    build_row_plans(active, max_slots, sprite_w, sprite_h, padding,
                    total_w, total_h, plans, ops);

    // Row 0: still has slots 0 and 1 (both active)
    {
        auto& plan = plans[0];
        CHECK_EQ(plan.ops_count, 2, "row0 ops_count");
    }

    // Row 5: slot 2 inactive, slot 3 active
    // slot 2 region: ox=0..11, slot 3 region: ox=10..21
    // prev_end from slot 2 (inactive) = 11, slot 3 sprite_ox=10
    // overlap = prev_end - sprite_ox = 11 - 10 = 1
    {
        auto& plan = plans[5];
        CHECK_EQ(plan.ops_count, 1, "row5 ops_count");
        CHECK_EQ(plan.trailing_skips, 0, "row5 trailing_skips");

        auto& op0 = ops[plan.ops_offset];
        CHECK_EQ(op0.slot_idx, 3, "row5 op0 slot_idx");
        CHECK_EQ(op0.sprite_row, 0, "row5 op0 sprite_row");
        /* pre_skip = max(sprite_ox(10), prev_end(11)) - last_active_end(0) = 11.
         * slot 2 inactive, so last_active_end stays at 0. */
        CHECK_EQ(op0.pre_skip, 11, "row5 op0 pre_skip");
        CHECK_EQ(op0.overlap, 1, "row5 op0 overlap");
    }

    printf("  partial_grid: %d new failures\n", failures - before);
}

static void test_empty_grid() {
    printf("test_empty_grid...\n");
    int before = failures;

    // All 4 slots inactive
    // slot_w = 11, stride_x = 10, total_w = 21, total_h = 11
    int sprite_w = 6, sprite_h = 6, padding = 1;
    int total_w = 21, total_h = 11;
    int max_slots = 4;
    bool active[] = {false, false, false, false};

    std::vector<CompositeRowPlan> plans;
    std::vector<RowOp> ops;
    build_row_plans(active, max_slots, sprite_w, sprite_h, padding,
                    total_w, total_h, plans, ops);

    for (int cy = 0; cy < total_h; cy++) {
        auto& plan = plans[cy];
        CHECK_EQ(plan.ops_count, 0, "ops_count");
        CHECK_EQ(plan.trailing_skips, total_w, "trailing_skips");
    }

    printf("  empty_grid: %d new failures\n", failures - before);
}

int main() {
    test_single_sprite();
    test_2x2_grid();
    test_partial_grid();
    test_empty_grid();

    if (failures == 0) {
        printf("PASS: all row_plans tests passed\n");
    } else {
        printf("FAIL: %d total failures\n", failures);
    }
    return failures > 0 ? 1 : 0;
}
