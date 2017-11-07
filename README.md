# lfit-menu-du-jour

Extract LFIT today's menu the monthly published PDF menu file and communicate it with [Pushover](https://pushover.net/)

## Usage:

Just run:
```bash
./mdj.sh
```

For example, the script can be cronned ton run on weekday mornings.

Note: the script expects the following environment variable to be set in order to send the push notification via Pushover:
- PUSHOVER_USER
- PUSHOVER_KEY

## Dependencies:

- curl
- xmllint
- tabulapdf/tabula-java (automatically downloaded on first run of the command)

## Implementation details

Logic used to avoid running the script on school holidays:
- check Japan national holidays [API](http://calendar-service.net])
- check if parsed menu is empty
- check French schools nummber holiday [API](https://www.data.gouv.fr/fr/datasets/le-calendrier-scolaire/) (TODO)
