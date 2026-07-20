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

# ── chain-conflation claims (3rd class, Wave-2 F5; registrar 046-AT-ARCH):
# the stack carries TWO hash chains that prove DIFFERENT things — the ICO
# trace chain proves a COMPILE ran; the INTKB audit chain proves a GOVERN
# admission decision. A sentence claiming one chain proves the OTHER side's
# domain (or proves content truth/accuracy — which NO chain proves) is the
# conflation failure mode. Two heuristic patterns:
#   A) "audit/admission/govern chain … proves/guarantees/verifies/certifies …
#      compile/content/truth/accuracy/correctness"
#   B) "trace/compile chain … proves/guarantees/verifies/certifies …
#      admission/governance/promotion/policy/curation"
# Negated / educational forms pass (mirrors the ALLOW_CTX discipline): "the
# audit chain does NOT prove the content is true", "NEITHER proves the
# other's", "conflating them is the failure mode" are exactly the honesty the
# brand teaches.
# gaps use [^.;:,]* so the match never spans a clause boundary — "the trace
# chain proves a compile ran; the audit chain proves the admission" (or the
# comma-separated form) is two correctly-scoped claims, not a conflation.
CONFLATION_A='(audit|admission|govern(ance)?)[- ](chain|log|trail)[^.;:,]*\b(prove[sdn]?|proving|guarantee[sd]?|verif(y|ies|ied)|certif(y|ies|ied))\b[^.;:,]*\b(compil|content|truth|true|correct|accura)'
CONFLATION_B='(trace|compile[r]?)[- ](chain|log|trail)[^.;:,]*\b(prove[sdn]?|proving|guarantee[sd]?|verif(y|ies|ied)|certif(y|ies|ied))\b[^.;:,]*\b(admiss|admit|govern|promot|policy|curat)'
# extra allow markers for the conflation class only — the wrong-form examples
# in teaching material are always negated, quoted-as-wrong, or exclusive-scoped
CONFLATION_ALLOW='neither|nor doe|cannot|conflat|failure mode|wrong|mistake|only prove|❌'

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

  # third pass — chain-conflation claims (Wave-2 F5): a sentence claiming the
  # govern chain proves compile-domain facts (or content truth), or the compile
  # chain proves govern-domain facts. Negated / educational / quoted-as-wrong
  # forms pass via ALLOW_CTX + CONFLATION_ALLOW; the escape works as everywhere.
  while IFS= read -r hit; do
    lineno="${hit%%:*}"
    text="${hit#*:}"
    if printf '%s' "$text" | grep -qiE "$ALLOW_CTX"; then continue; fi
    if printf '%s' "$text" | grep -qiE "$CONFLATION_ALLOW"; then continue; fi
    if printf '%s' "$text" | grep -qiE "$ESCAPE"; then continue; fi
    printf '  %s:%s  chain-conflation claim (one chain cannot prove the other side'\''s domain — see registrar 046-AT-ARCH):\n    %s\n' \
      "$f" "$lineno" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-160)"
    violations=$((violations + 1))
  done < <({ grep -inIE "$CONFLATION_A" "$f" || true; grep -inIE "$CONFLATION_B" "$f" || true; } | sort -t: -k1,1n -u)
done

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "✗ forbidden-words lint: $violations violation(s) — a brand surface asserted a claim the trust model forbids."
  echo "  Fix: state the honest, tiered claim (tamper-EVIDENT, integrity+ordering+rewrite-detection), negate the word,"
  echo "  or scope each chain to its own domain (trace chain = compile; audit chain = govern admission; neither = truth)."
  echo "  See 009-AT-DECR D1, registrar 046-AT-ARCH + the README trust-model box. Genuine exceptions: <!-- forbidden-words-lint: allow -->"
  exit 1
fi
echo "✓ forbidden-words lint: clean (${#FILES[@]} file(s) checked) — no un-negated tamper-proof/immutable/non-repudiation/blockchain claims, no chain-conflation claims."
