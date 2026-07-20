#!/usr/bin/env bash
#
# test-lint-forbidden-words.sh — self-test for scripts/lint-forbidden-words.sh.
#
# Exercises the lint exactly the way docs-honesty.yml does (bash, file
# arguments, exit code) against generated fixtures covering all three check
# classes: forbidden claim-words, qualifier-required terms, and (Wave-2 F5)
# chain-conflation claims. Each case asserts the exit code AND, for
# violations, that the offending line number is reported.
#
# Usage:  scripts/test-lint-forbidden-words.sh
# Exit 0 when every case behaves, 1 otherwise. Zero dependencies beyond the
# lint script itself.
set -euo pipefail

LINT="$(dirname "$0")/lint-forbidden-words.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

failures=0

# run <expected-exit> <name> <file...>
run() {
  local expected="$1" name="$2"
  shift 2
  local actual=0
  bash "$LINT" "$@" >"$TMP/out.txt" 2>&1 || actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "  ok    $name (exit $actual)"
  else
    echo "  FAIL  $name — expected exit $expected, got $actual"
    sed 's/^/        /' "$TMP/out.txt"
    failures=$((failures + 1))
  fi
}

# ── class 1: forbidden claim-words ─────────────────────────────────────────
cat >"$TMP/forbidden-bare.md" <<'EOF'
Our audit log is immutable and tamper-proof.
EOF
run 1 "bare forbidden claim fails" "$TMP/forbidden-bare.md"

cat >"$TMP/forbidden-negated.md" <<'EOF'
The chain is tamper-evident, not tamper-proof, and it is not a blockchain.
EOF
run 0 "negated forbidden words pass" "$TMP/forbidden-negated.md"

# ── class 2: qualifier-required terms ──────────────────────────────────────
cat >"$TMP/qualified-bare.md" <<'EOF'
Every event lands on an append-only receipt log.
EOF
run 1 "bare append-only fails" "$TMP/qualified-bare.md"

cat >"$TMP/qualified-ok.md" <<'EOF'
Every event lands on a receipt log that is append-only by protocol.
EOF
run 0 "qualified append-only passes" "$TMP/qualified-ok.md"

# ── class 3: chain-conflation claims (Wave-2 F5) ───────────────────────────
cat >"$TMP/conflation-audit-claims-compile.md" <<'EOF'
The audit chain proves the content was compiled correctly from its source.
EOF
run 1 "audit-chain-proves-compile fails" "$TMP/conflation-audit-claims-compile.md"

cat >"$TMP/conflation-audit-claims-truth.md" <<'EOF'
Because the audit chain verifies the truth of every stored memory, you can trust it.
EOF
run 1 "audit-chain-proves-truth fails" "$TMP/conflation-audit-claims-truth.md"

cat >"$TMP/conflation-trace-claims-admission.md" <<'EOF'
The trace chain guarantees the page was admitted under the governance policy.
EOF
run 1 "trace-chain-proves-admission fails" "$TMP/conflation-trace-claims-admission.md"

cat >"$TMP/conflation-negated.md" <<'EOF'
The audit chain does not prove the content is true or compiled correctly.
The trace chain cannot prove admission; neither chain proves the other's claims.
EOF
run 0 "negated conflation forms pass" "$TMP/conflation-negated.md"

cat >"$TMP/conflation-educational.md" <<'EOF'
Conflating them ("the audit chain proves the content was compiled correctly") is the failure mode.
The trace chain only proves a compile ran; the audit chain only proves a govern admission happened.
EOF
run 0 "educational/quoted-as-wrong conflation forms pass" "$TMP/conflation-educational.md"

cat >"$TMP/conflation-scoped.md" <<'EOF'
The trace chain proves a compile pass ran; the audit chain proves the admission decision.
EOF
run 0 "correctly-scoped per-chain claims pass" "$TMP/conflation-scoped.md"

cat >"$TMP/conflation-scoped-comma.md" <<'EOF'
The ICO trace chain proves compile, the INTKB audit chain proves govern admission.
EOF
run 0 "comma-separated scoped claims pass (title form)" "$TMP/conflation-scoped-comma.md"

cat >"$TMP/conflation-escaped.md" <<'EOF'
The audit chain proves the content is accurate. <!-- forbidden-words-lint: allow -->
EOF
run 0 "escape comment passes the conflation check" "$TMP/conflation-escaped.md"

# violation output must name file:line
bash "$LINT" "$TMP/conflation-audit-claims-compile.md" >"$TMP/out.txt" 2>&1 || true
if grep -q "conflation-audit-claims-compile.md:1" "$TMP/out.txt"; then
  echo "  ok    violation report carries file:line"
else
  echo "  FAIL  violation report missing file:line"
  failures=$((failures + 1))
fi

# ── multi-file: one clean + one dirty still fails ──────────────────────────
run 1 "mixed clean+dirty file set fails" "$TMP/forbidden-negated.md" "$TMP/conflation-trace-claims-admission.md"

echo ""
if [ "$failures" -gt 0 ]; then
  echo "✗ lint self-test: $failures case(s) failed"
  exit 1
fi
echo "✓ lint self-test: all cases behaved"
