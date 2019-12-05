module mux 
    #(parameter DATA_WIDTH = 8)
    (
        input [DATA_WIDTH-1:0] a,
        input [DATA_WIDTH-1:0] b,
        input sel,
        output [DATA_WIDTH-1:0] c
    );
    
    assign c = sel ? b : a ;

endmodule : mux


 module mux_4 
    #(parameter DATA_WIDTH = 8)
    (
        input [DATA_WIDTH-1:0] a,
        input [DATA_WIDTH-1:0] b,
        input [DATA_WIDTH-1:0] c,
        input [DATA_WIDTH-1:0] d,
        output [DATA_WIDTH-1:0] e,
        input [1:0] sel
    );

    logic [DATA_WIDTH-1:0] m00_o;
    logic [DATA_WIDTH-1:0] m01_o;

    mux #(.DATA_WIDTH(DATA_WIDTH)) m00(
        .a(a),
        .b(b),
        .c(m00_o),
        .sel(sel[0])
    );

    mux #(.DATA_WIDTH(DATA_WIDTH)) m01(
        .a(c),
        .b(d),
        .c(m01_o),
        .sel(sel[0])
    );

    mux #(.DATA_WIDTH(DATA_WIDTH)) m10(
        .a(m00_o),
        .b(m01_o),
        .c(e),
        .sel(sel[1])
    );

    

 endmodule : mux_4


