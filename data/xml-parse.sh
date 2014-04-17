#!/bin/bash
#
# Dont really parse it, just do some nassty tricks to make a subset of
# the xml that makes sense

ORIGINAL_XML=/scratch/cperivol/wikipedia-mirror/drafts/wikipedia-parts/enwiki-20131202-pages-articles20.xml-p011125004p013324998.fix.xml

# Throw page in stdout
function xml_page {

    term="<title>$@</title>"

    title_offset=$(grep -b -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*" | head -1)

    if [ ! $title_offset ]; then
	echo "Found '$title_offset' Grep-ing (grep -b -F \"$term\" -m 1 $ORIGINAL_XML | grep -o '[0-9]*')"
	grep -b -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*"
	exit 0
    fi

    count=1000
    if [[ $title_offset -lt 1000 ]]; then
	count=$title_offset
    fi

#    echo PROCESSING COUNT: $count
    dd if=$ORIGINAL_XML count=$count skip=$(($title_offset-$count)) ibs=1 | tac | sed '/<page>/q'
    dd if=$ORIGINAL_XML skip=$title_offset ibs=1 | sed -n '/<\/page>/{p;q};p'
}

# Throw everything but the page in stdout
function neg_xml_page {

    term="<title>$@</title>"
  
    title_offset=$(grep -b -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*" | head -1)

    if [ ! $title_offset ]; then
	echo "Found '$title_offset' Grep-ing (grep -b -F \"$term\" -m 1 $ORIGINAL_XML | grep -o '[0-9]*')"
	grep -b -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*"
	exit 0
    fi

    count=1000
    if [[ $title_offset -lt 1000 ]]; then
	count=$title_offset
    fi

#    echo PROCESSING COUNT: $count
    bytes_from_title=$(dd if=$ORIGINAL_XML count=$count skip=$(($title_offset-$count)) ibs=1 | tac | grep -b  -F "<page>" -m 1 | grep -o "[0-9]*")
    page_end=$(dd if=$ORIGINAL_XML skip=$title_offset ibs=1 | grep -b -F "</page>" -m 1 | grep -o "[0-9]*")+7
    page_start=$(($title_offset-$bytes_from_title))

    dd if=$ORIGINAL_XML count=$page_start ibs=1
    dd if=$ORIGINAL_XML skip=$page_end ibs=1
}

# Put stdin betwinn mediawiki tags and into stdout
function mediawiki_xml {
    (head -1 $ORIGINAL_XML; sed -n "/<siteinfo>/,/<\/siteinfo>/p;/<\/siteinfo>/q" $ORIGINAL_XML ; cat - ; tail -1 $ORIGINAL_XML )
}

# Create a file WITHOUT the pages in args (remove neg for JUST those pages)
(for i; do neg_xml_page "$i"; done) | mediawiki_xml
