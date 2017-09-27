#!/bin/sh

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
#PDF_URL=`xpath menus.xml '//div[@class="box-download"]/a/@href' 2> /dev/null | \
#    cut -c8- | sed s'/.$//'`
# the upper xpath expression doesn't seem to work with xmllint or xmlstarlet...
PDF_URL=`cat menus.xml | grep -A2 download | \
    tail -1 | tr -d ' ' | cut -c2- | sed s'/.$//'`
PDF_URL="http://www.lfitokyo.org/$PDF_URL"

# Download month menu PDF file
wget -q $PDF_URL -O menu.pdf

# Extract table from the 
java -Dfile.encoding=utf-8 -jar $TABULA -gti -fCSV menu.pdf 2> /dev/null > menu.csv

# Count columns
COL_COUNT=`awk -F, '{print NF}' menu.csv | sort -nu | tail -n 1`

# Merge columns
rm -f menu.txt
touch menu.txt
COLS=`seq $COL_COUNT`
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
TODAY=`LC_TIME='fr_FR.UTF-8' date '+%A %d'`
TODAY_UC=`echo $TODAY | awk '{print toupper($0)}'`

# Output today's menu
MENU=`cat menu.txt | \
    sed -n -e "/$TODAY_UC/,/LUNDI\|MARDI\|MERCREDI\|JEUDI\|VENDREDI/p" | \
    tail -n +2 | head -n -1`

curl -s -F "token=$PUSHOVER_KEY" \
    -F "user=$PUSHOVER_USER" \
    -F "device=caneton" \
    -F "title=LFIT Menu ($TODAY)" \
    -F "message=$MENU" \
    -F "url=$PDF_URL" \
    -F "url_title=Menus du mois (PDF)" \
    https://api.pushover.net/1/messages.json
