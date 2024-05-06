load_package report
package require cmdline

#Sourced from:
#https://www.intel.com/content/www/us/en/support/programmable/support-resources/design-examples/quartus/report-to-csv.html

proc panel_to_csv { panel_name csv_file } {

    set fh [open $csv_file w]
    load_report
    set num_rows [get_number_of_rows -name $panel_name]

    # Go through all the rows in the report file, including the
    # row with headings, and write out the comma-separated data
    for { set i 0 } { $i < $num_rows } { incr i } {
        set row_data [get_report_panel_row -name $panel_name -row $i]
        puts $fh [join $row_data ","]
    }

    unload_report
    close $fh
}

set options {\
    { "file.arg" "" "Output file name"} \
}
array set opts [::cmdline::getoptions quartus(args) $options]

project_open clarvi_fpga

panel_to_csv "Fitter||Resource Section||Fitter Resource Utilization by Entity" $opts(file)

unload_report
