#!/bin/zsh

# drop any missing links
find "$HOME/.local/share/zinit/completions" -type l ! -exec test -e {} \; -delete

# load all the fancy completions
(update_bin_completion rbw gen-completions zsh > /dev/null 2>&1 &)
(update_bin_completion tkn completion zsh > /dev/null 2>&1 &)
(update_bin_completion k3d completion zsh > /dev/null 2>&1 &)
(update_bin_completion podman completion zsh > /dev/null 2>&1 &)
(update_bin_completion kube-bench completion zsh > /dev/null 2>&1 &)
(update_bin_completion pv-migrate completion zsh > /dev/null 2>&1 &)
(update_bin_completion chezmoi completion zsh > /dev/null 2>&1 &)
(update_bin_completion kubectl completion zsh > /dev/null 2>&1 &)
(update_bin_completion helm completion zsh > /dev/null 2>&1 &)
(update_bin_completion helmfile completion zsh > /dev/null 2>&1 &)
(update_bin_completion helm_ls completion zsh > /dev/null 2>&1 &)
(update_bin_completion rbw gen-completions zsh > /dev/null 2>&1 &)
(update_bin_completion openshell completions zsh > /dev/null 2>&1 &)

# adding az completion
command -v az >/dev/null 2>&1 && \
    {export AZURE_OUTPUT=yamlc
    test -r /etc/bash_completion.d/azure-cli && \
        source /etc/bash_completion.d/azure-cli; }

# at the very end ..
unfunction int_extend_path
unfunction update_bin_completion
unset internet_access

# should be executed atthe end of rc
autoload -Uz compinit
compinit

# Added by p10k for quick launch of shell
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
