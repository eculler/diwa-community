import os
import stat
from pathlib import Path


def repair_ssh_private_key_permissions() -> None:
    """Repair mounted SSH private-key permissions without blocking startup."""
    ssh_dir = Path.home() / ".ssh"

    if not ssh_dir.is_dir():
        return

    for public_key in ssh_dir.glob("*.pub"):
        private_key = public_key.with_suffix("")

        if not private_key.is_file():
            continue

        try:
            current_mode = stat.S_IMODE(private_key.stat().st_mode)
            if current_mode != 0o600:
                private_key.chmod(0o600)
                print(
                    "Corrected SSH private-key permissions: "
                    f"{private_key} {current_mode:o} -> 600"
                )
        except OSError as exc:
            print(f"Warning: could not correct {private_key}: {exc}")


def configure_code_working_directory() -> None:
    """Set code-server's initial folder from persistent setup state."""
    if os.environ.get("CODE_WORKING_DIRECTORY"):
        return

    home = Path.home()
    workspace_path_file = home / ".config" / "diwa-community-site" / "workspace-path"
    workspace = home

    try:
        if workspace_path_file.is_file():
            configured_path = workspace_path_file.read_text(encoding="utf-8").strip()
            candidate = Path(configured_path).expanduser()

            if configured_path and candidate.is_dir():
                workspace = candidate
            elif configured_path:
                print(
                    "Warning: configured DIWA Community Site workspace does not exist: "
                    f"{candidate}. Using {home} instead."
                )
    except OSError as exc:
        print(
            "Warning: could not read the DIWA Community Site workspace setting: "
            f"{exc}. Using {home} instead."
        )

    os.environ["CODE_WORKING_DIRECTORY"] = str(workspace)


repair_ssh_private_key_permissions()
configure_code_working_directory()

os.environ.setdefault("CODE_DISABLE_PASSWORD", "true")

setup_command = r'''
if diwa-community-site-setup; then
    printf '\nSetup complete. You can close this tab.\n\n'
else
    printf '\nReview the errors above. Close this tab when finished.\n\n'
fi
exec bash
'''

c.ServerProxy.servers = {
    "diwa-community-site-setup": {
        "command": [
            "ttyd",
            "--writable",
            "--port",
            "{port}",
            "bash",
            "-lc",
            setup_command,
        ],
        "timeout": 30,
        "launcher_entry": {
            "enabled": True,
            "title": "Set Up DIWA Community Site Editor",
            "category": "DIWA Community Site",
            "icon_path": "",
            "new_browser_tab": False,
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
            "new_browser_tab": False,
        },
    },
}
