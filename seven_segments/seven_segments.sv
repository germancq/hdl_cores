/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2019-12-04 16:03:33
 * @ Modified by: Your name
 * @ Modified time: 2020-01-08 12:39:26
 * @ Description:
 */


module display
  #(parameter N = 32,
    parameter CLK_HZ = 100000000)
  (
    input clk,
    input rst,
    input [N-1:0] din,
    output [(N>>2)-1:0] an,
    output [6:0] seg
  );

    logic [$clog2(N>>2)-1:0] an_gen;
    div_clk_module #(.N(N)) div_clk_module_inst(
    .clk(clk),
    .rst(rst),
    .div($clog2(CLK_HZ)-$clog2(200)-1),
    .an_gen_o(an_gen)
    );

    
    logic [3:0] din_i [(N>>2)-1:0];
    genvar i;
    generate
        for (i=0;i<(N>>2);i=i+1) begin
            assign din_i[i] = din[(i<<2)+3:(i<<2)];
        end
    endgenerate

  

    dec_to_7_seg dec_to_7_seg_inst(
    .rst(rst),
    .din(din_i[an_gen]),
    .seg(seg)
    );

    an_gen #(.N(N)) an_gen_inst(
    .rst(rst),
    .an_gen_i(an_gen),
    .an(an)
    );

endmodule : display



module div_clk_module
    #(parameter N = 32)
    (
        input clk,
        input rst,
        input [31:0] div,
        output [$clog2(N>>2)-1:0] an_gen_o
    );

    logic [31:0] contador_o;
    counter #(.DATA_WIDTH(32)) div_clk_counter(
        .clk(clk),
        .rst(rst),
        .up(1'b1),
        .down(1'b0),
        .din(32'h0),
        .dout(contador_o)
    );

    genvar i;

    generate
        for (i=0;i<$clog2(N>>2);i=i+1) begin
            assign an_gen_o[i] = contador_o[div+i];
        end
    endgenerate


endmodule

module an_gen
  #(parameter N = 32)
  (
    input rst,
    input [$clog2(N>>2)-1:0] an_gen_i,
    output logic [(N>>2)-1:0] an
  );


    always_comb begin
        an = {(N>>2){1'b1}};
        if(~rst)
            begin
            an = ({(N>>2){1'b1}}) ^ (1'b1<<an_gen_i);
            end
    end


endmodule : an_gen


module dec_to_7_seg(
  input rst,
  input [3:0] din,
  output logic [6:0] seg
  );

  always_comb
  begin
    if(rst)
      seg = 7'b0000000;
    else
      begin
        case(din)
          //////////<---MSB-LSB<---
          //////////////gfedcba////////////////////////////////////////////     
          0:seg = 7'b1000000;////0000                                           
          1:seg = 7'b1111001;////0001                                           
          2:seg = 7'b0100100;////0010                                           
          3:seg = 7'b0110000;////0011                                           
          4:seg = 7'b0011001;////0100                                           
          5:seg = 7'b0010010;////0101                                          
          6:seg = 7'b0000010;////0110
          7:seg = 7'b1111000;////0111
          8:seg = 7'b0000000;////1000
          9:seg = 7'b0010000;////1001
          'hA:seg = 7'b0001000;
          'hB:seg = 7'b0000011;
          'hC:seg = 7'b1000110;
          'hD:seg = 7'b0100001;
          'hE:seg = 7'b0000110;
          'hF:seg = 7'b0001110;
        endcase
      end
  end

endmodule : dec_to_7_seg