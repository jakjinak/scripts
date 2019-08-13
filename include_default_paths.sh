#!/usr/bin/env bash

help()
{ cat << END_OF_BLOCK
Prints the default include paths for given compiler.
Give "gcc" or "g++" (or full path to those) as argument.
END_OF_BLOCK
  exit
}

d=0
case "$1" in
  -h|--help) help ;;
  */gcc) pn=cc1 ; d=1 ;;
  */g++) pn=cc1plus ; d=1 ;;
  gcc) pn=cc1 ;;
  g++) pn=cc1plus ;;
  *) echo "Invalid argument '$1'." ; exit 1 ;;
esac

if [ $d -eq 1 ]
then
  [ -x "$1" ] || {
    echo "'$1' does not exist."
    exit 1
  }
fi

echo | $("$1" -print-prog-name=$pn) -v 2>&1 | perl -e '
    $in=0;
    while (<STDIN>)
    { $in=1 if /^#include.*starts here/;
      $in=0 if /^End of search list/;
      next if /^(#include.*starts here|End of search list)/;
      s/^\s+//;
      print "\t$_" if $in == 1;
    }'
[ -r gccdump.s ] && rm gccdump.s
