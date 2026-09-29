// =============================================================
// Module      : sync_fifo
// Description : Parameterized synchronous (single-clock) FIFO
//               - Uses the classic "extra MSB" pointer trick to
//                 distinguish FULL from EMPTY without a separate
//                 counter.
// Parameters  :
//   DATA_WIDTH : width of each data word (default 8)
//   DEPTH      : number of entries, MUST be a power of 2 (default 8)
// =============================================================

`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 8                     // must be power of 2
) (
    input  wire                    clk,
    input  wire                    rst_n,         // active-low async reset

    // write side
    input  wire                    wr_en,
    input  wire [DATA_WIDTH-1:0]   data_in,
    output wire                    full,

    // read side
    input  wire                    rd_en,
    output reg  [DATA_WIDTH-1:0]   data_out,
    output wire                    empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // pointers are ADDR_WIDTH+1 bits wide.
    // The extra MSB is the "wrap bit": if wr_ptr and rd_ptr have the
    // same lower ADDR_WIDTH bits but DIFFERENT MSBs, the FIFO is FULL.
    // If they are fully equal (including MSB), the FIFO is EMPTY.
    reg [ADDR_WIDTH:0] wr_ptr, rd_ptr;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    // -------------------- write logic --------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= data_in;
            wr_ptr       <= wr_ptr + 1'b1;
        end
    end

    // -------------------- read logic --------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr   <= 0;
            data_out <= 0;
        end else if (rd_en && !empty) begin
            data_out <= mem[rd_addr];
            rd_ptr   <= rd_ptr + 1'b1;
        end
    end

endmodule
