#!/usr/bin/env bash
#
# dirsweep test suite - plain bash, no dependencies.
#   tests/run_tests.sh [-v]
#
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HERE/../bin/dirsweep"
MAKE_ENV="$HERE/make_test_env.sh"
VERBOSE=false; [[ ${1:-} == -v ]] && VERBOSE=true

WORK="$(mktemp -d /tmp/dirsweep-tests.XXXXXX)"
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf -- "$WORK"' EXIT
export XDG_STATE_HOME="$WORK/state" XDG_DATA_HOME="$WORK/data" XDG_CONFIG_HOME="$WORK/config"
export XDG_RUNTIME_DIR="$WORK/run" HOME="$WORK/home" NO_COLOR=1
mkdir -p "$XDG_RUNTIME_DIR" "$HOME"
LOG="$WORK/test.log"

PASS=0 FAIL=0 SKIP=0 CURRENT=""
if [[ -t 1 ]]; then G=$'\e[32m' R=$'\e[31m' Y=$'\e[33m' D=$'\e[2m' Z=$'\e[0m'; else G='' R='' Y='' D='' Z=''; fi

ds()    { "$BIN" --no-config -l "$LOG" "$@"; }
fresh() { T="$WORK/t$RANDOM$RANDOM"; "$MAKE_ENV" "$T" >/dev/null; }

begin() { CURRENT=$1; $VERBOSE && printf '%s%s%s\n' "$D" "$1" "$Z"; return 0; }
pass()  { PASS=$((PASS + 1)); $VERBOSE && printf '  %sok%s   %s\n' "$G" "$Z" "$1"; return 0; }
fail()  { FAIL=$((FAIL + 1)); printf '  %sFAIL%s %s  %s(%s)%s\n' "$R" "$Z" "$1" "$D" "$CURRENT" "$Z"; return 0; }
skip_t(){ SKIP=$((SKIP + 1)); printf '  %sskip%s %s\n' "$Y" "$Z" "$1"; return 0; }

has()    { [[ -e $1 || -L $1 ]] && pass "exists: ${1#"$T"/}" || fail "should exist: ${1#"$T"/}"; }
gone()   { [[ ! -e $1 && ! -L $1 ]] && pass "gone: ${1#"$T"/}" || fail "should be gone: ${1#"$T"/}"; }
eq()     { [[ $1 == "$2" ]] && pass "$3" || fail "$3 (got '$1', want '$2')"; }
status() { local want=$1; shift; "$@" >/dev/null 2>&1; eq "$?" "$want" "exit $want: ${*: -2}"; }

# ---------------------------------------------------------------- basics
begin "cli basics"
status 0 "$BIN" --version
status 0 "$BIN" --help
status 2 "$BIN" --definitely-not-an-option
status 2 "$BIN" --min-age banana /tmp
status 2 "$BIN" -e '(' "$WORK"
status 2 "$BIN" -j '*' "$WORK"
status 2 "$BIN" -m
out=$("$BIN" --version); [[ $out == dirsweep\ * ]] && pass "version string" || fail "version string"
out=$("$BIN" --no-default-junk -j '*.foo' --list-junk); eq "$out" '*.foo' "--no-default-junk --list-junk"

begin "banner"
out=$("$BIN" --banner); [[ $out == *'v4.0.0'* && $out == *'/_/'* ]] && pass "--banner prints the logo" || fail "--banner prints the logo"
out=$("$BIN" --no-config -d "$WORK" 2>&1); [[ $out != *'/_/'* ]] && pass "no banner when output is not a terminal" || fail "no banner when output is not a terminal"
out=$("$BIN" --no-config --banner -d "$WORK" 2>&1); [[ $out == *'v4.0.0'* ]] && pass "--banner wins" || fail "--banner wins"
status 0 "$BIN" --no-banner -V
printf 'banner = maybe\n' >"$WORK/b.conf"; status 2 "$BIN" --no-config -C "$WORK/b.conf" "$WORK"

# --------------------------------------------------------------- dry run
begin "dry run changes nothing and predicts the real run"
fresh
before=$(find "$T" | sort | md5sum)
ds -d "$T" >"$WORK/dry.out" 2>&1
eq "$(find "$T" | sort | md5sum)" "$before" "dry run left the tree untouched"
dry_dirs=$(grep -c '^would remove' "$WORK/dry.out")
ds -y "$T" >"$WORK/real.out" 2>&1
real_dirs=$(grep -c '^✓ removed' "$WORK/real.out")
eq "$dry_dirs" "$real_dirs" "dry-run count equals real-run count ($real_dirs)"

# ------------------------------------------------------------- real run
begin "real run: what goes and what stays"
for d in empty/single empty/nested/deep/very/deep empty/nested projects/abandoned old_builds \
         uploads junk/mac junk/win junk/vim junk/tmp junk/tilde junk chains/a/b/c/d/e chains/x \
         deep/a/b/c/empty_sibling 'weird/with space' 'weird/brackets[1]' 'weird/$dollar' \
         'weird/it'"'"'s quoted' weird/-dash-first 'weird/ünïcödé' 'weird/junk space'; do
    gone "$T/$d"
