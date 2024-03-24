module my_pio #(
    parameter OUTPUT_WIDTH=16,
    parameter MEMORY_WIDTH=16
)(
    input clk,
    input reset_n,

    input  logic [3:0]              avs_address,
    input  logic                    avs_byteenable,
    input  logic                    avs_write_n,
    input  logic [MEMORY_WIDTH-1:0] avs_writedata,
    input  logic                    avs_chipselect,
    input  logic                    avs_read_n,
    output logic [MEMORY_WIDTH-1:0] avs_readdata,

    output logic [OUTPUT_WIDTH-1:0] co_out_port
);
    localparam WIDTH_DIFF = OUTPUT_WIDTH - MEMORY_WIDTH;
    localparam MAP = { {WIDTH_DIFF{1'b0}}, {MEMORY_WIDTH{1'b1}} };

    always_ff@(posedge clk or negedge reset_n)
        if (!reset_n) 
            co_out_port <= {OUTPUT_WIDTH{1'b0}};
        else if (!avs_write_n)
            if (OUTPUT_WIDTH > MEMORY_WIDTH) 
                co_out_port <= (co_out_port & ~(MAP << (MEMORY_WIDTH * avs_address))) 
                             | ({{WIDTH_DIFF{1'b0}}, avs_writedata} << (MEMORY_WIDTH * avs_address));


    always_comb
        avs_readdata = {MEMORY_WIDTH{1'b0}};
endmodule
