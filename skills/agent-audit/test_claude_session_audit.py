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
    print("boom: model unavailable", file=sys.stderr); sys.exit(1)
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
        p = self.fx.run("--on-flag", "exit 7", STUB_MODE="clean")
        self.assertEqual(p.returncode, 2, p.stderr)
        self.assertNoLeak(self.fx.everything(p))

        files = self.fx.files()
        report = next(v for k, v in files.items()
                      if k.startswith("reports/") and not k.endswith("_timeline.md"))
        timeline = next(v for k, v in files.items() if k.endswith("_timeline.md"))
        self.assertIn("**VERDICT: FLAGGED**", report)  # the model said CLEAN
        lines = [l for l in report.splitlines() if l.startswith("- SECRET-EXPOSED ")]
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
        self.assertIn(f"FLAGGED ({len(self.planted)} SECRET-EXPOSED)", alert)
        self.assertNotIn("MODEL-MARKER", alert)
        self.assertNotIn("REDACTED", alert)
        self.assertIn("ALERT-FAILED on-flag #2 exited 7", files["audit.log"])
        self.assertTrue((self.fx.audit / "last_run").exists())

    def test_stdout_mode_is_redacted(self):
        p = self.fx.run("--stdout", "--no-llm")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNoLeak(p.stdout + p.stderr)
        self.assertEqual(p.stdout.count("- SECRET-EXPOSED "), len(self.planted))
        self.assertEqual(self.fx.files(), {})

    def _assert_failed_closed(self, p, before):
        self.assertEqual(p.returncode, 3, p.stderr)
        self.assertEqual(self.fx.files(), before)
        self.assertNotIn("SECRET", p.stdout)
        self.assertNoLeak(p.stdout + p.stderr + self.fx.read(self.fx.alerts))
        alerts = self.fx.alert_lines()
        self.assertEqual(len(alerts), 1)
        self.assertRegex(alerts[0][0], r"^Claude audit on \S+: redaction self-check failed$")

    def test_fails_closed_before_the_model_sees_a_leak(self):
        self.fx.audit.mkdir()
        (self.fx.audit / "last_run").write_text(ts(30))
        before = self.fx.files()
        p = self.fx.run(prelude="m.Redactor.redact = lambda self, t: (t, [])",
                        STUB_MODE="clean")
        self._assert_failed_closed(p, before)
        self.assertEqual(self.fx.read(self.fx.capture), "")  # nothing sent to the model

    def test_fails_closed_when_the_review_leaks(self):
        self.fx.audit.mkdir()
        (self.fx.audit / "last_run").write_text(ts(30))
        before = self.fx.files()
        leak = "gh" + "p_" + rnd(36)
        self.forbidden.append(leak)
        p = self.fx.run(prelude="m.Redactor.clean = lambda self, t: t",
                        STUB_MODE="leak", STUB_LEAK=leak)
        self._assert_failed_closed(p, before)
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
        write_session(self.fx.projects, entries, cwd=cwd)

    def run_two(self, bad_marker):
        self.big_session("ordinary work", "/home/dev/a")
        self.big_session(bad_marker, "/home/dev/b")
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
        return report, self.fx.alert_lines()

    def test_failed_batch_keeps_the_other_review(self):
        report, alerts = self.run_two("FAILME")
        self.assertRegex(report, r"- batch [12] of 2 failed: ")
        self.assertRegex(report, r"### batch [12] of 2: FAILED")
        self.assertEqual(len(alerts), 1)
        self.assertIn("1 HIGH, 1 BATCH-FAILED", alerts[0][0])

    def test_unclear_batch_is_not_hidden(self):
        report, alerts = self.run_two("UNCLEARME")
        self.assertRegex(report, r"- batch [12] of 2 came back UNCLEAR")
        self.assertIn("1 BATCH-UNCLEAR", alerts[0][0])


class RedactorTest(unittest.TestCase):
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


        for t in ["token = getToken()", "API_KEY=$API_KEY", 'export TOKEN="${TOKEN}"',
                  "https://user:${PASS}@host/x", "postgres://u:password@localhost/db",
                  "SSH_KEY_PATH=/home/me/.ssh/id_ed25519", "task-runner-1234567890abcdefghij",
                  "git clone git@github.com:org/repo.git", "Authorization: Bearer $TOKEN",
                  "MONKEY=bananas123", "ask-question-12345678901234567890",
                  'grep -rl -- "-----BEGIN OPENSSH ' + 'PRIVATE KEY-----" ~/.ssh']:
            self.assertEqual(audit.find_secrets(t), [], t)


if __name__ == "__main__":
    unittest.main(verbosity=2)
