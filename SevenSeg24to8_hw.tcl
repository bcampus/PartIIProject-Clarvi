# TCL File Generated by Component Editor 22.1
# Mon Oct 30 10:36:43 GMT 2023
# DO NOT MODIFY


# 
# SevenSeg24to8 "SevenSeg24to8" v1.0
#  2023.10.30.10:36:43
# Splits 24 bits into three 8-bit bundles
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module SevenSeg24to8
# 
set_module_property DESCRIPTION "Splits 24 bits into three 8-bit bundles"
set_module_property NAME SevenSeg24to8
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME SevenSeg24to8
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL SevenSeg24to8
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file SevenSeg24To8.sv SYSTEM_VERILOG PATH SevenSeg24To8.sv TOP_LEVEL_FILE


# 
# parameters
# 


# 
# display items
# 


# 
# connection point conduit_out0
# 
add_interface conduit_out0 conduit end
set_interface_property conduit_out0 associatedClock ""
set_interface_property conduit_out0 associatedReset ""
set_interface_property conduit_out0 ENABLED true
set_interface_property conduit_out0 EXPORT_OF ""
set_interface_property conduit_out0 PORT_NAME_MAP ""
set_interface_property conduit_out0 CMSIS_SVD_VARIABLES ""
set_interface_property conduit_out0 SVD_ADDRESS_GROUP ""

add_interface_port conduit_out0 bundle_out_0 export Output 8


# 
# connection point conduit_out1
# 
add_interface conduit_out1 conduit end
set_interface_property conduit_out1 associatedClock ""
set_interface_property conduit_out1 associatedReset ""
set_interface_property conduit_out1 ENABLED true
set_interface_property conduit_out1 EXPORT_OF ""
set_interface_property conduit_out1 PORT_NAME_MAP ""
set_interface_property conduit_out1 CMSIS_SVD_VARIABLES ""
set_interface_property conduit_out1 SVD_ADDRESS_GROUP ""

add_interface_port conduit_out1 bundle_out_1 export Output 8


# 
# connection point conduit_out2
# 
add_interface conduit_out2 conduit end
set_interface_property conduit_out2 associatedClock ""
set_interface_property conduit_out2 associatedReset ""
set_interface_property conduit_out2 ENABLED true
set_interface_property conduit_out2 EXPORT_OF ""
set_interface_property conduit_out2 PORT_NAME_MAP ""
set_interface_property conduit_out2 CMSIS_SVD_VARIABLES ""
set_interface_property conduit_out2 SVD_ADDRESS_GROUP ""

add_interface_port conduit_out2 bundle_out_2 export Output 8


# 
# connection point conduit_in
# 
add_interface conduit_in conduit end
set_interface_property conduit_in associatedClock ""
set_interface_property conduit_in associatedReset ""
set_interface_property conduit_in ENABLED true
set_interface_property conduit_in EXPORT_OF ""
set_interface_property conduit_in PORT_NAME_MAP ""
set_interface_property conduit_in CMSIS_SVD_VARIABLES ""
set_interface_property conduit_in SVD_ADDRESS_GROUP ""

add_interface_port conduit_in bundle_in export Input 24

