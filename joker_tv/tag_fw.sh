#!/bin/bash
set -e

if [ -z "$@" ];
then
	echo "Please specify firmware revision"
	echo "Usage: $0 fw_ver"
	echo "	Example: $0 28"
	false
fi

fw_ver=0.$@
dir=fw-$fw_ver
echo tagging fw to $fw_ver

mkdir $dir
cp joker_tv.jic $dir/joker_tv-$fw_ver.jic
(cd $dir && zip joker_tv-$fw_ver-jic.zip joker_tv-$fw_ver.jic && rm joker_tv-$fw_ver.jic && cp joker_tv-$fw_ver-jic.zip joker_tv-latest-jic.zip)
cp joker_tv.bin $dir/joker_tv-fw-$fw_ver.bin
cp joker_tv.bin $dir/joker_tv-fw-latest.bin

echo "Done. Result written to $dir directory"
