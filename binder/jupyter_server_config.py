import os
from pathlib import Path

workspace = Path.home() / "diwa-community"

os.environ.setdefault("CODE_DISABLE_PASSWORD", "true")
os.environ["CODE_WORKING_DIRECTORY"] = str(workspace)

c.ServerProxy.servers = {
    "diwa-community-site-setup": {
        "command": [
            "ttyd",
            "--writable",
            "--port",
            "{port}",
            "diwa-community-site-setup",
        ],
        "timeout": 30,
        "launcher_entry": {
            "enabled": True,
            "title": "Set Up DIWA Community Site Editor",
            "category": "DIWA Community Site",
            "icon_path": "",
        },
    },
    "diwa-community-site-editor": {
        "command": [
            "open-diwa-community-site-editor",
            "--port",
            "{port}",
        ],
        "timeout": 30,
        "absolute_url": False,
        "launcher_entry": {
            "enabled": True,
            "title": "Open DIWA Community Site Editor",
            "category": "DIWA Community Site",
            "icon_path": "",
        },
    },
}
