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

set -e
set -o pipefail

if [[ $# -lt 2 ]]; then
    echo "xml-parse.sh ORIGINAL_XML TITLE_OF_ARTICLE_TO_REMOVE [inplace]" 1>&2
    exit 0
fi

function my_dd {
    coreutils_version=$(dd --version | head -1 | cut -d\  -f3 | colrm 2 2 )
    if [[ $coreutils_version -ge 822 ]]; then
	eval "dd iflag=count_bytes iflag=direct oflag=seek_bytes ibs=1M $@"
    else
	echo "Your coreutils may be a bit old ($coreutils_version). 822 is the one cool kids use." >&2
	eval "dd $@ ibs=1"
    fi
}

ORIGINAL_XML=$1

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
	"end") my_dd if=$file skip=$start || exit 1; return 0;;
	"start") my_dd if=$file count=$start || exit 1; return 0;;
	"") echo "len was empty (file: $file, start: $start, len $len). Correct format <filename> <byte start> <length|'start'|'end'>" 1>&2; exit 1;;
	*) ;;
    esac

    if [[ $len -gt 0 ]]; then
	# Dump to stdout
	my_dd if=$file skip=$start count=$len || exit 1
    else
	skip=$(($start + ($len)))
	len=$((- ($len)))

	if [[ $skip -lt 0 ]]; then
	    skip=0
	    len=$start
	fi

	# Dump to stdout
        my_dd if=$file skip=$skip count=$len || exit 1
    fi
}

function backwards {
    tac -b | rev
}

function byte_offset {
    grep -b -o -m 1 -F  "$1" | cut -d : -f1
}

# Throw everything but the page in stdout
#
# neg_xml_page "Barack Obama"
function neg_xml_page {
    term="<title>$1</title>"
    title_offset=$(cat $ORIGINAL_XML | byte_offset "$term")
    echo -e "\n\tMethod: $2(blank is ok)" 1>&2
    echo -e "\tsearch term: $term" 1>&2
    echo -e "\tfile: $ORIGINAL_XML" 1>&2
    echo -e "\ttitle offset: $title_offset" 1>&2

    # Fail the term is invalid
    if [ -z "$title_offset" ]; then
	echo "Found '$title_offset' Grep-ing (cat  $ORIGINAL_XML | grep -b -m 1 -F \"$term\" | cut -d: -f1)" 1>&2
	exit 1
    fi

    to_page_start=$(($(file_range $ORIGINAL_XML $title_offset -1000 | backwards | byte_offset "$(echo '<page>' | rev)")+7))
    echo -e "\tto page start (relative): $to_page_start" 1>&2

    file_range $ORIGINAL_XML $title_offset end | byte_offset "</page>" >&2
    echo $(($(file_range $ORIGINAL_XML $title_offset end | byte_offset "</page>")+7)) >&2
    to_page_end=$(($(file_range $ORIGINAL_XML $title_offset end | byte_offset "</page>")+7)) # len('</page>') == 7
    echo -e "\tto page end (relative): $to_page_end" 1>&2

    page_start=$(($title_offset - $to_page_start +1 ))
    echo -e "\tpage start: $page_start" 1>&2

    page_end=$(($title_offset + $to_page_end))
    echo -e "\tpage end: $page_end" 1>&2

    echo -e "\tbytes to copy: $(($(du -b $ORIGINAL_XML | cut -f1) - $page_start + $page_end))" 1>&2

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

# 1: XML File
# 2: Article
# 3: Method (leave blank)
# Assert that the file is there and is not empty
fsize=$(du -b $ORIGINAL_XML | cut -f1)
if [[ 0 -eq $fsize ]]; then
    echo "ERROR: empty xml file $ORIGINAL_XML" 1>&2
    exit 1
fi

echo "Will remove article '$2' from file $1 (size: $fsize)" 1>&2
if ! neg_xml_page "$2" "$3"; then
    ret=$?
    echo "XML parsing script failed" 1>&2
    exit $ret;
fi
