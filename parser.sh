#!/bin/bash


#exit script at first error
set -o errexit

DOCSETNAME=GLSL
DOCSETFILES=scrape
DOCSETDIR=$DOCSETNAME.docset

if [ -d $DOCSETDIR ]; then
	echo Docset $DOCSETDIR already exists
	exit 1
fi

# if not finding docset files, download files from opengl.org
# and replace xml with html
if [ ! -d $DOCSETFILES/a ]; then
	echo Downloading files
	mkdir -p $DOCSETFILES
	pushd $DOCSETFILES

	# remove the '-w 0.5' from the next line to prevent the 1/2 second wait
	# between file downloads.  I added this to prevent an accidental DoS.
	wget -r -l 3 -nd -nH -k -w 0.5 http://www.opengl.org/sdk/docs/manglsl/xhtml/index.html

	wget http://www.opengl.org/sdk/docs/manglsl/xhtml/start.html
	for fil in *.xml; do
		if [ ! -e $fil ]; then
			continue
		fi
		newfil=${fil%.xml}.html
		mv $fil $newfil
	done

	# Replace links to .xml files with .html
	for fil in *.html; do
		sed -i '' 's/\.xml/\.html/g' $fil
	done
	popd
fi

# Create the docset folder
mkdir -p $DOCSETDIR/Contents/Resources/Documents

# Copy the HTML documentation
cp -R $DOCSETFILES/ $DOCSETDIR/Contents/Resources/Documents


# Copy the icon
cp icon.png $DOCSETDIR/icon.png

cat << PLIST > $DOCSETDIR/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>$DOCSETNAME</string>
	<key>CFBundleName</key>
	<string>$DOCSETNAME</string>
	<key>DocSetPlatformFamily</key>
	<string>$DOCSETNAME</string>
	<key>isDashDocset</key>
	<true/>
	<key>dashIndexFilePath</key>
	<string>index.html</string>
</dict>
</plist>
PLIST

SQLITEFILE=$DOCSETDIR/Contents/Resources/docSet.dsidx
# Create the SQLite Index
sqlite3 $SQLITEFILE 'CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);'

# Prevent duplicate entries
sqlite3 $SQLITEFILE 'CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);'

# Populate SQLite Index
pushd $DOCSETDIR/Contents/Resources/Documents
for fil in *.html; do
	name=`basename $fil .html`

	#skip the two files *not* corresponding to functions
	if [ $fil = start.html -o $fil = index.html ]; then
		continue
	fi
	sqlite3 ../docSet.dsidx "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('$name', 'Function', '$fil');"
done
popd
