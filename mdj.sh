#!/bin/bash

# Retrieve Japan holiday calendar
YEAR=$(date +"%Y")
if [[ ! -f "japan-$YEAR-holiday.csv" ]]; then
    curl -s -G \
        -d start_year=$YEAR -d end_year=$YEAR \
        -d id=3 -d start_mon=1 -d end_mon=12 -d year_style=normal \
        -d month_style=ja -d wday_style=en -d format=csv -d holiday_only=1 \
        -d zero_padding=1 \
        -H 'Accept-Encoding: gzip, deflate' --compressed \
        'http://calendar-service.net/cal' | \
        tail -n +2 | cut -d, -f1-3 | tr , - > japan-$YEAR-holiday.csv
fi

# Exit if today is a holiday
if cat japan-$YEAR-holiday.csv | grep $(date --iso) > /dev/null; then
    echo "Exiting as today is a Japan holiday"
    exit 0
fi

# Install dependencies
TABULA=tabula-1.0.1-jar-with-dependencies.jar
if [ ! -f tabula-1.0.1-jar-with-dependencies.jar ]; then
  wget https://github.com/tabulapdf/tabula-java/releases/download/v1.0.1/$TABULA
fi

# Download monthly menu file
wget -q http://www.lfitokyo.org/index.php/menus-cantine -O menus.html

# - fix html to valid xml
# - remove &nbsp; as xpath seems to have have problems with this
cat menus.html | tidy -asxhtml -indent - 2> /dev/null | \
    sed s'/&nbsp;/ /g' > menus.xml

# Extract link to the monthly menu PDF file

PDF_URL=$(xmllint \
    --xpath '//*[contains(@class, "box-download") or contains(@class, "jcepopup")]/@href' menus.xml | \
    sed s'/.*"\(.*\)".*/\1/')
PDF_URL="http://www.lfitokyo.org/$PDF_URL"

# Download monthly menu PDF file
LAST_MOD_F=menu.pdf.last_modif_time
LAST_MOD=$(curl -sI $PDF_URL | grep Last-Modified)
if [ ! -f $LAST_MOD_F ] || [ "$LAST_MOD" != "$(cat $LAST_MOD_F)" ]; then
  echo "Downloading monthly menu file"
  wget -q $PDF_URL -O menu.pdf
fi
echo $LAST_MOD > $LAST_MOD_F

# Extract table from PDF menu
java -Dfile.encoding=utf-8 -jar $TABULA -gti -fCSV menu.pdf 2> /dev/null > menu.csv

# Count columns
COL_COUNT=$(awk -F, '{print NF}' menu.csv | sort -nu | tail -n 1)

# Merge columns
rm -f menu.txt
touch menu.txt
COLS=$(seq $COL_COUNT)
for i in $COLS; do
  cut -d, -f $i menu.csv >> menu.txt
done

# Remove empty lines
dos2unix -q menu.txt
sed -i '/^\(""\|\)$/d' menu.txt 

# Fix spacing and add empty line at the end for simplifying later process
sed -i s"/\(LUNDI\|MARDI\|MERCREDI\|JEUDI\|VENDREDI\)\([^ ]\)/\1 \2/" menu.txt
sed -i s'/  */ /g' menu.txt
echo "" >> menu.txt

# Compute current date in French
TODAY=$(LC_TIME='fr_FR.UTF-8' date '+%A %d')
TODAY_UC=$(echo $TODAY | awk '{print toupper($0)}')

# Output today's menu
MENU=$(cat menu.txt | \
    sed -n -e "/$TODAY_UC/,/LUNDI\|MARDI\|MERCREDI\|JEUDI\|VENDREDI/p" | \
    tail -n +2 | head -n -1 | \
    sed 'N;s/\n\([a-z]\)/ \1/g' | sed s'/- /-/') # fix unwanted line breaks

# Exit if today's menu is empty
# (in most cases, it should mean today is a school holiday)
if [[ -z "$MENU" ]]; then
    echo "Exiting as today is a school holiday"
    exit 0
fi

# Exit if the env vars required for Pushover are not set
if [[ -z "$PUSHOVER_KEY" ]] || [[ -z "$PUSHOVER_USER" ]]; then
    echo "The following environment variables are not set:"
    echo "- PUSHOVER_KEY"
    echo "- PUSHOVER_USER"
    exit 1
fi

# Send today's menu as a push notification with Pushover
curl -s -F "token=$PUSHOVER_KEY" \
    -F "user=$PUSHOVER_USER" \
    -F "device=caneton" \
    -F "title=LFIT Menu ($TODAY)" \
    -F "message=$MENU" \
    -F "url=$PDF_URL" \
    -F "url_title=Menus du mois (PDF)" \
    https://api.pushover.net/1/messages.json

echo ""
echo "Done"
