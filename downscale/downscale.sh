#!/bin/bash

# START CLI Interface
#   DEFAULTS   #
# END DEFAULTS #

help_msg () {
      cat << EOF
downscale.sh
---------------
Description:
    A helper script to process MITgcm simulation output to create initial,
    boundary, and forcing conditions for a downscaled simulation. This 
    script is meant to be used with the downscale.py program and pymitgcm.py
    module.


Usage: 
  downscale.sh [--input_path ./] [--output_path ./downscale] [--iter0 0] 
               [--iterN 0] [--diter 1] [--refinement-factor 2] 
               [--south "0.0"] [--north "0.0"] [--east "0.0"] [--west "0.0"]
Options:
  --input_path        The path to exisiting MITgcm metadata output. This path must include
                      grid and ocean state files (U,V,W,T,S,Eta). [Default: "./"]

  --datafile_path     The path to the data* namelist files.
  
  --output_path       The output path for the initial, boundary, and forcing binary files. 
                      [Default: "./downscale"]
  
  --iter0             The initial MITgcm simulation iterate to start the processing at.
                      [Default: 0]
  
  --iterN             The final MITgcm simulation iterate to stop the processing at.
                      [Default: 0]
  
  --diter             The difference between sucessive iterates.
                      [Default: 1]

  --cheapaml_iter0    The first time level in the CheapAML files to use in post-processed output. [Default: 0]

  --cheapaml_iterN    The last time level in the CheapAML files to use in post-processed output. [Default: -1]

  --refinement-factor The integer factor to increase the resolution by for the downscaling.
                      [Default: 2]

  --south             The southern extent of the new domain in degrees N latitude. [Default: 0.0]
  
  --north             The northern extent of the new domain in degrees N latitude. [Default: 0.0]
  
  --west              The western extent of the new domain in degrees, relative to the parent grid. [Default: 0.0]
 
  --east              The eastern extent of the new domain in degrees, relative to the parent grid. [Default: 0.0]
  
  
  --help              Print this message.


Examples:

  downscale.sh --input_path /tank/topog/gulf-stream/simulation/MITGCM50_z75/run/production/metadata \\
               --datafile_path /tank/topog/gulf-stream/simulation/MITGCM50_z75/run/production/input \\
               --output_path /tank/topog/gulf-stream/simulation/MITGCM100_z75/input \\
               --iter0 108720 \\
               --iterN 1749600 \\
               --cheapaml_iter0 604 \\
               --cheapaml_iterN -1 \\
               --diter 720 \\
               --refinement-factor 2 \\
               --south "29.0" \\
               --north "41.215" \\
               --west "0.0" \\
               --east "15.0"


  This example reads in MITgcm simulation data in 

        "/tank/topog/gulf-stream/simulation/MITGCM50_z75/run/production/metadata"  

  using ocean state files
      * [U,V,W,T,S,Eta].0000108720.data
      * [U,V,W,T,S,Eta].0000109440.data
      * [U,V,W,T,S,Eta].0000110160.data
      * ...
      * [U,V,W,T,S,Eta].0001749600.data
  
  The ocean state files are processed to create initial conditions for a grid with 2x
  the resolution on the input grid. The grid is confined to [29.0N,41.215N] x [0.0E, 15.0E],
  with the longitude bounds set relative to the input grid. Boundary conditions are 
  created for the four boundaries of the domain in this process. 

  Downscaled atmospheric files are created by reading in the atmospheric files in the 
  input_path directory. Atmospheric files are assumed to be listed in the input_path/data.cheapaml
  file under the following paramters
    * UWindFile
    * VWindFile
    * SolarFile
    * TrFile
    * QrFile
    * cheap_dlwfile
    * cheap_prfile

  All output files are stored in the output directory

  
      "/tank/topog/gulf-stream/simulation/MITGCM100_z75/input"

  
EOF
      exit 0

}

while [ "$#" -ge "1" ]; do

  key="$1"
  case $key in

    --input_path)
      INPUT_PATH="$2"
      shift
      ;;

    --output_path)
      OUTPUT_PATH="$2"
      shift
      ;;

    --datafile_path)
      DATAFILE_PATH="$2"
      shift
      ;;

    --iter0)
      ITER0="$2"
      shift
      ;;

    --iterN)
      ITERN="$2"
      shift
      ;;

    --diter)
      DITER="$2"
      shift
      ;;

    --cheapaml_iter0)
      CHEAP_ITER0="$2"
      shift
      ;;

    --cheapaml_iterN)
      CHEAP_ITERN="$2"
      shift
      ;;

    --refinement-factor)
      FACTOR="$2"
      shift
      ;;

    --south)
      SOUTH="$2"
      shift
      ;;

    --north)
      NORTH="$2"
      shift
      ;;

    --west)
      WEST="$2"
      shift
      ;;

    --east)
      EAST="$2"
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

