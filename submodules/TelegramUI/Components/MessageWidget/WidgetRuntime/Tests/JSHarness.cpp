#include "Tests/JSHarness.h"

namespace wr_test {

JSEnv::JSEnv(const wr::InterfaceTable& table, wr::Host* host) {
    wr::Runtime::Options options;
    options.interfaces = &table;
    options.host = host;
    m_runtime = wr::Runtime::create(options);
}

JSEnv::~JSEnv() = default;

std::string JSEnv::eval(std::string_view code) {
    bool threw = false;
    std::string result = m_runtime->evaluateToString(code, "<test>", &threw);
    return threw ? "THROW " + result : result;
}

} // namespace wr_test
