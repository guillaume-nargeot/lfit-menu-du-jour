# lfit-menu-du-jour

Extract LFIT today's menu the monthly published PDF menu file and communicate it with Pushover

Usage:
```bash
./mdj.sh
```

Note: the script expects the following environment variable to be set in order to send the push notification via Pushover:
- PUSHOVER_USER
- PUSHOVER_KEY

Dependencies:
- curl
- tabulapdf/tabula-java (automatically downloaded on first run of the command)
