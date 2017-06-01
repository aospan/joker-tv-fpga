transcript on
set tcl_interactive true

# load simulation
vsim joker_control_tb

# Open some selected windows for viewing
view structure
view signals
view wave

#show waves
add wave /joker_control_tb/*
add wave /joker_control_tb/USBEP/*
add wave /joker_control_tb/USBEP_IN/*
add wave /joker_control_tb/DUT/*
add wave /joker_control_tb/DUT/i2c_inst/*
add wave /joker_control_tb/DUT/i2c_inst/i2c_master_top_inst/*
add wave /joker_control_tb/DUT/i2c_inst/i2c_master_top_inst/byte_controller/*
add wave /joker_control_tb/DUT/i2c_inst/i2c_master_top_inst/byte_controller/bit_controller/*
wave zoom range 0 1600ns

run 40us
mem display -startaddress 0 -endaddress 10 /joker_control_tb/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
mem display -startaddress 1024 -endaddress 1034 /joker_control_tb/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data

mem display -startaddress 0 -endaddress 10 /joker_control_tb/USBEP_IN/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
mem display -startaddress 1024 -endaddress 1034 /joker_control_tb/USBEP_IN/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
