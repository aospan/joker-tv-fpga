proc tsdo {} {
	run 800ns
	mem display -startaddress 0 -endaddress 20 /ts_proxy_tb/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
	mem display -startaddress 1024 -endaddress 1032 /ts_proxy_tb/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
}

transcript on
set tcl_interactive true

#TODO: compile all required Verilog/VHDL files
#vlib work-new
#/mnt/sdd/altera/16.1/quartus/eda/sim_lib/altera_mf.v
vlog -work work /home/aospan/work-tb/ts_proxy.v
vlog -work work /home/aospan/work-tb/ts_proxy_tb.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/usb2_ep.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/mf_usb2_ep.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/targets/usb/tsfifo.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/usb2_ulpi.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/usb2_packet.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/usb2_protocol.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/usb2_top.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/usb2_crc.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/usb2_ep0.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/mf_usb2_ep0in.v
vlog -work work /mnt/sdd/src/universal/fpga-with-i2c/daisho/common/usb3/mf_usb2_descrip.v


# load simulation
vsim ts_proxy_tb

# Open some selected windows for viewing
view structure
view signals
view wave

#show waves
add wave /ts_proxy_tb/*
add wave /ts_proxy_tb/USBTOP/*
#ep3
add wave /ts_proxy_tb/USBTOP/ipr/iep3/*
#ulpi
add wave /ts_proxy_tb/USBTOP/ia/*
#packet
add wave /ts_proxy_tb/USBTOP/ip/*
#protocol
add wave /ts_proxy_tb/USBTOP/ipr/*
#add wave /ts_proxy_tb/USBEP/*
add wave /ts_proxy_tb/DUT/*
add wave /ts_proxy_tb/DUT/tssel/ATSC_DESER_0/*
add wave /ts_proxy_tb/DUT/tssel/ATSC_SYNC_0/*
wave zoom range 0 1600ns

run 80us
#run 1600ns
#mem display -startaddress 0 -endaddress 7 /ts_proxy_tb/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
#mem display -startaddress 1024 -endaddress 1031 /ts_proxy_tb/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data

#mem display -startaddress 0 -endaddress 7 /ts_proxy_tb/USBTOP/ipr/iep3/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
#mem display -startaddress 1024 -endaddress 1031 /ts_proxy_tb/USBTOP/ipr/iep3/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
mem display -startaddress 0 -endaddress 1100 /ts_proxy_tb/USBTOP/ipr/iep3/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