done
gone "$T/weird/new"$'\n'"line"
for f in project/src/main.c project/config/app.conf docs/reports/q3.txt deep/a/b/c/d/deep.txt \
         mixed/important_plus_junk/data.csv mixed/important_plus_junk/.DS_Store \
         mixed/important_plus_junk/output.log symlinks/link_to_dir symlinks/link_to_file \
         symlinks/real_target/file.txt; do
    has "$T/$f"
done
has "$T"
eq "$(cat "$T/project/src/main.c")" 'int main(void) { return 0; }' "file contents untouched"

begin "the target directory itself is never removed"
D="$WORK/onlyempties"; mkdir -p "$D/a/b/c"; T=$D
ds -y "$D" >/dev/null 2>&1
has "$D"; gone "$D/a"

# ---------------------------------------------------------------- strict
begin "--strict-empty leaves junk-only directories alone"
fresh
ds -y -s "$T" >/dev/null 2>&1
has "$T/junk/mac/.DS_Store"; has "$T/junk/tmp/output.log"
gone "$T/empty/single"; gone "$T/chains/a"

# ---------------------------------------------------------------- exclude
begin "exclusions"
fresh
ds -y -e 'cache,sessions' "$T" >/dev/null 2>&1
has "$T/cache/redis"; has "$T/cache/memcache"; has "$T/sessions/expired"; gone "$T/empty"
fresh
ds -y -e '^cache$' "$T" >/dev/null 2>&1
has "$T/cache/redis"; gone "$T/sessions"
fresh
mkdir -p "$T/mycache_dir/x"
ds -y -e 'mycache' "$T" >/dev/null 2>&1
has "$T/mycache_dir/x"
begin "exclusions are relative to the target, not the absolute path"
D="$WORK/cachehome"; mkdir -p "$D/proj/empty"; T=$D
ds -y -e '^proj$' "$D" >/dev/null 2>&1; has "$D/proj/empty"
ds -y -e 'cachehome' "$D/proj" >/dev/null 2>&1; gone "$D/proj/empty"

# ---------------------------------------------------------------- min-age
begin "--min-age"
fresh
ds -y --min-age 1 "$T" >/dev/null 2>&1
has "$T/age/fresh"; gone "$T/age/old_leaf"
gone "$T/age/chain"
has "$T/age"
fresh
ds -y --min-age 2h "$T" >/dev/null 2>&1; has "$T/age/fresh"
fresh
ds -y --min-age 0 "$T" >/dev/null 2>&1; gone "$T/age"

# ---------------------------------------------------------------- depth
begin "depth limits"
fresh
ds -y -n "$T" >/dev/null 2>&1
has "$T/empty/single"; has "$T/chains/a/b"
fresh
ds -y -m 2 "$T" >/dev/null 2>&1
gone "$T/empty/single"; has "$T/chains/a/b/c/d/e"

# ----------------------------------------------------------- junk patterns
begin "custom junk patterns"
fresh
mkdir -p "$T/custom"; : >"$T/custom/dump.sql"
ds -y "$T" >/dev/null 2>&1; has "$T/custom/dump.sql"
ds -y -j '*.sql' "$T" >/dev/null 2>&1; gone "$T/custom"
begin "risky names are not junk by default"
fresh
mkdir -p "$T/risky"; : >"$T/risky/yarn.lock"; : >"$T/risky/daemon.pid"; : >"$T/risky/core"
ds -y "$T" >/dev/null 2>&1; has "$T/risky/yarn.lock"; has "$T/risky/daemon.pid"; has "$T/risky/core"

# --------------------------------------------------------------- protected
begin "own log and report are never treated as junk"
D="$WORK/logdir"; mkdir -p "$D/sub"; T=$D
"$BIN" --no-config -y -l "$D/sub/run.log" --json "$D/sub/report.json" "$D" >/dev/null 2>&1
has "$D/sub/run.log"; has "$D/sub/report.json"

# ------------------------------------------------------------------ trash
begin "trash and restore round trip"
fresh
snap() { (cd "$T" && find . -printf '%p %y %m\n' | sort | md5sum); }
before=$(snap); mtime_before=$(stat -c %Y "$T/secret/mode700")
S="$WORK/session1"
ds -y -T "$S" "$T" >/dev/null 2>&1
gone "$T/empty"; gone "$T/junk"
has "$S/manifest"
ds --restore "$S" >/dev/null 2>&1
eq "$(snap)" "$before" "tree identical after restore (names, types, modes)"
eq "$(stat -c %a "$T/secret/mode700")" 700 "mode 700 restored"
eq "$(stat -c %Y "$T/secret/mode700")" "$mtime_before" "mtime restored"
has "$T/junk/mac/.DS_Store"
ds --restore "$S" >/dev/null 2>&1; eq "$?" 0 "second restore is harmless"
eq "$(snap)" "$before" "tree unchanged after second restore"

