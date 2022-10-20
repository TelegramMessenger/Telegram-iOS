#!/bin/sh

# Output a Makefile rule describing the dependencies of a given source file.
# Expected arguments are $(CC) $(CFLAGS) $(SRC) $(OBJ)

set -f

[ -n "$1" ] && [ -n "$3" ] && [ -n "$4" ] || exit 1

# Add flags to only perform syntax checking and output a list of included files
# Discard all output other than included files
# Convert '\' directory separators to '/'
# Remove system includes (hack: check for "/Program Files" string in path)
# Add the source file itself as a dependency
deps="$($1 $2 -nologo -showIncludes -W0 -Zs "$3" 2>&1 |
        grep '^Note: including file:' |
        sed 's/^Note: including file:[[:space:]]*\(.*\)$/\1/; s/\\/\//g' |
        sed '/\/[Pp]rogram [Ff]iles/d')
$3"

# Convert Windows paths to Unix paths if possible
if command -v cygpath >/dev/null 2>&1 ; then
    IFS='
'
    deps="$(cygpath -u -- $deps)"
elif grep -q 'Microsoft' /proc/sys/kernel/osrelease 2>/dev/null ; then
    # Running under WSL. We don't have access to cygpath but since the Windows
    # file system resides under "/mnt/<drive_letter>/" we can simply replace
    # "C:" with "/mnt/c". This command uses a GNU extension to sed but that's
    # available on WSL so we don't need to limit ourselves by what POSIX says.
    deps="$(printf '%s' "$deps" | sed 's/^\([a-zA-Z]\):/\/mnt\/\L\1/')"
fi

# Escape characters as required to create valid Makefile file names
escape() {
    sed 's/ /\\ /g; s/#/\\#/g; s/\$/\$\$/g'
}

# Remove prefixes that are equal to the working directory
# Sort and remove duplicate entries
# Escape and collapse the dependencies into one line
deps="$(printf '%s' "$deps" |
        sed "s/^$(pwd | sed 's/\//\\\//g')\///; s/^\.\///" |
        sort | uniq |
        escape | tr -s '\n\r' ' ' | sed 's/^ *\(.*\) $/\1/')"

# Escape the target file name as well
target="$(printf '%s' "$4" | escape)"

printf '%s: %s\n' "$target" "$deps"
