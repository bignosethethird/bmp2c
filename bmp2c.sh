#!/bin/bash

#============================================================================#
# TRAPS
#============================================================================#
function cleanup {
  rm $tmp1 2>/dev/null
  rm $tmp2 2>/dev/null
  rm $tmp3 2>/dev/null
  rm $tmp4 2>/dev/null
  rm $tmp5 2>/dev/null  
  sync
}
for sig in KILL TERM INT EXIT; do trap "cleanup $sig" "$sig" ; done

#============================================================================#
# Global variables
#============================================================================#

PROGNAME=${0##*/}
PROGNAME=${PROGNAME%.*}
tmp1=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX.bmp)
tmp2=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX.bmp)
tmp3=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX.raster)
tmp4=$(mktemp /tmp/tmp.${PROGNAME}.XXXXXX.raster)

NOW=$(date +"%Y-%m-%d %H:%M:%S")
TODAY=$(date +"%d %b %Y")
YEAR=$(date +"%Y")
ISODATE=$(date +%Y%m%d)
EXITCODE=0
ENVIRONMENT=$(hostname)

# Set up logging if not already setup - this is important if we run this as a cron job
LOGFILE="${HOME}/.${PROGNAME}.log"
[[ ! -f $LOGFILE ]] && touch $LOGFILE 2>/dev/null 
[[ ! -f $LOGFILE ]] && LOGFILE=/dev/null

#============================================================================#
# Diagnostics
#============================================================================#
function TRACE {
  if [[ -z $option_quiet ]]; then
    if [[ $option_verbose -eq 1 || $option_debug -eq 1 ]]; then
      TS=$(date '+%Y/%m/%d %H:%M:%S')
      printf "[$TS][TRACE][${PROGNAME}][${ENVIRONMENT}] $@\n" >> $LOGFILE
    fi
  fi
}

function DEBUG {
  if [[ -z $option_quiet ]]; then
    if [[ $option_verbose -eq 1 ]]; then
      TS=$(date '+%Y/%m/%d %H:%M:%S')
      printf "[$TS][DEBUG][${PROGNAME}][${ENVIRONMENT}] " >> $LOGFILE
      while [[ -n $1 ]] ; do
        printf "$1 " >>  $LOGFILE
        shift
      done
      printf "\n" >> $LOGFILE
    fi
  fi
}

function TODO {
  if [[ -z $option_quiet ]]; then
    TS=$(date '+%Y/%m/%d %H:%M:%S')
    printf "[$TS][TODO][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 2 > >(tee -a $LOGFILE >&2)
  fi
}

function INFO {
  if [[ -z $option_quiet ]]; then
    TS=$(date '+%Y/%m/%d %H:%M:%S')
    printf "[$TS][INFO][${PROGNAME}][${ENVIRONMENT}] $(echo $@ | sed -e 's/%/%%/g')\n" >&2 2 > >(tee -a $LOGFILE >&2)
  fi
}

function WARN {
  if [[ -z $option_quiet ]]; then
    TS=$(date '+%Y/%m/%d %H:%M:%S')
    printf "[$TS][WARN][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 2 > >(tee -a $LOGFILE >&2)
  fi
}

function ERROR {
  if [[ -z $option_quiet ]]; then
    TS=$(date '+%Y/%m/%d %H:%M:%S')
    printf "[$TS][ERROR][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 2 > >(tee -a $LOGFILE >&2)
  fi
}

function FATAL {
  if [[ -z $option_quiet ]]; then
    TS=$(date '+%Y/%m/%d %H:%M:%S')
    printf "[$TS][FATAL][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 2 > >(tee -a $LOGFILE >&2)
  fi
}

function LOGDIE {
  if [[ -z $option_quiet ]]; then
    TS=$(date '+%Y/%m/%d %H:%M:%S')
    printf "[$TS][FATAL][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 2 > >(tee -a $LOGFILE >&2)
  fi
  exit 1
}

function SECURITY {
  if [[ -z $option_quiet ]]; then
    TS=$(date '+%Y/%m/%d %H:%M:%S')
    printf "[$TS][SECURITY][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 2 > >(tee -a $LOGFILE >&2)
  fi
}

#============================================================================#
# Howto
#============================================================================#
function synopsis {
cat <<!
bmp2c -f|--file=filepath [-h|--height=height pixels] [-w|--width=width pixels]
    [-r|--rotate={90|180|270}] [-s|--stretch] [-t|--trim] [-o|--output]  
    [-v|--verbose | -d|--debug | -q|--quiet] [-h|help] 
!
}