begin "--undo finds the latest session"
fresh
before=$(snap)
ds -y -t "$T" >/dev/null 2>&1
gone "$T/empty"
ds --undo >/dev/null 2>&1
eq "$(snap)" "$before" "tree identical after --undo"
status 1 "$BIN" --no-config --undo

begin "restore never overwrites newer data"
fresh
S="$WORK/session2"
ds -y -T "$S" "$T" >/dev/null 2>&1
mkdir -p "$T/junk"; echo mine >"$T/junk/win"
ds --restore "$S" >/dev/null 2>&1; eq "$?" 1 "restore reports the conflict"
eq "$(cat "$T/junk/win")" mine "conflicting file untouched"

begin "trash directory inside the target is refused"
fresh
status 2 "$BIN" --no-config -y -T "$T/trash" "$T"

# ------------------------------------------------------------------- json
begin "json report"
fresh
ds -y --json "$WORK/r.json" "$T" >/dev/null 2>&1
if command -v python3 >/dev/null; then
    python3 -m json.tool "$WORK/r.json" >/dev/null 2>&1 && pass "valid JSON" || fail "valid JSON"
    n=$(python3 -c "import json;d=json.load(open('$WORK/r.json'));print(d['stats']['removed_dirs'], len(d['removed_dirs']), d['stats']['errors'], d['dry_run'])")
    read -r a b c d <<<"$n"; eq "$a" "$b" "stats match listed directories"; eq "$c" 0 "no errors recorded"; eq "$d" False "dry_run flag"
    python3 -c "import json;d=json.load(open('$WORK/r.json'));assert any('\n' in p for p in d['removed_dirs'])" 2>/dev/null \
        && pass "newline in path escaped correctly" || fail "newline in path escaped correctly"
else
    skip_t "json (python3 not available)"
fi

# ----------------------------------------------------------------- config
begin "config file"
fresh
cat >"$WORK/c.conf" <<CONF
# comment
path = $T
exclude = cache
min_age = 1
junk = *.sql
CONF
mkdir -p "$T/custom"; : >"$T/custom/a.sql"; touch -d "30 days ago" "$T/custom"
ds -y -C "$WORK/c.conf" >/dev/null 2>&1
has "$T/cache/redis"; has "$T/age/fresh"; gone "$T/custom"
begin "config is data, never code"
printf 'path = $(touch %s/pwned)\nexclude = `touch %s/pwned2`\n' "$WORK" "$WORK" >"$WORK/evil.conf"
ds -d -C "$WORK/evil.conf" >/dev/null 2>&1
[[ ! -e $WORK/pwned && ! -e $WORK/pwned2 ]] && pass "nothing executed" || fail "config executed code"
printf 'nonsense = 1\n' >"$WORK/bad.conf"; status 2 "$BIN" --no-config -C "$WORK/bad.conf" "$WORK"
begin "CLI overrides config"
fresh
printf 'dry_run = true\n' >"$WORK/dry.conf"
ds -C "$WORK/dry.conf" -d "$T" >/dev/null 2>&1; has "$T/empty/single"

# ----------------------------------------------------------------- safety
begin "refusals"
status 2 "$BIN" --no-config -d /
status 2 "$BIN" --no-config -d /etc
status 2 "$BIN" --no-config -d /usr/share
status 2 "$BIN" --no-config -d "$WORK/does-not-exist"
fresh
begin "no silent deletion without --yes"
status 2 "$BIN" --no-config -l "$LOG" "$T" </dev/null
has "$T/empty/single"
status 2 "$BIN" --no-config -q -l "$LOG" "$T"

begin "symlinks are never followed by default"
D="$WORK/lnk"; mkdir -p "$D/real/inside" "$D/scan"; ln -s "$D/real" "$D/scan/link"; T=$D
ds -y "$D/scan" >/dev/null 2>&1
has "$D/real/inside"; has "$D/scan/link"

begin "several targets"
D="$WORK/multi"; mkdir -p "$D/a/x" "$D/b/y"; T=$D
ds -y "$D/a" "$D/b" >/dev/null 2>&1; gone "$D/a/x"; gone "$D/b/y"; has "$D/a"; has "$D/b"

begin "combined short flags and --opt=value"
fresh
ds -dv --min-age=1 "$T" >"$WORK/o.out" 2>&1; eq "$?" 0 "-dv --min-age=1 parses"
has "$T/empty/single"

begin "permissions"
if (( EUID == 0 )); then
    skip_t "read-only parent (root ignores permissions; CI runs this as a normal user)"
else
    fresh
    ds -y "$T" >/dev/null 2>&1
    has "$T/locked/readonly_parent/empty_child"
    out=$(ds -d -v "$T" 2>&1)
    [[ $out == *'skipped (no permission)'* ]] && pass "reason reported" || fail "reason reported"
fi

# ---------------------------------------------------------------- summary
printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
(( FAIL == 0 ))
