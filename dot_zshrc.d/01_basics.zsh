#!/bin/zsh
# - functions to load
# - ZSH basic options
# - ENVs to set

ZDEBUG="${ZDEBUG:-"false"}"

# if employeer-proxy; settings need to be set first
test -f /etc/profile.d/10_proxy_settings.sh && \
    source /etc/profile.d/10_proxy_settings.sh

internet_access=true; timeout 1 curl https://ipinfo.io/ip >/dev/null 2>&1 || internet_access=false

# reminder 'sh -c "$(curl -fsLS get.chezmoi.io/lb)"'

# Script sourcing check
test -z "$PS1" \
	&& echo -e "This script \033[00;31mshould be sourced\033[0m not executed" && exit 1

source "$(dirname "$0")/00_functions.zsh"

# some history configurations
export HISTFILE=~/.zsh_history # Where it gets saved
export HISTSIZE=1000000
export SAVEHIST=1000000
# share_history already appends each command and reads other shells.
# A second append option is a second writer.
unsetopt append_history
unsetopt inc_append_history
setopt share_history
# zsh 5.9 drops its fcntl lock when savehistfile() closes the history fd,
# and this option disables the symlink lock. Concurrent writes then leave
# a run of NUL bytes. readhistline() stops there ("corrupt history file").
unsetopt hist_fcntl_lock
setopt hist_save_by_copy # rewrite a temp file, then rename over HISTFILE
setopt hist_expire_dups_first # Expire duplicate entries first when trimming history.
setopt hist_ignore_all_dups # Delete old recorded entry if new entry is a duplicate.
setopt hist_lex_words # better word splitting, but more CPU heavy
setopt hist_reduce_blanks # Remove superfluous blanks before recording entry.
setopt hist_save_no_dups # Don't write duplicate entries in the history file.
setopt HIST_IGNORE_SPACE # Don't record an entry starting with a space.
export ZSH_COMPDUMP=$ZSH/.cache/zcompdump-$HOST

# unmanaged bin dir in .local/bin
int_extend_path "$HOME/.local/bin:$PATH" "true"

# default editor
command -v code >/dev/null 2>&1 && \
	export EDITOR="code -w" || \
    export EDITOR="vi"
command -v codium >/dev/null 2>&1 && \
	export EDITOR="codium -w" || \
    export EDITOR="vi"
command -v kubectl >/dev/null 2>&1 && \
	export KUBE_EDITOR="$EDITOR"

# adding some bin paths for terraform/terragrunt
# see https://github.com/tfutils/tfenv and https://github.com/tgenv/tgenv
int_extend_path "$HOME/.tfenv/bin" "true"
int_extend_path "$HOME/.tgenv/bin" "true"
int_extend_path "${KREW_ROOT:-$HOME/.krew}/bin" "true"
int_extend_path "$HOME/.local/bin" "true"

# setting go-stuff
mkdir -p "$HOME/.golib"
export GOPATH="$HOME/.golib"
int_extend_path "$GOPATH/bin"

# adding SSH keys
#add_ssh_id "$HOME/.ssh/id_rsa"
#add_ssh_id "$HOME/.ssh/id_ed25519"

# added because Tilix is asking for:
# https://gnunn1.github.io/tilix-web/manual/vteconfig/
if [ $TILIX_ID ] || [ $VTE_VERSION ]; then
        test -f /etc/profile.d/vte.sh && \
            source /etc/profile.d/vte.sh
fi