function usage {
  synopsis
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
          The file name of the source image. It can be type of image file and
          of any size or form factor.
  -w, --width=[target width in pixels]
          This is the (horizontal) width of the target file in pixels. If you
          don't specify either the width or the height, the width will default
          to 32 pixels and the height will be determined by the aspect ratio of
          the source image.
  -h, --height=[target height in pixels]
          This is (vertical) height of the target file in pixels and if not
          specified, this dimension will be calculated for you based on the
          aspect ratio of the source image and the width dimension that you
          specified. If you only specify the height but not the width, then the
          width is likewise calculated based on the source image aspect ratio. 
  -r, --rotate=[degrees to rotate]
          Rotate the source image either by 90°, 180° or 270°. 
  -s, --strech Option
          You can specify both width and height dimensions such that they do
          not correspond to the source images aspect ratio. If you specify the
          "stretch" option, then the source image will be deformed to fill the
          entire target canvas. If this option is not selected, then whitespace
          is padded into the surrounding space that is created. This option 
          will be ignored if neither the width nor height are specified.
  -t,--trim Option
          Remove all surrounding whitespace or alpha-channel from the source
          image first
  -o, --output Option
          Produce output header file named according to the source image 
          filename, without having to do any redirection. The ouput file will
          created in the current working directory, with an .h extension.          
  -v, --verbose Option
          Verbose screen output to stderr. All output will also be logged.
  -d, --debug Option
          Output debug messages to stderr screen and log.           
  -q, --quiet Option
          Does not produce any process commentary to stderr nor does logging.
  -h, --help Option
          Displays this text 


!
}

#============================================================================#
# Main
#============================================================================#

if [[ -z $1 ]] ; then
  synopsis
  exit 1
fi

while [[ $1 = -* ]]; do
  ARG=$(echo $1|cut -d'=' -f1)
  VAL=$(echo $1|cut -d'=' -f2)

  case $ARG in
    "--file" | "-f")
      if [[ -z $infile ]]; then
        infile=$VAL; [[ $VAL = "$ARG" ]] && shift && infile=$1        
      fi
      ;;
    "--width" | "-w")
      if [[ -z $width ]]; then
        width=$VAL; [[ $VAL = "$ARG" ]] && shift && width=$1        
      fi
      ;;
    "--height" | "-h")
      if [[ -z $height ]]; then
        height=$VAL; [[ $VAL = "$ARG" ]] && shift && height=$1        
      fi
      ;;
    "--rotate" | "-r")
      if [[ -z $height ]]; then
        rotate=$VAL; [[ $VAL = "$ARG" ]] && shift && rotate=$1
      fi
      ;;
    "--stretch" | "-s" )
      option_stretch=1
      ;;
    "--trim" | "-t" )
      option_trim=1
      ;;
    "--verbose" | "-v" )
      option_verbose=1
      ;;
    "--quiet" | "-q" )
      option_quiet=1
      ;;
    "--output" | "-o" )
      option_output=1
      ;;
    "--debug" | "-d" )
      option_debug=1
      option_verbose=1
      ;;
    "--help" | "-h" )      
      usage
      exit 1
      ;;
    *)    
      ERROR "Invalid option: $1"
      synopsis
      exit 1
      ;;
  esac
  shift
done

# parameter validate
if [[ -z width || -z height ]] && [[ option_stretch -eq 1 ]]; then
  WARN "Ignoring the stretch option, since either the width or the height have not been specified"
  unset option_stretch
fi

if [[ -n $rotate ]]; then
  case $rotate in
    90 | 180 | 270 ) 
      TRACE "[$LINEON] Specified image rotation of $rotate degrees."
      ;; 
    *)
      ERROR "Invalid rotation specified: $rotate. Specify either 90, 180 or 270."
      synopsis
      exit 1
      ;;
  esac  
fi

# Input validate
if [[ ! -f $infile ]]; then
  ERROR "File $infile does not exist. Exiting..." 
  exit 1
fi

