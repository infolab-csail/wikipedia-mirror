#!/bin/sh
#
# Dont really parse it, just do some nassty tricks to make a subset of
# the xml that makes sense

ORIGINAL_XML=/scratch/cperivol/wikipedia-mirror/drafts/wikipedia-parts/enwiki-20131202-pages-articles20.xml-p011125004p013324998.fix.xml

# Throw page in stdout
function page {
    mknod original_tail original_head
    title_offset=$(grep -b "<title>$1</title>" -m 1 $ORIGINAL_XML | grep -o "[0-9]" | head -1)


    dd if=$ORIGINAL_XML count=1000 skip=$(($title_offset-1000)) ibs=1 | tac | sed '/<page>/q'
    dd if=$ORIGINAL_XML skip=$title_offset ibs=1 | sed -n '/<\/page>/{p;q};p'
}

# Put stdin betwinn mediawiki tags and into stdout
function mediawiki_xml {
    (head -1 $ORIGINAL_XML; sed -n "/<siteinfo>/,/<\/siteinfo>/p;/<\/siteinfo>/q" $ORIGINAL_XML ; cat - ; tail -1 $ORIGINAL_XML )
}

xml_page "Cranopsis bocourti" | mediawiki_xml
