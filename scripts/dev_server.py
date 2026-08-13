#!/usr/bin/env python3
"""Build, watch, serve, and live-reload the local Typst website."""

from __future__ import annotations

import argparse
import functools
import http.server
from pathlib import Path
import subprocess
import threading
import time


ROOT = Path(__file__).resolve().parents[1]
SITE_DIR = ROOT / "_site"
PREVIEW_DIR = ROOT / "_preview"
PREVIEW_LINK = PREVIEW_DIR / "xiaoxu"
VERSION_FILE = PREVIEW_DIR / "__xiaoxu_reload"
WATCH_ROOTS = (ROOT / "content", ROOT / "assets")
WATCH_FILES = (ROOT / "config.typ", ROOT / "Makefile")

LIVE_RELOAD = """
<script id="xiaoxu-live-reload">
(() => {
  let currentVersion = null;
  const checkForUpdate = async () => {
    try {
      const response = await fetch(`/__xiaoxu_reload?time=${Date.now()}`, {
        cache: "no-store",
      });
      const nextVersion = await response.text();
      if (currentVersion === null) currentVersion = nextVersion;
      else if (nextVersion !== currentVersion) window.location.reload();
    } catch (_) {
      // The next polling cycle will retry while a rebuild is in progress.
    }
  };
  checkForUpdate();
  window.setInterval(checkForUpdate, 700);
})();
</script>
"""


def watched_paths() -> list[Path]:
    paths = [path for path in WATCH_FILES if path.exists()]
    for root in WATCH_ROOTS:
        paths.extend(
            path
            for path in root.rglob("*")
            if path.is_file() and path.name != ".DS_Store"
        )
    return sorted(paths)


def signature() -> dict[Path, tuple[int, int]]:
    result = {}
    for path in watched_paths():
        try:
            stat = path.stat()
            result[path] = (stat.st_mtime_ns, stat.st_size)
        except FileNotFoundError:
            pass
    return result


def changed_paths(before, after) -> set[Path]:
    changed = set(before) ^ set(after)
    changed.update(path for path in set(before) & set(after) if before[path] != after[path])
    return changed


def inject_live_reload() -> None:
    for html_path in SITE_DIR.rglob("*.html"):
        html = html_path.read_text(encoding="utf-8")
        if "xiaoxu-live-reload" not in html:
            html = html.replace("</body>", f"{LIVE_RELOAD}</body>")
            html_path.write_text(html, encoding="utf-8")


def compile_page(source: Path) -> int:
    relative = source.relative_to(ROOT / "content")
    output = (SITE_DIR / relative).with_suffix(".html")
    output.parent.mkdir(parents=True, exist_ok=True)
    return subprocess.run(
        [
            "typst",
            "compile",
            "--root",
            "..",
            "--features",
            "html",
            "--format",
            "html",
            str(source.relative_to(ROOT)),
            str(output.relative_to(ROOT)),
        ],
        cwd=ROOT,
    ).returncode


def owning_page(path: Path) -> Path | None:
    if path.suffix == ".typ":
        return path
    parent = path.parent
    content_root = ROOT / "content"
    while parent == content_root or content_root in parent.parents:
        candidate = parent / "index.typ"
        if candidate.exists():
            return candidate
        parent = parent.parent
    return None


def build(changed: set[Path] | None = None) -> bool:
    print("\n[预览] 正在重新编译……", flush=True)
    return_codes = []

    if changed is None:
        return_codes.append(subprocess.run(["make", "-B", "html"], cwd=ROOT).returncode)
    elif any(path in WATCH_FILES for path in changed):
        return_codes.append(subprocess.run(["make", "-B", "html"], cwd=ROOT).returncode)
    else:
        changed_assets = {
            path
            for path in changed
            if ROOT / "assets" == path.parent or ROOT / "assets" in path.parents
        }
        if changed_assets and all(path.suffix == ".css" for path in changed_assets):
            return_codes.append(subprocess.run(["make", "assets"], cwd=ROOT).returncode)
        elif changed_assets:
            return_codes.append(subprocess.run(["make", "-B", "html"], cwd=ROOT).returncode)
            changed = set()

        pages = {
            page
            for path in changed
            if ROOT / "content" == path.parent or ROOT / "content" in path.parents
            if (page := owning_page(path)) is not None and page.exists()
        }
        return_codes.extend(compile_page(page) for page in sorted(pages))

    if any(code != 0 for code in return_codes):
        print("[预览] 编译失败，浏览器继续显示上一次成功结果。", flush=True)
        return False

    inject_live_reload()
    VERSION_FILE.write_text(str(time.time_ns()), encoding="utf-8")
    print("[预览] 编译完成，浏览器已自动刷新。", flush=True)
    return True


def prepare_preview() -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    if PREVIEW_LINK.is_symlink() or PREVIEW_LINK.is_file():
        PREVIEW_LINK.unlink()
    elif PREVIEW_LINK.exists():
        raise RuntimeError(f"无法创建预览链接：{PREVIEW_LINK} 已是一个目录")
    PREVIEW_LINK.symlink_to(Path("../_site"))


def watch() -> None:
    previous = signature()
    while True:
        time.sleep(0.5)
        current = signature()
        if current == previous:
            continue

        # Give editors a brief moment to finish an atomic save before compiling.
        time.sleep(0.35)
        current = signature()
        changed = changed_paths(previous, current)
        names = [str(path.relative_to(ROOT)) for path in sorted(changed)]
        print(f"\n[预览] 检测到更新：{', '.join(names)}", flush=True)
        previous = current
        build(changed)


class PreviewHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:
        if self.path.startswith("/__xiaoxu_reload"):
            return
        super().log_message(format, *args)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    prepare_preview()
    if not build():
        raise SystemExit(1)

    watcher = threading.Thread(target=watch, daemon=True)
    watcher.start()

    handler = functools.partial(PreviewHandler, directory=str(PREVIEW_DIR))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"\n[预览] http://127.0.0.1:{args.port}/xiaoxu/", flush=True)
    print("[预览] 保存文件后会自动编译并刷新；按 Ctrl+C 停止。", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[预览] 已停止。")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
