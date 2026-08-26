# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/). The repo
contains shell configuration, scripts, Git/SSH/editor configuration, encrypted
private config, and a small Ansible bootstrap for package setup.

> Looking for shared team setup? That lives in the team dotfiles repository.

## Supported Systems

- Debian-based Linux on `x86_64`
- macOS on Apple Silicon (`arm64`)

Other systems may work for individual dotfiles, but the bootstrap playbook
explicitly supports only those two combinations.

## First Setup

Install the minimum tooling first:

- Linux: install `chezmoi` and `rbw`
- macOS: install Homebrew, then `brew install chezmoi rbw`

Then initialize:

```bash
chezmoi init --apply NGallmann/dotfiles
```

## Encryption

Private files are stored as age-encrypted `*.age` files. Chezmoi needs an age
identity key at:

```text
$HOME/.config/chezmoi/age_identity_key.txt
```

One common workflow is to retrieve that key from your password manager with
`rbw`, write it to the path above, and lock down permissions:

```bash
mkdir -p "$HOME/.config/chezmoi"
rbw login
rbw get "<entry-name-or-id>" --raw | jq -r '.data.password' > "$HOME/.config/chezmoi/age_identity_key.txt"
chmod 600 "$HOME/.config/chezmoi/age_identity_key.txt"
```

Do not commit decrypted secrets. Decrypted helper files in this repo keep the
`encrypted_` prefix, insert `_decrypted` before the extension, and are ignored
by Git.

## Decrypted Symlinks

Encrypted files have local decrypted companions that point to the real target in
`$HOME`. For example:

```text
dot_zshrc.d/encrypted_05_work.zsh.age
dot_zshrc.d/encrypted_05_work_decrypted.zsh -> $HOME/.zshrc.d/05_work.zsh
```

This makes sensitive files easy to edit while keeping plaintext out of the
repository. When changing a decrypted target, re-encrypt it intentionally with
the `chezmoi add --encrypt ...` command shown in the file, if the file format can
carry comments.

## Bootstrap With Ansible

After chezmoi applies files, `run_onchange_exec_ansible.sh.tmpl` runs when the
bootstrap files change. It installs or verifies Ansible dependencies, installs
Galaxy requirements from:

```text
~/.config/bootstrap/requirements.yaml
```

and then runs:

```bash
ansible-playbook "$HOME/.config/bootstrap/main.yaml"
```

On Linux it uses `apt-get` for the initial Ansible install and asks for become
permissions. On macOS it expects Homebrew to already exist.

The playbook in `dot_config/bootstrap/` installs common CLI tools, shell
utilities, editor tooling, and platform-specific packages.

## Useful Commands

Inspect pending changes:

```bash
git status --short --ignored
git diff
```

Apply dotfiles:

```bash
chezmoi apply
```

Edit a managed file:

```bash
chezmoi edit <target-path>
```

Re-encrypt a changed private file:

```bash
chezmoi add --encrypt <target-path>
```

Install and run pre-commit checks:

```bash
pre-commit install
pre-commit run --all-files
```

## Safety Notes

- Keep secrets, personal data, employer names, internal hosts, tokens,
  certificates, and private keys out of plaintext Git history.
- Decrypted symlinks must stay ignored and must never be committed.
- Avoid adding machine-local or work-specific values to unencrypted files.
- Review `git status --short --ignored` before committing.
