# listening backup check

Backup outside check for db.futureofrecords.com. GitHub Actions runs `check.sh` every 5 minutes. It alerts a Telegram chat when:
- the site's health check fails twice, 60 seconds apart; or
- the main Cloudflare outside check stops recording healthy runs.

It sends at most one alert an hour. The code holds no secrets: the Telegram details are repository secrets.
