#!/bin/bash
# check_sqlite_export.sh — Validate a KeyLens SQLite export file.
#
# Usage:
#   ./scripts/check_sqlite_export.sh [path/to/KeyLens_YYYY-MM-DD.db]
#
# If no argument is given, looks for the most recent *.db file in the
# current directory.

set -euo pipefail

# Resolve DB path
if [ $# -ge 1 ]; then
    DB="$1"
else
    DB=$(ls -t ./*.db 2>/dev/null | head -1)
fi

if [ -z "${DB:-}" ] || [ ! -f "$DB" ]; then
    echo "ERROR: No .db file found. Run 'Export SQLite...' from the KeyLens menu first."
    echo "Usage: $0 [path/to/KeyLens_YYYY-MM-DD.db]"
    exit 1
fi

echo "=== KeyLens SQLite Export Validator ==="
echo "File: $DB"
echo "Size: $(du -h "$DB" | cut -f1)"
echo ""

PASS=0
FAIL=0

check() {
    local label="$1"
    local result="$2"
    local expected="$3"
    if [ "$result" = "$expected" ]; then
        echo "  PASS  $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $label (got: $result, expected: $expected)"
        FAIL=$((FAIL + 1))
    fi
}

check_gt() {
    local label="$1"
    local result="$2"
    local min="$3"
    if [ "$result" -gt "$min" ] 2>/dev/null; then
        echo "  PASS  $label ($result rows)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $label (got: $result rows, expected > $min)"
        FAIL=$((FAIL + 1))
    fi
}

# --- Table existence ---
echo "--- Tables ---"
TABLES=$(sqlite3 "$DB" ".tables")
for t in key_counts daily_counts hourly_counts bigram_counts; do
    if echo "$TABLES" | grep -qw "$t"; then
        echo "  PASS  table '$t' exists"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  table '$t' missing"
        FAIL=$((FAIL + 1))
    fi
done

# --- Row counts > 0 ---
echo ""
echo "--- Row counts ---"
KC=$(sqlite3 "$DB" "SELECT COUNT(*) FROM key_counts;")
DC=$(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_counts;")
HC=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hourly_counts;")
BC=$(sqlite3 "$DB" "SELECT COUNT(*) FROM bigram_counts;")

check_gt "key_counts has rows"    "$KC" 0
check_gt "daily_counts has rows"  "$DC" 0
check_gt "hourly_counts has rows" "$HC" 0
check_gt "bigram_counts has rows" "$BC" 0

# --- Sanity: totals are positive integers ---
echo ""
echo "--- Data sanity ---"
NEG_KEYS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM key_counts WHERE total <= 0;")
check "key_counts: no zero/negative totals" "$NEG_KEYS" "0"

NEG_DAILY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_counts WHERE count <= 0;")
check "daily_counts: no zero/negative counts" "$NEG_DAILY" "0"

NEG_BIGRAM=$(sqlite3 "$DB" "SELECT COUNT(*) FROM bigram_counts WHERE count <= 0;")
check "bigram_counts: no zero/negative counts" "$NEG_BIGRAM" "0"

# --- Sanity: daily_counts dates look like yyyy-MM-dd ---
BAD_DATES=$(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_counts WHERE date NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]';")
check "daily_counts: dates are yyyy-MM-dd" "$BAD_DATES" "0"

# --- Summary: top 5 keys ---
echo ""
echo "--- Top 5 keys (key_counts) ---"
sqlite3 "$DB" <<SQL
.headers on
.mode column
.width 20 10
SELECT key, total FROM key_counts ORDER BY total DESC LIMIT 5;
SQL

# --- Summary: top 5 bigrams ---
echo ""
echo "--- Top 5 bigrams (bigram_counts) ---"
sqlite3 "$DB" <<SQL
.headers on
.mode column
.width 20 10
SELECT bigram, count FROM bigram_counts ORDER BY count DESC LIMIT 5;
SQL

# --- Final result ---
echo ""
echo "=================================="
echo "Result: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
    echo "All checks passed."
    exit 0
else
    exit 1
fi
