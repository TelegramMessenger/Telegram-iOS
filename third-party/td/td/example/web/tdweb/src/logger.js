class Logger {
  constructor() {
    this.setVerbosity('WARNING');
  }
  debug(...str) {
    if (this.checkVerbosity(4)) {
      console.log(...str);
    }
  }
  log(...str) {
    if (this.checkVerbosity(4)) {
      console.log(...str);
    }
  }
  info(...str) {
    if (this.checkVerbosity(3)) {
      console.info(...str);
    }
  }
  warn(...str) {
    if (this.checkVerbosity(2)) {
      console.warn(...str);
    }
  }
  error(...str) {
    if (this.checkVerbosity(1)) {
      console.error(...str);
    }
  }
  setVerbosity(level, default_level = 'info') {
    if (level === undefined) {
      level = default_level;
    }
    if (typeof level === 'string') {
      level =
        { ERROR: 1, WARNING: 2, INFO: 3, LOG: 4, DEBUG: 4 }[
          level.toUpperCase()
        ] || 2;
    }
    this.level = level;
  }
  checkVerbosity(level) {
    return this.level >= level;
  }
}
let log = new Logger();
export default log;
