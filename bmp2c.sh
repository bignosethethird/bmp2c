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
  rm $tmp6 2>/dev/null  
  sync
}
for sig in KILL TERM INT EXIT; do trap "cleanup $sig" "$sig" ; done

#============================================================================#
# Global variables
#============================================================================#
PROGNAME=${0##*/}
PROGNAME=${PROGNAME%.*}
COMMAND="$PROGNAME $@"
tmp1=$(mktemp "/tmp/tmp.${PROGNAME}.XXXXXX.bmp")
tmp2=$(mktemp "/tmp/tmp.${PROGNAME}.XXXXXX.bmp")
tmp3=$(mktemp "/tmp/tmp.${PROGNAME}.XXXXXX.raster")
tmp4=$(mktemp "/tmp/tmp.${PROGNAME}.XXXXXX.raster")
tmp5=$(mktemp "/tmp/tmp.${PROGNAME}.XXXXXX.raster")

#NOW=$(date +"%Y-%m-%d %H:%M:%S")
#TODAY=$(date +"%d %b %Y")
#YEAR=$(date +"%Y")
#ISODATE=$(date +%Y%m%d)
#EXITCODE=0
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
  TS=$(date '+%Y/%m/%d %H:%M:%S')
  printf "[$TS][FATAL][${PROGNAME}][${ENVIRONMENT}] $@\n" >&2 2 > >(tee -a $LOGFILE >&2)
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
bmp2c image-filepath [-h|--height=height pixels] [-w|--width=width pixels]
    [-r|--rotate={90|180|270|-90}] [-i|--invert] [-o|--output] [-p|--progmem] 
    [-s|--stretch] [-t|--trim] [-v|--verbose | -d|--debug | -q|--quiet] 
    [--help]
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

PARAMETERS
  image-filepath    
          The filepath of the source image. It can be any type of image file 
          and of any size or form factor. This must be the first parameter.

OPTIONS (Note that there is an '=' sign between argument and value):
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
  -i, --invert Option
          Inverts black to white pixels and white to black pixels
  -o, --output Option
          Produce output header file named according to the source image 
          filename, without having to do any redirection. The ouput file will
          created in the current working directory, with an .h extension.          
  -p, --progmem Option
          The PROGMEM directive is added to the generated C-array to store it
          in flash program memory instead of SRAM. This is essential for some
          MCUs, especially the ones used in Arduino boards.
  -r, --rotate=[degrees to rotate]
          Rotate the source image either by 90°, 180° or 270°/-90°. 
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
  -v, --verbose Option
          Verbose screen output to stderr. All output will also be logged.
  -d, --debug Option
          Output debug messages to stderr screen and log.           
  -q, --quiet Option
          Does not produce any process commentary to stderr nor does logging.
  --help Option
          Displays this text..

!
}

#============================================================================#
# Main
#============================================================================#

if [[ -z $1 ]] ; then
  synopsis
  exit 1
fi

if [[ $1 != "-*" ]]; then
  infile=$1
  shift
fi      

while [[ $1 = -* ]]; do
  ARG=$(echo $1|cut -d'=' -f1)
  VAL=$(echo $1|cut -d'=' -f2)

  case $ARG in
    "--debug" | "-d" )
      option_debug=1
      option_verbose=1
      ;;
    "--file" | "-f")  # old-style
      if [[ -z $infile ]]; then
        infile=$VAL; [[ $VAL = "$ARG" ]] && shift && infile=$1
      fi
      ;;
    "--height" | "-h")
      if [[ -z $height ]]; then
        height=$VAL; [[ $VAL = "$ARG" ]] && shift && height=$1        
      fi
      ;;
    "--invert" | "-i" )
      option_invert=1
      ;;
    "--output" | "-o" )
      option_output=1
      ;;
    "--progmem" | "-p" )
      option_progmem=1
      ;;
    "--quiet" | "-q" )
      option_quiet=1
      ;;
    "--rotate" | "-r")
      if [[ -z $rotate ]]; then
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
    "--width" | "-w")
      if [[ -z $width ]]; then
        width=$VAL; [[ $VAL = "$ARG" ]] && shift && width=$1        
      fi
      ;;
    "--help" )      
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

# Input validate
[[ ! -f $infile ]] && LOGDIE "File $infile does not exist. Exiting..." 

