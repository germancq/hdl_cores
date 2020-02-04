/**
 * @Author: German Cano Quiveu <germancq>
 * @Date:   2019-03-01T13:23:45+01:00
 * @Email:  germancq@dte.us.es
 * @Filename: sdspihost.v
 * @Last modified by:   germancq
 * @Last modified time: 2019-03-06T13:43:01+01:00
 */
 /****************************
  BASED ON https://github.com/paulino/minsdhcspi-host
 *****************************/

 module sdspihost(
   input clk,
   input reset,

   output logic busy,
   output logic err,
   output crc_err,

   input r_block,
   input r_multi_block,
   input r_byte,
   input w_block,
   input w_byte,
   input [31:0] block_addr,
   output [7:0] data_out,
   input [7:0] data_in,


   //SPI interface
   input miso,
   output mosi,
   output sclk,
   output ss,
   //output SD_RESET,
   //output SD_DAT_1,
   //output SD_DAT_2,
   ////
   /*
    sclk speed es un divisor de frecuencia del clk global, para poner el sclk de la microsd a un multiplo del clk.
   */
   input [4:0] sclk_speed,

   
   output[31:0] debug
 );

 //assign SD_RESET = 1'b0;
 //assign SD_DAT_1 = 1'b1;
 //assign SD_DAT_2 = 1'b1;

 parameter CYCLES_CLK_WAIT = 32'd25000000;


 //spi_master inteface
 logic[7:0] spi_in; // output from MUX
 logic cs_spi;
 logic busy_spi;
 logic switch_sclk;
 logic w_data;

 spi_master spi_module(
   .clk(clk),
   .ss_in(cs_spi),
   .w_data(w_data),
   .data_in(spi_in),
   .data_out(data_out),

   .w_conf(switch_sclk),
   .busy(busy_spi),

   ////spi signals
   .miso(miso),
   .mosi(mosi),
   .ss(ss),
   .sclk(sclk),
   .debug()
 );

 

 //sdcmd interface
 logic[7:0] spi_in_cmd_out;
 logic cs_cmd_spi;
 logic w_sdcmd_spi_data;
 logic w_cmd;
 logic sdcmd_busy;
 logic [39:0] response;
 logic [47:0] command;
 logic rst_sdcmd;
 sdcmd sdcmd_module(
   .clk(clk),
   .reset(rst_sdcmd),
   .w_cmd(w_cmd),
   .command(command),
   .response(response),
   .busy(sdcmd_busy),

   .spi_out_sdcmd_in(data_out),
   .spi_in_sdcmd_out(spi_in_cmd_out),
   .spi_busy(busy_spi),
   .w_spi_data(w_sdcmd_spi_data),
   .cs_spi(cs_cmd_spi),
   .debug()
 );


 logic [7:0] spi_in_internal_signal_o;
 logic [7:0] spi_in_internal_signal;
 logic spi_in_internal_signal_cl;
 logic spi_in_internal_signal_w;
 register #(.DATA_WIDTH(8)) reg_spi_internal(
 	.clk(clk),
 	.cl(spi_in_internal_signal_cl),
 	.w(spi_in_internal_signal_w),
 	.din(spi_in_internal_signal),
 	.dout(spi_in_internal_signal_o)
 );

 /////////////////////////////////////////

 logic spi_mux_ctl;

 mux #(.DATA_WIDTH(8)) spi_input_mux(
   .a(spi_in_internal_signal_o),
   .b(spi_in_cmd_out),
   .c(spi_in),
   .sel(spi_mux_ctl)
 );

 
 logic cs_internal_signal;
 mux #(.DATA_WIDTH(1)) spi_cs_mux(
   .a(cs_internal_signal),
   .b(cs_cmd_spi),
   .c(cs_spi),
   .sel(spi_mux_ctl)
 );

 
 logic w_data_internal;
 mux #(.DATA_WIDTH(1)) spi_wdata_mux(
   .a(w_data_internal),
   .b(w_sdcmd_spi_data),
   .c(w_data),
   .sel(spi_mux_ctl)
 );

 ////////////////////////////////

 
 

 //command register

 logic  command_cl;
 logic  command_w;
 logic  [47:0] command_in;

 register #(.DATA_WIDTH(48)) r_command(
        .clk(clk),
        .cl(command_cl),
        .w(command_w),
        .din(command_in),
        .dout(command)
      );


 logic up_counter;
 logic [31:0] counter_o;
 logic rst_counter;
 counter #(.DATA_WIDTH(32)) counter_wait(
    .clk(clk),
    .rst(rst_counter),
    .up(up_counter),
    .down(1'b0),
    .din(32'h0),
    .dout(counter_o)
 );


 logic r_block_prev;
 logic r_multi_block_prev;

 //21 estados
 logic[4:0] current_state;
 logic[4:0] next_state;

 logic [4:0] reg_state_prev;
 logic r_state_prev_cl;
 logic r_state_prev_w;
 register #(.DATA_WIDTH(5)) r_state_prev_0(
     .clk(clk),
     .cl(r_state_prev_cl),
     .w(r_state_prev_w),
     .din(current_state),
     .dout(reg_state_prev)
 );

 reg crc_err_w;
 reg crc_err_cl;
 register #(.DATA_WIDTH(1)) crc_err_reg(
     .clk(clk),
     .cl(crc_err_cl),
     .w(crc_err_w),
     .din(data_out[1]),
     .dout(crc_err)
 );

 logic [15:0] crc16;
 assign crc16 = 16'h7fa1;

 localparam INIT_0 = 5'h0;
 localparam WAIT_250_ms = 5'h1;
 localparam WAIT_74_CYC = 5'h2;
 localparam CMD0_0 = 5'h3;
 localparam CMD0_1 = 5'h4;
 localparam CMD8_0 = 5'h5;
 localparam CMD8_1 = 5'h6;
 localparam CMD55_0 = 5'h7;
 localparam CMD55_1 = 5'h8;
 localparam ACMD41_0 = 5'h9;
 localparam ACMD41_1 = 5'hA;
 localparam IDLE = 5'hB;
 localparam WAIT_BEFORE_READ = 5'hC;
 localparam CMD17_0 = 5'hD;
 localparam CMD17_1 = 5'hE;
 localparam CMD18_0 = 5'hF;
 localparam CMD18_1 = 5'h10;
 localparam CMD24_0 = 5'h11;
 localparam CMD24_1 = 5'h12;
 localparam CMD12_0 = 5'h13;
 localparam CMD12_1 =  5'h14;
 localparam WRITE_FE_TOKEN = 5'h15;
 localparam WAIT_FOR_BYTE_TO_WRITE = 5'h16;
 localparam WRITE_BYTE = 5'h17;
 localparam WAIT_WRITE_BLOCK_RSP = 5'h18;
 localparam WAIT_FE_TOKEN = 5'h19;
 localparam WAIT_BYTE = 5'h1A;
 localparam BYTE_READY = 5'h1B;
 localparam ABORT_READ = 5'h1C;
 localparam WAIT_CMD_RSP = 5'h1D;
 localparam WAIT_SPI = 5'h1E;
 localparam ERROR = 5'h1F;

 /*
   States of SD
     1) Power up
       - usaremos tambien identification clock rate , sclk_div rango[7-9] [390 KHz - 97.65 KHz]
       - wait 250 ms, a 50MHz(20ns) son 12500 ciclos, 0x30D4, a 100Mhz son 25000 ciclos, 0x61A8
       - wait max (74 ciclos SD clk , 1 ms), esos 74 ciclos con mosi = '1'
     2) Identification Mode (Idle State + Ready State + Identification State)
       - During the card identification process,
         the card shall operate in the SD clock frequency
         of the identification clock rate (100-400)KHz
       - CMD 0
       - CMD 8
       - CMD55+ACMD41 (bucle)
     3) data-transfer Mode
       - Ponemos la frecuencia 6.25-12.5 MHz
       - CMD 17 , read single block
 */

 always_comb
 begin
     next_state = current_state;


     busy = 1;
     err = 0;

     rst_sdcmd = 0;
     w_cmd = 0;

     spi_mux_ctl = 0;
     spi_in_internal_signal = 8'hff;
     cs_internal_signal = 0;
     w_data_internal = 0;

     switch_sclk = 0;

     r_state_prev_cl = 0;
     r_state_prev_w = 0;

     rst_counter = 0;
     up_counter = 0;


     command_cl = 0;
     command_w = 0;
     command_in = 48'hFFFFFFFFFFFF;
     

     crc_err_w = 0;
     crc_err_cl = 0;

     spi_in_internal_signal_w = 0;
     spi_in_internal_signal_cl = 0;

     case(current_state)
       INIT_0:
         begin

           rst_sdcmd = 1;
           cs_internal_signal = 1;

           command_cl = 1;
           r_state_prev_cl = 1;

           rst_counter = 1;

           spi_in_internal_signal = {3'h7,5'hB};
           switch_sclk = 1;

           spi_in_internal_signal_w = 1;

           next_state = WAIT_250_ms;


         end
       WAIT_250_ms:
         begin
           cs_internal_signal = 1;
           up_counter = 1;


           if(counter_o == CYCLES_CLK_WAIT)
           begin
             next_state = WAIT_74_CYC;
             rst_counter = 1;
           end
         end
       WAIT_74_CYC:
         begin
           r_state_prev_w = 1;
           spi_in_internal_signal = 8'hFF;
           spi_in_internal_signal_w = 1;
           up_counter = 1;
           w_data_internal = 1;
           next_state = WAIT_SPI;
           if(counter_o == 32'd16)
           begin
             cs_internal_signal = 0;
             next_state = CMD0_0;
           end
         end
       CMD0_0:
         begin
            
           spi_mux_ctl = 1;
           
           rst_counter = 1;
          
           r_state_prev_w = 1;
           
           
           command_w = 1;
           command_in = {1'b0,1'b1,6'h0,32'h0,8'h95};
          
           w_cmd = 1;
           
           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;
            
         end
       CMD0_1:
         begin
           spi_mux_ctl = 1;
           

           if(response[39:32] == 8'h1)
             next_state = CMD8_0;
           else
             next_state = ERROR;

         end
       CMD8_0:
         begin
           spi_mux_ctl = 1;
           
           r_state_prev_w = 1;
           
           command_w = 1;
           command_in = {1'b0,1'b1,6'h8,32'h1AA,8'h87};

           w_cmd = 1'b1;
           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;
         end
       CMD8_1:
         begin
           spi_mux_ctl = 1;
           

           if(response[39:32] == 8'h1) //&& response[7:0] == 8'hAA)
             next_state = CMD55_0;
           else
             next_state = ERROR;

         end
       CMD55_0:
         begin
           spi_mux_ctl = 1;
           
           r_state_prev_w = 1;

          
           command_w = 1;
           command_in = {1'b0,1'b1,6'h37,32'h0,8'h1};

           w_cmd = 1;
           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;
         end
       CMD55_1:
         begin
           spi_mux_ctl = 1;
           
           if(response[39:32] == 8'h1)
             next_state = ACMD41_0;
           else
             next_state = ERROR;
         end
       ACMD41_0:
         begin
           spi_mux_ctl = 1;
           
           r_state_prev_w = 1;

           
           command_w = 1;
           command_in = {1'b0,1'b1,6'h29,8'h40,24'h0,8'h1};

           w_cmd = 1;
           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;
         end
       ACMD41_1:
         begin
           spi_mux_ctl = 1;
           
           up_counter = 1;
           if(response[39:32] == 8'h0)
           begin
             spi_in_internal_signal = {3'h4,sclk_speed};
             spi_in_internal_signal_w = 1;
             switch_sclk = 1;
             next_state = IDLE;
           end
           else
             if(counter_o == 32'hFF)
               next_state = ERROR;
             else
               next_state = CMD55_0;
         end
       IDLE:
         begin
           spi_in_internal_signal = {3'h4,sclk_speed};
           busy = 0;
           rst_counter = 1;

           if(r_block == 1)
             next_state = WAIT_BEFORE_READ;
           else if(r_multi_block == 1)
             next_state = WAIT_BEFORE_READ;
           else if(w_block == 1)
           begin
             next_state = WAIT_BEFORE_READ;
             crc_err_cl = 1;
           end
         end
       WAIT_BEFORE_READ:
         begin
             r_state_prev_w = 1;
             spi_in_internal_signal = 8'hFF;
             spi_in_internal_signal_w = 1;
             up_counter = 1;
             w_data_internal = 1;
             next_state = WAIT_SPI;

              //spi_in_internal_signal = {3'h7,5'h0};
              //rst_counter = 1;


             if(counter_o == 32'd16)
             begin
              if(r_block == 1)
                next_state = CMD17_0;
              else if(r_multi_block == 1)
                next_state = CMD18_0;
               else if(w_block == 1)
                 next_state = CMD24_0;
              end
         end
       CMD17_0:
         begin
           spi_mux_ctl = 1;
           
           r_state_prev_w = 1;

           
           command_w = 1;
           command_in = {1'b0,1'b1,6'h11,block_addr,8'h1};

           w_cmd = 1;
           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;
         end
       CMD17_1:
         begin
           spi_mux_ctl = 1;
           

           if(response[39:32] != 8'h0)
             next_state = ERROR;
           else
             next_state = WAIT_FE_TOKEN;

         end
       CMD18_0:
         begin
           spi_mux_ctl = 1;
           
           r_state_prev_w = 1;

           
           command_w = 1;
           command_in = {1'b0,1'b1,6'h12,block_addr,8'h1};

           w_cmd = 1;
           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;
         end
       CMD18_1:
         begin
           spi_mux_ctl = 1;
           

           if(response[39:32] != 8'h0)
             next_state = ERROR;
           else
             next_state = WAIT_FE_TOKEN;
         end
       CMD24_0:
         begin
           spi_mux_ctl = 1;
           
           r_state_prev_w = 1;


           command_w = 1;
           command_in = {1'b0,1'b1,6'h18,block_addr,8'h1};

           w_cmd = 1;
           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;

         end
       CMD24_1:
         begin
           spi_mux_ctl = 1;
           

           if(response[39:32] != 8'h0)
             next_state = ERROR;
           else
             next_state = WRITE_FE_TOKEN;

         end
       CMD12_0:
         begin
           spi_mux_ctl = 1;
           
           r_state_prev_w = 1;

           command_w = 1;
           command_in = {1'b0,1'b1,6'hC,32'h0,8'h1};

           w_cmd = 1;

           if(sdcmd_busy == 1)
             next_state = WAIT_CMD_RSP;

         end
       CMD12_1:
         begin
           spi_mux_ctl = 1;
           

           if(response[39:32] != 8'h0)
             next_state = ERROR;
           else
             next_state = IDLE;
         end
       WRITE_FE_TOKEN:
         begin

           spi_in_internal_signal = 8'hFE;
           spi_in_internal_signal_w = 1;
           w_data_internal = 1;
           rst_counter = 1;
           r_state_prev_w = 1;

           if(busy_spi == 1)
               next_state = WAIT_SPI;
           

         end
       WAIT_FOR_BYTE_TO_WRITE:
         begin
           busy = 0;
           
           if(counter_o == 32'h202)
           begin
             next_state = WAIT_WRITE_BLOCK_RSP;
           end
           else if(w_byte == 1)
             begin
               next_state = WRITE_BYTE;
               up_counter = 1;
             end
         end
       WAIT_WRITE_BLOCK_RSP:
         begin
           spi_in_internal_signal = 8'hFF;
           spi_in_internal_signal_w = 1;
           w_data_internal = 1;
           r_state_prev_w = 1;
           next_state = WAIT_SPI;
           if(data_out != 8'hFF)
             begin
               crc_err_w = 1;
               w_data_internal = 0;
               next_state = IDLE;
             end
         end
       WRITE_BYTE:
         begin
           spi_in_internal_signal = data_in;
           w_data_internal = 1;
           spi_in_internal_signal_w = 1;
           if(counter_o == 32'h201)
             spi_in_internal_signal = crc16[15:8];
           else if(counter_o == 32'h202)
             spi_in_internal_signal = crc16[7:0];

           r_state_prev_w = 1;
           if(busy_spi == 1)
             next_state = WAIT_SPI;
         end
       WAIT_FE_TOKEN:
         begin
           spi_in_internal_signal = 8'hFF;
           spi_in_internal_signal_w = 1;
           w_data_internal = 1;
           r_state_prev_w = 1;
           rst_counter = 1;
           next_state = WAIT_SPI;
           if(data_out == 8'hFE)
             next_state = WAIT_BYTE;
         end
       WAIT_BYTE:
         begin

           spi_in_internal_signal = 8'hFF;
           spi_in_internal_signal_w = 1;
           w_data_internal = 1;
           r_state_prev_w = 1;
           next_state = WAIT_SPI;
           up_counter = 1;


         end
       BYTE_READY:
         begin
           busy = 0;

           if(r_block == 0 && r_block_prev == 1)
             next_state = ABORT_READ;
           else if(r_multi_block == 0 && r_multi_block_prev == 1)
             next_state = CMD12_0;
           else if(r_multi_block == 1 && counter_o > 32'h200)
             begin
               busy = 1;
               if(counter_o == 32'h204)
               begin
                 next_state = WAIT_FE_TOKEN;
                 rst_counter = 1;
               end

               next_state = WAIT_BYTE;
             end
           else if(r_byte == 1)
             next_state = WAIT_BYTE;
         end
       ABORT_READ:
         begin
           spi_in_internal_signal = 8'hFF;
           spi_in_internal_signal_w = 1;
           w_data_internal = 1;
           r_state_prev_w = 1;
           next_state = WAIT_SPI;
           up_counter = 1;
           //user_byte 0 => counter = 1 -> 512 bytes + 2 crc = 0-513 => 1-514

           if(counter_o == 32'h203) // 512 bytes user_data + 2 bytes de CRC
             begin
               next_state = IDLE;
             end

         end
       WAIT_CMD_RSP:
         begin
           spi_mux_ctl = 1;
           
           if(sdcmd_busy == 0)
             next_state = reg_state_prev + 1;
         end
       WAIT_SPI:
         begin

           if(busy_spi == 0)
           begin
             next_state = reg_state_prev;
             if(reg_state_prev == WAIT_BYTE)
               next_state = BYTE_READY;
             else if(reg_state_prev == WRITE_BYTE)
               next_state = WAIT_FOR_BYTE_TO_WRITE;
             else if(reg_state_prev == WRITE_FE_TOKEN)
               next_state = WAIT_FOR_BYTE_TO_WRITE;
           end
         end
       ERROR:
         begin
           err = 1;
         end
     endcase
 end


 always_ff @ ( posedge clk )
 begin
   if(reset)
     current_state <= INIT_0;
   else
     begin
       current_state <= next_state;
       r_block_prev <= r_block;
       r_multi_block_prev <= r_multi_block;
     end
 end

 assign debug = {counter_o[7:0],spi_in,data_out,3'b000,current_state};

 endmodule
