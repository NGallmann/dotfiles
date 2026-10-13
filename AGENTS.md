# AGENTS.md

This repository is a personal chezmoi source tree for managing dotfiles and
machine bootstrap configuration. Treat it as sensitive by default.

## Purpose

- Manage shell, Git, SSH, editor, credential-helper, VPN, and tool
  configuration through chezmoi.
- Bootstrap supported machines with Ansible after chezmoi applies the source
  tree.
- Install Pi only through the managed installer in the bootstrap. Do not commit
  Pi settings, models, extension source, or sandbox config. Those live in
  pi-setup.
- Clone pi-setup with `git-mgmt clone` from the encrypted URL and link
  `scripts/pi` ahead of the managed launcher.
- Keep this source checkout at `~/git/private/github.com/NGallmann/dotfiles`.
  `github.com/NGallmann` is private. Do not clone it into `~/.local/share/chezmoi`.
- Keep encrypted private configuration in the repository while keeping
  decrypted files outside Git.

## Structure

- `dot_*`, `private_*`, and `executable_*` paths follow chezmoi source-state
  naming.
- `dot_zshrc.d/` contains zsh startup fragments.
- `dot_scripts/` contains user scripts that chezmoi installs into `~/.scripts`.
- `dot_config/bootstrap/` contains the Ansible bootstrap playbook, task files,
  and Galaxy requirements.
- `run_onchange_exec_ansible.sh.tmpl` installs Ansible when needed and runs the
  bootstrap playbook after relevant bootstrap files change.
- `run_after_chezmoi_mgmt.sh.tmpl` creates ignored decrypted-helper symlinks
  after chezmoi applies files, only when the decrypted target exists.
- `*.age` files are age-encrypted files managed by chezmoi.

## Sensitive Data Rules

This tree is published on public GitHub. Keep private material in age files.
Before commit or push, reject new plaintext that identifies private
infrastructure, people, or accounts. Leave plaintext that is already tracked
as it is unless the user asks to change it, and do not copy it into other
files, commit messages, or docs.

Before finishing changes, inspect the tracked diff with:

```bash
git status --short --ignored
git diff --cached
git diff
pre-commit run --all-files
```

If decrypted files are present, they must remain ignored. They should appear as
`!! ...decrypted...` in `git status --short --ignored`, not as tracked or staged
files.

## Encrypted File Workflow

Encrypted files use an ignored symlink next to the encrypted source file so the
plaintext target in `$HOME` can be edited naturally.

Example pattern:

```text
dot_zshrc.d/encrypted_05_work.zsh.age
dot_zshrc.d/encrypted_05_work_decrypted.zsh -> $HOME/.zshrc.d/05_work.zsh
```

Use the same pattern for other encrypted files:

- The repository stores only the `.age` file.
- The decrypted companion is a symlink to the real target under `$HOME`.
- The symlink name must keep the `encrypted_` prefix and insert `_decrypted`
  before the extension so existing ignore rules prevent it from being checked in.
- Add or update the matching guarded `test -f ... && ln -sf ...` entry in
  `run_after_chezmoi_mgmt.sh.tmpl` so chezmoi recreates the helper symlink after
  apply. Do not rely on only creating the symlink manually.
- Before adding helper symlinks, check `.chezmoiignore`. If the encrypted source
  path is platform-specific, mirror the same platform guard in
  `run_after_chezmoi_mgmt.sh.tmpl` so Linux-only and Darwin-only helpers are not
  created on the wrong OS.
- Do not commit decrypted symlinks or decrypted plaintext.
- Do not re-encrypt changed plaintext unless the user explicitly asks. If a
  decrypted target was changed, report that re-encryption is still needed.
- Decrypted files should contain a short reminder comment with the matching
  `chezmoi add --encrypt ...` command when the file format safely supports
  comments. Do not add comments to strict formats such as JSON, certificates, or
  key material.

## Ansible Bootstrap

Ansible is part of the chezmoi apply flow:

- `run_onchange_exec_ansible.sh.tmpl` is a chezmoi run-on-change script.
- It hashes the bootstrap files so updates to the playbook or requirements
  rerun the bootstrap.
- On Debian/x86_64 it installs Ansible with `apt-get`, installs Galaxy
  requirements, then runs `~/.config/bootstrap/main.yaml` with become prompting.
- On Darwin/arm64 it expects Homebrew, installs Galaxy requirements, then runs
  the same playbook.
- The playbook currently supports Debian/x86_64 and Darwin/arm64 only.

When editing bootstrap behavior, keep changes small and verify YAML syntax where
possible. Avoid adding employer-specific package sources, internal URLs, or
private credentials to the playbook.

Generated Ansible state and caches, such as `.ansible/`, must stay ignored and
out of commits.

## Pre-Commit

This repository uses pre-commit for basic hygiene and safety checks:

- Community hooks handle whitespace, final newlines, YAML syntax, merge
  conflicts, private-key detection, large files, and executable shebangs.
- Local hooks run `shellcheck` for bash scripts/templates and `yamllint` for
  YAML files.
- Local safety hooks verify that `*.age` files are age-armored, that
  `_decrypted` helper files are not tracked, and that newly added lines do not
  contain LAN addresses.
- Some hooks auto-fix files. After running pre-commit, review the diff and do
  not keep unrelated formatting churn unless it is intentional.

Run:

```bash
pre-commit run --all-files
```

## Change Discipline

- Keep changes surgical and aligned with existing chezmoi naming conventions.
- Do not modify encrypted `.age` files unless explicitly requested.
- Do not remove unrelated ignored symlinks or user-local files.
- Preserve executable bits for scripts under `dot_scripts/executable_*`.
- Keep `.pre-commit-config.yaml` focused on checks that work for a chezmoi
  source tree: generic hygiene, shell/YAML linting, age-file sanity, and
  preventing tracked decrypted files.
- Prefer `rg`, `find`, `git status`, and `git diff` for inspection.
