/mnt/sdd/altera/16.1/nios2eds/nios2_command_shell.sh java -Xmx512m -jar /mnt/sdb/altera/16.1/nios2eds/bin/sof2flash.jar --input=output_files/joker_tv.sof --output=joker_tv.srec --compress --epcs --offset=0
/mnt/sdd/altera/16.1/nios2eds/nios2_command_shell.sh /mnt/sdd/altera/16.1/nios2eds/bin/gnu/H-x86_64-pc-linux-gnu/bin/nios2-elf-objcopy -I srec -O binary joker_tv.srec joker_tv.bin

echo "Generated joker_tv.bin"
