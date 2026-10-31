// The virtual-time driver (M1b plan, Task 17) the WPT runner and the corpus boot share: tasks while runnable, then a
// wanted frame at the next 60 Hz tick unless a timer is due first, then the next timer deadline.
#include "Tests/HostHarness.h"
#include "Tests/JSHarness.h"
#include "Tests/VirtualTime.h"

WR_TEST(testDriveRunsTimersAndFramesInDeadlineOrder) {
    wr_test::HostEnv env;
    env.eval("globalThis.log = [];"
             "setTimeout(() => log.push('t30'), 30);"
             "setTimeout(() => log.push('t5'), 5);"
             "requestAnimationFrame(() => log.push('frame'));");
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env, 100, {}, 100000);
    CHECK(end == wr_test::DriveEnd::Idle);
    CHECK_JS_EQ(env, "log.join()", "t5,frame,t30");
    CHECK(env.host().now == 30);  // the clock stopped at the last deadline
}

WR_TEST(testDriveFramesAdvanceTheClockEveryTick) {
    // Tick 63 is 1050 ms, and 1050 / (1000 / 60) evaluates below 63: a next frame computed from the clock's own time
    // came out at the clock's time, and the loop ran frames at 1050 ms forever.
    wr_test::HostEnv env;
    env.eval("globalThis.stamps = [];"
             "requestAnimationFrame(function again(t) { stamps.push(t); requestAnimationFrame(again); });");
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env, 2000, {}, 100000);
    CHECK(end == wr_test::DriveEnd::TimeLimit);
    CHECK(env.host().now == 2000);
    // Ticks 1 to 119: tick 120 is 2000.0000000000002 ms, past the limit.
    CHECK_JS_EQ(env, "stamps.length", "119");
    CHECK_JS(env, "stamps.every((t, i) => i == 0 || t > stamps[i - 1])");
    CHECK_JS(env, "stamps[62] == 1050 && stamps[63] > 1050");
}

WR_TEST(testDriveRunsAFrameDueWithATimerAtThatTickAfterTheTimer) {
    // Tick 3 is exactly 50 ms. The frame wanted from 40 ms is due at the tick the 50 ms timer is due at: the timer's
    // task runs first, and the frame runs at that same tick after it.
    wr_test::HostEnv env;
    env.eval("globalThis.log = [];"
             "setTimeout(() => requestAnimationFrame(t => log.push('frame ' + t)), 40);"
             "setTimeout(() => log.push('t50'), 50);");
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env, 100, {}, 100000);
    CHECK(end == wr_test::DriveEnd::Idle);
    CHECK_JS_EQ(env, "log.join()", "t50,frame 50");
    CHECK(env.host().now == 50);
}

WR_TEST(testDriveStopsAtTheTimeLimitWithoutPassingIt) {
    wr_test::HostEnv env;
    env.eval("globalThis.n = 0; setInterval(() => n++, 10);");
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env, 95, {}, 100000);
    CHECK(end == wr_test::DriveEnd::TimeLimit);
    CHECK(env.host().now == 95);
    CHECK_JS_EQ(env, "n", "9");
}

WR_TEST(testDriveEndsWhenDoneHolds) {
    wr_test::HostEnv env;
    env.eval("globalThis.n = 0; setInterval(() => n++, 10);");
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env, 1000, [&] { return env.eval("n") == "3"; }, 100000);
    CHECK(end == wr_test::DriveEnd::Done);
    CHECK(env.host().now == 30);
}

WR_TEST(testDriveReportsTheStopLatch) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    wr_test::stopAfter(env.runtime());
    env.eval("setTimeout(function spin() { for (;;) {} }, 1);");
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env, 1000, {}, 100000);
    CHECK(end == wr_test::DriveEnd::Stopped);
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
}

WR_TEST(testDriveIsBoundedBySteps) {
    wr_test::HostEnv env;
    env.eval("requestAnimationFrame(function again() { requestAnimationFrame(again); });");
    wr_test::DriveEnd end = wr_test::driveVirtualTime(env, 1e9, {}, 50);
    CHECK(end == wr_test::DriveEnd::StepLimit);
}
