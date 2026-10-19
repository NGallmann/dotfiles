#!/bin/sh
# copy from https://github.com/doy/rbw/blob/main/bin/git-credential-rbw
# Extended with an agent escape hatch: when rbw is missing/locked, use
# GH_TOKEN/GITHUB_TOKEN or GITLAB_TOKEN/GLAB_TOKEN instead of calling rbw.
set -f

[ "$1" = get ] || exit

while read -r line; do
	case $line in
		protocol=*)
			protocol=${line#*=} ;;
		host=*)
			host=${line#*=} ;;
		username=*)
			user=${line#*=} ;;
	esac
done

rbw_usable() {
	command -v rbw >/dev/null 2>&1 || return 1
	rbw unlocked >/dev/null 2>&1
}

emit_token_credentials() {
	default_user=$1
	token=$2
	printf 'username=%s\n' "${user:-$default_user}"
	printf 'password=%s\n' "$token"
}

# Host heuristics for well-known token env vars.
case $host in
	*github.com*)
		kind=github
		default_user=x-access-token
		;;
	*gitlab.*|*git.intern.*)
		kind=gitlab
		default_user=oauth2
		;;
	*)
		kind=
		default_user=git
		;;
esac

if [ "$kind" = github ]; then
	if [ -n "${GH_TOKEN:-}" ]; then
		env_token=$GH_TOKEN
	elif [ -n "${GITHUB_TOKEN:-}" ]; then
		env_token=$GITHUB_TOKEN
	else
		env_token=
	fi
	hint='Set GH_TOKEN or GITHUB_TOKEN, or run: rbw unlock'
elif [ "$kind" = gitlab ]; then
	if [ -n "${GITLAB_TOKEN:-}" ]; then
		env_token=$GITLAB_TOKEN
	elif [ -n "${GLAB_TOKEN:-}" ]; then
		env_token=$GLAB_TOKEN
	else
		env_token=
	fi
	hint='Set GITLAB_TOKEN or GLAB_TOKEN, or run: rbw unlock'
else
	env_token=
	hint='Unlock rbw (rbw unlock) or set a matching token env var'
fi

# Prefer unlocked rbw for interactive use. Fall back to env tokens for agents.
if rbw_usable; then
	output=
	#shellcheck disable=2154
	for arg in \
		"$host" \
		"${protocol:+$protocol://}$host" \
		"$host" \
		"${host2=${host%.*}}" \
		"${host2#*.}"
	do
		# exit on first good result
		[ -n "$user" ] && output=$(rbw get --full "$arg" "$user") && break
		output=$(rbw get --full "$arg") && break
	done || {
		if [ -n "$env_token" ]; then
			echo "Using env token for $host (rbw lookup failed)" >&2
			emit_token_credentials "$default_user" "$env_token"
			exit 0
		fi
		echo "git-credential-rbw: rbw lookup failed for $host" >&2
		echo "$hint" >&2
		exit 1
	}

	printf '%s\n' "$output" | sed -n '
		1{ s/^/password=/p }
		s/^Username: /username=/p
		s/^URI: /host=/p
		'
	exit 0
fi

if [ -n "$env_token" ]; then
	echo "Using env token for $host (rbw unavailable)" >&2
	emit_token_credentials "$default_user" "$env_token"
	exit 0
fi

echo "git-credential-rbw: cannot auth to $host" >&2
echo "rbw is not available/unlocked and no token env is set." >&2
echo "$hint" >&2
exit 1