# If the input file is not a BMP file. convert it to one
if [[ ${infile##*.} != "bmp" ]]; then
  INFO "$infile is not a bitmap file. Converting it to $tmp1..."
  TRACE "[$LINENO] convert to BMP"
  convert $infile $tmp1  
  DEBUG "[$LINENO] $(identify $tmp1)"
else
  cp $infile $tmp1  
fi

if [[ -n $trim ]]; then
  INFO "Trim $infile..."
  TRACE "[$LINENO] convert -trim"
  convert $tmp1 -trim $tmp1
  DEBUG "[$LINENO] $(identify $tmp1)"
fi

if [[ -n $rotate ]]; then
  INFO "Rotate $infile  by $rotate degrees.."
  TRACE "[$LINENO] convert -rotate"
  convert $tmp1 -rotate $rotate $tmp1
  DEBUG "[$LINENO] $(identify $tmp1)"
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
  WARN "More than 1 bit per pixel is used in the source image - we will fix this now"  
fi

# Resize - first we start by leaving a border of 1 pixel all around
if [[ -z $height ]]; then
  if [[ -z $width ]]; then 
    TRACE "[$LINENO] Setting horizontal width to default of 32 and calculating height based on aspect ratio of the source image"
    width=32
    size_x=$((width-2))
    size_y=$(((width*H/W)-2)) 
    height=$((width*H/W))
  else
    TRACE "[$LINENO] Calculate height based on aspect ratio of the source image and given width of $width"
    size_x=$((width-2))
    size_y=$(((width*H/W)-2))
    height=$((width*H/W))
  fi
else
  if [[ -z $width ]]; then 
    TRACE "[$LINENO] Calculating width based on aspect ratio of the source image and given height of $height"
    size_x=$(((height*H/W)-2))
    width=$((height*H/W))
    size_y=$((height-2))    
  else
    TRACE "[$LINENO] Width and Length given on command line: ${width}x${height}"
    size_x=$((width-2))
    size_y=$((height-2))
  fi
fi
TRACE "[$LINENO] Working size is ${size_x}x${size_y} before adding 1 pixel border for final size ${width}x${height}."

if [[ $option_stretch -eq 1 ]]; then
  # Deform the image
  INFO "Deforming the image to fit inside the required size if necessary"
  TRACE "[$LINENO] convert -resize"
  convert $tmp1 -resize ${size_x}x${size_y}\! $tmp2
  DEBUG "[$LINENO] $(identify $tmp2)"
else
  # Keep the geometry of the original 
  INFO "Patching white-space around the image to fit inside the required size if necessary"
  TRACE "[$LINENO] convert -resize"
  convert $tmp1 -resize ${size_x}x${size_y} $tmp2 
  TRACE "[$LINENO] $(identify $tmp2)"
  TRACE "[$LINENO] convert -extent"
  convert $tmp2 -background white -gravity center -extent ${size_x}x${size_y} +repage $tmp2
  DEBUG "[$LINENO] $(identify $tmp2)"
fi

# Put a 1 pixel border around it 
size_x=$((size_x+2))
size_y=$((size_y+2))
INFO "Creating target image of size WxH: ${size_x}x${size_y} pixels"
TRACE "[$LINENO] Adding 1-pixel border"
convert $tmp2 -bordercolor white -border 1x1 $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
# Set the colour depth to 2 colours, so that we have a single bit per pixel in the end:
TRACE "[$LINENO] Set the colour depth to 2 colours"
convert $tmp2 -depth 2 $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
# Set the colour pallete to 2 colours:
TRACE "[$LINENO] Set the colour pallete to 2 colours:"
convert $tmp2 +dither -colors 2 -colorspace gray -contrast-stretch 0 $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
# Final tweak: Set to monochrome
TRACE "[$LINENO] Final tweak: Set to monochrome"
convert $tmp2 -monochrome $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
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
TRACE "[$LINENO] Imagesize is calculated to be $imagesize bytes, total working BMP-file size is $filesize"
chopbytes=$((filesize-imagesize))
TRACE "[$LINENO] Chopping leading $chopbytes bytes from image"
dd if=$tmp2 of=$tmp3 skip=${chopbytes} iflag=skip_bytes,count_bytes 2>/dev/null
if [[ $? -ne 0 ]]; then
  ERROR "There was an error lopping the BMP header from the 1-bit bitmap file $tmp2. Doing a HEX DUMP and then exiting."
  hexdump -C $tmp2 > /dev/stderr
  exit 1
fi 
# Final sanity check
filesize=$(stat -c%s $tmp3)
if [[ $filesize -ne $imagesize ]]; then
  ERROR "The file size does not tally with the calculated image data size in the 1-bit bitmap file $tmp3. Doing a BINARY DUMP and then exiting."
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
_infile=$(basename $infile)
imagename=$(echo ${_infile%.*} | sed -e 's/-/_/g')
# Rename the file that holds the result so that xxd can create the correct variable name from it
tmp5=$(printf "/tmp/%s.%dx%d" $imagename $size_x $size_y)
cp $tmp4 $tmp5
if [[ $option_output -eq 1 ]]; then
  # Current working directory
  outputfilename=$(printf "%s.h" $imagename)
  INFO "Generating C header file $outputfilename for source file $infile"
  printf "#ifndef _${imagename^^}_H_\n#define _${imagename^^}_H_\n\nconst " > $outputfilename
  if [[ ! -f $outputfilename ]]; then
    FATAL "Could not create the file $outputfilename here in $PWD. Exiting."
    exit 1
  fi
  xxd -i $tmp5 | sed -e 's/_tmp_//'  >> $outputfilename
  printf "\n#endif   /* _${imagename^^}_H_ */\n" >> $outputfilename
else 
  INFO "Generating C header file content for source file $infile"
  # Output to stdout  
  xxd -i $tmp5 | sed -e 's/_tmp_//'  
fi

# THE END.

