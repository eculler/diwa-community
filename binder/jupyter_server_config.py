import os
from pathlib import Path

workspace = Path.home() / "diwa-community"

os.environ.setdefault("CODE_DISABLE_PASSWORD", "true")
os.environ["CODE_WORKING_DIRECTORY"] = str(workspace)