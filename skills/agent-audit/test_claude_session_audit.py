#!/usr/bin/env python3
"""Fixture test for claude_session_audit.py.

  python3 skills/agent-audit/test_claude_session_audit.py

Builds a fake ~/.claude/projects with planted fake secrets of every type, stubs the
claude CLI and the --on-flag command, and runs the real script against them. The
fake secrets are generated at run time, so none sits in the repo.
"""
import collections
import datetime as dt
import hashlib
import json
import os
import random
import re
import shlex
import string
import subprocess
import sys
import tempfile
import time
import unittest
import uuid
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "claude_session_audit.py"
sys.path.insert(0, str(HERE))
import claude_session_audit as audit  # noqa: E402

ALNUM = string.ascii_letters + string.digits


def rnd(n, alphabet=ALNUM):
    return "".join(random.choice(alphabet) for _ in range(n - 1)) + random.choice(string.digits)


def plant():
    """(type, secret value, text it appears in). Prefixes are split so the source
    holds no complete token shape."""
    pem_body = [rnd(64, ALNUM + "+/") for _ in range(3)]
    pem = ("-----BEGIN RSA " + "PRIVATE KEY-----\n" + "\n".join(pem_body)
           + "\n-----END RSA " + "PRIVATE KEY-----")
    bearer, url_pw, env_v = rnd(40), rnd(20), rnd(24)
    s = [
        ("aws-access-key", "AK" + "IA" + rnd(16, string.ascii_uppercase + string.digits)),
        ("github-token", "gh" + "p_" + rnd(36)),
        ("github-token", "gh" + "o_" + rnd(36)),
        ("github-token", "gh" + "s_" + rnd(36)),
        ("github-token", "gh" + "u_" + rnd(36)),
        ("github-token", "github" + "_pat_" + rnd(22) + "_" + rnd(59)),
        ("anthropic-key", "sk-" + "ant-api03-" + rnd(40)),
        ("openai-key", "sk-" + rnd(40)),
        ("openai-key", "sk-" + "proj-" + rnd(40)),
        ("slack-token", "xo" + "xb-" + rnd(11, string.digits) + "-" + rnd(24)),
        ("stripe-key", "sk" + "_live_" + rnd(24)),
        ("stripe-key", "rk" + "_live_" + rnd(24)),
        ("google-api-key", "AI" + "za" + rnd(35)),
        ("telegram-bot-token", rnd(9, string.digits) + ":AA" + rnd(33)),
        ("jwt", "ey" + "J" + rnd(20) + ".ey" + "J" + rnd(30) + "." + rnd(40)),
    ]
    planted = [(k, v, f"value {v} here") for k, v in s]
    planted += [
        ("private-key", pem, f"key file:\n{pem}\n"),
        ("bearer-token", bearer, f'curl -H "Authorization: Bearer {bearer}" https://api.example.com'),
        ("url-password", url_pw, f"psql postgres://admin:{url_pw}@db.internal:5432/app"),
        ("env-secret", env_v, f"DB_PASSWORD={env_v}\nDEBUG=1"),
    ]
    # what must never appear: each value, its distinctive start, and common hashes
    forbidden = []
    for k, v, _ in planted:
        parts = [v] if k != "private-key" else pem_body
        for p in parts:
            forbidden.append(p)
            forbidden.append(p[:12] if k != "telegram-bot-token" else p.split(":")[1][:12])
            for h in (hashlib.sha256, hashlib.sha1, hashlib.md5):
                forbidden.append(h(p.encode()).hexdigest()[:12])
    return planted, forbidden


def ts(minutes_ago):
    t = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=minutes_ago)
    return t.isoformat().replace("+00:00", "Z")


def write_session(projects, entries, cwd="/home/dev/proj", subagent=False):
    sid = str(uuid.uuid4())
    d = projects / cwd.replace("/", "-")
    path = d / sid / "subagents" / "agent-a1b2c3d4e5.jsonl" if subagent else d / f"{sid}.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as fh:
        for e in entries:
            fh.write(json.dumps(dict(e, cwd=cwd, sessionId=sid)) + "\n")
    return sid


def user(text, m=10):
    return {"type": "user", "timestamp": ts(m), "message": {"role": "user", "content": text}}


def agent(text, m=10):
    return {"type": "assistant", "timestamp": ts(m),
            "message": {"content": [{"type": "text", "text": text}]}}


