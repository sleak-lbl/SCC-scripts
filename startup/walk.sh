#!/bin/bash

# read lines from a file, give user the chance to edit each
# and then execute it:
_verbose=0
if [[ "$1" == "-v" ]] ; then
  _verbose=1
  shift
fi

while IFS='' read -r line || [[ -n "$line" ]]; do
    # skip blank lines
    [[ -z "$line" ]] && continue
    _m='^\s*#'
    if [[ "$line" =~ $_m ]] ; then
        echo -e "$line"
        continue
    fi
    # do variable expansion so it is explicit what will be run
    # (to avoid "forgot to set the variable, overwrote the wrong thing"
    # type errors):
    expline=$(envsubst <<< "$line")
    # 'read' seems to clear escape characters, so replace each with 
    # two (to escape the escape char): 
    escapes=$(sed -e 's/\\/\\\\/g' <<< "$expline")

    fail=1
    while (( $fail )) ; do 
        # give the user a chance to edit (or delete) the command:
        read -i "$escapes" -e cmd < /dev/tty
        # print what will actually get run:
        (( $_verbose )) && echo -e "$cmd"
        # run what remains:
        eval $cmd
        fail=$?
        (( $fail )) && echo "failed - try again?"
    done
done < "$1"

