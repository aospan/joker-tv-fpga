transcript on
set tcl_interactive true

# load simulation
vsim joker_control_tb_spi

# Open some selected windows for viewing
view structure
view signals
view wave

#show waves
add wave /joker_control_tb_spi/*
add wave /joker_control_tb_spi/USBEP/*
add wave /joker_control_tb_spi/USBEP_IN/*
add wave /joker_control_tb_spi/DUT/*
add wave /joker_control_tb_spi/DUT/joker_spi_inst/*
add wave /joker_control_tb_spi/DUT/joker_spi_inst/i_spi_top/*
add wave /joker_control_tb_spi/i_spi_slave/*
add wave /joker_control_tb_spi/DUT/joker_spi_inst/i_spi_top/shift/*
add wave /joker_control_tb_spi/DUT/joker_spi_inst/i_spi_top/clgen/*
wave zoom range 0 1000ns

run 10us
mem display -startaddress 0 -endaddress 10 /joker_control_tb_spi/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
mem display -startaddress 1024 -endaddress 1034 /joker_control_tb_spi/USBEP/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data

mem display -startaddress 0 -endaddress 10 /joker_control_tb_spi/USBEP_IN/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
mem display -startaddress 1024 -endaddress 1034 /joker_control_tb_spi/USBEP_IN/iu2ep/altsyncram_component/m_default/altsyncram_inst/mem_data