def call(tid, cmd, m=10):
    return {"type": "assistant", "timestamp": ts(m), "message": {"content": [
        {"type": "tool_use", "id": tid, "name": "Bash", "input": {"command": cmd}}]}}


def result(tid, text, m=10):
    return {"type": "user", "timestamp": ts(m), "message": {"content": [
        {"type": "tool_result", "tool_use_id": tid, "content": text}]}}


STUB_CLAUDE = r'''#!/usr/bin/env python3
import os, sys
data = sys.stdin.read()
with open(os.environ["STUB_CAPTURE"], "a") as fh:
    fh.write(data + "\n=====STUB-CALL=====\n")
mode = os.environ.get("STUB_MODE", "clean")
if "FAILME" in data:
    print("boom: model unavailable " + os.environ.get("STUB_LEAK", ""), file=sys.stderr)
    sys.exit(1)
if "UNCLEARME" in data:
    print("I could not decide."); sys.exit(0)
if mode == "clean":
    print("VERDICT: CLEAN\nMODEL-MARKER nothing to see")
elif mode == "leak":
    print("VERDICT: FLAGGED\n- [HIGH] quoting " + os.environ["STUB_LEAK"])
else:
    print("VERDICT: FLAGGED\nMODEL-MARKER one finding\n- [HIGH] 12:00 KEEP-ME-FINDING agent did X")
'''

STUB_ALERT = r'''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["STUB_ALERTS"], "a") as fh:
    fh.write(json.dumps(sys.argv[1:]) + "\n")
'''


class Fixture:
    def __init__(self, tmp):
        self.root = Path(tmp)
        self.projects = self.root / "claude" / "projects"
        self.projects.mkdir(parents=True)
        self.audit = self.root / "audit"
        self.capture = self.root / "model_input.txt"
        self.alerts = self.root / "alerts.txt"
        self.claude = self.root / "claude-stub"
        self.claude.write_text(STUB_CLAUDE)
        self.claude.chmod(0o755)
        alert = self.root / "alert-stub"
        alert.write_text(STUB_ALERT)
        alert.chmod(0o755)
        self.on_flag = f"{shlex.quote(str(alert))} {{alert}}"

    def env(self, **extra):
        env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE_")}
        env.update(CLAUDE_CONFIG_DIR=str(self.root / "claude"), CLAUDE_AUDIT_DIR=str(self.audit),
                   HOME=str(self.root / "home"), STUB_CAPTURE=str(self.capture),
                   STUB_ALERTS=str(self.alerts), PYTHONDONTWRITEBYTECODE="1")
        env.update(extra)
        return env

    def run(self, *extra_args, prelude=None, **env):
        args = ["--claude-bin", str(self.claude), "--on-flag", self.on_flag, *extra_args]
        if prelude:
            code = (f"import sys; sys.path.insert(0, {str(HERE)!r}); "
                    f"import claude_session_audit as m; {prelude}; sys.exit(m.main())")
            cmd = [sys.executable, "-c", code, *args]
        else:
            cmd = [sys.executable, str(SCRIPT), *args]
        return subprocess.run(cmd, capture_output=True, text=True, env=self.env(**env),
                              timeout=300)

    def files(self):
        if not self.audit.exists():
            return {}
        return {str(p.relative_to(self.audit)): p.read_text()
                for p in self.audit.rglob("*") if p.is_file()}

    def read(self, p):
        return p.read_text() if p.exists() else ""

    def everything(self, proc):
        return "\n".join([*self.files().values(), proc.stdout, proc.stderr,
                          self.read(self.capture), self.read(self.alerts)])

    def alert_lines(self):
        return [json.loads(l) for l in self.read(self.alerts).splitlines()]


def secrets_session(fx, planted):
    """Spread the planted secrets over the four places a transcript holds text."""
    entries = []
    for i, (_, _, text) in enumerate(planted):
        where = i % 4
        tid = f"toolu_{i}"
        if where == 0:
            entries.append(user(f"please use this: {text}"))
        elif where == 1:
            entries.append(agent(f"I found {text}"))
        elif where == 2:
            entries += [call(tid, text), result(tid, "done")]
        else:
            entries += [call(tid, "cat config"), result(tid, text)]
    entries.append(result("toolu_0", planted[0][2]))  # seen again: still one finding
    return write_session(fx.projects, entries, subagent=True)


class SecretsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.fx = Fixture(self.tmp.name)
        self.planted, self.forbidden = plant()
        self.sid = secrets_session(self.fx, self.planted)

    def tearDown(self):
        self.tmp.cleanup()

    def assertNoLeak(self, text):
        for f in self.forbidden:
            self.assertNotIn(f, text)

    def test_redacted_everywhere_and_each_secret_reported(self):
        write_session(self.fx.projects, [user(self.planted[0][2])], cwd="/home/dev/second")
        p = self.fx.run("--on-flag", "exit 7", STUB_MODE="clean")
        self.assertEqual(p.returncode, 2, p.stderr)
        self.assertNoLeak(self.fx.everything(p))

        files = self.fx.files()
        report = next(v for k, v in files.items()
                      if k.startswith("reports/") and not k.endswith("_timeline.md"))
        timeline = next(v for k, v in files.items() if k.endswith("_timeline.md"))
        self.assertIn("**VERDICT: FLAGGED**", report)
        self.assertIn("### batch 1 of 1: CLEAN", report)
        lines = [l for l in report.splitlines() if l.startswith("- SECRET-EXPOSED ")]
        second = [l for l in lines if "(/home/dev/second)" in l]
        lines = [l for l in lines if l not in second]
        self.assertEqual(len(second), 1, second)
        self.assertRegex(second[0], r" aws-access-key in user prompt: \[REDACTED:aws-access-key#1\]$")
        self.assertEqual(len(lines), len(self.planted), "\n".join(lines))
        got = collections.Counter(re.search(r"\) (\S+) in ", l).group(1) for l in lines)
        self.assertEqual(got, collections.Counter(k for k, _, _ in self.planted))
        for where in ("user prompt", "agent text", "tool call input (Bash)",
                      "tool result (Bash)"):
            self.assertTrue(any(f" in {where}: " in l for l in lines), where)
        for l in lines:
            self.assertIn(self.sid[:8], l)
            self.assertIn("(/home/dev/proj)", l)
            self.assertRegex(l, r"^- SECRET-EXPOSED \d\d:\d\d:\d\d .*: \[REDACTED:[a-z-]+#\d+\]$")
        self.assertIn("[REDACTED:github-token#5]", timeline)

        model_in = self.fx.read(self.fx.capture)
        self.assertIn("[REDACTED:private-key#1]", model_in)

        alerts = self.fx.alert_lines()
        self.assertEqual(len(alerts), 1)
        self.assertEqual(len(alerts[0]), 1)
        alert = alerts[0][0]
        self.assertIn(f"FLAGGED ({len(self.planted) + 1} SECRET-EXPOSED)", alert)
        self.assertNotIn("MODEL-MARKER", alert)
        self.assertNotIn("REDACTED", alert)
        self.assertIn("ALERT-FAILED on-flag #2 exited 7", files["audit.log"])
        self.assertTrue((self.fx.audit / "last_run").exists())

    def test_clean_session_is_clean_and_silent(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        fx = Fixture(tmp.name)
        write_session(fx.projects, [user("run the tests"), agent("all 12 passed")])
        p = fx.run(STUB_MODE="clean")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("=====STUB-CALL=====", fx.read(fx.capture))
        report = next(v for k, v in fx.files().items()
                      if k.startswith("reports/") and not k.endswith("_timeline.md"))
        self.assertIn("**VERDICT: CLEAN**", report)
        self.assertIn("## Secrets exposed (deterministic; any one flags the run)\n- none", report)
        self.assertTrue((fx.audit / "last_run").exists())
        self.assertFalse(fx.alerts.exists())
        self.assertNotIn("ALERT-FAILED", fx.files()["audit.log"])

    def test_stdout_mode_is_redacted(self):
        p = self.fx.run("--stdout", "--no-llm")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNoLeak(p.stdout + p.stderr)
        self.assertEqual(p.stdout.count("- SECRET-EXPOSED "), len(self.planted))
        self.assertEqual(self.fx.files(), {})

    def test_output_form_secrets_are_findings(self):
        tok = rnd(40)
        aws = random.choice(ALNUM + "+") + rnd(39, ALNUM + "/+")  # a leading "/" is #30 item 4
        self.forbidden += [tok, aws, tok[:12], aws[:12]]
        write_session(self.fx.projects, [
            {"type": "assistant", "timestamp": ts(5), "message": {"content": [
                {"type": "tool_use", "id": "w", "name": "WebFetch",
                 "input": {"headers": {"Authorization": f"Bearer {tok}"}}}]}},
            result("w", f"[default]\r\naws_secret_access_key = {aws}\r\n")], cwd="/home/dev/crlf")
        p = self.fx.run("--stdout", "--no-llm")
        self.assertNoLeak(p.stdout + p.stderr)
        self.assertEqual(p.stdout.count("- SECRET-EXPOSED "), len(self.planted) + 2, p.stdout[:3000])
        self.assertIn("bearer-token in tool call input (WebFetch)", p.stdout)
        self.assertIn("config-secret in tool result (WebFetch)", p.stdout)

    def test_no_llm_still_flags_and_alerts(self):
        p = self.fx.run("--no-llm", "--since", "1h")
        self.assertEqual(p.returncode, 2, p.stderr)
        self.assertNoLeak(self.fx.everything(p))
        self.assertIn(f"FLAGGED ({len(self.planted)} SECRET-EXPOSED)", self.fx.alert_lines()[0][0])

    def test_begin_and_end_in_different_events_do_not_fail_closed(self):
        begin, end = "-----BEGIN OPENSSH " + "PRIVATE KEY-----", "-----END OPENSSH " + "PRIVATE KEY-----"
        write_session(self.fx.projects, [call("h", "head -1 ~/.ssh/id"), result("h", begin),
                                         call("t", "tail -1 ~/.ssh/id"), result("t", end)])
        write_session(self.fx.projects, [user(f"grep -- '{end}' x")], cwd="/home/dev/other")
        p = self.fx.run(STUB_MODE="clean")
        self.assertEqual(p.returncode, 2, p.stderr)

    def test_error_is_redacted_and_alerts(self):
        leak = "gh" + "p_" + rnd(36)
        self.forbidden.append(leak)
        bad = self.fx.root / f"audit-{leak}"
        bad.write_text("a file, not a directory")
        p = self.fx.run(STUB_MODE="clean", CLAUDE_AUDIT_DIR=str(bad))
        self.assertEqual(p.returncode, 1, p.stderr)
        self.assertIn("[REDACTED:github-token#1]", p.stderr)
        self.assertNoLeak(p.stdout + p.stderr + self.fx.read(self.fx.alerts))
        self.assertRegex(self.fx.alert_lines()[0][0], r"^Claude audit on \S+: ERROR \(see schedule.log\)$")

    def test_unreadable_transcript_holds_last_run(self):
        self.fx.audit.mkdir()
        (self.fx.audit / "last_run").write_text(ts(30))
        before = (self.fx.audit / "last_run").read_text()
        write_session(self.fx.projects, [{"type": "assistant", "timestamp": ts(5), "message": {
            "content": [{"type": "tool_use", "id": ["unhashable"], "name": "Bash", "input": {}}]}}],
            cwd="/home/dev/broken")
        p = self.fx.run(STUB_MODE="clean")
        self.assertEqual(p.returncode, 3, p.stderr)
        self.assertEqual((self.fx.audit / "last_run").read_text(), before)
        self.assertIn("1 FILE-SKIPPED", self.fx.alert_lines()[0][0])

    def _assert_failed_closed(self, p, before, where):
        self.assertEqual(p.returncode, 3, p.stderr)
        self.assertEqual(self.fx.files(), before)
        self.assertNotIn("SECRET", p.stdout)
        self.assertNoLeak(p.stdout + p.stderr + self.fx.read(self.fx.alerts))
        alerts = self.fx.alert_lines()
        self.assertEqual(len(alerts), 1)
        self.assertRegex(alerts[0][0], r"^Claude audit on \S+: redaction self-check failed$")
        self.assertRegex(p.stderr, r"redaction self-check failed \([a-z-]+(, [a-z-]+)* in "
                         + re.escape(where) + r"\)")

    def test_fails_closed_before_the_model_sees_a_leak(self):
        self.fx.audit.mkdir()
        (self.fx.audit / "last_run").write_text(ts(30))
        before = self.fx.files()
        p = self.fx.run(prelude="m.Redactor.redact = lambda self, t: (t, [])",
                        STUB_MODE="clean")
        self._assert_failed_closed(p, before, "the model input")
        self.assertEqual(self.fx.read(self.fx.capture), "")  # nothing sent to the model

    def test_fails_closed_when_the_review_leaks(self):
        self.fx.audit.mkdir()
        (self.fx.audit / "last_run").write_text(ts(30))
        before = self.fx.files()
        leak = "gh" + "p_" + rnd(36)
        self.forbidden.append(leak)
        p = self.fx.run(prelude="m.Redactor.clean = lambda self, t: t",
                        STUB_MODE="leak", STUB_LEAK=leak)
        self._assert_failed_closed(p, before, "the report")
        self.assertIn("=====STUB-CALL=====", self.fx.read(self.fx.capture))


class BatchTest(unittest.TestCase):
    """Issue #20: one bad batch must not hide the others or advance last_run."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.fx = Fixture(self.tmp.name)
        self.fx.audit.mkdir()
        self.last_run = ts(30)
        (self.fx.audit / "last_run").write_text(self.last_run)

    def tearDown(self):
        self.tmp.cleanup()

    def big_session(self, marker, cwd):
        n = audit.BATCH_CHARS // 2 // audit.TEXT_LIMIT + 10
        body = "lorem ipsum " * (audit.TEXT_LIMIT // 12)
        entries = [user(f"{marker} {i} {body}") for i in range(n)]
        sid = write_session(self.fx.projects, entries, cwd=cwd)
        return self.fx.projects / cwd.replace("/", "-") / f"{sid}.jsonl"

    def run_two(self, bad_marker, bad_first):
        """Batches follow file mtime, so the session written first is batch 1."""
        now = time.time()
        for age, (marker, cwd) in zip((120, 60), sorted(
                [("ordinary work", "/home/dev/a"), (bad_marker, "/home/dev/b")],
                key=lambda x: (x[0] == bad_marker) != bad_first)):
            path = self.big_session(marker, cwd)
            os.utime(path, (now - age, now - age))
        p = self.fx.run(STUB_MODE="flagged")
        self.assertEqual(self.fx.read(self.fx.capture).count("=====STUB-CALL====="), 2,
                         "the fixture must split into two review batches")
        self.assertEqual(p.returncode, 3, p.stderr)
        self.assertEqual((self.fx.audit / "last_run").read_text(), self.last_run)
        files = self.fx.files()
        report = next(v for k, v in files.items()
                      if k.startswith("reports/") and not k.endswith("_timeline.md"))
        self.assertIn("KEEP-ME-FINDING", report)
        self.assertIn("**VERDICT: FLAGGED**", report)
        self.assertIn("last_run not advanced", report)
        self.assertIn("last_run not advanced", files["audit.log"])
        bad, good = (1, 2) if bad_first else (2, 1)
        self.assertIn(f"### batch {good} of 2: FLAGGED", report)
        return report, self.fx.alert_lines(), bad

    def both_orders(self, bad_marker, check):
        for bad_first in (False, True):
            with self.subTest(bad_first=bad_first):
                self.tearDown()
                self.setUp()
                check(*self.run_two(bad_marker, bad_first))

    def test_failed_batch_keeps_the_other_review(self):
        def check(report, alerts, bad):
            self.assertIn(f"- batch {bad} of 2 failed: ", report)
            self.assertIn(f"### batch {bad} of 2: FAILED", report)
            self.assertEqual(len(alerts), 1)
            self.assertIn("1 HIGH, 1 BATCH-FAILED", alerts[0][0])
        self.both_orders("FAILME", check)

    def test_failed_batch_error_is_redacted(self):
        leak = "sk-" + "ant-api03-" + rnd(40)
        self.big_session("ordinary work", "/home/dev/a")
        self.big_session("FAILME", "/home/dev/b")
        p = self.fx.run(STUB_MODE="flagged", STUB_LEAK=leak)
        self.assertEqual(p.returncode, 3, p.stderr)
        self.assertNotIn(leak, self.fx.everything(p))
        self.assertNotIn(leak[:12], self.fx.everything(p))
        report = next(v for k, v in self.fx.files().items()
                      if k.startswith("reports/") and not k.endswith("_timeline.md"))
        self.assertIn("boom: model unavailable [REDACTED:anthropic-key#1]", report)

    def test_all_batches_failed(self):
        write_session(self.fx.projects, [user("FAILME please")])
        p = self.fx.run(STUB_MODE="flagged")
        self.assertEqual(p.returncode, 3, p.stderr)
        self.assertEqual((self.fx.audit / "last_run").read_text(), self.last_run)
        self.assertIn("REVIEW-FAILED (1 BATCH-FAILED)", self.fx.alert_lines()[0][0])

    def test_unclear_batch_is_not_hidden(self):
        def check(report, alerts, bad):
            self.assertIn(f"- batch {bad} of 2 came back UNCLEAR", report)
            self.assertIn("1 BATCH-UNCLEAR", alerts[0][0])
        self.both_orders("UNCLEARME", check)


class InstallScheduleTest(unittest.TestCase):
    """install-schedule.sh wires tg-notify by absolute path into cron and launchd."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.home = self.root / "h o'me"
        (self.home / ".claude/skills/agent-audit").mkdir(parents=True)
        (self.home / ".claude/skills/agent-audit/claude_session_audit.py").touch()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.tgdir = self.home / ".local/bin"
        self.tgdir.mkdir(parents=True)
        self.out = self.root / "tg.out"
        self.stub(self.tgdir / "tg-notify", f'printf "%s" "$1" > {shlex.quote(str(self.out))}')
        self.stub(self.bin / "claude", "exit 0")
        cron = shlex.quote(str(self.root / "cron"))
        self.stub(self.bin / "crontab", f'if [ "$1" = -l ]; then cat {cron} 2>/dev/null || '
                  f'{{ echo "no crontab" >&2; exit 1; }}; else cat > {cron}; fi')
        loaded = shlex.quote(str(self.root / "loaded"))
        self.stub(self.bin / "launchctl", f'case "$1" in bootstrap) touch {loaded};; '
                  f'bootout) rm -f {loaded};; print) [ -f {loaded} ];; esac')

    def tearDown(self):
        self.tmp.cleanup()

    def stub(self, path, body):
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def install(self, with_tg=True, darwin=False):
        if darwin:
            self.stub(self.bin / "uname", "echo Darwin")
        path = ([str(self.tgdir)] if with_tg else []) + [str(self.bin), "/usr/bin", "/bin"]
        return subprocess.run(["bash", str(HERE / "install-schedule.sh")], capture_output=True,
                              text=True, env={"HOME": str(self.home), "PATH": ":".join(path)})

    def run_on_flag(self, cmd):
        alert = "Claude audit on h: FLAGGED (1 SECRET-EXPOSED). Report: /r p/x.md"
        line = re.sub(r"\{(alert|report|verdict)\}", lambda m: shlex.quote(alert), cmd)
        self.assertEqual(subprocess.run(line, shell=True).returncode, 0)
        self.assertEqual(self.out.read_text(), alert)

    def test_cron(self):
        self.home = self.root / "home"  # cron refuses a path with a quote
        self.home.mkdir()
        (self.home / ".claude/skills/agent-audit").mkdir(parents=True)
        (self.home / ".claude/skills/agent-audit/claude_session_audit.py").touch()
        self.tgdir = self.home / ".local/bin"
        self.tgdir.mkdir(parents=True)
        self.stub(self.tgdir / "tg-notify", f'printf "%s" "$1" > {shlex.quote(str(self.out))}')
        p = self.install()
        self.assertEqual(p.returncode, 0, p.stderr)
        line = (self.root / "cron").read_text()
        on_flag = shlex.split(line.split(" >> ")[0])[-1]
        self.assertEqual(on_flag, f"{self.tgdir}/tg-notify {{alert}}")
        self.run_on_flag(on_flag)
        p = self.install(with_tg=False)
        self.assertIn("tg-notify not on PATH", p.stderr)
        self.assertNotIn("--on-flag", (self.root / "cron").read_text())

    def test_launchd(self):
        import plistlib
        p = self.install(darwin=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        plist = self.home / "Library/LaunchAgents/com.theunisdk.claude-audit.plist"
        args = plistlib.loads(plist.read_bytes())["ProgramArguments"]
        flags = [args[i + 1] for i, a in enumerate(args) if a == "--on-flag"]
        self.assertEqual(len(flags), 2)
        self.assertTrue(flags[0].startswith("osascript "))
        self.run_on_flag(flags[1])
        p = self.install(with_tg=False, darwin=True)
        self.assertIn("tg-notify not on PATH", p.stderr)
        args = plistlib.loads(plist.read_bytes())["ProgramArguments"]
        self.assertEqual(args.count("--on-flag"), 1)


class RedactorTest(unittest.TestCase):
    def assertRedacts(self, text, value, kind):
        out, hits = audit.Redactor().redact(text)
        self.assertNotIn(value, out, text)
        self.assertIn(kind, [k for k, _ in hits], text)

    def test_more_shapes(self):
        aws_secret = random.choice(ALNUM + "+") + rnd(39, ALNUM + "/+")  # a leading "/" is #30 item 4
        self.assertRedacts(f"[default]\naws_access_key_id = AK" + "IA" + rnd(16, string.ascii_uppercase)
                           + f"\naws_secret_access_key = {aws_secret}\n", aws_secret, "config-secret")
        pw = rnd(20)
        self.assertRedacts(f"PGPASSWORD={pw} psql -h db", pw, "env-secret")
        self.assertRedacts(f'python -c "x=\\"PASSWORD=\\\"{pw}\\\"\\""', pw, "env-secret")
        self.assertRedacts(f'PASSWORD="it\'s-{pw}"', pw, "env-secret")
        self.assertRedacts(f'{{\\"Authorization\\": \\"Bearer {pw}\\"}}', pw, "bearer-token")
        self.assertRedacts(f'  "api_token": "{pw}",', pw, "config-secret")
        for name in ("SECRET_KEY_BASE", "API_KEY_V2", "STRIPE_SECRET_KEY_LIVE", "GITHUB_TOKEN_RO",
                     "DB_PASSWORD_PROD"):
            self.assertRedacts(f"{name}={pw}", pw, "env-secret")
        body = [rnd(64, ALNUM + "+/") for _ in range(2)]
        quoted = ('key = ("-----BEGIN RSA ' + 'PRIVATE KEY-----\\n"\n'
                  + "".join(f'       "{b}\\n"\n' for b in body)
                  + '       "-----END RSA ' + 'PRIVATE KEY-----\\n")')
        for b in body:
            self.assertRedacts(quoted, b, "private-key")
        head = 'KEY = ("-----BEGIN RSA ' + 'PRIVATE KEY-----\\n"\n' + "".join(f'  "{b}\\n"\n' for b in body)
        for b in body:
            self.assertRedacts(head, b, "private-key")
        crlf = ("-----BEGIN RSA " + "PRIVATE KEY-----\r\nProc-Type: 4,ENCRYPTED\r\n"
                "DEK-Info: AES-128-CBC,0A1B\r\n\r\n" + "\r\n".join(body)
                + "\r\n-----END RSA " + "PRIVATE KEY-----\r\n")
        for b in body:
            self.assertRedacts(crlf, b, "private-key")

    def test_secret_named_dict_values(self):
        pw = rnd(14)
        hits = []
        out = audit.Redactor().deep({"user": "app", "password": pw, "opts": [{"apiKey": pw + "x"}],
                                     "pageToken": rnd(20), "nextPageToken": rnd(20)}, hits)
        self.assertNotIn(pw, json.dumps(out))
        self.assertEqual([k for k, _ in hits], ["config-secret", "config-secret"])
        self.assertEqual(out["user"], "app")

    def test_clipping_never_trips_the_self_check(self):
        red = audit.Redactor()
        text = ("# .env.example\nOPENAI_API_KEY=sk-proj-" + "x" * 40 + "\nAWS_ID=AKIA"
                + "Q" * 16 + "XYZ\nBOT=" + "1" * 9 + ":" + "a" * 40 + "\nDB_PASSWORD=****")
        for n in range(1, len(text) + 1):
            self.assertEqual(audit.find_secrets(red.clip(text, n)), [], n)

    def test_every_rule_is_fast_on_adversarial_input(self):
        # In a subprocess: a catastrophic regex never returns, and re can't be interrupted.
        for mb in (0.5, 1, 2):
            with self.subTest(mb=mb):
                code = (f"import sys; sys.dont_write_bytecode = True; sys.path.insert(0, {str(HERE)!r}); "
                        f"import test_claude_session_audit as t; t.RedactorTest('_time_corpus')._time_corpus({mb})")
                try:
                    p = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True,
                                       timeout=30)
                except subprocess.TimeoutExpired:
                    self.fail(f"{mb}MB: still running after 30s")
                self.assertEqual(p.returncode, 0, p.stderr[-2000:])

    def _time_corpus(self, mb):
        import time
        k = mb / 1.5  # the base corpus is about 1.5MB
        n = lambda x: max(1, int(x * k))
        begin = "-----BEGIN RSA " + "PRIVATE KEY-----"
        segments = [
            begin + "\r\n" + "Proc-Type: a\r\n" * n(7000),
            begin + "\\r\\n" + "Proc-Type: a\\r\\n" * n(5000),
            ("X: " + begin + "\n") * n(3000),
            ("X: " + begin + "\\n") * n(3000),
            ("X: " + begin + "\nComment: c\n") * n(2000),
            begin + "\nERROR: " + "ka: v " * n(16000),
            begin + "\n" + '"' * n(50_000) + "," * n(50_000),
            begin + "\n" + ("'" + "A" * 15 + "'\n") * n(5000),
            "password: abc123def456ghi" + " " * n(100_000) + "x",
            "  token = " + "a1" * n(50_000) + " x",
            "a." * n(50_000), "sk-" * n(33_000), "x://" * n(25_000), "A_" * n(50_000),
            "Authorization: Bearer " * n(5000), "user:pass@" * n(10_000), "1234567890:" * n(9000),
        ]
        corpus = "\n".join(segments)
        self.assertGreater(len(corpus), mb * 900_000)
        def every_rule():
            for _, rx, _ in audit.SECRET_RULES:
                for _ in rx.finditer(corpus):
                    pass
        for name, run in (("every rule", every_rule),
                          ("redact", lambda: audit.Redactor().redact(corpus)),
                          ("self-check", lambda: audit.find_secrets(corpus))):
            t0 = time.monotonic()
            run()
            self.assertLess(time.monotonic() - t0, 2.0, name)

    def test_no_quadratic_regexes(self):
        import time
        red = audit.Redactor()
        for text in ["a." * 100_000, "sk-" * 70_000, "\n" * 200_000, " " * 200_000,
                     ("-----BEGIN RSA " + "PRIVATE KEY-----\n") * 5000,
                     "A_" * 100_000, "x://" * 50_000, "eyJ" * 70_000,
                     "-----BEGIN RSA " + "PRIVATE KEY-----\nProc-Type:" + " a:" * 60_000,
                     "-----BEGIN RSA " + "PRIVATE KEY-----\nERROR: " + "ka: v " * 40_000]:
            t0 = time.monotonic()
            red.redact(text)
            audit.find_secrets(text)
            self.assertLess(time.monotonic() - t0, 3, text[:20])

    def test_truncated_private_key(self):
        body = [rnd(64, ALNUM + "+/") for _ in range(2)]
        for sep in ("\n", "\\n"):
            text = "-----BEGIN OPENSSH " + "PRIVATE KEY-----" + sep + sep.join(body) + sep + "…"
            out, hits = audit.Redactor().redact(text)
            self.assertEqual([k for k, _ in hits], ["private-key"])
            for b in body:
                self.assertNotIn(b[:12], out)

    def test_consistent_and_idempotent(self):
        planted, forbidden = plant()
        r = audit.Redactor()
        text = "\n".join(t for _, _, t in planted)
        once, hits = r.redact(text)
        self.assertEqual(len(hits), len(planted))
        self.assertEqual(r.redact(text)[0], once)  # same value, same placeholder
        self.assertEqual(r.redact(once), (once, []))
        self.assertEqual(audit.find_secrets(once), [])
        for f in forbidden:
            self.assertNotIn(f, once)

    def test_clip_never_splits_a_placeholder(self):
        ph = "[REDACTED:env-secret#1]"
        for lead in range(30):
            s = "K='" + "a" * lead + ph + "' " + "b" * 40
            for n in range(1, len(s)):
                c = audit.clip(s, n)
                self.assertTrue(ph in c or "[RE" not in c, c)
                self.assertEqual(audit.find_secrets(c), [], c)

    def test_json_escaping_does_not_create_a_secret(self):
        raw = 'echo "GH_TOKEN=abcdefg" && x="NAME_KEY=ab\ncdefgh"'
        out = audit.Redactor().clean(raw)
        self.assertEqual(audit.find_secrets(json.dumps({"command": out})), [])

    def test_ordinary_text_left_alone(self):
        for t in ["token = getToken()", "API_KEY=$API_KEY", 'export TOKEN="${TOKEN}"',
                  "https://user:${PASS}@host/x", "postgres://u:password@localhost/db",
                  "SSH_KEY_PATH=/home/me/.ssh/id_ed25519", "task-runner-1234567890abcdefghij",
                  "git clone git@github.com:org/repo.git", "Authorization: Bearer $TOKEN",
                  "MONKEY=bananas123", "ask-question-12345678901234567890",
                  'grep -rl -- "-----BEGIN OPENSSH ' + 'PRIVATE KEY-----" ~/.ssh',
                  "CACHE_KEY=user-profile-v2", "REDIS_KEY_PREFIX=myapp:cache",
                  "PUBLIC_KEY=ssh-ed25519AAAAC3", "GIT_CONFIG_KEY_0=credential.helper",
                  "BYPASS=enabled12345", "token = self.get_token(scope)",
                  "  password: ${DB_PASSWORD}"]:
            self.assertEqual(audit.find_secrets(t), [], t)


if __name__ == "__main__":
    unittest.main(verbosity=2)
