
module SevenSeg24to8 (
    input logic [23:0] bundle_in,
    output logic [7:0] bundle_out_0,
    output logic [7:0] bundle_out_1,
    output logic [7:0] bundle_out_2);

    assign bundle_out_0 = bundle_in[7:0];
    assign bundle_out_1 = bundle_in[15:8];
    assign bundle_out_2 = bundle_in[23:16];

endmodule
