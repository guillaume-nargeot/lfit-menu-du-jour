#!/bin/sh

# Install dependencies
if [ ! -f tabula-1.0.1-jar-with-dependencies.jar ]; then
  wget https://github.com/tabulapdf/tabula-java/releases/download/v1.0.1/tabula-1.0.1-jar-with-dependencies.jar
fi

# Download monthly menu file
wget -q http://www.lfitokyo.org/index.php/menus-cantine -O menus.html

# Fix html to valid xml, remove &nbsp; as xpath seems to have have problems with this
cat menus.html | tidy -asxhtml -indent - 2> /dev/null | sed s'/&nbsp;/ /g' > menus.xml

# Extract link to the monthly menu PDF file
PDF_HREF=`xpath menus.xml '//div[@class="box-download"]/a/@href' 2> /dev/null | cut -c8- | sed s'/.$//'`

# Download month menu PDF file
wget -q http://www.lfitokyo.org/$PDF_HREF -O menu.pdf

# Extract table from the 
java -jar tabula-1.0.1-jar-with-dependencies.jar -gti -fCSV menu.pdf 2> /dev/null > menu.csv

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

# Fix spacing
sed -i s'/\(LUNDI\|MARDI\|MERCREDI\|JEUDI\|VENDREDI\)\([^ ]\)/\1 \2/' menu.txt
sed -i s'/  */ /g' menu.txt

# Compute current date in French
TODAY=`LC_TIME='fr_FR.UTF-8' date '+%A %d' | awk '{print toupper($0)}'`

# Output today's menu
awk "/$TODAY/,0" menu.txt > menutmp.txt
head -6 menutmp.txt # temporary solution
