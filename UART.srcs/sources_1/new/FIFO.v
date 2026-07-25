module FIFO #(
    parameter FIFO_DEPTH = 16   // Depth must be a power of 2 for correct operation 
)(
    input  wire       clk,
    input  wire       reset,

    input  wire       wr_en,    // tells you whether wr_data is valid or invalid
    input  wire [7:0] wr_data,

    input  wire       rd_en,    // tells you whether tx unit is ready to recieve data or not
    output reg  [7:0] rd_data,

    output wire       full,
    output wire       empty
);
    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

    reg [7:0]           fifo_buffer[FIFO_DEPTH-1:0];
    reg [PTR_WIDTH  :0] count;
    reg [PTR_WIDTH-1:0] read_ptr,
                        write_ptr;

    wire write, read;

    assign write = wr_en && !full;
    assign read  = rd_en && !empty;

    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);

    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            count     <= 0;
            write_ptr <= 0;
            read_ptr  <= 0;
            rd_data   <= 8'b0;
        end

        else begin 
            if (write) begin 
                fifo_buffer[write_ptr] <= wr_data;
                write_ptr              <= write_ptr + 1;
            end

            if (read) begin 
                rd_data  <= fifo_buffer[read_ptr];
                read_ptr <= read_ptr + 1;
            end

            case({read, write})
                2'b01: count <= count + 1;
                2'b10: count <= count - 1;
            endcase
        end
    end

endmodule