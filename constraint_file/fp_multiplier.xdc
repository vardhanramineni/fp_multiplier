## ============================================================================
## Constraint File : fp_multiplier.xdc
## Device          : xc7a100tcsg324-1  (Artix-7, CSG324 package, -1 speed)
## Purpose         : Implementation only — power, utilization, timing analysis
##                   No board I/O mapping required.
## ============================================================================

## ----------------------------------------------------------------------------
## Virtual Clock
## A virtual clock with a 10 ns period (100 MHz) is defined without being
## attached to any physical pin. This gives the timing engine a reference
## to report setup/hold slack, critical path delay, and power estimates
## against a realistic target frequency.
## Change the period value here to target a different frequency.
## ----------------------------------------------------------------------------
create_clock -period 10.000 -name vclk_100MHz -waveform {0.000 5.000}


## ----------------------------------------------------------------------------
## Input / Output Delays
## Applied to all top-level ports so the timing engine can compute the full
## data-path delay from input pins through the combinational multiplier logic
## to output pins. Values assume a 2 ns PCB/package delay model.
## ----------------------------------------------------------------------------
#set_input_delay  -clock vclk_100MHz -max 2.000 [get_ports {a[*]}]
#set_input_delay  -clock vclk_100MHz -min 0.500 [get_ports {a[*]}]

#set_input_delay  -clock vclk_100MHz -max 2.000 [get_ports {b[*]}]
#set_input_delay  -clock vclk_100MHz -min 0.500 [get_ports {b[*]}]

#set_output_delay -clock vclk_100MHz -max 2.000 [get_ports {p[*]}]
#set_output_delay -clock vclk_100MHz -min 0.500 [get_ports {p[*]}]


## ----------------------------------------------------------------------------
## Configuration Properties (required by Vivado for Artix-7 implementation)
## ----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE    3.3  [current_design]
set_property CFGBVS            VCCO [current_design]

## ============================================================================
## END OF CONSTRAINT FILE
## ============================================================================
