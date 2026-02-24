import os
import signal

from lldb_common import load_launch_info

launch_info = load_launch_info()
debug_pid = int(launch_info["pid"])
try:
    os.kill(debug_pid, signal.SIGKILL)
except Exception:
    pass
