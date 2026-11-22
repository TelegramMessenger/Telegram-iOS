// html5lib's tree-construction tests (html5lib-tests 9329e64, the last revision before they moved to WPT) through
// the fork, with its default limits. Every case passes except the ones listed in the expected-failures file, which
// fail before the fork too; a listed case that starts passing, or does not run, fails the test until it is removed from
// the list. A file that cannot be read or gives no case, or a total other than 1,792 cases in 57 files, fails it too.
// The reading, skipping and counting are html5lib_dat.h's, which WidgetRuntime's builder suite shares.
//
// Usage: GumboHtml5libTests <expected-failures.txt> <file.dat>...
#include "html5lib_dat.h"

int main(int argc, char** argv) {
    return gumbo_test::runSuite(argc, argv, gumbo_test::gumboTree);
}
