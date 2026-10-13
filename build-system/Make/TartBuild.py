import contextlib
import fcntl
import os
import json
import re
import shutil
import signal
import sys
import tempfile
import subprocess
import uuid
import time
import threading
import logging
from typing import Dict, Optional, List, Any
from pathlib import Path

from BuildEnvironment import run_executable_with_output

from RemoteBuildInterface import *

logger = logging.getLogger(__name__)

class TartBuildError(Exception):
    """Exception raised for Tart build errors"""
    pass

TART_VMS_DIR = os.path.expanduser('~/.tart/vms')
# One build at a time is the default. Overriding the lock path runs a build in its own
# exclusion domain, which is only safe from a SEPARATE checkout: a vm-build deletes and
# rebuilds build-input/remote-input in its working directory, so two runs sharing one
# checkout corrupt each other's codesigning inputs no matter what the lock says.
VM_BUILD_LOCK_PATH = os.environ.get(
    'TELEGRAM_VM_BUILD_LOCK_PATH',
    os.path.expanduser('~/.telegram-build/vm-build.lock')
)


def _vm_build_domain() -> str:
    """Token naming this build's exclusion domain, derived from the lock file."""
    name = os.path.basename(VM_BUILD_LOCK_PATH)
    if name.endswith('.lock'):
        name = name[:-len('.lock')]
    # Hyphens are stripped, not preserved: '-' separates the domain from the uuid, so a
    # token containing one would make prefixes ambiguous and 'telegrambuild-vm-build-'
    # would match 'telegrambuild-vm-build-b-<uuid>' -- the second domain's live VM.
    return re.sub(r'[^a-z0-9]+', '', name.lower()) or 'default'


# Ephemeral VM names carry their exclusion domain, and reap_orphan_vms only ever touches
# its own prefix. The reaper deletes matching VMs unconditionally, which is sound only
# while every VM it can see belongs to a run its lock has already excluded -- so builds
# under different locks MUST NOT share a prefix, or the one that starts second stops and
# deletes the first one's live VM.
EPHEMERAL_VM_PREFIX = 'telegrambuild-{}-'.format(_vm_build_domain())


def list_local_vm_names() -> List[str]:
    """Names of the locally stored Tart VMs, read from ~/.tart/vms.

    A directory listing rather than `tart list`, which exits 1 while any ASIF-backed
    VM is attached (see TartVMManager._is_vm_running) and is therefore unavailable
    exactly when a VM is running.
    """
    try:
        return sorted(
            name for name in os.listdir(TART_VMS_DIR)
            if os.path.isdir(os.path.join(TART_VMS_DIR, name))
        )
    except FileNotFoundError:
        return []


# Tart refuses to configure a VM below this, so it doubles as the floor for both defaults.
MINIMUM_VM_MEMORY_MB = 4096
# Half of host memory would hand a large host far more than the build can use, and would
# leave no room for the second VM that --random-mac/--random-serial exist to allow.
MAXIMUM_VM_MEMORY_MB = 32 * 1024


def default_vm_cpu_count() -> int:
    """All host cores but one, which is left for the host itself."""
    return max(1, (os.cpu_count() or 2) - 1)


