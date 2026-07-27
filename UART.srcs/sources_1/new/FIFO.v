module FIFO #(
    parameter FIFO_DEPTH = 16   // Depth must be a power of 2 for correct operation 
)(
    input  wire       clk,
    input  wire       reset,

    input  wire       wr_en,    //  if 1 wr_data is valid else invalid
    input  wire [7:0] wr_data,

    input  wire       rd_en,
    output wire [7:0] rd_data,

    output wire       full,
    output wire       empty
);
    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

    reg [7:0]           fifo_buffer[FIFO_DEPTH-1:0];
    reg [PTR_WIDTH  :0] count;
    reg [PTR_WIDTH-1:0] read_ptr,
                        write_ptr;

    wire write, read;

    // comment to myself: if fifo is to be read at clock edge 1, make sure rd_en pulse is high before clock edge 1, but after clock edge 0
    // if fifo is to be written at clock edge 1, wr_en pulse should be high before clock edge 1 (and after clock edge 0, else clock 0 could also write)

    assign write = wr_en && !full;
    assign read  = rd_en && !empty;

    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);

    assign rd_data = fifo_buffer[read_ptr];

    always @(posedge clk or posedge reset) begin 
        if (reset) begin  
            count     <= 0;
            write_ptr <= 0;
            read_ptr  <= 0;
        end

        else begin 
            if (write) begin 
                fifo_buffer[write_ptr] <= wr_data;
                write_ptr              <= write_ptr + 1;
            end

            if (read) begin 
                read_ptr <= read_ptr + 1;
            end

            case({read, write})
                2'b01: count <= count + 1;
                2'b10: count <= count - 1;
            endcase
        end
    end

endmodule