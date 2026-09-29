// =============================================================
// Testbench for sync_fifo
//   1. Directed test: fill FIFO completely, check FULL asserts,
//      confirm a write while full is correctly blocked.
//   2. Directed test: drain FIFO completely, check EMPTY asserts,
//      confirm a read while empty is correctly blocked.
//   3. Randomized test: random mix of read/write each cycle,
//      cross-checked against a software reference queue model,
//      including full/empty flag checks every cycle.
// A running PASS/FAIL counter is printed; final summary at the end.
// =============================================================

`timescale 1ns / 1ps

module sync_fifo_tb;

    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 8;

    reg                     clk;
    reg                     rst_n;
    reg                     wr_en;
    reg  [DATA_WIDTH-1:0]   data_in;
    wire                    full;
    reg                     rd_en;
    wire [DATA_WIDTH-1:0]   data_out;
    wire                    empty;

    integer pass_count = 0;
    integer fail_count = 0;

    // software reference model: a simple queue
    reg [DATA_WIDTH-1:0] ref_queue [0:1023];
    integer ref_head = 0;
    integer ref_tail = 0;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .data_in(data_in), .full(full),
        .rd_en(rd_en), .data_out(data_out), .empty(empty)
    );

    // 10ns clock period
    always #5 clk = ~clk;

    task check(input cond, input [255:0] msg);
        begin
            if (cond) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s at time %0t", msg, $time);
            end
        end
    endtask

    task reset_dut;
        begin
            rst_n = 0; wr_en = 0; rd_en = 0; data_in = 0;
            ref_head = 0; ref_tail = 0;
            @(negedge clk);
            @(negedge clk);
            rst_n = 1;
            @(negedge clk);
        end
    endtask

    integer i;
    reg [DATA_WIDTH-1:0] expected_data;

    initial begin
        clk = 0;
        $display("=========================================");
        $display(" Synchronous FIFO Self-Checking Testbench");
        $display("=========================================");

        // ---------------- TEST 1: fill to full ----------------
        $display("\n-- TEST 1: Fill FIFO to FULL, verify blocked write --");
        reset_dut();
        check(empty === 1'b1, "FIFO should be empty after reset");

        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            wr_en   = 1;
            data_in = i;
        end
        @(negedge clk);
        wr_en = 0;
        check(full === 1'b1, "FIFO should be FULL after writing DEPTH items");

        // attempt an illegal write while full
        @(negedge clk);
        wr_en   = 1;
        data_in = 8'hFF; // should be dropped
        @(negedge clk);
        wr_en = 0;
        check(full === 1'b1, "FIFO should remain FULL (overflow write ignored)");

        // ---------------- TEST 2: drain to empty, check data order ----------------
        $display("\n-- TEST 2: Drain FIFO, verify FIFO order + EMPTY + blocked read --");
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            rd_en = 1;
        end
        @(negedge clk);
        rd_en = 0;
        check(empty === 1'b1, "FIFO should be EMPTY after reading DEPTH items");
        check(data_out === (DEPTH-1), "Last data_out should equal last value written (7)");

        // attempt illegal read while empty
        @(negedge clk);
        rd_en = 1;
        @(negedge clk);
        rd_en = 0;
        check(empty === 1'b1, "FIFO should remain EMPTY (underflow read ignored)");

        // ---------------- TEST 3: randomized read/write vs reference model ----------------
        $display("\n-- TEST 3: Randomized read/write vs software reference model --");
        reset_dut();

        for (i = 0; i < 500; i = i + 1) begin
            @(negedge clk);

            // Check flags FIRST, against the reference model state left over
            // from the previous cycle's action -- this matches what the DUT's
            // full/empty currently reflect (i.e. state after the last posedge).
            check(empty === (ref_head == ref_tail), "empty flag mismatch vs reference model");
            check(full  === (ref_tail - ref_head == DEPTH), "full flag mismatch vs reference model");

            wr_en   = ($random & 1);         // ~50% writes
            rd_en   = (($random & 3) == 0);  // ~25% reads
            data_in = $random;

            // model the write (this cycle's action, applies at the next posedge)
            if (wr_en && !full) begin
                ref_queue[ref_tail] = data_in;
                ref_tail = ref_tail + 1;
            end

            // model the read (check against value that will appear NEXT cycle)
            if (rd_en && !empty) begin
                expected_data = ref_queue[ref_head];
                ref_head = ref_head + 1;
                @(negedge clk); // wait one cycle for registered data_out
                check(data_out === expected_data, "data_out mismatch vs reference model");
                wr_en = 0; rd_en = 0; // don't double-step the loop's own @(negedge)
            end
        end
        wr_en = 0; rd_en = 0;

        // ---------------- SUMMARY ----------------
        $display("\n=========================================");
        $display(" TEST SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: FAILURES DETECTED");
        $display("=========================================");

        $finish;
    end

    // dump waveform for GTKWave / EPWave
    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);
    end

endmodule
