"""Exercise the shipped executable in a logged-in Mac session using a private note library."""
import concurrent.futures
import json
import os
from pathlib import Path
import plistlib
import signal
import subprocess
import tempfile
import time
import uuid


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=25)
    if result.returncode:
        raise RuntimeError(f'{args[0]} exited {result.returncode}: {result.stderr}')
    return result


def stop_test_app(bundle):
    executable = str(bundle / "Contents/MacOS/GlassNotes")
    for row in run("ps", "-ax", "-o", "pid=,comm=").stdout.splitlines():
        pid, command = row.strip().split(None, 1)
        if command != executable:
            continue
        pid = int(pid)
        os.kill(pid, signal.SIGTERM)
        for _ in range(100):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.05)
        else:
            raise RuntimeError("The isolated test app did not exit")
        socket = Path(run("getconf", "DARWIN_USER_TEMP_DIR").stdout.strip()) / f"glassnotes-{pid}.sock"
        if socket.is_socket():
            socket.unlink()


def check(root):
    bundle = root / "GlassNotesIntegration.app"
    run("ditto", "dist/GlassNotes.app", bundle)
    home = root / "user"
    store = home / "Library/Application Support/GlassNotes/notes.json"
    store.parent.mkdir(parents=True)
    legacy_id = str(uuid.uuid4()).upper()
    legacy = dict(id=legacy_id, text="legacy test", ink="chalk",
                  placement=dict(display="main", x=0.3, y=0.4), createdAt=1)
    store.write_text(json.dumps(dict(version=1, notes=[legacy])))
    info = bundle / "Contents/Info.plist"
    metadata = plistlib.loads(info.read_bytes())
    metadata.update(CFBundleIdentifier="app.glassnotes.test-" + uuid.uuid4().hex,
                    LSEnvironment={"CFFIXED_USER_HOME": str(home)})
    info.write_bytes(plistlib.dumps(metadata))
    run("codesign", "--force", "--sign", "-", bundle)
    cli = root / "glassnotes"
    cli.symlink_to(bundle / "Contents/Helpers/glassnotes")

    def call(*args):
        return json.loads(run(cli, *args).stdout)

    def failure(*args):
        result = subprocess.run([cli, *args], capture_output=True, text=True, timeout=20)
        assert result.returncode != 0 and result.stderr and not result.stdout, result
        return result.stderr

    try:
        listed = call("list", "--json")
        assert len(listed) == 1 and listed[0]["id"] == legacy_id, "Expected isolated library"
        assert listed[0]["updatedAt"] is None and listed[0]["createdAt"] == "2001-01-01T00:00:01.000Z"
        assert json.loads(store.read_text())["notes"] == [legacy]
        added = call("add", '会议待办\n确认 "报价"')
        assert added["createdAt"] == added["updatedAt"] and added["completedAt"] is None
        assert added in call("list")
        done = call("complete", added["id"])
        assert done["updatedAt"] == done["completedAt"] and done["createdAt"] == added["createdAt"]
        assert call("complete", added["id"]) == done
        failure("add", " ")
        failure("complete", str(uuid.uuid4()))
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            others = list(pool.map(lambda i: call("add", f"parallel {i}"), range(4)))
        assert len({n["id"] for n in others}) == 4
        stop_test_app(bundle)
        reopened = call("list")
        assert len(reopened) == 6 and done in reopened and all(n in reopened for n in others)
        stop_test_app(bundle)
        store.write_text("invalid")
        assert "无法读取便签库" in failure("list")
        assert store.read_text() == "invalid"
    finally:
        stop_test_app(bundle)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="glassnotes-cli-") as folder:
        check(Path(folder).resolve())
    print("Packaged CLI creation, listing, completion and startup errors passed.")
