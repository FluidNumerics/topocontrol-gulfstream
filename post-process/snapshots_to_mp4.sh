#!/bin/bash
#
# Usage
#
#   snapshots_to_mp4.sh --pattern /path/to/images.*.png
#                 --fps 60
#                 --size "1920x1080"
#                 --out /path/to/output
#


# START CLI Interface

#   DEFAULTS   #
OUT="./movie.mp4"
PATTERN="*.png"
FPS=60
SIZE="1920x1080"
# END DEFAULTS #

help_msg () {
      cat << EOF


snapshots_to_mp4
---------------

Description:
    A helper script to process individual frames to mp4 with ffmpeg 
    using a few standard settings. This script is meant to be used 
    with other post-processing scripts in the topocontrol-gulfstream 
    repository.


Usage: 
  snapshots_to_mp4.sh [--pattern ./*.png] [--fps 60] [--size "1920x1080"] [--out ./movie.mp4]

Options:

  --pattern        Search pattern for all of your individual "snapshots" 
                   that you want to compile into a video. [Default: ./*.png]
  
  --fps            The resulting frames-per-second for your mp4. [Default: 60]
  
  --size           The size of video in "X x Y" format. [Default: "1920x1080"]
  
  --out            The full path to the output file for the mp4. 
                   [Default: ./movie.mp4]
  
  --help           Print this message.

EOF
      exit 0

}

while [ "$#" -ge "1" ]; do

  key="$1"
  case $key in

    --out)
      OUTDIR="$2"
      shift
      ;;

    --pattern)
      PATTERN="$2"
      shift
      ;;

    --fps)
      FPS="$2"
      shift
      ;;

    --size)
      SIZE="$2"
      shift
      ;;

    --help)
      help_msg
      ;;
  esac
  shift
done

# END CLI Interface
# /////////////////////////////// #

echo "snapshots_to_mp4"
echo "------------------------------------"
echo "Search pattern : "${PATTERN}
echo "Using FPS : "${FPS}
echo "Using size : "${SIZE}
echo "Using output :"${OUT}

k=0
for f in ${PATTERN};
do
    printf -v id "%05d" $k
    mv $f frame_$id.png
    ((k=k+1))
done

ffmpeg -r ${FPS} -f image2 -s ${SIZE} -i frame_%05d.png -vcodec libx264 -crf 25 -pix_fmt yuv420p ${OUT}

rm frame_*.png
