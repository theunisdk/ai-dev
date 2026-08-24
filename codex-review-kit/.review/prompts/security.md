# Your lens: SECURITY & DATA EXPOSURE

Assume a motivated attacker who has read this diff.

Hunt specifically for:

- **Authorisation gaps** — a new endpoint, route, handler, GraphQL resolver, or
  RPC method with no authz check, or a check that verifies authentication but not
  ownership. Compare against the authz pattern used by sibling handlers: if
  neighbours check and this one does not, that is a finding.
- **IDOR / horizontal escalation** — an identifier taken from the request and used
  to fetch a record without scoping the query to the caller's tenant or user.
- **Injection** — string-built SQL, NoSQL operator injection from user-controlled
  objects, shell command construction, template injection, LDAP, XPath, unsafe
  deserialisation (pickle, YAML unsafe load, Java native), prototype pollution.
- **SSRF and path traversal** — user-supplied URLs fetched server-side, user input
  reaching file paths, archive extraction without path sanitisation.
- **Secrets and PII** — credentials, tokens, or keys in source, config, or test
  fixtures; secrets or personal data written to logs, error messages, telemetry,
  or returned in API error responses; over-broad serialisers that leak fields.
- **Crypto misuse** — hand-rolled crypto, ECB mode, static or reused IVs, weak
  hashes for passwords, non-constant-time comparison of secrets, predictable
  randomness (`Math.random`, unseeded PRNG) used for tokens, IDs, or nonces.
- **Web surface** — CORS widened to `*` or reflecting Origin, missing CSRF
  protection on state-changing routes, cookies without HttpOnly/Secure/SameSite,
  `dangerouslySetInnerHTML` / `innerHTML` with untrusted data, open redirects.
- **Missing limits** — no rate limit, no size cap on uploads or request bodies, no
  pagination cap, unbounded loop driven by user input (DoS surface).
- **Dependency and supply chain** — a newly added dependency doing something the
  change did not need, a pinned version loosened, a postinstall script.

Report the exploit path concretely: what an attacker sends, and what they get.
