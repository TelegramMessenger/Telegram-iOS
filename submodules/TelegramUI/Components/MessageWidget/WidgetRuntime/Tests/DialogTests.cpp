// HTMLDialogElement as profile 1's sandbox has it (V4 plan, Task 8; RB §8.2): show() and showModal() set open, close()
// removes it, sets returnValue when given and fires a non-bubbling close synchronously. The renderer's copy is an inert
// div with data-tg-tag, in flow: no top layer, no backdrop.
#include <string>

#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

WR_TEST(testDialogMethodsSetOpenOnly) {
    RenderEnv env("<!doctype html><body><dialog id=dlg>m</dialog><script>window.dlg = document.getElementById('dlg');"
                  "window.log = []; dlg.addEventListener('close', e => log.push('close:' + e.bubbles + ':' + dlg.open));"
                  "document.body.addEventListener('close', () => log.push('bubbled'));</script></body>");
    CHECK_EQ(env.env().eval("[dlg instanceof HTMLDialogElement, dlg.open, JSON.stringify(dlg.returnValue)].join()"),
             std::string("true,false,\"\""));
    CHECK_EQ(env.env().eval("dlg.showModal(); [dlg.open, JSON.stringify(dlg.getAttribute('open'))].join()"),
             std::string("true,\"\""));
    env.flush();
    CHECK(env.render().renderInput().find("<div data-tg-tag=\"dialog\" id=\"dlg\" open=\"\">") != std::string::npos);
    CHECK_EQ(env.env().eval("dlg.close('x'); log.push('returned'); [dlg.open, dlg.returnValue, log.join(' ')].join()"),
             std::string("false,x,close:false:false returned"));
    CHECK_EQ(env.env().eval("dlg.show(); dlg.open"), std::string("true"));
    // close() without a value keeps the returnValue; a closed dialog's close() still fires (the sandbox does).
    CHECK_EQ(env.env().eval("log.length = 0; dlg.close(); dlg.close(); [dlg.returnValue, log.length].join()"),
             std::string("x,2"));
    CHECK_EQ(env.env().eval("dlg.returnValue = 'y'; dlg.returnValue"), std::string("y"));
}

// RB §8.1: the selection methods of an input are no-ops (the element is dropped from the renderer).
WR_TEST(testInputSelectionMethodsAreNoOps) {
    RenderEnv env("<!doctype html><body><input id=i value=abc></body>");
    CHECK_EQ(env.env().eval("const i = document.getElementById('i'); i.select(); i.setSelectionRange(0, 2, 'forward');"
                            " i.setSelectionRange(1, 1); [typeof i.select, i.value].join()"),
             std::string("function,abc"));
}
