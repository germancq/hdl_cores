/**
 * @Author: German Cano Quiveu <germancq>
 * @Date:   2019-03-01T13:24:00+01:00
 * @Email:  germancq@dte.us.es
 * @Filename: spi_master.v
 * @Last modified by:   germancq
 * @Last modified time: 2019-03-01T13:24:42+01:00
 */

 module spi_master (
           input clk ,
           input [7:0] data_in,
           output [7:0] data_out,
           input w_data,//0: read / 1: write
           input w_conf,//1: write_config, 0: write data
           input ss_in,// SPI SS

           output logic busy,// Data ready when not busy
           
           
           input miso,//SPI external connections
           output mosi,
           output sclk,
           output ss,
           

           output [31:0] debug
   );

 assign ss = ss_in;
 logic sclk_prev;
 logic sclk_curr;


 logic master_out_w;
 logic master_out_shl;

 //miso
 logic master_in_w;
 logic master_in_shl;
 shift_register #(.DATA_WIDTH(8)) master_in_reg(
   .clk(clk),
   .cl(1'b0),
   .load(master_in_w),
   .din(8'hFF),
   .dout(data_out),
   .shift_right(1'b0),
   .shift_left(master_in_shl),
   .output_bit(),
   .input_bit(miso)
   );

 logic [7:0] reg_data_in;
 register #(.DATA_WIDTH(8)) sclk_reg(
    .clk(clk),
    .cl(1'b0),
    .w(master_out_w),
    .din(data_in),
    .dout(reg_data_in)
  );


 //mosi
 assign mosi = master_out_o[7];
 logic [7:0] master_out_o;
 
 shift_register #(.DATA_WIDTH(8)) master_out_reg(
   .clk(clk),
   .cl(1'b0),
   .load(master_out_w),
   .din(data_in),
   .dout(master_out_o),
   .shift_right(1'b0),
   .output_bit(),
   .shift_left(master_out_shl),
   .input_bit(1'b0)
   );


 logic [7:0] sclk_div;
 logic sclk_cl;
 logic sclk_w;
 register #(.DATA_WIDTH(8)) reg_data_input(
   .clk(clk),
   .cl(sclk_cl),
   .w(sclk_w),
   .din(data_in),
   .dout(sclk_div)
 );


 logic reg_sclk;
 logic reg_sclk_w;
 register #(.DATA_WIDTH(1)) sclk_register(
   .clk(clk),
   .cl(1'b0),
   .w(reg_sclk_w),
   .din(reg_sclk),
   .dout(sclk)
 );


 assign sclk_curr = counter_sclk_o[sclk_div[4:0]];
 logic up_sclk;
 logic [31:0] counter_sclk_o;
 logic rst_counter_sclk;
 counter #(.DATA_WIDTH(32)) counter_sclk(
    .clk(clk),
    .rst(rst_counter_sclk),
    .up(up_sclk),
    .down(1'b0),
    .din(32'h0),
    .dout(counter_sclk_o)
 );

 logic up_data;
 logic [4:0] counter_data_o;
 logic rst_counter_data;
 counter #(.DATA_WIDTH(5)) counter_data(
    .clk(clk),
    .rst(rst_counter_data),
    .up(up_data),
    .down(1'h0),
    .din(5'h0),
    .dout(counter_data_o)
 );

 assign debug = {master_out_o,data_out,data_in,sclk_div};


 always_ff @(posedge clk)
 begin

   sclk_prev <= sclk_curr;

   rst_counter_data <= 0;
   up_data <= 0;

   rst_counter_sclk <= 0;
   up_sclk <= 0;

   sclk_cl <= 0;
   sclk_w <= 0;

   master_out_w <= 0;
   master_out_shl <= 0;

   master_in_w <= 0;
   master_in_shl <= 0;

   reg_sclk_w <= 0;

   busy <= 0;

   if(w_conf == 1)
     begin
       rst_counter_sclk <= 1;
       rst_counter_data <= 1;
       sclk_w <= 1;
       reg_sclk <= 0;
       reg_sclk_w <= 1;
     end
   else if(ss_in == 1)
     begin
       up_sclk <= 1;
       master_in_w <= 1;
       master_out_w <= 1;
       if(sclk_curr != sclk_prev)
       begin
         reg_sclk <= ~sclk;
         reg_sclk_w <= 1;
       end
     end
   else if(w_data == 1)
     begin
       rst_counter_data <= 1;
       master_out_w <= 1;
       busy <= 1;
       reg_sclk <= 0;
       reg_sclk_w <= 1;
     end
   else if(counter_data_o == 5'd15)
     begin
       rst_counter_data <= 1;
       rst_counter_sclk <= 1;
       busy <= 0;
       reg_sclk <= 0;
       reg_sclk_w <= 1;
     end
   else if(busy == 1)
     begin
       up_sclk <= 1;
       busy <= 1;
       if(sclk_curr != sclk_prev)
         begin
           //slave captured at rising edge
           
           up_data <= 1;
           if(sclk_curr == 1)
             begin
               //rising edge
               reg_sclk <= 1;
               master_in_shl <= 1;

               reg_sclk_w <= 1;
             end
           else
             begin
               //falling edge
               reg_sclk <= 0;
               reg_sclk_w <= 1;
               master_out_shl <= 1;
             end

         end

     end
 end



 endmodule : spi_master
