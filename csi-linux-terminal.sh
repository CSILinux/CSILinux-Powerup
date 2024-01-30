#!/bin/bash

echo "Installing dependencies..."

sudo apt install -y \
    bash-completion boxes tree fonts-cascadia-code fonts-firacode

# ------------------------------------------

echo "Updating terminal settings..."

tmp=$(mktemp)

cat <<EOF > ${tmp}
[org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9]
background-color='rgb(29,29,29)'
cursor-blink-mode='on'
cursor-shape='ibeam'
default-size-columns=120
default-size-rows=30
font='Fira Code 11'
foreground-color='rgb(255,255,255)'
palette=['rgb(46,52,54)', 'rgb(204,0,0)', 'rgb(78,154,6)', 'rgb(196,160,0)', 'rgb(52,101,164)', 'rgb(117,80,123)', 'rgb(6,152,154)', 'rgb(211,215,207)', 'rgb(85,87,83)', 'rgb(239,41,41)', 'rgb(138,226,52)', 'rgb(252,233,79)', 'rgb(114,159,207)', 'rgb(173,127,168)', 'rgb(52,226,226)', 'rgb(238,238,236)']
scrollback-unlimited=true
use-system-font=false
use-theme-colors=false
EOF

dconf load -f / < ${tmp} || exit 1

# ------------------------------------------

if ! grep 'PROMPT_COMMAND' ~/.bashrc &> /dev/null ; then

echo "Updating bash prompt..."

tmp=$(mktemp)

cat <<EOF > ${tmp}

PROMPT_COMMAND=__prompt_command

__prompt_command() {

    local EXIT="\$?"             # This needs to be first
		
    local NoCol='\[\e[0m\]'
    
    local BoldOff='\[\$(tput sgr0)\]'
    
    local Red='\[\033[38;5;9m\]'
	
    local Green='\[\033[38;5;10m\]'
   
    local Yellow='\[\033[38;5;11m\]'

    local Blue='\[\033[38;5;12m\]'

    local Magenta='\[\033[38;5;13m\]'

    local Cyan='\[\033[38;5;14m\]'
    
    local Silver='\[\033[38;5;145m\]'
    
    local Gold='\[\033[38;5;179m\]'
    
    PS1="\n\${BoldOff}"
    
    PS1+="\${Gold}\T\${NoCol}"
    
    PS1+=" \${Yellow}\u@\h\${NoCol}"
    
    PS1+=" \${Cyan}\w\${NoCol}"

    PS1+="\n"
     
    if [ \$EXIT != 0 ]; then
        PS1+="\${Red}"
    else
        PS1+="\${Green}"
    fi
    
    PS1+="â¯ \${NoCol}" # â¯ âžœ âš¡
    
    export PS1
}

EOF

cat ${tmp} >> ~/.bashrc

fi

# ------------------------------------------

echo "Done. Restart the terminal to reload changes." | boxes -d stone -p l2r2
