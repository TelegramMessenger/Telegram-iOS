from typing import List, Dict, Any

class RemoteBuildSessionInterface:
    def __init__(self):
        pass

    def upload_file(self, local_path: str, remote_path: str) -> None:
        raise NotImplementedError
    
    def upload_directory(self, local_path: str, remote_path: str, exclude_patterns: List[str] = []) -> None:
        raise NotImplementedError
    
    def download_file(self, remote_path: str, local_path: str) -> None:
        raise NotImplementedError
    
    def download_directory(self, remote_path: str, local_path: str, exclude_patterns: List[str] = []) -> None:
        raise NotImplementedError
    
    def run(self, command: str) -> Dict[str, Any]:
        raise NotImplementedError

class RemoteBuildSessionContextInterface:
    def __enter__(self) -> RemoteBuildSessionInterface:
        raise NotImplementedError
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        raise NotImplementedError

class RemoteBuildInterface:
    def __init__(self):
        pass

    def session(self, macos_version: str, xcode_version: str) -> RemoteBuildSessionContextInterface:
        raise NotImplementedError
