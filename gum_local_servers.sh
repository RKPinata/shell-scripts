#!/bin/bash
# Lists servers reachable at local.respond.io and kills the ones picked.
# local.respond.io resolves to 127.0.0.1, so a server counts when it listens on
# 127.0.0.1 or on all interfaces.
#
# Usage: gum_local_servers.sh [-a]
#   -a  show every listener, not only those whose cwd matches $LOCAL_SERVERS_MATCH
#
# LOCAL_SERVERS_MATCH (default: respond-io) is a grep -E pattern for the cwd.

HOST="local.respond.io"
MATCH="${LOCAL_SERVERS_MATCH:-respond-io}"
[ "$1" = "-a" ] && MATCH="."

if ! command -v gum &>/dev/null; then
  echo "❌ gum is not installed."
  exit 1
fi

# One "pid port" line per listening socket on 127.0.0.1 or *.
listeners() {
  lsof -nP -iTCP -sTCP:LISTEN -Fpn 2>/dev/null | awk '
    /^p/ { pid = substr($0, 2) }
    /^n/ {
      addr = substr($0, 2)
      port = addr; sub(/.*:/, "", port)
      host = addr; sub(/:[0-9]+$/, "", host)
      if (host == "127.0.0.1" || host == "*") print pid, port
    }' | sort -u
}

rows=()
for pid in $(listeners | awk '{print $1}' | sort -un); do
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  echo "$cwd" | grep -qE "$MATCH" || continue

  ports=$(listeners | awk -v p="$pid" '$1 == p {print $2}' | sort -n | paste -sd, -)
  # Command line with every path cut to its basename, minus a leading node.
  cmd=$(ps -o command= -p "$pid" |
    awk '{ for (i = 1; i <= NF; i++) sub(/.*\//, "", $i); sub(/^node /, ""); print }' |
    cut -c1-40)
  label=$(printf '%-24s %-7s %-40s %s' "$HOST:$ports" "$pid" "$cmd" "${cwd/#$HOME/~}")
  rows+=("$label"$'\t'"$pid")
done

if [ ${#rows[@]} -eq 0 ]; then
  echo "No servers on $HOST."
  exit 0
fi

header=$(printf '%-24s %-7s %-40s %s' "URL" "PID" "COMMAND" "CWD")
pids=$(printf '%s\n' "${rows[@]}" | sort -t: -k2 -n | gum choose --no-limit \
  --label-delimiter=$'\t' \
  --header "$header"$'\n'"space: select · enter: kill · esc: cancel")

[ -z "$pids" ] && exit 0

# shellcheck disable=SC2086
kill $pids 2>/dev/null

# Give dev servers a moment to shut down before checking for survivors.
for _ in 1 2 3 4 5 6; do
  alive=""
  for pid in $pids; do
    kill -0 "$pid" 2>/dev/null && alive="$alive $pid"
  done
  [ -z "$alive" ] && break
  sleep 0.5
done

for pid in $pids; do
  case " $alive " in
    *" $pid "*) ;;
    *) echo "✅ killed $pid" ;;
  esac
done

if [ -n "$alive" ]; then
  echo "⚠️  still running:$alive"
  # shellcheck disable=SC2086
  gum confirm "Force kill (SIGKILL)?" && kill -9 $alive && echo "✅ force killed:$alive"
fi
