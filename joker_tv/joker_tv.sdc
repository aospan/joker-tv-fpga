## Generated SDC file "joker_tv.sdc"

## Copyright (C) 2017  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 17.1.0 Build 590 10/25/2017 SJ Lite Edition"

## DATE    "Thu Mar  1 09:00:04 2018"

##
## DEVICE  "EP4CE22F17C8"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {SYSCLK} -period 37.037 -waveform { 0.000 18.518 } [get_ports {clk_27}]
create_clock -name {ATSC_CLOCK} -period 16.666 -waveform { 0.000 8.333 } [get_ports {lg_clk}]
create_clock -name {DTMB_CLOCK} -period 16.666 -waveform { 0.000 8.333 } [get_ports {TS_ATBM8881_CLK}]
create_clock -name {SONY_CLOCK} -period 5.555 -waveform { 0.000 2.777 } [get_ports {sony_clk}]
create_clock -name {usb_ulpi_clk} -period 16.666 -waveform { 0.000 8.333 } [get_ports {usb_ulpi_clk}]
create_clock -name {CI_MCLKO} -period 40.000 -waveform { 0.000 20.000 } [get_ports { CI_MCLKO }]
create_clock -name {CI_MCLKI} -period 111.111 -waveform { 0.000 55.555 } [get_ports { CI_MCLKI }]
create_clock -name {usb0_rx_launch_clock} -period 4.000 -waveform { 1.000 3.000 } 


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {apll|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {apll|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 50 -divide_by 27 -master_clock {SYSCLK} [get_pins {apll|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {apll|altpll_component|auto_generated|pll1|clk[1]} -source [get_pins {apll|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 1 -divide_by 3 -master_clock {SYSCLK} [get_pins {apll|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -name {CI_MCLKO_v} -source [get_ports {CI_MCLKO}] -master_clock {CI_MCLKO} 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {CI_MCLKI}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {CI_MCLKI}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {CI_MCLKI}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {CI_MCLKI}] -hold 0.070  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {CI_MCLKI}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {CI_MCLKI}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {CI_MCLKI}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {CI_MCLKI}] -hold 0.070  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -rise_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {usb_ulpi_clk}] -setup 0.110  
set_clock_uncertainty -fall_from [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {usb_ulpi_clk}] -hold 0.090  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.110  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.110  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {SONY_CLOCK}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {SONY_CLOCK}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {DTMB_CLOCK}]  0.040  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {DTMB_CLOCK}]  0.040  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {ATSC_CLOCK}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {ATSC_CLOCK}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.110  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[1]}] -hold 0.110  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.090  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {apll|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.110  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {SONY_CLOCK}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {SONY_CLOCK}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {DTMB_CLOCK}]  0.040  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {DTMB_CLOCK}]  0.040  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -rise_to [get_clocks {ATSC_CLOCK}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {usb_ulpi_clk}] -fall_to [get_clocks {ATSC_CLOCK}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {SONY_CLOCK}] -rise_to [get_clocks {usb_ulpi_clk}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {SONY_CLOCK}] -fall_to [get_clocks {usb_ulpi_clk}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {SONY_CLOCK}] -rise_to [get_clocks {usb_ulpi_clk}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {SONY_CLOCK}] -fall_to [get_clocks {usb_ulpi_clk}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {CI_MCLKO}] -rise_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {CI_MCLKO}] -fall_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {CI_MCLKO}] -rise_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {CI_MCLKO}] -fall_to [get_clocks {usb_ulpi_clk}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {DTMB_CLOCK}] -rise_to [get_clocks {usb_ulpi_clk}]  0.040  
set_clock_uncertainty -rise_from [get_clocks {DTMB_CLOCK}] -fall_to [get_clocks {usb_ulpi_clk}]  0.040  
set_clock_uncertainty -rise_from [get_clocks {DTMB_CLOCK}] -rise_to [get_clocks {DTMB_CLOCK}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {DTMB_CLOCK}] -fall_to [get_clocks {DTMB_CLOCK}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {DTMB_CLOCK}] -rise_to [get_clocks {usb_ulpi_clk}]  0.040  
set_clock_uncertainty -fall_from [get_clocks {DTMB_CLOCK}] -fall_to [get_clocks {usb_ulpi_clk}]  0.040  
set_clock_uncertainty -fall_from [get_clocks {DTMB_CLOCK}] -rise_to [get_clocks {DTMB_CLOCK}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {DTMB_CLOCK}] -fall_to [get_clocks {DTMB_CLOCK}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {ATSC_CLOCK}] -rise_to [get_clocks {usb_ulpi_clk}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {ATSC_CLOCK}] -fall_to [get_clocks {usb_ulpi_clk}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {ATSC_CLOCK}] -rise_to [get_clocks {usb_ulpi_clk}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {ATSC_CLOCK}] -fall_to [get_clocks {usb_ulpi_clk}]  0.030  


#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -add_delay -clock_fall -max -clock [get_clocks {CI_MCLKO_v}]  2.400 [get_ports {CI_MOSTRT CI_MOVAL CI_MDO*}]
set_input_delay -add_delay -clock_fall -min -clock [get_clocks {CI_MCLKO_v}]  -2.400 [get_ports {CI_MOSTRT CI_MOVAL CI_MDO*}]

#**************************************************************
# Set Output Delay
#**************************************************************

# aospan:
# from en50221:
# Item Symbol Min Max
# Clock period tclkp 111 ns
# Clock High time tclkh 40 ns
# Clock Low time tclkl 40 ns
# Input Data Setup tsu 15 ns
# Input Data Hold th 10 ns
# Output Data Setup tosu 20 ns
# Output Data Hold toh 15 ns

set_output_delay -add_delay -max -clock [get_clocks {CI_MCLKI}]  20.000 [get_ports {CI_MISTRT CI_MIVAL CI_MDI*}]
set_output_delay -add_delay -min -clock [get_clocks {CI_MCLKI}]  -20.000 [get_ports {CI_MISTRT CI_MIVAL CI_MDI*}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from [get_keepers {*rdptr_g*}] -to [get_keepers {*ws_dgrp|dffpipe_id9:dffpipe16|dffe17a*}]
set_false_path -from [get_keepers {*delayed_wrptr_g*}] -to [get_keepers {*rs_dgwp|dffpipe_hd9:dffpipe12|dffe13a*}]
set_false_path -from [get_keepers {*rdptr_g*}] -to [get_keepers {*ws_dgrp|dffpipe_kd9:dffpipe9|dffe10a*}]
set_false_path -from [get_keepers {*delayed_wrptr_g*}] -to [get_keepers {*rs_dgwp|dffpipe_jd9:dffpipe6|dffe7a*}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

