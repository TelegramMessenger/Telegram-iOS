// WidgetRuntime's testharnessreport.js (M1b plan, Task 17). The WPT runner serves this file at
// /resources/testharnessreport.js in place of upstream's. It turns the harness's output UI off (the UI needs layout)
// and hands every result to the runner's natives, which the runner installs before the page boots.
setup({output: false});
add_completion_callback(function (tests, harnessStatus) {
    for (var i = 0; i < tests.length; i++) {
        var test = tests[i];
        __wptSubtest(String(test.name), test.status, test.message == null ? "" : String(test.message));
    }
    __wptDone(harnessStatus.status, harnessStatus.message == null ? "" : String(harnessStatus.message));
});
