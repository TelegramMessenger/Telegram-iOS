_x264()
{
    local path args cur prev

    path="${COMP_LINE%%[[:blank:]]*}"
    args="${COMP_LINE:${#path}:$((COMP_POINT-${#path}))}"
    cur="${args##*[[:blank:]=]}"
    prev="$(sed 's/[[:blank:]=]*$//; s/^.*[[:blank:]]//' <<< "${args%%"$cur"}")"

    # Expand ~
    printf -v path '%q' "$path" && eval path="${path/#'\~'/'~'}"

    COMPREPLY=($("$path" --autocomplete "$prev" "$cur")) && compopt +o default
} 2>/dev/null
complete -o default -F _x264 x264
