#!/bin/bash

PROGNAME=${0##*/}
PROGNAME=${PROGNAME%.*}
tmp1=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX).bmp
tmp2=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX).bmp
tmp3=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX).raster
tmp4=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX).raster

NOW=$(date +"%Y-%m-%d %H:%M:%S")
TODAY=$(date +"%d %b %Y")
YEAR=$(date +"%Y")
ISODATE=$(date +%Y%m%d)
EXITCODE=0
ENVIRONMENT=$(hostname)

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
  printf "[$TS][TODO][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 | tee -a $LOGFILE
}

function INFO {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][INFO][${PROGNAME}][${ENVIRONMENT}] $(echo $@ | sed -e 's/%/%%/g')\n" >&2 | tee -a $LOGFILE
}

function WARN {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][WARN][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 | tee -a $LOGFILE
}

function ERROR {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][ERROR][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 | tee -a $LOGFILE
}

function FATAL {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][FATAL][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 | tee -a $LOGFILE
}

function LOGDIE {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][FATAL][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 | tee -a $LOGFILE
  exit 1
}

function SECURITY {
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][SECURITY][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 | tee -a $LOGFILE
}

#============================================================================#
# Howto
#============================================================================#

function usage {
  cat <<!
Creates a C header-file that contains a C-array of the source file's content.
This is for use in embedded displays, where two-color bitmaps still rule and
where storage space and processing power is still at a premium.

You can pass any image file into this utility and you do need to specify the
horizontal dimension of the target file in pixels, unless you are happy with
the default 32 pixel size. The vertical dimension will be calculated fo you.

The resulting output can be redirected into a ready-to-compile C header-file:

  ${PROGNAME} -f=myimage.svg > ~/project/include/myimage.h

The resulting C-array will be called {filename}_{width}x{height}, e.g. 

  #ifndef _MYIMAGE_H_
  #define _MYIMAGE_H_
  const unsigned char myimage_32x32[128] = {
    .....
  };
  #endif   /* _MYIMAGE_H_ */

OPTIONS (Note that there is an '=' sign between argument and value):
  -f, --file=[full path to file if in other directory]
          The file name of the source image. It can be type of image file
          and of any size or form factor.
  -l, --lexicon=[full path to sed lexicon file]
          Optional lexicon SED file for a crude translation attempt of the
          source string. This may save some typing and may even deliver an
          occasional correct result.
  -g, --google
          Look text up in Google Translation. There is a limit of how many 
          such lookups you can do one day from one IP address.
          Google has suspended this service so this does not work any more.
  -s, --size
          This is the horizontal size of the target file in pixels.          
          If you don't specify it, it will default to 32 pixels.
          The vertical dimension will be calculated fo you.          
  -v, --verbose
          Verbose screen output. All output will also be logged.
  -d, --debug
          Output debug messages to screen and log.           
  -h, --help
          Displays this text 

!
  exit 1
}

#============================================================================#
# TRAPS
#============================================================================#
function cleanup {
  TRACE "[$LINENO] === END [PID $$] on signal $1. Cleaning up ==="
  rm $tmp1 2>/dev/null
  rm $tmp2 2>/dev/null
  rm $tmp3 2>/dev/null
  rm $tmp4 2>/dev/null
  rm $tmp5 2>/dev/null
  exit
}
for sig in KILL TERM INT EXIT; do trap "cleanup $sig" "$sig" ; done


#============================================================================#
# Main
#============================================================================#

while [[ $1 = -* ]]; do
  ARG=$(echo $1|cut -d'=' -f1)
  VAL=$(echo $1|cut -d'=' -f2)

  case $ARG in
    "--file" | "-f")
      if [[ -z $infile ]]; then
        infile=$VAL; [[ $VAL = "$ARG" ]] && shift && infile=$1        
      fi
      ;;
    "--size" | "-s")
      if [[ -z $size ]]; then
        size=$VAL; [[ $VAL = "$ARG" ]] && shift && size=$1        
      fi
      ;;
    "--help" | "-h" )
      usage
      ;;
    "--verbose" | "-v" )
      option_verbose=1
      ;;
    "--debug" | "-d" )
      option_debug=1
      option_verbose=1
      ;;
    *)
      print "Invalid option: $1"
      exit 1
      ;;
  esac
  shift
done

# parameter validate
if [[ -z $size ]]; then
  INFO "Setting horizontal size to default of 32"
  size=32
fi

# Input validate
if [[ ! -f $infile ]]; then
  WARN "[$LINENO] File $infile does not exist. Exiting..." 
  exit 1
fi