echo "downscale"
echo "------------------------------------"

mkdir -p $OUTPUT_PATH/prep


echo "Processing Atmospheric files ... "
atmkeys=("UWindFile" "VWindFile" "SolarFile" "TrFile" "QrFile" "cheap_dlwfile" "cheap_prfile")

for key in ${atmkeys[@]}; do

    thisFile=$(grep "$key" ${DATAFILE_PATH}/data.cheapaml | awk -F "=" '{print $2}' | sed "s/'//g" | sed "s/,//g")
    if [[ -f ${DATAFILE_PATH}/${thisFile} ]]; then
      echo "Found $key : ${DATAFILE_PATH}/${thisFile}"
      python3 downscale.py atmosphere "$INPUT_PATH" --iter0="$CHEAP_ITER0" \
                                                    --iterN="$CHEAP_ITERN" \
                                                    --south="$SOUTH" \
                                                    --north="$NORTH" \
                                                    --west="$WEST" \
                                                    --east="$EAST" \
                                                    --refine-factor="$FACTOR" \
                                                    --cheapaml-file="${DATAFILE_PATH}/${thisFile}" \
                                                    --outdir="${OUTPUT_PATH}"
  
    fi
done

for i in `seq $ITER0 $DITER $ITERN`; do

    echo "  > iterate : $i"
    if [[ "$i" == "$ITER0" ]]; then

      echo "  > > Initial conditions "
      python3 downscale.py init "$INPUT_PATH" --iterate="$i" \
                                              --south="$SOUTH" \
                                              --north="$NORTH" \
                                              --west="$WEST" \
                                              --east="$EAST" \
                                              --refine-factor="$FACTOR" \
                                              --outdir="${OUTPUT_PATH}/prep"

      printf -v iter "%010d" $i 
      mv ${OUTPUT_PATH}/prep/temperature.$iter.bin ${OUTPUT_PATH}/temperature.init.bin
      mv ${OUTPUT_PATH}/prep/salinity.$iter.bin ${OUTPUT_PATH}/salinity.init.bin

      mv ${OUTPUT_PATH}/prep/u.$iter.bin ${OUTPUT_PATH}/u.init.bin

      mv ${OUTPUT_PATH}/prep/v.$iter.bin ${OUTPUT_PATH}/v.init.bin

      mv ${OUTPUT_PATH}/prep/w.$iter.bin ${OUTPUT_PATH}/w.init.bin

      mv ${OUTPUT_PATH}/prep/eta.$iter.bin ${OUTPUT_PATH}/eta.init.bin

      mv ${OUTPUT_PATH}/prep/xc.bin ${OUTPUT_PATH}/xc.bin
      mv ${OUTPUT_PATH}/prep/yc.bin ${OUTPUT_PATH}/yc.bin
      mv ${OUTPUT_PATH}/prep/dxc.bin ${OUTPUT_PATH}/dxc.bin
      mv ${OUTPUT_PATH}/prep/dyc.bin ${OUTPUT_PATH}/dyc.bin
      mv ${OUTPUT_PATH}/prep/drf.bin ${OUTPUT_PATH}/drf.bin

    fi

    # Process boundary conditions
    echo "  > > Boundary Conditions "
    python3 downscale.py boundary "$INPUT_PATH" --iterate="$i" \
                                              --south="$SOUTH" \
                                              --north="$NORTH" \
                                              --west="$WEST" \
                                              --east="$EAST" \
                                              --refine-factor="$FACTOR" \
                                              --outdir="${OUTPUT_PATH}/prep" >> ${OUTPUT_PATH}/logs.txt
    
    printf -v iter "%010d" $i 
    # Accumulate boundary conditions
    cat ${OUTPUT_PATH}/prep/temperature.south.${iter}.bin >> ${OUTPUT_PATH}/temperature.south.bin
    cat ${OUTPUT_PATH}/prep/temperature.north.${iter}.bin >> ${OUTPUT_PATH}/temperature.north.bin
    cat ${OUTPUT_PATH}/prep/temperature.east.${iter}.bin >> ${OUTPUT_PATH}/temperature.east.bin
    cat ${OUTPUT_PATH}/prep/temperature.west.${iter}.bin >> ${OUTPUT_PATH}/temperature.west.bin

    cat ${OUTPUT_PATH}/prep/salinity.south.${iter}.bin >> ${OUTPUT_PATH}/salinity.south.bin
    cat ${OUTPUT_PATH}/prep/salinity.north.${iter}.bin >> ${OUTPUT_PATH}/salinity.north.bin
    cat ${OUTPUT_PATH}/prep/salinity.east.${iter}.bin >> ${OUTPUT_PATH}/salinity.east.bin
    cat ${OUTPUT_PATH}/prep/salinity.west.${iter}.bin >> ${OUTPUT_PATH}/salinity.west.bin

    cat ${OUTPUT_PATH}/prep/u.south.${iter}.bin >> ${OUTPUT_PATH}/u.south.bin
    cat ${OUTPUT_PATH}/prep/u.north.${iter}.bin >> ${OUTPUT_PATH}/u.north.bin
    cat ${OUTPUT_PATH}/prep/u.east.${iter}.bin >> ${OUTPUT_PATH}/u.east.bin
    cat ${OUTPUT_PATH}/prep/u.west.${iter}.bin >> ${OUTPUT_PATH}/u.west.bin

    cat ${OUTPUT_PATH}/prep/v.south.${iter}.bin >> ${OUTPUT_PATH}/v.south.bin
    cat ${OUTPUT_PATH}/prep/v.north.${iter}.bin >> ${OUTPUT_PATH}/v.north.bin
    cat ${OUTPUT_PATH}/prep/v.east.${iter}.bin >> ${OUTPUT_PATH}/v.east.bin
    cat ${OUTPUT_PATH}/prep/v.west.${iter}.bin >> ${OUTPUT_PATH}/v.west.bin

    cat ${OUTPUT_PATH}/prep/w.south.${iter}.bin >> ${OUTPUT_PATH}/w.south.bin
    cat ${OUTPUT_PATH}/prep/w.north.${iter}.bin >> ${OUTPUT_PATH}/w.north.bin
    cat ${OUTPUT_PATH}/prep/w.east.${iter}.bin >> ${OUTPUT_PATH}/w.east.bin
    cat ${OUTPUT_PATH}/prep/w.west.${iter}.bin >> ${OUTPUT_PATH}/w.west.bin

    cat ${OUTPUT_PATH}/prep/eta.south.${iter}.bin >> ${OUTPUT_PATH}/eta.south.bin
    cat ${OUTPUT_PATH}/prep/eta.north.${iter}.bin >> ${OUTPUT_PATH}/eta.north.bin
    cat ${OUTPUT_PATH}/prep/eta.east.${iter}.bin >> ${OUTPUT_PATH}/eta.east.bin
    cat ${OUTPUT_PATH}/prep/eta.west.${iter}.bin >> ${OUTPUT_PATH}/eta.west.bin

    rm ${OUTPUT_PATH}/prep/temperature.south.${iter}.bin
    rm ${OUTPUT_PATH}/prep/temperature.north.${iter}.bin
    rm ${OUTPUT_PATH}/prep/temperature.east.${iter}.bin
    rm ${OUTPUT_PATH}/prep/temperature.west.${iter}.bin

    rm ${OUTPUT_PATH}/prep/salinity.south.${iter}.bin
    rm ${OUTPUT_PATH}/prep/salinity.north.${iter}.bin
    rm ${OUTPUT_PATH}/prep/salinity.east.${iter}.bin
    rm ${OUTPUT_PATH}/prep/salinity.west.${iter}.bin

    rm ${OUTPUT_PATH}/prep/u.south.${iter}.bin
    rm ${OUTPUT_PATH}/prep/u.north.${iter}.bin
    rm ${OUTPUT_PATH}/prep/u.east.${iter}.bin
    rm ${OUTPUT_PATH}/prep/u.west.${iter}.bin

    rm ${OUTPUT_PATH}/prep/v.south.${iter}.bin
    rm ${OUTPUT_PATH}/prep/v.north.${iter}.bin
    rm ${OUTPUT_PATH}/prep/v.east.${iter}.bin
    rm ${OUTPUT_PATH}/prep/v.west.${iter}.bin

    rm ${OUTPUT_PATH}/prep/w.south.${iter}.bin
    rm ${OUTPUT_PATH}/prep/w.north.${iter}.bin
    rm ${OUTPUT_PATH}/prep/w.east.${iter}.bin
    rm ${OUTPUT_PATH}/prep/w.west.${iter}.bin

    rm ${OUTPUT_PATH}/prep/eta.south.${iter}.bin
    rm ${OUTPUT_PATH}/prep/eta.north.${iter}.bin
    rm ${OUTPUT_PATH}/prep/eta.east.${iter}.bin
    rm ${OUTPUT_PATH}/prep/eta.west.${iter}.bin

done
