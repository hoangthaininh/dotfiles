# Core shell behavior.

# Directory navigation: `dirs -v` lists the stack, `cd -<Tab>` jumps.
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

setopt EXTENDED_GLOB           # ^, ~, (#q...) qualifiers
setopt INTERACTIVE_COMMENTS    # allow # comments on the command line
setopt NUMERIC_GLOB_SORT       # sort globs numerically (2 before 10)

setopt NO_BEEP
setopt NO_FLOW_CONTROL         # free up Ctrl-S / Ctrl-Q
setopt NO_NOMATCH              # leave unmatched globs as-is instead of erroring
setopt LONG_LIST_JOBS
