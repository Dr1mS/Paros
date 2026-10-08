#!/usr/bin/env python3
"""Tells Paros when a Claude Code session asks its advisor.

Claude Code writes nothing while the advisor works: no hook, and the
transcript only once the answer is there. But its terminal shows
"Advising using <model>" meanwhile. This helper reads the visible text of the
terminals, through the accessibility service of the desktop (AT-SPI), and
looks for that line. It keeps and sends nothing of what it reads.

Writes one file, replaced at once: the Unix time of the writing, then one
line per terminal that shows the advisor at work, with the Unix time since
when. Ends when Paros ends.

Usage: paros-terminal.py --parent PID --out FILE
       paros-terminal.py --test < text    (prints 1 when the text shows it)
"""
import os
import re
import sys
import time

POLL_SECONDS = 0.5
# The terminals are searched again this often: one may open or close.
SCAN_SECONDS = 5.0
# The file is written again at least this often, so that Paros knows the helper lives.
BEAT_SECONDS = 2.0
# Programs whose windows hold terminals. Others are not looked at: walking a
# browser costs much.
TERMINAL_APPS = ("terminal", "ptyxis", "kgx", "console", "tilix", "terminator", "guake", "konsole")
ADVISING = re.compile(r"^(?:\S\s*)?Advising using \S.*$")
# The line of the spinner, under what the session does: "✻ Herding… (1m 28s · …)".
SPINNER = re.compile(r"^\S\s.*…")
SEPARATOR = re.compile(r"^─{10,}")


def is_advising(text):
    """True when the last thing the session shows is the advisor at work.

    The line stays on the screen once the advisor has answered, and may be
    quoted in a message. It counts only when nothing follows it but the
    spinner: its answer, or anything else, comes right under it.
    """
    lines = [line.strip() for line in text.split("\n")]
    lines = [line for line in lines if line]
    for index in range(len(lines) - 1, -1, -1):
        if SEPARATOR.match(lines[index]):
            # Under the last separators: the prompt and the footer.
            continue
        if ADVISING.match(lines[index]):
            after = lines[index + 1] if index + 1 < len(lines) else ""
            return after == "" or bool(SPINNER.match(after)) or bool(SEPARATOR.match(after))
    return False


def main():
    if "--test" in sys.argv:
        print(1 if is_advising(sys.stdin.read()) else 0)
        return
    parent = int(sys.argv[sys.argv.index("--parent") + 1])
    out = sys.argv[sys.argv.index("--out") + 1]

    import gi
    gi.require_version("Atspi", "2.0")
    from gi.repository import Atspi
    Atspi.init()

    def find_terminals():
        found = []

        def walk(node, depth):
            try:
                if node.get_role_name() == "terminal":
                    found.append(node)
                elif depth < 12:
                    for index in range(node.get_child_count()):
                        child = node.get_child_at_index(index)
                        if child:
                            walk(child, depth + 1)
            except Exception:
                pass

        desktop = Atspi.get_desktop(0)
        for index in range(desktop.get_child_count()):
            try:
                app = desktop.get_child_at_index(index)
                if app and any(name in (app.get_name() or "").lower() for name in TERMINAL_APPS):
                    walk(app, 0)
            except Exception:
                pass
        return found

    terminals = []
    scanned = 0.0
    # Terminal -> Unix time since when it shows the advisor at work.
    since = {}
    written = ""
    written_at = 0.0
    while os.path.exists("/proc/%d" % parent):
        now = time.time()
        if now - scanned >= SCAN_SECONDS:
            terminals = find_terminals()
            scanned = now
        seen = {}
        for terminal in terminals:
            try:
                text = Atspi.Text.get_text(terminal, 0, Atspi.Text.get_character_count(terminal))
            except Exception:
                continue
            if is_advising(text):
                seen[terminal] = since.get(terminal, now)
        since = seen
        lines = "".join("%.3f\n" % start for start in sorted(since.values()))
        if lines != written or now - written_at >= BEAT_SECONDS:
            with open(out + ".part", "w") as file:
                file.write("%.3f\n%s" % (now, lines))
            os.replace(out + ".part", out)
            written = lines
            written_at = now
        time.sleep(POLL_SECONDS)
    try:
        os.remove(out)
    except OSError:
        pass


if __name__ == "__main__":
    main()