# If the input file is not a BMP file. convert it to one
if [[ ${infile##*.} != "bmp" ]]; then
  INFO "$infile is not a bitmap file. Converting it to $tmp1..."
  convert $infile $tmp1  
else
  cp $infile $tmp1  
fi

# Get Width in HEX (offset 0x12 = 18)
W=$(hexdump -v -e '/1 "%02X "' $tmp1 | awk '{printf "%s%s%s%s", $22, $21, $20, $19 }' | sed -e 's/ //g')
W=$((16#$W))
# Get Height in HEX (offset 0x16h = 22)
H=$(hexdump -v -e '/1 "%02X "' $tmp1 | awk '{printf "%s%s%s%s", $26, $25, $24, $23}' | sed -e 's/ //g')
H=$((16#$H))
# Get bits per pixel in HEX (offset 0x1C = 28)
BPP=$(hexdump -v -e '/1 "%02X "' $tmp1 | awk '{printf "%s%s", $30, $29}' | sed -e 's/ //g')
BPP=$((16#$BPP))
# Get data bytes in HEX (offset 0x22 = tmp1)
BYTES=$(hexdump -v -e '/1 "%02X "' $tmp1 | awk '{printf "%s%s%s%s",  $38, $37, $36, $35 }' | sed -e 's/ //g')
BYTES=$((16#$BYTES))

INFO "File $infile has $BPP bits per pixel and is sized WxH: ${W}x${H} pixels. Total bytes: ${BYTES}"
if [[ $BPP -gt 1 ]] ; then
  WARN "More than 1 bit per pixel is used. This is not optimal for single-color embedded system displays. We will fix this soon..."  
fi

# Resize - first we start by leaving a border of 1 pixel all around
size_x=$((size-2))
size_y=$(((size * H / W)-2))
convert $tmp1 -resize ${size_x}x${size_y} $tmp2
size_x=$((size_x+2))
size_y=$((size_y+2))
# Put a 1 pixel border around it 
convert $tmp2 -bordercolor white -border 1x1 $tmp2
# Set the colour depth to 2 colours, so that we have a single bit per pixel in the end:
convert $tmp2 -depth 2 $tmp2
# Set the colour pallete to 2 colours:
convert $tmp2 +dither -colors 2 -colorspace gray -contrast-stretch 0 $tmp2
# Final tweak: Set to monochrome
convert $tmp2 -monochrome $tmp2
# Check that we have 2 colours and 1 bit per pixel:
identify $tmp2 | grep "1-bit" > /dev/null
if [[ $? -ne 0 ]]; then
  ERROR "Failed to convert $infile to a 2-colour file. Exiting..."
  exit 1
fi 

# Chop BMP header so that we only remain with the raster data
# Calculate bytes
filesize=$(stat -c%s $tmp2)
imagesize=$((size_x * size_y / 8))
chopbytes=$((filesize-imagesize))
dd if=$tmp2 of=$tmp3 skip=${chopbytes} iflag=skip_bytes,count_bytes 2>/dev/null
if [[ $? -ne 0 ]]; then
  ERROR "There was an error lopping the BMP header from the 1-bit bitmap file $tmp2. Doing a HEX DUMP and then exiting..."
  hexdump -C $tmp2 > /dev/stderr
  exit 1
fi 
# Final sanity check
filesize=$(stat -c%s $tmp3)
if [[ $filesize -ne $imagesize ]]; then
  ERROR "The file size does not tally with the calculated image data size in the 1-bit bitmap file $tmp3. Doing a BINARY DUMP and then exiting..."
  xxr -b -c 4 $tmp3 > /dev/stderr
  exit 1
fi 

# reversing the content on a bit-wise basis
rm $tmp4 2>/dev/null
binstr=$(xxd -b -c 1 $tmp3 | cut -f 2 -d " " | sed -E 's/(.)/\1 /g' | tr '\n' ' ' | sed -E 's/ //g' | rev )
binstrlen=${#binstr}
for ((i=0;i<$binstrlen;i+=8)); do 
  binchar=${binstr:$i:8}  
  printf "%02X " $((2#${binchar})) | xxd -r -p >> $tmp4
done

# Creating output
INFO "Generating C header file content for $infile..."
_infile=$(basename $infile)
imagename=${_infile%.*}
tmp5=$(printf "/tmp/%s.%dx%d" $imagename $size_x $size_y)
cp $tmp4 $tmp5

printf \
"#ifndef _${imagename^^}_H_
#define _${imagename^^}_H_

const "
xxd -i $tmp5 | sed -e 's/_tmp_//'
printf "
#endif   /* _${imagename^^}_H_ */
"
