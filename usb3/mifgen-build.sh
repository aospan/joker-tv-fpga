set -e

gcc -g -o usb3_mifgen-jokertv usb3_mifgen-jokertv.c -lm
./usb3_mifgen-jokertv -r 50
cp usb2_descrip.mif ../joker_tv/

echo "All done. usb2_descrip.mif file generated. Recompile Quartus project"
