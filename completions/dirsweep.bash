# bash completion for dirsweep
_dirsweep() {
    local cur prev
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    case $prev in
        -p|--path|-T|--trash-dir|--restore|-l|--log|-C|--config|--json)
            mapfile -t COMPREPLY < <(compgen -f -- "$cur"); return ;;
        -e|--exclude|--exceptions|-j|--junk|--junk-patterns|-m|--max-depth|--min-age)
            return ;;
    esac

    if [[ $cur == -* ]]; then
        local opts="-p --path -n --no-subdirs -m --max-depth -s --strict-empty
            -e --exclude -j --junk --no-default-junk --list-junk --min-age
            -x --cross-filesystems -f --follow-symlinks -d --dry-run
            -i --interactive -y --yes -t --trash -T --trash-dir --undo --restore
            -v --verbose -q --quiet --progress --banner --no-banner --no-color --json -l --log
            -C --config --no-config -V --version -h --help"
        mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
    else
        mapfile -t COMPREPLY < <(compgen -d -- "$cur")
    fi
}
complete -o filenames -F _dirsweep dirsweep
