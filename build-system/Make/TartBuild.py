import os
import json
import shutil
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

class TartVMManager:
    """Manages Tart VM lifecycle operations"""
    
    def __init__(self):
        self.active_vms: Dict[str, Dict] = {}
        
    def create_vm(self, session_id: str, image: str, mount_directories: Dict[str, str]) -> Dict:
        """Create a new ephemeral VM for the session"""
        vm_name = f"telegrambuild-{session_id}"
        
        # Check if we already have a running VM (limit: 1)
        for session_id in self.active_vms.keys():
            vm_status = self.check_vm(session_id)
            if vm_status.get("status") in ["running", "starting"]:
                status = vm_status.get("status", "unknown")
                raise RuntimeError(f"Maximum VM limit reached (1). VM '{vm_status['name']}' is already {status} for session '{session_id}'")
        
        try:
            # Clone the base image
            logger.info(f"Cloning VM {vm_name} from image {image}")
            clone_result = subprocess.run([
                "tart", "clone", image, vm_name
            ], check=True, capture_output=True, text=True)
            
            logger.info(f"Successfully cloned VM {vm_name}")
            
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
                "thread": vm_thread
            }
            
            self.active_vms[session_id] = vm_data
            logger.info(f"VM {vm_name} thread started, initializing...")
            
            return vm_data
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error creating VM {vm_name}: {e}")
            raise RuntimeError(f"Failed to create VM: {e}")
    
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
    
    def stop_vm(self, session_id: str) -> bool:
        """Stop a VM for the given session"""
        vm_data = self.active_vms.get(session_id)
        if not vm_data:
            logger.warning(f"No VM found for session {session_id}")
            return False
            
        vm_name = vm_data["name"]
        
        try:
            logger.info(f"Stopping VM {vm_name}")
            subprocess.run([
                "tart", "stop", vm_name
            ], check=True, capture_output=True, text=True)
            
            logger.info(f"VM {vm_name} stopped successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error stopping VM {vm_name}: {e}")
            return False
    
    def delete_vm(self, session_id: str) -> bool:
        """Delete a VM for the given session"""
        vm_data = self.active_vms.get(session_id)
        if not vm_data:
            logger.warning(f"No VM found for session {session_id}")
            return False
            
        vm_name = vm_data["name"]
        
        # Stop the VM first if it's running
        if self._is_vm_running(vm_name):
            self.stop_vm(session_id)
        
        # Delete the VM
        success = self._delete_vm(vm_name)
        
        if success:
            # Remove from active VMs
            del self.active_vms[session_id]
            logger.info(f"VM {vm_name} deleted successfully")
        
        return success
    
    def _delete_vm(self, vm_name: str) -> bool:
        """Internal method to delete a VM by name"""
        try:
            logger.info(f"Deleting VM {vm_name}")
            subprocess.run([
                "tart", "delete", vm_name
            ], check=True, capture_output=True, text=True)
            
            return True
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error deleting VM {vm_name}: {e}")
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
            logger.warning(f"Could not check VM status for {vm_name}: {e}")
            return False
    
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
                self.delete_vm(session_id)
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
    
    def __init__(self, vm_manager: TartVMManager, image: str, session_id: str, mount_directories: Dict[str, str]):
        self.vm_manager = vm_manager
        self.image = image
        self.session_id = session_id
        self.mount_directories = mount_directories
        self.session = None
        
    def __enter__(self) -> TartBuildSession:
        """Create and start a VM session"""
        print(f"Creating VM session with image: {self.image}")
        
        # Create the VM
        self.vm_manager.create_vm(session_id=self.session_id, image=self.image, mount_directories=self.mount_directories)
        
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
                success = self.vm_manager.delete_vm(self.session.session_id)
                if success:
                    print("✓ VM session cleaned up")
                else:
                    print("✗ Failed to clean up VM")
            except Exception as e:
                print(f"✗ Error during cleanup: {e}")

class TartBuild(RemoteBuildInterface):
    def __init__(self):
        self.vm_manager = TartVMManager()
    
    def session(self, macos_version: str, xcode_version: str, mount_directories: Dict[str, str]) -> TartBuildSessionContext:
        image_name = f"macos-{macos_version}-xcode-{xcode_version}"
        print(f"Image name: {image_name}")
        session_id = str(uuid.uuid4())

        return TartBuildSessionContext(self.vm_manager, image_name, session_id, mount_directories)

def create_rsync_ignore_file(exclude_patterns: List[str] = []):
    """Create a temporary rsync ignore file with exclusion patterns"""
    rsync_ignore_content = "\n".join(exclude_patterns)
    
    rsync_ignore_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.rsyncignore')
    rsync_ignore_file.write(rsync_ignore_content.strip())
    rsync_ignore_file.close()
    
    return rsync_ignore_file.name

def remote_build_tart(macos_version, bazel_cache_host, configuration, build_input_data_path):
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

    with TartBuild().session(macos_version=macos_version, xcode_version=xcode_version, mount_directories=mount_directories) as session:
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
            ".build/"
        ]
        session.upload_directory(local_path=base_dir, remote_path="/Users/Shared/telegram-ios", exclude_patterns=source_exclude_patterns)

        guest_build_sh = '''
            set -x
            set -e

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
        if bazel_cache_host is not None:
            if bazel_cache_host.startswith("file://"):
                guest_build_sh += '--cacheDir="/Volumes/My Shared Files/bazel-cache" \\'
            else:
                guest_build_sh += '--cacheHost="$CACHE_HOST" \\'
        guest_build_sh += 'build \\'
        guest_build_sh += '--lock \\'
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

        session.run(command='bash -l guest-build-telegram.sh')

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
