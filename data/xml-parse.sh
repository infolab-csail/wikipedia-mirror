#!/bin/bash
#
# Simply removing specific articles fixes the xerces error with
# UTF8. If the articles are alone the error goes away
# aswell. Extremely weird but that's life. Fortunately the article is
# just a stub about some toad (Cranopsis bocourti)
#
# xml-parse.sh ORIGINAL_XML TITLE_OF_ARTICLE_TO_REMOVE [inplace]
#
# if `inplace` is there the c program will be used to cover the article
# with spaces. This is much faster. Should be anyway. Otherwise the
# page is just ommited and the result is dumped in stdout. Helping
# messages are dumped in stderr After this you can run:
#
# java -jar tools/mwdumper.jar RESULTING_XML --format=sql:1.5 > SQL_DUMP

if [[ $# -lt 2 ]]; then
    echo "xml-parse.sh ORIGINAL_XML TITLE_OF_ARTICLE_TO_REMOVE [inplace]" 1>&2
    exit 0
fi

PROJECT_ROOT=/scratch/cperivol/wikipedia-mirror
PAGE_REMOVER=$PROJECT_ROOT/data/page_remover
ORIGINAL_XML=$1
# ORIGINAL_XML=$PROJECT_ROOT/drafts/wikipedia-parts/enwiki-20131202-pages-articles20.xml-p011125004p013324998.fix.xml
# ORIGINAL_XML=/tmp/123.xml

# Dump a part of the file in sdout using dd.
# Usage:
# file_range <filename> <first_byte> <start|end|length>
#
# Length can be negative
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
	dd ibs=1 if=$file skip=$start count=$len
    else
	skip=$(($start + ($len)))
	len=$((- ($len)))

	if [[ $skip -lt 0 ]]; then
	    skip=0
	    len=$start
	fi

	# Dump to stdout
        time dd ibs=1 if=$file skip=$skip count=$len
    fi
}

# Throw page in stdout
#
# xml_page "Barack Obama"
function xml_page {

    term="<title>$1</title>"

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


function backwards {
    tac -b | rev
}

function grep_once {
    grep -b -o -F "$1" -m 1
}

# Throw everything but the page in stdout
#
# neg_xml_page "Barack Obama"
function neg_xml_page {
    term="<title>$1</title>"
    title_offset=$(grep -b -o -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*" -m 1 | head -1)
    echo -e "\nMethod: $2" 1>&2
    echo -e "\tsearch term: $term" 1>&2
    echo -e "\ttitle offset: $title_offset" 1>&2

    if [ ! $title_offset ]; then
	echo "Found '$title_offset' Grep-ing (grep -b -F \"$term\" -m 1 $ORIGINAL_XML | grep -o '[0-9]*')"
	grep -b -o -F "$term" -m 1 $ORIGINAL_XML | grep -o "[0-9]*"
	return
    fi

    to_page_start=$(($(file_range $ORIGINAL_XML $title_offset -1000 | backwards | grep_once "$(echo '<page>' | rev)" | cut -d: -f 1 )+7))
    echo -e "\tto page start: $to_page_start" 1>&2
    to_page_end=$(($(file_range $ORIGINAL_XML $title_offset end | grep_once "</page>" | cut -d: -f 1)+7))
    echo -e "\tto page end: $to_page_end" 1>&2
    page_start=$(($title_offset - $to_page_start +1 ))
    page_end=$(($title_offset + $to_page_end))

    echo -e "\tpage start: $page_start" 1>&2
    echo -e "\tpage end: $page_end" 1>&2
    echo -e "\tbytes to copy: $(($(du -b $ORIGINAL_XML | awk '{print $1}') - $page_start + $page_end))" 1>&2

    if [[ "$2" = "inplace" ]]; then
	echo -e "Using in place covering with $PAGE_REMOVER.." 1>&2
	cmd="$PAGE_REMOVER $ORIGINAL_XML $page_start $(($page_end-$page_start))"
	echo "Running: $cmd" 1>&2
	eval $cmd
	return;
    fi

    echo "Going to copy $page_start bytes" 1>&2
    file_range $ORIGINAL_XML $page_start start
    echo "Finished the first half up to $page_start, $(( $(du -b $ORIGINAL_XML | cut -f 1) - $page_end )) to go" 1>&2
    file_range $ORIGINAL_XML $page_end end
    echo "Finished the whole thing." 1>&2
}

# Put stdin betwinn mediawiki tags and into stdout
function mediawiki_xml {
    (head -1 $ORIGINAL_XML; sed -n "/<siteinfo>/,/<\/siteinfo>/p;/<\/siteinfo>/q" $ORIGINAL_XML ; cat - ; tail -1 $ORIGINAL_XML )
}

# (for i; do xml_page "$i"; done) | mediawiki_xml
neg_xml_page "$2" "$3"
