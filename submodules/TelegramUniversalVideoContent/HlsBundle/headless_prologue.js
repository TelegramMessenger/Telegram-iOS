
class ConsolePolyfill {
    constructor() {
    }

    log(...messageArgs) {
        var string = "";
        for (const arg of messageArgs) {
            string += arg;
        }
        _JsCorePolyfills.consoleLog(string);
    }

    error(...messageArgs) {
        var string = "";
        for (const arg of messageArgs) {
            string += arg;
        }
        _JsCorePolyfills.consoleLog(string);
    }
}

class PerformancePolyfill {
    constructor() {
    }

    now() {
        return _JsCorePolyfills.performanceNow();
    }
}

console = new ConsolePolyfill();
performance = new PerformancePolyfill();

self = {
    console: console,
    performance: performance
};
