setPSUUU()
{ PSUUU=`cols=$( [ "$TERM" -a "$TERM" != dumb ] && tput cols || echo 1) ; ((cols--)) ; i=0; while ((i<cols)) ; do echo -n $'\u2581' ; ((i++)) ; done`
}

trap setPSUUU WINCH
setPSUUU
PS1='\e[1;3${PSCOLOR}m$PSUUU\e[0m\n\[\e[30;10${PSCOLOR}m\]$?\[\e[49;31m\] \t \[\e[32m\]\u@\h \[\e[33m\]\w \[\e[1;36m\][$(MYPROMPTFUN)]\[\e[0m\]\n\[\e[30;10${PSCOLOR}m\]>\[\e[0m\]'
PS2='>'
