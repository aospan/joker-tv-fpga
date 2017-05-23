set -e

gcc -o usb3_mifgen-jokertv usb3_mifgen-jokertv.c -lm
./usb3_mifgen-jokertv
cp usb2_descrip.mif ../joker_tv/

echo "All done. Recompile Quartus project"
