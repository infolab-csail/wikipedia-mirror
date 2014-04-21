#!/bin/bash
#
# Dont really parse it, just do some nassty tricks to make a subset of
# the xml that makes sense

#!/bin/sh

ORIGINAL_XML=/scratch/cperivol/wikipedia-mirror/drafts/wikipedia-parts/enwiki-20131202-pages-articles20.xml-p011125004p013324998.fix.xml
# ORIGINAL_XML=/tmp/123.xml

function file_range {
    file=$1
    start=$2
    len=$3

    case $len in
	"end") dd ibs=1 if=$file skip=$start; return 0;;
	"start") dd ibs=1 if=$file count=$start; return 0;;
	"") echo "You need to tell me <filename> <byte start> <length|'start'|'end'>" 1>&2; return 1;;
    esac

    if [[ $len -gt 0 ]]; then
	# Dump to stdout
	dd ibs=1 if=$file skip=$start count=$len;
    else
	skip=$(($start + ($len)))
	len=$((- ($len)))
	if [[ $skip -lt 0 ]]; then
	    skip=0
	    len=$start
	fi

	# Dump to stdout
        dd ibs=1 if=$file skip=$skip count=$len
    fi
}

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

    # echo PROCESSING COUNT: $count 1>&2
    dd if=$ORIGINAL_XML count=$count skip=$(($title_offset-$count)) ibs=1 | tac | sed '/<page>/q'
    dd if=$ORIGINAL_XML skip=$title_offset ibs=1 | sed -n '/<\/page>/{p;q};p'
}

# Throw everything but the page in stdout
function neg_xml_page {
    term="<title>$@</title>"
    title_offset=$(grep -b -o -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*" -m 1 | head -1)

    echo -e "\ttitle offset: $title_offset" 1>&2

    if [ ! $title_offset ]; then
	echo "Found '$title_offset' Grep-ing (grep -b -F \"$term\" -m 1 $ORIGINAL_XML | grep -o '[0-9]*')"
	grep -b -o -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*"
	exit 0
    fi

    to_page_start=$(($(file_range $ORIGINAL_XML $title_offset -1000 | tac |rev | grep -b -o -F "$(echo '<page>' | rev)" -m 1 | grep -o "[0-9]*" -m 1)+6))
    echo -e "\tto page start: $to_page_start" 1>&2
    to_page_end=$(($(file_range $ORIGINAL_XML $title_offset end | grep -o -b -F "</page>" -m 1 | grep -o "[0-9]*")+7))
    echo -e "\tto page end: $to_page_end" 1>&2
    page_start=$(($title_offset - $to_page_start))
    page_end=$(($title_offset + $to_page_end))

    echo -e "\tpage start: $page_start\n\tpage end: $page_end,\n\tbytes to copy: $(($(du -b $ORIGINAL_XML | awk '{print $1}') - $page_start + $page_end))" 1>&2

    file_range $ORIGINAL_XML $page_start start
    file_range $ORIGINAL_XML $page_end end
}

# Put stdin betwinn mediawiki tags and into stdout
function mediawiki_xml {
    (head -1 $ORIGINAL_XML; sed -n "/<siteinfo>/,/<\/siteinfo>/p;/<\/siteinfo>/q" $ORIGINAL_XML ; cat - ; tail -1 $ORIGINAL_XML )
}

# (for i; do xml_page "$i"; done) | mediawiki_xml
# neg_xml_page $1
