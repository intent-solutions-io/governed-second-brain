#!/usr/bin/env bash
#
# lint-forbidden-words.sh — enforce the Governed Second Brain honesty discipline
# (ISEDC decision 009-AT-DECR D1 / CISO bind): the words below must NEVER appear
# as a GSB *claim* on a public brand surface. They MAY appear when explicitly
# NEGATED or discussed as forbidden (the trust-model disclaimer says "tamper-
# EVIDENT, not tamper-proof … not a blockchain … not immutable storage"), which
# is exactly the honesty the brand is built on — so a bare positive assertion
# fails, a negated/disclaimer usage passes.
#
# Forbidden as a claim: tamper-proof · immutable · non-repudiation · blockchain
# ("tamper-evident" is the CORRECT term and never matches.)
#
# A line is a VIOLATION when it contains a forbidden word AND neither
#   - a negation / contrast marker on the same line (not, never, no, n't, ≠,
#     "instead of", "rather than", "as opposed to", "forbidden", "avoid"), nor
#   - an explicit escape:  <!-- forbidden-words-lint: allow -->
#
# Usage:  scripts/lint-forbidden-words.sh [file ...]   (default: README.md)
# Exit 0 clean, 1 on any violation. Zero dependencies (grep + POSIX sh).
set -euo pipefail

FILES=("$@")
[ "${#FILES[@]}" -eq 0 ] && FILES=(README.md)

# word-boundary, case-insensitive; hyphenated forms handled explicitly
FORBIDDEN='tamper-proof|immutable|non-repudiation|blockchain'
# negation / contrast / meta markers that make a forbidden word an honest disclaimer
ALLOW_CTX="not|never|no |n't|≠|instead of|rather than|as opposed to|forbidden|avoid|isn't|aren't|doesn't|won't|do not|does not"
ESCAPE='forbidden-words-lint:[[:space:]]*allow'

# ── qualifier-required terms (2nd class, bead compile-then-govern-6ps.12): TRUE of
# the Bob's Big Brain chain, but only in a QUALIFIED sense — append-only *by
# protocol/convention* (not filesystem-enforced), an ordered log with *disclosed
# same-timestamp CHAIN_FORKs*. A bare positive assertion drifts toward the forbidden
# "immutable", so it passes ONLY with an honest qualifier (protocol / disclosed-forks
# / the hash-chain tamper-EVIDENCE framing), a negation, or the escape.
QUALIFIED='append-only|ordered log'
QUALIFIER_CTX='by protocol|by convention|protocol-level|disclosed|same-timestamp|CHAIN_FORK|benign fork|tamper-evident|hash-chained|hash of the|prev_hash|rewrite-detection|not [^.]*(enforced|filesystem|storage)'

violations=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "lint-forbidden-words: skip (not found): $f" >&2; continue; }
  # -n line numbers; -I skip binary; -E extended regex; -i case-insensitive
  while IFS= read -r hit; do
    lineno="${hit%%:*}"
    text="${hit#*:}"
    # allow if the line negates the word or carries the escape
    if printf '%s' "$text" | grep -qiE "$ALLOW_CTX"; then continue; fi
    if printf '%s' "$text" | grep -qiE "$ESCAPE"; then continue; fi
    printf '  %s:%s  forbidden claim-word (negate it, or use the correct term e.g. tamper-EVIDENT):\n    %s\n' \
      "$f" "$lineno" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-160)"
    violations=$((violations + 1))
  done < <(grep -inIE "$FORBIDDEN" "$f" || true)

  # second pass — qualifier-required terms (6ps.12): flag a BARE append-only /
  # ordered log; pass if an honest qualifier, a negation, or the escape is on the line.
  while IFS= read -r hit; do
    lineno="${hit%%:*}"
    text="${hit#*:}"
    if printf '%s' "$text" | grep -qiE "$QUALIFIER_CTX"; then continue; fi
    if printf '%s' "$text" | grep -qiE "$ALLOW_CTX"; then continue; fi
    if printf '%s' "$text" | grep -qiE "$ESCAPE"; then continue; fi
    printf '  %s:%s  qualifier-required term (add "by protocol" / "disclosed same-timestamp forks" / a hash-chain framing, or negate it):\n    %s\n' \
      "$f" "$lineno" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-160)"
    violations=$((violations + 1))
  done < <(grep -inIE "$QUALIFIED" "$f" || true)
done

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "✗ forbidden-words lint: $violations violation(s) — a brand surface asserted a word the trust model forbids."
  echo "  Fix: state the honest, tiered claim (tamper-EVIDENT, integrity+ordering+rewrite-detection), or negate the word."
  echo "  See 009-AT-DECR D1 + the README trust-model box. Genuine exceptions: <!-- forbidden-words-lint: allow -->"
  exit 1
fi
echo "✓ forbidden-words lint: clean (${#FILES[@]} file(s) checked) — no un-negated tamper-proof/immutable/non-repudiation/blockchain claims."
