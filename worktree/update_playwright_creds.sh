#!/usr/bin/env bash
# Update the Playwright test-account credentials in .env.direct across the main
# respond-io-web checkout and every sentiment-analysis worktree.
#
# Usage: bash ~/scripts/worktree/update_playwright_creds.sh [--no-verify]

set -euo pipefail

MAIN_REPO="/Users/danish/Repo/respond-io-web"
WORKTREE_FILTER="sentiment-analysis"
LOGIN_URL="https://staging.respond.io/auth/login"
BOT_ID="25566"
ORG_ID="27555"

VERIFY=1
[[ "${1:-}" == "--no-verify" ]] && VERIFY=0

if [[ ! -d "$MAIN_REPO/.git" ]]; then
	echo "Main checkout not found at $MAIN_REPO" >&2
	exit 1
fi

# --- collect credentials -----------------------------------------------------

read -r -p "PLAYWRIGHT_TESTING_EMAIL: " EMAIL
read -r -s -p "PLAYWRIGHT_TESTING_PASSWORD: " PASSWORD
echo

if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
	echo "Email and password are both required." >&2
	exit 1
fi

quote_value() {
	local value="$1"
	if [[ "$value" == *"'"* ]]; then
		echo "Value contains a single quote; .env quoting cannot be done safely here." >&2
		exit 1
	fi
	if [[ "$value" =~ [[:space:]\#] ]]; then
		printf "'%s'" "$value"
	else
		printf '%s' "$value"
	fi
}

EMAIL_OUT="$(quote_value "$EMAIL")"
PASSWORD_OUT="$(quote_value "$PASSWORD")"

# --- verify against staging before touching any file -------------------------

if [[ "$VERIFY" == "1" ]]; then
	echo
	echo "Verifying credentials against $LOGIN_URL ..."
	VERIFY_SCRIPT="$(mktemp -t pwcreds).mjs"
	trap 'rm -f "$VERIFY_SCRIPT"' EXIT
	cat >"$VERIFY_SCRIPT" <<'NODE'
const [url, email, password] = process.argv.slice(2);
const res = await globalThis.fetch(url, {
	method: 'POST',
	headers: { 'content-type': 'application/json', 'x-mfa-bypass': 'true' },
	body: JSON.stringify({ email, password }),
});
const body = await res.text();
if (!res.ok) {
	console.error(`login failed: ${res.status} ${res.statusText} ${body.slice(0, 200)}`);
	process.exit(1);
}
let token;
try {
	token = JSON.parse(body)?.data?.idToken;
} catch {
	token = undefined;
}
if (!token) {
	console.error('login returned 200 but no data.idToken');
	process.exit(1);
}
console.log('login OK, idToken received');
NODE
	if ! node "$VERIFY_SCRIPT" "$LOGIN_URL" "$EMAIL" "$PASSWORD"; then
		echo "Credentials rejected. Nothing written." >&2
		exit 1
	fi
fi

# --- resolve targets ---------------------------------------------------------

TARGETS=()
seen=""
add_target() {
	local env_file="$1/.env.direct"
	[[ -e "$env_file" ]] || return 0
	local real
	real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$env_file")"
	case "$seen" in
		*"|$real|"*) return 0 ;;
	esac
	seen="$seen|$real|"
	TARGETS+=("$real")
}

add_target "$MAIN_REPO"
while read -r path; do
	[[ "$path" == *"$WORKTREE_FILTER"* ]] && add_target "$path"
done < <(git -C "$MAIN_REPO" worktree list --porcelain | awk '/^worktree /{print $2}')

if [[ ${#TARGETS[@]} -eq 0 ]]; then
	echo "No .env.direct files found." >&2
	exit 1
fi

echo
echo "Will update ${#TARGETS[@]} file(s):"
printf '  %s\n' "${TARGETS[@]}"
read -r -p "Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || { echo "Aborted."; exit 1; }

# --- write -------------------------------------------------------------------

STAMP="$(date +%Y%m%d-%H%M%S)"

for env_file in "${TARGETS[@]}"; do
	cp -p "$env_file" "$env_file.bak.$STAMP"
	tmp="$(mktemp)"
	grep -vE '^(PLAYWRIGHT_TESTING_EMAIL|PLAYWRIGHT_TESTING_PASSWORD|PLAYWRIGHT_TESTING_BOT_ID|PLAYWRIGHT_TESTING_ORG_ID)=' "$env_file" >"$tmp" || true
	# keep exactly one trailing blank line before the appended block
	printf '%s\n' "" >>"$tmp"
	{
		printf 'PLAYWRIGHT_TESTING_EMAIL=%s\n' "$EMAIL_OUT"
		printf 'PLAYWRIGHT_TESTING_PASSWORD=%s\n' "$PASSWORD_OUT"
		printf 'PLAYWRIGHT_TESTING_BOT_ID=%s\n' "$BOT_ID"
		printf 'PLAYWRIGHT_TESTING_ORG_ID=%s\n' "$ORG_ID"
	} >>"$tmp"
	cat "$tmp" >"$env_file"
	rm -f "$tmp"
	echo "updated $env_file (backup: $env_file.bak.$STAMP)"
done

echo
echo "Done. Remove backups when happy:"
echo "  find /Users/danish/Repo/respond-io-web -name '.env.direct.bak.$STAMP' -delete"
