# Autoload functions from functions/ — one function per file, named after the file.
# Autoload is lazy: the body is read on first call.

fpath=("$ZDOTDIR/functions" $fpath)
[[ -d "$ZDOTDIR/functions" ]] && autoload -Uz "$ZDOTDIR"/functions/*(N:t)
