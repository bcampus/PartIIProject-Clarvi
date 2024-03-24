# TCL File Generated by Component Editor 22.1
# Sat Mar 23 15:47:26 GMT 2024
# DO NOT MODIFY


# 
# my_pio "my_pio" v1.0
#  2024.03.23.15:47:26
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module my_pio
# 
set_module_property DESCRIPTION ""
set_module_property NAME my_pio
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME my_pio
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL my_pio
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file my_pio.sv SYSTEM_VERILOG PATH my_pio.sv TOP_LEVEL_FILE


# 
# parameters
# 
add_parameter OUTPUT_WIDTH INTEGER 16
set_parameter_property OUTPUT_WIDTH DEFAULT_VALUE 16
set_parameter_property OUTPUT_WIDTH DISPLAY_NAME OUTPUT_WIDTH
set_parameter_property OUTPUT_WIDTH TYPE INTEGER
set_parameter_property OUTPUT_WIDTH UNITS None
set_parameter_property OUTPUT_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property OUTPUT_WIDTH HDL_PARAMETER true
add_parameter MEMORY_WIDTH INTEGER 8 ""
set_parameter_property MEMORY_WIDTH DEFAULT_VALUE 8
set_parameter_property MEMORY_WIDTH DISPLAY_NAME MEMORY_WIDTH
set_parameter_property MEMORY_WIDTH TYPE INTEGER
set_parameter_property MEMORY_WIDTH UNITS None
set_parameter_property MEMORY_WIDTH ALLOWED_RANGES -2147483648:2147483647
set_parameter_property MEMORY_WIDTH DESCRIPTION ""
set_parameter_property MEMORY_WIDTH HDL_PARAMETER true


# 
# display items
# 


# 
# connection point external_connection
# 
add_interface external_connection conduit end
set_interface_property external_connection associatedClock ""
set_interface_property external_connection associatedReset ""
set_interface_property external_connection ENABLED true
set_interface_property external_connection EXPORT_OF ""
set_interface_property external_connection PORT_NAME_MAP ""
set_interface_property external_connection CMSIS_SVD_VARIABLES ""
set_interface_property external_connection SVD_ADDRESS_GROUP ""

add_interface_port external_connection co_out_port export Output "((OUTPUT_WIDTH-1)) - (0) + 1"


# 
# connection point s1
# 
add_interface s1 avalon end
set_interface_property s1 addressUnits WORDS
set_interface_property s1 associatedClock clk
set_interface_property s1 associatedReset reset
set_interface_property s1 bitsPerSymbol 8
set_interface_property s1 burstOnBurstBoundariesOnly false
set_interface_property s1 burstcountUnits WORDS
set_interface_property s1 explicitAddressSpan 0
set_interface_property s1 holdTime 0
set_interface_property s1 linewrapBursts false
set_interface_property s1 maximumPendingReadTransactions 0
set_interface_property s1 maximumPendingWriteTransactions 0
set_interface_property s1 readLatency 0
set_interface_property s1 readWaitTime 1
set_interface_property s1 setupTime 0
set_interface_property s1 timingUnits Cycles
set_interface_property s1 writeWaitTime 0
set_interface_property s1 ENABLED true
set_interface_property s1 EXPORT_OF ""
set_interface_property s1 PORT_NAME_MAP ""
set_interface_property s1 CMSIS_SVD_VARIABLES ""
set_interface_property s1 SVD_ADDRESS_GROUP ""

add_interface_port s1 avs_address address Input 4
add_interface_port s1 avs_byteenable byteenable Input 1
add_interface_port s1 avs_write_n write_n Input 1
add_interface_port s1 avs_writedata writedata Input "((MEMORY_WIDTH-1)) - (0) + 1"
add_interface_port s1 avs_chipselect chipselect Input 1
add_interface_port s1 avs_read_n read_n Input 1
add_interface_port s1 avs_readdata readdata Output "((MEMORY_WIDTH-1)) - (0) + 1"
set_interface_assignment s1 embeddedsw.configuration.isFlash 0
set_interface_assignment s1 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment s1 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s1 embeddedsw.configuration.isPrintableDevice 0


# 
# connection point clk
# 
add_interface clk clock end
set_interface_property clk clockRate 0
set_interface_property clk ENABLED true
set_interface_property clk EXPORT_OF ""
set_interface_property clk PORT_NAME_MAP ""
set_interface_property clk CMSIS_SVD_VARIABLES ""
set_interface_property clk SVD_ADDRESS_GROUP ""

add_interface_port clk clk clk Input 1


# 
# connection point reset
# 
add_interface reset reset end
set_interface_property reset associatedClock clk
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset reset_n reset_n Input 1

