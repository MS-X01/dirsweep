#!/usr/bin/env bash
#
# Build a throwaway directory tree that exercises every rule in dirsweep.
#
#   tests/make_test_env.sh [DIR]        (default: /tmp/dirsweep_test)
#
# Author: Mohammad Sadra Naderi (ZVitoX)
set -euo pipefail

BASE="${1:-/tmp/dirsweep_test}"
MARKER=".dirsweep-testenv"

if [[ -t 1 ]]; then B=$'\e[1m' G=$'\e[32m' D=$'\e[2m' Y=$'\e[33m' R=$'\e[0m'; else B='' G='' D='' Y='' R=''; fi
section() { printf '\n%s%s%s\n' "$B$G" "$*" "$R"; }
note()    { printf '  %s%s%s\n' "$D" "$*" "$R"; }

# Never wipe a directory we did not create ourselves.
if [[ -e $BASE ]]; then
    if [[ -f $BASE/$MARKER ]]; then
        chmod -R u+rwx "$BASE" 2>/dev/null || true
        rm -rf -- "$BASE"
    else
        echo "refusing to reuse '$BASE': it exists and was not created by this script" >&2
        exit 1
    fi
fi
mkdir -p -- "$BASE"
: >"$BASE/$MARKER"

mk()   { mkdir -p -- "$BASE/$1"; }
put()  { mkdir -p -- "$(dirname -- "$BASE/$1")"; printf '%s\n' "${2:-data}" >"$BASE/$1"; }
junk() { mkdir -p -- "$(dirname -- "$BASE/$1")"; : >"$BASE/$1"; }
old()  { touch -d '30 days ago' -- "$BASE/$1"; }

section "1. empty directories (removed)"
for d in empty/single empty/nested/deep/very/deep empty/nested/sibling \
         projects/abandoned/v1 projects/abandoned/v2 old_builds/2021/jan \
         old_builds/2022/mar uploads/queue/pending uploads/queue/processing; do
    mk "$d"
done
note "9 leaf directories, several with empty parents"

section "2. junk-only directories (removed)"
junk junk/mac/.DS_Store;      junk junk/mac/._.DS_Store
junk junk/win/Thumbs.db;      junk junk/win/desktop.ini
junk junk/vim/notes.swp;      junk junk/vim/draft.swo;  junk 'junk/vim/#autosave#'
junk junk/tmp/output.log;     junk junk/tmp/run.tmp;    junk junk/tmp/backup.bak
junk junk/tilde/main.c~;      junk junk/tilde/config.py~
note "mac, win, vim, tmp, tilde"

section "3. real content (kept)"
put project/src/main.c 'int main(void) { return 0; }'
put project/config/app.conf 'port=8080'
put docs/reports/q3.txt 'Q3'
put mixed/important_plus_junk/data.csv 'critical'
junk mixed/important_plus_junk/.DS_Store
junk mixed/important_plus_junk/output.log
put deep/a/b/c/d/deep.txt 'deep'
mk deep/a/b/c/empty_sibling
note "mixed/important_plus_junk keeps its junk: real data sits next to it"

section "4. symlinks (never followed, never removed)"
put symlinks/real_target/file.txt 'real'
ln -s "$BASE/symlinks/real_target" "$BASE/symlinks/link_to_dir"
ln -s "$BASE/symlinks/real_target/file.txt" "$BASE/symlinks/link_to_file"

section "5. age (--min-age 1)"
mk age/fresh
mk age/chain/a/b/c
touch -d '30 days ago' -- "$BASE/age/chain/a/b/c" "$BASE/age/chain/a/b" \
                          "$BASE/age/chain/a" "$BASE/age/chain"
mk age/old_leaf; old age/old_leaf
note "age/chain is 4 levels deep and all old: the whole chain must go in one run"

section "6. exclusions (-e cache)"
mk cache/redis; mk cache/memcache; mk sessions/expired
note "cache/* and sessions/expired are empty but skipped when excluded"

section "7. nested chains"
mk chains/a/b/c/d/e; mk chains/x/y/z

section "8. awkward names"
mk 'weird/with space/inner dir'
mk $'weird/new\nline'
mk "weird/it's quoted"
mk 'weird/brackets[1]'
mk 'weird/$dollar'
mk 'weird/-dash-first'
mk 'weird/ünïcödé/дир'
junk 'weird/junk space/a b.log'

section "9. permissions"
put locked/readonly_parent/keep.txt 'x'
mk locked/readonly_parent/empty_child
chmod 555 "$BASE/locked/readonly_parent"
mk secret/mode700; chmod 700 "$BASE/secret/mode700"
note "empty_child lives in a read-only parent (skipped); mode700 must survive an undo"

total_dirs=$(find "$BASE" -type d | wc -l)
total_files=$(find "$BASE" -type f | wc -l)
total_links=$(find "$BASE" -type l | wc -l)
printf '\n%sTest tree ready:%s %s\n' "$B" "$R" "$BASE"
printf '  %d directories, %d files, %d symlinks\n\n' "$total_dirs" "$total_files" "$total_links"
printf '%sTry:%s\n' "$B" "$R"
printf '  bin/dirsweep -d -v %q\n' "$BASE"
printf '  bin/dirsweep -t -y %q && bin/dirsweep --undo\n' "$BASE"
printf '  bin/dirsweep -d -e %q --min-age 1 %q\n' 'cache,sessions' "$BASE"
printf '  bin/dirsweep -d -s %q\n' "$BASE"
printf '  bin/dirsweep -d --json /tmp/report.json %q && cat /tmp/report.json\n' "$BASE"
printf '\n%sRe-run this script to reset the tree.%s\n' "$Y" "$R"