# parameter validate
if [[ -z $width || -z $height ]] && [[ $option_stretch -eq 1 ]]; then
  WARN "Ignoring the stretch option, since either the width or the height have not been specified"
  unset option_stretch
fi

if [[ -n $rotate ]]; then
  case $rotate in
    90 | 180 | 270 ) 
      TRACE "[$LINENO] Specified image rotation of $rotate degrees."
      ;; 
   -90 ) 
     rotate=270
     ;;
    *)
      ERROR "Invalid rotation specified: $rotate. Specify either 90, 180 or 270."
      synopsis
      exit 1
      ;;
  esac  
fi


# If the input file is not a BMP file. convert it to one
if [[ ${infile##*.} != "bmp" ]]; then
  INFO "$infile is not a bitmap file. Converting it to $tmp1..."
  TRACE "[$LINENO] convert $infile $tmp1"
  convert $infile $tmp1  
  DEBUG "[$LINENO] $(identify $tmp1)"
else
  cp $infile $tmp1  
fi

if [[ -n $option_trim ]]; then
  INFO "Trim $infile..."
  TRACE "[$LINENO] convert $tmp1 -trim $tmp1"
  convert $tmp1 -trim $tmp1
  DEBUG "[$LINENO] $(identify $tmp1)"
fi

if [[ -n $rotate ]]; then
  INFO "Rotate $infile  by $rotate degrees.."
  TRACE "[$LINENO] convert $tmp1 -rotate $rotate $tmp1"
  convert $tmp1 -rotate $rotate $tmp1
  DEBUG "[$LINENO] $(identify $tmp1)"
fi

# Get technical details from BMP file
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
  TRACE "[$LINENO] convert $tmp1 -resize ${size_x}x${size_y}\! $tmp2"
  convert $tmp1 -resize ${size_x}x${size_y}\! $tmp2
  DEBUG "[$LINENO] $(identify $tmp2)"
else
  # Keep the geometry of the original 
  INFO "Patching white-space around the image to fit inside the required size if necessary"
  TRACE "[$LINENO] convert $tmp1 -resize ${size_x}x${size_y} $tmp2 "
  convert $tmp1 -resize ${size_x}x${size_y} $tmp2 
  TRACE "[$LINENO] $(identify $tmp2)"
  TRACE "[$LINENO] convert $tmp2 -background white -gravity center -extent ${size_x}x${size_y} +repage $tmp2"
  convert $tmp2 -background white -gravity center -extent ${size_x}x${size_y} +repage $tmp2
  DEBUG "[$LINENO] $(identify $tmp2)"
fi

# Put a 1 pixel border around it 
size_x=$((size_x+2))
size_y=$((size_y+2))
INFO "Creating target image of size WxH: ${size_x}x${size_y} pixels"
TRACE "[$LINENO] Adding 1-pixel border: convert $tmp2 -bordercolor white -border 1x1 $tmp2"
convert $tmp2 -bordercolor white -border 1x1 $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
# Set the colour depth to 2 colours, so that we have a single bit per pixel in the end:
TRACE "[$LINENO] Set the colour depth to 2 colours: convert $tmp2 -depth 2 $tmp2"
convert $tmp2 -depth 2 $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
# Set the colour pallete to 2 colours:
TRACE "[$LINENO] Set the colour pallete to 2 colours: convert $tmp2 +dither -colors 2 -colorspace gray -contrast-stretch 0 $tmp2"
convert $tmp2 +dither -colors 2 -colorspace gray -contrast-stretch 0 $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
# Final tweak: Set to monochrome
TRACE "[$LINENO] Final tweak: Set to monochrome: convert $tmp2 -monochrome $tmp2"
convert $tmp2 -monochrome $tmp2
DEBUG "[$LINENO] $(identify $tmp2)"
# Check that we have 2 colours and 1 bit per pixel:
identify $tmp2 | grep "1-bit" > /dev/null
if [[ $? -ne 0 ]]; then
  ERROR "Failed to convert $infile to a 2-colour file. Exiting..."
  exit 1
fi 


# Deterrmine image offset from technical BMP header
image_offset=$(hexdump -v -e '/1 "%02X "' $tmp2 | awk '{printf "%s%s%s%s", $14, $13, $12, $11 }' | sed -e 's/ //g')
image_offset=$((16#$image_offset))
filesize=$(stat -c%s $tmp2)
imagesize=$((size_x * size_y / 8))

# Chop BMP header so that we only remain with the raster data
DEBUG "[$LINENO] BMP-file size is $filesize. Imagesize is calculated to be $imagesize bytes. Chopping leading $image_offset bytes from image."
TRACE "[$LINENO] dd if=$tmp2 of=$tmp3 skip=${image_offset} iflag=skip_bytes,count_bytes 2>/dev/null"
dd if=$tmp2 of=$tmp3 skip=${image_offset} iflag=skip_bytes,count_bytes 2>/dev/null
if [[ $? -ne 0 ]]; then
  ERROR "There was an error lopping the BMP header from the 1-bit bitmap file $tmp2. Doing a HEX DUMP and then exiting."
  hexdump -C $tmp2 > /dev/stderr
  exit 1
fi 

# Check if image data words are padded out with 0-value words
offset_calculated=$((filesize-imagesize))
if [[ $offset_calculated -eq $image_offset ]]; then
  TRACE "[$LINENO] No word padding in image data"
  cp $tmp3 $tmp4
else
  TRACE "[$LINENO] Word padding in image data - remove every second zero word"
  hexdump -v -e '/1 "%02X "' $tmp3 | sed -e 's/\([0-9A-F]\{2\}\) \([0-9A-F]\{2\}\) \([0-9A-F]\{2\}\) \([0-9A-F]\{2\}\) /\1 \2 /g' |  sed -e 's/ / 0x/g' | xxd -r -p  > $tmp4
fi

# Final sanity check
filesize=$(stat -c%s $tmp4)
if [[ $filesize -ne $imagesize ]]; then
  ERROR "The final file size does not tally with the calculated image data size in the 1-bit bitmap file $tmp4. Doing a BINARY DUMP and then exiting."
  xxd -b -c 4 $tmp4 > /dev/stderr
  exit 1
fi 

# reversing the content on a bit-wise basis
rm $tmp5 2>/dev/null
binstr=$(xxd -b -c 1 $tmp4 | cut -f 2 -d " " | sed -E 's/(.)/\1 /g' | tr '\n' ' ' | sed -E 's/ //g' | rev )
# Now i a good time to invert the bits if required...
if [[ -n $option_invert ]]; then
  TRACE  "[$LINENO] Swapping 0s and 1s around"
  binstr=$(echo $binstr | sed -e 's/1/w/g' | sed -e 's/0/1/g' | sed -e 's/w/0/g')
fi
binstrlen=${#binstr}
for ((i=0;i<$binstrlen;i+=8)); do 
  binchar=${binstr:$i:8}  
  printf "%02X " $((2#${binchar})) | xxd -r -p >> $tmp5
done

# Creating output
_infile=$(basename $infile)
imagename=$(echo ${_infile%.*} | sed -e 's/-/_/g')
# Rename the file that holds the result so that xxd can create the correct variable name from it
tmp6=$(printf "/tmp/%s.%dx%d" $imagename $size_x $size_y)
cp $tmp5 $tmp6
if [[ $option_output -eq 1 ]]; then
  # Output to C header file in current working directory
  outputfilename=$(printf "%s.h" $imagename)
  INFO "Generating C header file $outputfilename for source file $infile"
  printf "#ifndef _%s_H_\n#define _%s_H_\n\n" ${imagename^^} ${imagename^^} > $outputfilename
  if [[ ! -f $outputfilename ]]; then
    LOGDIE "Could not create the file $outputfilename here in $PWD. Exiting."    
  fi
  printf "// Auto-generated file: %s\n\n" "$COMMAND" >> $outputfilename
  printf "const " >> $outputfilename
  if [[ $option_progmem -eq 1 ]]; then
    xxd -i $tmp6 | sed -e 's/_tmp_//' -e 's/= {/PROGMEM = {/' >> $outputfilename
  else
    xxd -i $tmp6 | sed -e 's/_tmp_//'  >> $outputfilename
  fi
  printf "\n#endif   /* _%s_H_ */\n" ${imagename^^} >> $outputfilename
else 
  INFO "Generating C header file content only for source file $infile to stdout"
  # Output to stdout  
  printf "// Auto-generated file: %s\n\n" "$COMMAND"
  xxd -i $tmp6 | sed -e 's/_tmp_//'  
fi

# THE END.

