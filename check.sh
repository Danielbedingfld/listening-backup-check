#!/usr/bin/env bash
# Backup outside check for the listening room. Runs on GitHub Actions every 5 minutes.
# Alerts Maggie's Telegram chat when the site fails twice (60 s apart), or when the
# Cloudflare outside check has not recorded a healthy run for 10 minutes.
# Prints only check results; secrets come from the environment and are never echoed.
set -u
fail=()
site() { curl -s -o /dev/null -m 15 -w '%{http_code}' https://db.futureofrecords.com/api/health; }
s1=$(site)
if [ "$s1" != 200 ]; then
  sleep 60; s2=$(site)
  [ "$s2" != 200 ] && fail+=("site /api/health returned $s1 then $s2")
fi
curl -s -m 15 -o worker-state.json https://listening-outside-check.futureof.workers.dev/ || echo '{}' > worker-state.json
read -r age fails < <(python3 - <<'PY'
import json,time
try:d=json.load(open('worker-state.json'))
except Exception:d={}
t=d.get('last_ok') or 0
print(int(time.time()-t/1000) if t else -1, d.get('fails',0))
PY
)
# The Worker is fine if it passed in the last 10 min, or is counting failures (then it alerts itself).
if [ "$age" -lt 0 ] || { [ "$age" -gt 600 ] && [ "$fails" -eq 0 ]; }; then
  fail+=("the Cloudflare outside check has not recorded a healthy run for ${age}s, so it may be broken")
fi
echo "site=$s1 worker_last_ok_age=${age}s worker_fails=$fails"
if [ ${#fail[@]} -eq 0 ]; then echo healthy; exit 0; fi
msg="Listening backup check (GitHub): $(IFS=';'; echo "${fail[*]}")."
echo "ALERT: $msg"
echo "alert=1" >> "${GITHUB_OUTPUT:-/dev/null}"
curl -s -o /dev/null -m 20 --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=$msg" \
  "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
