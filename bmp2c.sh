#!/bin/bash

PROGNAME=${0##*/}
tmp1=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX)
tmp2=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX)
tmp3=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX)

NOW=$(date +"%Y-%m-%d %H:%M:%S")
TODAY=$(date +"%d %b %Y")
YEAR=$(date +"%Y")
ISODATE=$(date +%Y%m%d)
EXITCODE=0
COMMAND="$0" # Save command
CWD=$PWD
VERBOSE=0
DICTIONARY=""
TMPFILE=$(mktemp)

# Set up logging if not already setup - this is important if we run this as a cron job
LOGFILE="${HOME}/.${PROGNAME}.log"
[[ ! -f $LOGFILE ]] && touch $LOGFILE 2>/dev/null
[[ $? -ne 0 ]] && LOGFILE=/dev/null

#============================================================================#
# Diagnostics
#============================================================================#
function TRACE {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][TRACE][${PROGNAME}][${ENVIRONMENT}] $@\n" >> $LOGFILE
}

function DEBUG {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][DEBUG][${PROGNAME}][${ENVIRONMENT}] " >> $LOGFILE
  while [[ -n $1 ]] ; do
    printf "$1 " >>  $LOGFILE
    shift
  done
  printf "\n" >> $LOGFILE
}

function TODO {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][TODO][${PROGNAME}][${ENVIRONMENT}] $@\n" > /dev/stderr | tee -a $LOGFILE
}

function INFO {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][INFO][${PROGNAME}][${ENVIRONMENT}] $(echo $@ | sed -e 's/%/%%/g')\n" > /dev/stderr | tee -a $LOGFILE
}

function WARN {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][WARN][${PROGNAME}][${ENVIRONMENT}] $@\n" > /dev/stderr | tee -a $LOGFILE
}

function ERROR {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][ERROR][${PROGNAME}][${ENVIRONMENT}] $@\n" > /dev/stderr | tee -a $LOGFILE
}

function FATAL {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][FATAL][${PROGNAME}][${ENVIRONMENT}] $@\n" > /dev/stderr | tee -a $LOGFILE
}

function LOGDIE {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][FATAL][${PROGNAME}][${ENVIRONMENT}] $@\n" > /dev/stderr | tee -a $LOGFILE
  exit 1
}

function SECURITY {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][SECURITY][${PROGNAME}][${ENVIRONMENT}] $@\n" > /dev/stderr | tee -a $LOGFILE
}

#============================================================================#
# Howto
#============================================================================#

if [[ -z $1 ]]; then
  cat <<!
Creates a C header-file that contains a C-array of the bitmap file's content.
This is for use in embedded displays, where single-color bitmaps still rule
and where storage space is still at a premium.

You can pass any bitmap file into this utility - it will attempt to create a
single bit-per-pixel file if it is not one yet, so that you end with a compact
C-array where every bit in the C-array counts as a pixel.


The resulting output can be piped into a ready-to-compile C header-file:

${0##*/} mybitmap.bmp > ~/project/include/mybitmap.h

The dimensions and other attributes will be captured and the resulting C-array
will be called {filename}{width}x{height}, e.g. 

  #ifndef _MYBITMAP_H_
  #define _MYBITMAP_H_

  const unsigned char mybitmap32x32[128] = {.....};

  #endif   /* _MYBITMAP_H_ */

Parameters:
 1. Bitmap file
 
 The resulting file is created in the current working directory.
!
  exit 1
fi

#============================================================================#
# TRAPS
#============================================================================#
function cleanup {
  TRACE "[$LINENO] === END [PID $$] on signal $1. Cleaning up ==="
  rm $tmp1 2>/dev/null
  rm $tmp2 2>/dev/null
  rm $tmp3 2>/dev/null
  exit
}
for sig in KILL TERM INT EXIT; do trap "cleanup $sig" "$sig" ; done


#============================================================================#
# Main
#============================================================================#
infile=${1}

# Input validate
if [[ ! -f $infile ]]; then
  WARN "[$LINENO] File $infile does not exist. Exiting..." 
  exit 1
fi

# Get Width in HEX (offset 0x12 = 18)
W=$(hexdump -v -e '/1 "%02X "' $infile | awk '{printf "%s%s%s%s", $22, $21, $20, $19 }' | sed -e 's/ //g')
W=$((16#$W))
# Get Height in HEX (offset 0x16h = 22)
H=$(hexdump -v -e '/1 "%02X "' $infile | awk '{printf "%s%s%s%s", $26, $25, $24, $23}' | sed -e 's/ //g')
H=$((16#$H))
# Get bits per pixel in HEX (offset 0x1C = 28)
BPP=$(hexdump -v -e '/1 "%02X "' $infile | awk '{printf "%s%s", $30, $29}' | sed -e 's/ //g')
BPP=$((16#$BPP))
# Get data bytes in HEX (offset 0x22 = 34)
BYTES=$(hexdump -v -e '/1 "%02X "' $infile | awk '{printf "%s%s%s%s",  $38, $37, $36, $35 }' | sed -e 's/ //g')
BYTES=$((16#$BYTES))

INFO "File $infile has $BPP bits per pixel and is sized WxH: ${W}x${H} pixels. Total bytes: ${BYTES}"
if [[ $BPP -gt 1 ]] ; then
  WARN "More than 1 bit per pixel is used. This is not optimal for single-color embedded system displays"
fi

# Calculate where the bitmap data starts:
# If colorspace = 38 bits , skip xxx bytes - 248T colours
# If colorspace = 32 bits , skip 138 bytes - 16M colours + transparency
# If colorspace = 24 bits , skip xx bytes - 16M colours
# If colorspace = 16 bits , skip xx bytes - 65536 colours
# If colorspace = 8 bits , skip xx bytes - 256 colours
# If colorspace = 4 bits , skip xx bytes - 16 colours
# If colorspace = 1 bits , skip  122 bytes  - 2 colours


_infile=$(basename ${1})
bitmapname=${_infile%.*}

INFO "File $infile has $BPP bits per pixel."

echo "#ifndef _${bitmapname^^}_H_"
echo "#define _${bitmapname^^}_H_"
echo ""
echo "const unsigned char ${bitmapname}${W}x${H}[] = {"
hexdump -v -e '/1 "0x%02X, "' $infile | tail -128 | sed -E 's|((...., ){16})|\1\n|g'
echo "};"
echo ""
echo "#endif   /* _${bitmapname^^}_H_ */"