def default_vm_memory_mb() -> int:
    """Half of host memory, capped, rounded down to a whole gigabyte."""
    try:
        result = subprocess.run([
            'sysctl', '-n', 'hw.memsize'
        ], check=True, capture_output=True, text=True)
        total_bytes = int(result.stdout.strip())
    except Exception as e:
        logger.warning('Could not read host memory size, defaulting to {} MB: {}'.format(MINIMUM_VM_MEMORY_MB, e))
        return MINIMUM_VM_MEMORY_MB
    megabytes = min(MAXIMUM_VM_MEMORY_MB, (total_bytes // 2) // (1024 * 1024))
    return max(MINIMUM_VM_MEMORY_MB, (megabytes // 1024) * 1024)


def default_vm_image_name(macos_version: str, xcode_version: str) -> str:
    return 'macos-{}-xcode-{}'.format(macos_version, xcode_version)


def format_duration(seconds: float) -> str:
    seconds = int(max(0, seconds))
    if seconds < 60:
        return '{}s'.format(seconds)
    if seconds < 3600:
        return '{}m{}s'.format(seconds // 60, seconds % 60)
    return '{}h{}m'.format(seconds // 3600, (seconds % 3600) // 60)


class TartLock:
    """Host-wide mutual exclusion between concurrent `Make.py vm-build` processes.

    The kernel drops an flock when the holding process dies, however it dies, so a
    crashed or `kill -9`ed build never wedges the next one -- the property a pid file
    does not have. The guard this replaces lived in TartVMManager.active_vms, which is
    per-process state and so is always empty on a fresh run; it never excluded anything.
    """

    def __init__(self, path: str = VM_BUILD_LOCK_PATH):
        self.path = path
        self.fd: Optional[int] = None

    def acquire(self, target: str, mode: str) -> None:
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        fd = os.open(self.path, os.O_RDWR | os.O_CREAT, 0o644)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            holder = self._describe_holder()
            os.close(fd)
            raise TartBuildError(
                'Another vm-build is already running on this host{}.\n'
                'Only one build VM is allowed at a time; wait for it to finish, or stop it.'.format(holder)
            )

        self.fd = fd
        os.ftruncate(fd, 0)
        os.write(fd, json.dumps({
            'pid': os.getpid(),
            'target': target,
            'mode': mode,
            'started_at': time.time()
        }).encode('utf-8'))
        os.fsync(fd)

    def _describe_holder(self) -> str:
        try:
            with open(self.path) as file:
                holder = json.load(file)
        except Exception:
            # The holder writes without synchronisation, so an empty or torn read just
            # means a less specific message -- never a failure to report the conflict.
            return ''

        parts = []
        if holder.get('pid') is not None:
            parts.append('pid {}'.format(holder['pid']))
        if holder.get('target'):
            parts.append("{} vm '{}'".format(holder.get('mode', ''), holder['target']).strip())
        if holder.get('started_at'):
            parts.append('started {} ago'.format(format_duration(time.time() - holder['started_at'])))
        if not parts:
            return ''
        return ' ({})'.format(', '.join(parts))

    def release(self) -> None:
        if self.fd is None:
            return
        try:
            fcntl.flock(self.fd, fcntl.LOCK_UN)
        except Exception:
            pass
        try:
            os.close(self.fd)
        except Exception:
            pass
        self.fd = None

    def __enter__(self) -> 'TartLock':
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release()


_active_vm_build_lock: Optional[TartLock] = None


@contextlib.contextmanager
def exclusive_vm_build(target: str, mode: str):
    """Hold the host-wide vm-build lock, then reclaim orphans from earlier runs.

    Enter this BEFORE touching anything shared between runs -- in particular before
    `build-input/remote-input` is rebuilt. That directory is rsynced into the VM, and a
    second vm-build empties it on its way to being refused, so taking the lock late let a
    refused run strip the certificates out from under a build that was already uploading
    them. The guest then imported nothing and failed in `security set-key-partition-list`
    with "The specified item could not be found in the keychain", which reads like a
    codesigning problem and is really a concurrency one.

    The reaping sits inside the lock deliberately: holding it is what makes "every
    EPHEMERAL_VM_PREFIX VM on this host belongs to a process that is gone" true, and
    therefore what makes deleting them unconditionally safe.
    """
    global _active_vm_build_lock

    lock = TartLock()
    lock.acquire(target=target, mode=mode)
    _active_vm_build_lock = lock
    try:
        TartVMManager().reap_orphan_vms()
        yield lock
    finally:
        _active_vm_build_lock = None
        lock.release()


@contextlib.contextmanager
def teardown_signal_handlers():
    """Turn SIGTERM/SIGHUP into an exception so the enclosing `with` blocks still run.

    Without this a killed CI job leaves the VM running: the `tart run` child is not in
    a process group anything tears down, so it is reparented to launchd and outlives us.
    SIGINT already raises KeyboardInterrupt, and SIGKILL cannot be caught at all -- that
    last case is what the next run's orphan reaping covers.

    The handler restores the previous handlers before raising, so a second Ctrl-C during
    cleanup does the default thing rather than trapping the user in a hanging teardown.
    """
    previous: Dict[int, Any] = {}

    def restore():
        for sig, old in previous.items():
            try:
                signal.signal(sig, old)
            except Exception:
                pass

    def handler(signum, frame):
        restore()
        raise TartBuildError('Interrupted by signal {}'.format(signum))

    for sig in (signal.SIGTERM, signal.SIGHUP):
        try:
            previous[sig] = signal.signal(sig, handler)
        except (ValueError, OSError):
            pass
    try:
        yield
    finally:
        restore()

class TartVMManager:
    """Manages Tart VM lifecycle operations"""
    
    def __init__(self):
        self.active_vms: Dict[str, Dict] = {}
        
    def create_vm(self, session_id: str, image: str, mount_directories: Dict[str, str], ephemeral: bool = True, cpu: Optional[int] = None, memory: Optional[int] = None) -> Dict:
        """Create a VM for the session.

        Ephemeral (the default): `image` is cloned into a throwaway VM that is deleted
        when the session ends. Otherwise `image` names a pre-configured VM that is booted
        in place and left alone, so its guest-side bazel cache and source tree survive
        between runs -- which is the entire point of the persistent mode.

        Mutual exclusion is not enforced here. It belongs to the host-wide TartLock the
        caller holds, which is the only thing that sees other Make.py processes.
        """
        if ephemeral:
            vm_name = f"{EPHEMERAL_VM_PREFIX}{session_id}"
        else:
            vm_name = image
            if vm_name not in list_local_vm_names():
                raise TartBuildError(
                    f"No local Tart VM named '{vm_name}'. A persistent VM is booted in place, not created; "
                    f"clone and configure it first, or drop --persistentVM to build in an ephemeral clone."
                )
            if self._is_vm_process_running(vm_name):
                raise TartBuildError(f"VM '{vm_name}' is already running and cannot be reused by this build.")

        try:
            if ephemeral:
                # Clone the base image
                logger.info(f"Cloning VM {vm_name} from image {image}")
                clone_result = subprocess.run([
                    "tart", "clone", image, vm_name
                ], check=True, capture_output=True, text=True)

                logger.info(f"Successfully cloned VM {vm_name}")

                # --random-mac is load-bearing, not cosmetic: `tart ip` resolves through the
                # host DHCP lease file keyed by MAC, so clones that inherited the base image's
                # address would all resolve to the same guest. Disk size is deliberately left
                # alone -- it comes from the (pre-configured) base image.
                set_arguments = ["tart", "set", vm_name, "--random-mac", "--random-serial"]
                if cpu is not None:
                    set_arguments += ["--cpu", str(cpu)]
                if memory is not None:
                    set_arguments += ["--memory", str(memory)]
                logger.info(f"Configuring VM {vm_name} (cpu={cpu}, memory={memory} MB)")
                subprocess.run(set_arguments, check=True, capture_output=True, text=True)

            # Start the VM in background thread
            logger.info(f"Starting VM {vm_name}")
            
            def run_vm():
                """Run the VM in background thread"""
                try:
                    run_arguments = ["tart", "run", vm_name]
                    for mount_directory in mount_directories.keys():
                        run_arguments.append(f"--dir={mount_directory}:{mount_directories[mount_directory]}")
                    subprocess.run(run_arguments, check=True, capture_output=False, text=True)
                except subprocess.CalledProcessError as e:
                    logger.error(f"VM {vm_name} exited with error: {e}")
                except Exception as e:
                    logger.error(f"Unexpected error running VM {vm_name}: {e}")
            
            # Start VM thread
            vm_thread = threading.Thread(target=run_vm, daemon=True)
            vm_thread.start()
            
            # Create VM data with thread reference
            vm_data = {
                "name": vm_name,
                "session_id": session_id,
                "created_at": time.time(),
                "thread": vm_thread,
                "ephemeral": ephemeral
            }
            
            self.active_vms[session_id] = vm_data
            logger.info(f"VM {vm_name} thread started, initializing...")
            
            return vm_data
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error creating VM {vm_name}: {e}")
            if ephemeral and vm_name in list_local_vm_names():
                # The clone succeeded and a later step did not; reclaim it now rather than
                # leaving it for the next run's reaping.
                self._shutdown_vm(vm_name)
                self._delete_vm(vm_name)
            raise TartBuildError(f"Failed to create VM: {e.stderr or e}")
    
    def get_vm(self, session_id: str) -> Optional[Dict]:
        """Get VM information for a session"""
        return self.active_vms.get(session_id)
    
    def check_vm(self, session_id: str) -> Dict:
        """Check and compute VM status dynamically"""
        vm_data = self.active_vms.get(session_id)
        if not vm_data:
            return {"status": "not_found", "error": f"No VM found for session {session_id}"}
        
        vm_name = vm_data["name"]
        vm_thread = vm_data.get("thread")
        
        # Build response with base data
        response = {
            "name": vm_name,
            "session_id": session_id,
            "created_at": vm_data["created_at"]
        }
        
        # Get VM info first (IP address, SSH connectivity, etc.)
        vm_info = self._get_vm_info(vm_name)
        response["info"] = vm_info
        
        # Determine status based on thread, VM state, and SSH connectivity
        if vm_thread and not vm_thread.is_alive():
            # Thread died
            response["status"] = "failed"
            response["error"] = "VM thread has died"
            logger.error(f"VM {vm_name} thread has died")
        elif not self._is_vm_running(vm_name):
            # VM not in tart list
            if vm_thread and vm_thread.is_alive():
                # Thread still alive but VM not running - probably starting
                response["status"] = "starting"
            else:
                # Thread dead and VM not running - failed
                response["status"] = "failed" 
                response["error"] = "VM not found in tart list"
        elif vm_info.get("ssh_responsive", False):
            # VM is running and SSH responsive - fully ready
            response["status"] = "running"
        else:
            # VM is in tart list but not SSH responsive yet - still booting
            response["status"] = "starting"
        
        return response
    
    def release_vm(self, session_id: str) -> bool:
        """Shut the session's VM down, then delete it if it was an ephemeral clone."""
        vm_data = self.active_vms.get(session_id)
        if not vm_data:
            logger.warning(f"No VM found for session {session_id}")
            return False

        vm_name = vm_data["name"]
        stopped = self._shutdown_vm(vm_name)

        if not vm_data.get("ephemeral", True):
            if stopped:
                logger.info(f"VM {vm_name} stopped and kept in place (persistent mode)")
            del self.active_vms[session_id]
            return stopped

        if not stopped:
            # Deleting a live VM fails and leaves the clone on disk. Leave it registered
            # instead; the next run's reap_orphan_vms will reclaim it under the lock.
            logger.error(f"Refusing to delete {vm_name}: it is still running")
            return False

        success = self._delete_vm(vm_name)
        if success:
            del self.active_vms[session_id]
            logger.info(f"VM {vm_name} deleted successfully")

        return success

    def _shutdown_vm(self, vm_name: str, timeout: int = 60) -> bool:
        """Stop a VM by name, escalating to signals when `tart stop` does not take.

        The previous stop ran with check=True; when it failed the caller logged, carried
        on regardless, and `tart delete` then failed against a live VM -- leaving a full
        clone on disk that nothing ever reclaimed.
        """
        if not self._vm_process_pids(vm_name):
            return True

        logger.info(f"Stopping VM {vm_name}")
        subprocess.run([
            "tart", "stop", vm_name
        ], check=False, capture_output=True, text=True)

        if self._wait_for_vm_process_exit(vm_name, timeout):
            logger.info(f"VM {vm_name} stopped successfully")
            return True

        for sig, label in ((signal.SIGTERM, 'SIGTERM'), (signal.SIGKILL, 'SIGKILL')):
            pids = self._vm_process_pids(vm_name)
            if not pids:
                return True
            logger.warning(f"VM {vm_name} did not stop; sending {label} to {pids}")
            for pid in pids:
                try:
                    os.kill(pid, sig)
                except ProcessLookupError:
                    pass
                except Exception as e:
                    logger.error(f"Could not signal process {pid} for VM {vm_name}: {e}")
            if self._wait_for_vm_process_exit(vm_name, 10):
                return True

        logger.error(f"VM {vm_name} is still running after SIGKILL")
        return False

    def _wait_for_vm_process_exit(self, vm_name: str, timeout: int) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if not self._vm_process_pids(vm_name):
                return True
            time.sleep(1)
        return not self._vm_process_pids(vm_name)

    def reap_orphan_vms(self) -> int:
        """Delete ephemeral clones left behind by runs that died before cleaning up.

        Safe to do unconditionally because the caller holds the lock for this domain, and
        EPHEMERAL_VM_PREFIX is scoped to that domain: every VM this can see belongs to a
        run the lock has already excluded, so it belongs to a process that is gone. Each
        clone is a full copy-on-write image of the base, so an unreclaimed one is
        expensive to leave lying around.
        """
        orphans = [name for name in list_local_vm_names() if name.startswith(EPHEMERAL_VM_PREFIX)]
        if not orphans:
            return 0

        print(f"Reclaiming {len(orphans)} orphaned build VM(s) from previous runs...")
        reclaimed = 0
        for vm_name in orphans:
            self._shutdown_vm(vm_name)
            if self._delete_vm(vm_name):
                print(f"  ✓ deleted {vm_name}")
                reclaimed += 1
            else:
                print(f"  ✗ could not delete {vm_name}")

        return reclaimed

    def _delete_vm(self, vm_name: str, attempts: int = 2) -> bool:
        """Internal method to delete a VM by name"""
        for attempt in range(attempts):
            try:
                logger.info(f"Deleting VM {vm_name}")
                subprocess.run([
                    "tart", "delete", vm_name
                ], check=True, capture_output=True, text=True)

                return True

            except subprocess.CalledProcessError as e:
                logger.error(f"Error deleting VM {vm_name} (attempt {attempt + 1}/{attempts}): {e.stderr or e}")
                if attempt + 1 < attempts:
                    time.sleep(2)

        return False
    
    def _is_vm_running(self, vm_name: str) -> bool:
        """Check if a VM is currently running"""
        try:
            result = subprocess.run([
                "tart", "list"
            ], check=True, capture_output=True, text=True)
            
            # Check if the VM appears in the list with "running" status
            for line in result.stdout.split('\n'):
                if vm_name in line and "running" in line:
                    return True
            return False
            
        except subprocess.CalledProcessError as e:
            # `tart list` prints each VM's disk usage, and reading that metadata fails
            # ("Resource temporarily unavailable") for a VM whose disk is an ASIF image
            # that is currently attached. That makes `tart list` unusable as a liveness
            # probe exactly while a VM is running, so fall back to looking for the
            # `tart run <vm_name>` process. `tart ip` is not a substitute here: it answers
            # from the host DHCP lease file and keeps returning the last known address
            # long after the VM has stopped.
            logger.debug(f"'tart list' failed for {vm_name}, falling back to a process check: {e}")
            return self._is_vm_process_running(vm_name)

    def _is_vm_process_running(self, vm_name: str) -> bool:
        """Check whether a `tart run <vm_name>` process is alive"""
        return len(self._vm_process_pids(vm_name)) > 0

    def _vm_process_pids(self, vm_name: str) -> List[int]:
        """PIDs of `tart run <vm_name>` processes, matched on argv rather than a substring.

        `pgrep -f "tart run foo"` also matches `tart run foobar`, which matters now that a
        persistent VM's name is chosen by the user rather than being a uuid.
        """
        try:
            result = subprocess.run([
                "ps", "-Ao", "pid=,command="
            ], capture_output=True, text=True)
        except Exception as e:
            logger.warning(f"Could not enumerate processes for {vm_name}: {e}")
            return []

        pids = []
        for line in result.stdout.splitlines():
            pid_text, _, command = line.strip().partition(' ')
            arguments = command.split()
            if len(arguments) < 3:
                continue
            if os.path.basename(arguments[0]) != 'tart' or arguments[1] != 'run' or arguments[2] != vm_name:
                continue
            try:
                pids.append(int(pid_text))
            except ValueError:
                pass

        return pids

    def _check_ssh_connectivity(self, ip_address: str, timeout: int = 5) -> bool:
        """Check if VM is responsive via SSH"""
        if not ip_address:
            return False
            
        try:
            # Try to run a simple echo command via SSH
            result = subprocess.run([
                "ssh",
                "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", "LogLevel=quiet",
                f"admin@{ip_address}",
                "echo", "alive"
            ], check=True, capture_output=True, text=True, timeout=timeout)
            
            return result.stdout.strip() == "alive"
            
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            logger.debug(f"SSH connectivity check failed for {ip_address}: {e}")
            return False
        except Exception as e:
            logger.debug(f"Unexpected error during SSH check for {ip_address}: {e}")
            return False

    def _get_vm_info(self, vm_name: str) -> Dict:
        """Get detailed information about a VM"""
        try:
            result = subprocess.run([
                "tart", "ip", vm_name
            ], check=True, capture_output=True, text=True)
            
            ip_address = result.stdout.strip()
            
            # Check SSH connectivity for more accurate liveness
            ssh_responsive = self._check_ssh_connectivity(ip_address)
            
            return {
                "name": vm_name,
                "ip_address": ip_address,
                "ssh_port": 22,
                "ssh_responsive": ssh_responsive
            }
            
        except subprocess.CalledProcessError as e:
            return {
                "name": vm_name,
                "ip_address": None,
                "ssh_port": 22,
                "ssh_responsive": False
            }
    
    def cleanup_all(self):
        """Clean up all active VMs"""
        logger.info("Cleaning up all active VMs")
        for session_id in list(self.active_vms.keys()):
            try:
                self.release_vm(session_id)
            except Exception as e:
                logger.error(f"Error cleaning up VM for session {session_id}: {e}")
        
        logger.info("VM cleanup completed")

class TartBuildSession(RemoteBuildSessionInterface):
    """A session represents a VM instance with upload/run/download capabilities"""
    
    def __init__(self, vm_manager: TartVMManager, session_id: str):
        self.vm_manager = vm_manager
        self.session_id = session_id
        self.vm_ip = None
        self.ssh_user = "admin"
        
    def _wait_for_vm_ready(self, timeout: int = 60) -> bool:
        """Wait for VM to be SSH responsive"""
        print(f"Waiting for VM {self.session_id} to be ready...")
        
        for attempt in range(timeout):
            try:
                vm_status = self.vm_manager.check_vm(self.session_id)
                
                if vm_status["status"] == "running":
                    vm_info = vm_status["info"]
                    if vm_info.get("ssh_responsive", False):
                        self.vm_ip = vm_info["ip_address"]
                        print(f"✓ VM ready with IP: {self.vm_ip}")
                        return True
                elif vm_status["status"] == "failed":
                    raise TartBuildError(f"VM failed to start: {vm_status.get('error', 'Unknown error')}")
                        
            except Exception as e:
                if attempt == timeout - 1:  # Last attempt
                    raise TartBuildError(f"Failed to check VM status: {e}")
                    
            time.sleep(1)
        
        raise TartBuildError(f"VM did not become ready within {timeout} seconds")
    
    def upload_file(self, local_path: str, remote_path: str) -> None:
        """Upload a file to the VM"""
        # Check if local_path is a directory
        local_path = Path(local_path)
        if local_path.is_dir():
            raise TartBuildError(f"Local path must be a file, not a directory: {local_path}")

        if not self.vm_ip:
            raise TartBuildError("VM is not ready for file operations")
            
        local_path = Path(local_path)
        if not local_path.exists():
            raise TartBuildError(f"Local path does not exist: {local_path}")
        
        print(f"Uploading {local_path} to {remote_path}...")
        
        try:
            # Use scp to upload files
            cmd = [
                "scp",
                "-r",  # Recursive for directories
                "-o", "ConnectTimeout=10",
                "-o", "StrictHostKeyChecking=no", 
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", "LogLevel=quiet",
                str(local_path),
                f"{self.ssh_user}@{self.vm_ip}:{remote_path}"
            ]
            
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            print(f"✓ Upload completed")
            
        except subprocess.CalledProcessError as e:
            raise TartBuildError(f"Upload failed: {e.stderr}")
        
    def upload_directory(self, local_path: str, remote_path: str, exclude_patterns: List[str] = []) -> None:
        """Efficiently sync source code to VM using rsync"""
        rsync_ignore_file = create_rsync_ignore_file(exclude_patterns=exclude_patterns)
        
        try:
            print('Syncing source code using rsync...')
            
            # Create remote directory first
            self.run(f'mkdir -p {remote_path}')
            
            if not self.vm_ip:
                raise TartBuildError("VM is not ready for file operations")
            
            # Use rsync to sync files directly to VM
            cmd = [
                "rsync",
                "-a",  # archive, compress
                f"--exclude-from={rsync_ignore_file}",
                "--delete",  # Delete files on remote that don't exist locally
                "-e", "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -o Compression=no",
                f"{local_path}/",  # Source directory (trailing slash important)
                f"{self.ssh_user}@{self.vm_ip}:{remote_path}/"
            ]
            
            # Don't capture output so we can see rsync progress in real-time
            result = subprocess.run(cmd, check=True, text=True)
            print("✓ Source sync completed")
            
        except subprocess.CalledProcessError as e:
            print(f"Debug: Rsync command failed with exit code: {e.returncode}")
            if hasattr(e, 'stderr') and e.stderr:
                print(f"Debug: Stderr: {e.stderr}")
            if hasattr(e, 'stdout') and e.stdout:
                print(f"Debug: Stdout: {e.stdout}")
            raise TartBuildError(f"Rsync failed with exit code {e.returncode}")
        except Exception as e:
            print(f"Debug: Unexpected error: {e}")
            raise TartBuildError(f"Rsync failed: {e}")
        finally:
            # Clean up temporary ignore file
            try:
                os.unlink(rsync_ignore_file)
            except Exception:
                pass
    
    def run(self, command: str) -> Dict[str, Any]:
        """Run a command in the VM and return the result"""
        if not self.vm_ip:
            raise TartBuildError("VM is not ready for command execution")
            
        print(f"Running command: {command}")
        
        try:
            # Use ssh to run the command
            cmd = [
                "ssh",
                "-o", "ConnectTimeout=10",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=/dev/null", 
                "-o", "LogLevel=quiet",
                f"{self.ssh_user}@{self.vm_ip}",
                command
            ]
            
            # Run command interactively so output is visible in real-time
            result = subprocess.run(
                cmd, 
                text=True
            )
            
            # Since we're not capturing output, we can only return the exit code
            command_result = {
                "status": result.returncode,
                "stdout": "",  # Not captured for interactive mode
                "stderr": ""   # Not captured for interactive mode
            }
            
            if result.returncode == 0:
                print(f"✓ Command completed successfully")
            else:
                print(f"✗ Command failed with exit code {result.returncode}")
                
            return command_result
            
        except subprocess.CalledProcessError as e:
            print(f"✗ SSH command failed with exit code: {e.returncode}")
            raise TartBuildError(f"SSH command failed with exit code {e.returncode}")
        except Exception as e:
            print(f"✗ Unexpected error running command: {e}")
            raise TartBuildError(f"SSH command failed: {e}")
    
    def download_file(self, remote_path: str, local_path: str) -> None:
        """Download a file from the VM"""
        if not self.vm_ip:
            raise TartBuildError("VM is not ready for file operations")
            
        print(f"Downloading {remote_path} to {local_path}...")
        
        try:
            # Use scp to download files
            cmd = [
                "scp",
                "-r",  # Recursive for directories
                "-o", "ConnectTimeout=10",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", "LogLevel=quiet", 
                f"{self.ssh_user}@{self.vm_ip}:{remote_path}",
                str(local_path)
            ]
            
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            print(f"✓ Download completed")
            
        except subprocess.CalledProcessError as e:
            raise TartBuildError(f"Download failed: {e.stderr}")
        
    def download_directory(self, remote_path: str, local_path: str, exclude_patterns: List[str] = []) -> None:
        return self.download_file(remote_path, local_path)
        
class TartBuildSessionContext(RemoteBuildSessionContextInterface):
    """Context manager for Tart VM sessions"""
    
    def __init__(self, vm_manager: TartVMManager, image: str, session_id: str, mount_directories: Dict[str, str], ephemeral: bool = True, cpu: Optional[int] = None, memory: Optional[int] = None):
        self.vm_manager = vm_manager
        self.image = image
        self.session_id = session_id
        self.mount_directories = mount_directories
        self.ephemeral = ephemeral
        self.cpu = cpu
        self.memory = memory
        self.session = None
        
    def __enter__(self) -> TartBuildSession:
        """Create and start a VM session"""
        print(f"Creating VM session with image: {self.image}")
        
        # Create the VM
        self.vm_manager.create_vm(
            session_id=self.session_id,
            image=self.image,
            mount_directories=self.mount_directories,
            ephemeral=self.ephemeral,
            cpu=self.cpu,
            memory=self.memory
        )
        
        print(f"✓ VM session created: {self.session_id}")
        
        # Create session object
        self.session = TartBuildSession(self.vm_manager, self.session_id)
        
        # Wait for VM to be ready
        self.session._wait_for_vm_ready()
        
        return self.session
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Clean up the VM session"""
        if self.session:
            print(f"Cleaning up VM session: {self.session.session_id}")
            try:
                success = self.vm_manager.release_vm(self.session.session_id)
                if success:
                    print("✓ VM session cleaned up")
                else:
                    print("✗ Failed to clean up VM")
            except Exception as e:
                print(f"✗ Error during cleanup: {e}")

class TartBuild(RemoteBuildInterface):
    def __init__(self):
        self.vm_manager = TartVMManager()
    
    def session(self, macos_version: str, xcode_version: str, mount_directories: Dict[str, str], image: Optional[str] = None, ephemeral: bool = True, cpu: Optional[int] = None, memory: Optional[int] = None) -> TartBuildSessionContext:
        image_name = image if image is not None else default_vm_image_name(macos_version, xcode_version)
        print(f"Image name: {image_name}")
        session_id = str(uuid.uuid4())

        return TartBuildSessionContext(self.vm_manager, image_name, session_id, mount_directories, ephemeral=ephemeral, cpu=cpu, memory=memory)

def create_rsync_ignore_file(exclude_patterns: List[str] = []):
    """Create a temporary rsync ignore file with exclusion patterns"""
    rsync_ignore_content = "\n".join(exclude_patterns)
    
    rsync_ignore_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.rsyncignore')
    rsync_ignore_file.write(rsync_ignore_content.strip())
    rsync_ignore_file.close()
    
    return rsync_ignore_file.name

def remote_build_tart(macos_version, bazel_cache_host, configuration, build_input_data_path, vm_image=None, override_xcode_version=False, ephemeral_vm=True, vm_cpu=None, vm_memory=None):
    if _active_vm_build_lock is None:
        raise TartBuildError('remote_build_tart must be called inside exclusive_vm_build(); the caller owns the lock because it also owns the shared build-input directory.')

    base_dir = os.getcwd()

    configuration_path = 'versions.json'
    xcode_version = ''
    with open(configuration_path) as file:
        configuration_dict = json.load(file)
        if configuration_dict['xcode'] is None:
            raise Exception('Missing xcode version in {}'.format(configuration_path))
        xcode_version = configuration_dict['xcode']

    print('Xcode version: {}'.format(xcode_version))

    commit_count = run_executable_with_output('git', [
        'rev-list',
        '--count',
        'HEAD'
    ])

    build_number_offset = 0
    with open('build_number_offset') as file:
        build_number_offset = int(file.read())

    build_number = build_number_offset + int(commit_count)
    print('Build number: {}'.format(build_number))

    source_dir = os.path.basename(base_dir)
    buildbox_dir = 'buildbox'

    transient_data_dir = '{}/transient-data'.format(buildbox_dir)
    os.makedirs(transient_data_dir, exist_ok=True)

    mount_directories = {}
    if bazel_cache_host is not None and bazel_cache_host.startswith("file://"):
        local_path = bazel_cache_host.replace("file://", "")
        mount_directories["bazel-cache"] = local_path

    vm_target = vm_image if vm_image is not None else default_vm_image_name(macos_version, xcode_version)
    if ephemeral_vm:
        if vm_cpu is None:
            vm_cpu = default_vm_cpu_count()
        if vm_memory is None:
            vm_memory = default_vm_memory_mb()
        print('VM: ephemeral clone of {} ({} cpu, {} MB memory), deleted after the build'.format(vm_target, vm_cpu, vm_memory))
    else:
        # A persistent VM is used exactly as it was configured.
        vm_cpu = None
        vm_memory = None
        print('VM: persistent {}, kept after the build'.format(vm_target))

    tart_build = TartBuild()

    with teardown_signal_handlers(), \
            tart_build.session(macos_version=macos_version, xcode_version=xcode_version, mount_directories=mount_directories, image=vm_image, ephemeral=ephemeral_vm, cpu=vm_cpu, memory=vm_memory) as session:
        print('Uploading data to VM...')
        session.upload_directory(local_path=build_input_data_path, remote_path="telegram-build-input")
        
        source_exclude_patterns = [
            ".git/",
            "/bazel-bin/",
            "/bazel-out/",
            "/bazel-testlogs/",
            "/bazel-telegram-ios/",
            "/buildbox/",
            "/build/",
            ".build/",
            "/.claude/worktrees/"
        ]
        session.upload_directory(local_path=base_dir, remote_path="/Users/Shared/telegram-ios", exclude_patterns=source_exclude_patterns)

        # Since Xcode 26 the Metal toolchain is an optional download that only works while
        # its cryptex DMG is mounted at /Volumes/MetalToolchainCryptex, and that mount does
        # NOT survive a reboot -- so a freshly booted VM never has it, however the asset was
        # installed into the image. Xcode remounts it lazily, which races when bazel starts
        # ~17 MetalCompile actions at once: some `xcrun metal` calls succeed while others
        # fail with "cannot execute tool 'metal' due to missing Metal Toolchain", breaking
        # the build on a different shader each time. Mounting it once, serially, before
        # bazel runs removes the race.
        #
        # Mounting alone is not enough for `metal` itself. Once the cryptex is mounted xcrun
        # resolves every Metal tool inside it (metallib, air-lld, ...) -- except `metal`,
        # which is shadowed by a stub of the same name in XcodeDefault.xctoolchain whose
        # only behaviour is to print that error; it has no idea the cryptex exists. So the
        # name is pointed at the real compiler. Both steps are best-effort: a VM whose image
        # carries no Metal asset must still build everything that needs no shaders.
        guest_build_sh = '''
            set -x
            set -e

            if [ ! -d /Volumes/MetalToolchainCryptex ]; then
                METAL_DMG="$(ls -t /System/Library/AssetsV2/com_apple_MobileAsset_MetalToolchain/*.asset/AssetData/Restore/*.dmg 2>/dev/null | head -n 1)"
                if [ -n "$METAL_DMG" ]; then
                    hdiutil attach "$METAL_DMG" -mountpoint /Volumes/MetalToolchainCryptex -nobrowse -quiet || true
                fi
            fi
            METAL_REAL=/Volumes/MetalToolchainCryptex/Metal.xctoolchain/usr/bin/metal
            if [ -x "$METAL_REAL" ] && ! xcrun metal --version >/dev/null 2>&1; then
                sudo ln -sf "$METAL_REAL" "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/metal" || true
            fi
            xcrun metal --version || true
            xcrun -f metallib || true

            cd /Users/Shared/telegram-ios

            python3 build-system/Make/ImportCertificates.py --path $HOME/telegram-build-input/certs
        '''

        if bazel_cache_host is not None:
            if bazel_cache_host.startswith("file://"):
                pass
            elif "@auto" in bazel_cache_host:
                host_parts = bazel_cache_host.split("@auto")
                host_left_part = host_parts[0]
                host_right_part = host_parts[1]
                guest_host_command = "export CACHE_HOST_IP=\"$(netstat -nr | grep default | head -n 1 | awk '{print $2}')\""
                guest_build_sh += guest_host_command + "\n"
                guest_host_string = f"export CACHE_HOST=\"{host_left_part}$CACHE_HOST_IP{host_right_part}\""
                guest_build_sh += guest_host_string + "\n"
            else:
                guest_build_sh += f"export CACHE_HOST=\"{bazel_cache_host}\"\n"

        guest_build_sh += 'python3 build-system/Make/Make.py \\'
        if override_xcode_version:
            guest_build_sh += '--overrideXcodeVersion \\'
        if bazel_cache_host is not None:
            if bazel_cache_host.startswith("file://"):
                guest_build_sh += '--cacheDir="/Volumes/My Shared Files/bazel-cache" \\'
            else:
                guest_build_sh += '--cacheHost="$CACHE_HOST" \\'
        guest_build_sh += 'build \\'
        #guest_build_sh += '--lock \\'
        guest_build_sh += '--buildNumber={} \\'.format(build_number)
        guest_build_sh += '--configuration={} \\'.format(configuration)
        guest_build_sh += '--configurationPath=$HOME/telegram-build-input/configuration.json \\'
        guest_build_sh += '--codesigningInformationPath=$HOME/telegram-build-input \\'
        guest_build_sh += '--outputBuildArtifactsPath=/Users/Shared/telegram-ios/build/artifacts \\'

        guest_build_file_path = tempfile.mktemp()
        with open(guest_build_file_path, 'w+') as file:
            file.write(guest_build_sh)
        session.upload_file(local_path=guest_build_file_path, remote_path='guest-build-telegram.sh')
        os.unlink(guest_build_file_path)

        print('Executing remote build...')

        build_result = session.run(command='bash -l guest-build-telegram.sh')
        if build_result['status'] != 0:
            raise TartBuildError('Remote build failed with exit code {}'.format(build_result['status']))

        print('Retrieving build artifacts...')

        artifacts_path=f'{base_dir}/build/artifacts'
        if os.path.exists(artifacts_path):
            shutil.rmtree(artifacts_path)
        session.download_directory(remote_path='/Users/Shared/telegram-ios/build/artifacts', local_path=artifacts_path)

        if os.path.exists(artifacts_path + '/Telegram.ipa'):
            print('Artifacts have been stored at {}'.format(artifacts_path))
            sys.exit(0)
        else:
            print('Telegram.ipa not found')
            sys.exit(1)
