// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on

module SNN(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	img,
	ker,
	weight,

	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input cg_en;
input [7:0] img;
input [7:0] ker;
input [7:0] weight;

output reg out_valid;
output reg [9:0] out_data;


reg cg_en_d1;
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) cg_en_d1 <= 0;
    else        cg_en_d1 <= cg_en;
end

reg [6:0] input_cnt;
always @(posedge clk, negedge rst_n)begin
    if(!rst_n)                                       input_cnt <= 0;
    else begin
        if(in_valid || (input_cnt[6] && !out_valid)) input_cnt <= input_cnt + 1;
        else                                         input_cnt <= 0;
    end
end




wire conv_ready;
wire [7:0] p_out00, p_out01, p_out02, p_out10, p_out11, p_out12, p_out20, p_out21, p_out22;
wire [7:0] k_out00, k_out01, k_out02, k_out10, k_out11, k_out12, k_out20, k_out21, k_out22;
pixel_out po1(.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .img(img), .ker(ker), .input_cnt(input_cnt), .cg_en_d1(cg_en_d1),
              .p_out00(p_out00), .p_out01(p_out01), .p_out02(p_out02), 
              .p_out10(p_out10), .p_out11(p_out11), .p_out12(p_out12), 
              .p_out20(p_out20), .p_out21(p_out21), .p_out22(p_out22), 
              .k_out00(k_out00), .k_out01(k_out01), .k_out02(k_out02), 
              .k_out10(k_out10), .k_out11(k_out11), .k_out12(k_out12), 
              .k_out20(k_out20), .k_out21(k_out21), .k_out22(k_out22) );


////////////////// convolution /////////////////////////////////////
wire [15:0] out_00, out_01, out_02, out_10, out_11, out_12, out_20, out_21, out_22;
wire [19:0] out;
reg [19:0] conv_out;
assign out_00 = p_out00 * k_out00;
assign out_01 = p_out01 * k_out01;
assign out_02 = p_out02 * k_out02;
assign out_10 = p_out10 * k_out10;
assign out_11 = p_out11 * k_out11;
assign out_12 = p_out12 * k_out12;
assign out_20 = p_out20 * k_out20;
assign out_21 = p_out21 * k_out21;
assign out_22 = p_out22 * k_out22;
assign out = ((out_00 + out_01) + (out_02 + out_10)) + ((out_11 + out_12) + (out_20 + out_21)) + out_22;

wire con1 = (input_cnt > 36 && input_cnt < 57 || input_cnt > 72);
wire sleep_conv_out = ( (input_cnt < 21 || con1 ) && cg_en_d1);
wire gated_conv_out;
GATED_OR GATED_conv_out(.CLOCK(clk), .SLEEP_CTRL(sleep_conv_out), .RST_N(rst_n), .CLOCK_GATED(gated_conv_out));
always @(posedge gated_conv_out)begin   
    conv_out <= out;
end



wire [7:0] quan_out;
Quan1 q1(.clk(clk), .rst_n(rst_n), .input_cnt(input_cnt), .conv_out(conv_out), .quan_out(quan_out));


wire [7:0] pooling_out;
Max_pooling M1(.clk(clk), .rst_n(rst_n), .quan_out(quan_out), .input_cnt(input_cnt), .pooling_out(pooling_out), .cg_en_d1(cg_en_d1));

wire [16:0] FC_out;
FC fc1(.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .pooling_out(pooling_out), .weight(weight), .input_cnt(input_cnt), .FC_out(FC_out), .cg_en_d1(cg_en_d1));

wire [7:0] quan_out_two;
Quan2 quan2(.clk(clk), .rst_n(rst_n), .FC_out(FC_out), .quan_out_two(quan_out_two));


wire [9:0] temp_out;
Distance d1(.clk(clk), .rst_n(rst_n), .quan_out_two(quan_out_two), .input_cnt(input_cnt), .temp_out1(temp_out), .cg_en_d1(cg_en_d1));



always @(posedge clk, negedge rst_n)begin
    if(!rst_n)begin
        out_valid <= 0;
        out_data <= 0;
    end
    else begin  
        if(input_cnt == 75)begin
            out_valid <= 1;
            out_data <= (|temp_out[9:4]) ? temp_out : 0;
        end
        else begin
            out_valid <= 0;
            out_data <= 0;
        end
    end
end

endmodule


module pixel_out(clk, rst_n, in_valid, img, ker, input_cnt, cg_en_d1,
                 p_out00, p_out01, p_out02, p_out10, p_out11, p_out12, p_out20, p_out21, p_out22, 
                 k_out00, k_out01, k_out02, k_out10, k_out11, k_out12, k_out20, k_out21, k_out22);

input clk, rst_n, in_valid, cg_en_d1;
input [7:0] img, ker;
input [6:0] input_cnt;
output reg [7:0] p_out00, p_out01, p_out02, p_out10, p_out11, p_out12, p_out20, p_out21, p_out22;
output reg [7:0] k_out00, k_out01, k_out02, k_out10, k_out11, k_out12, k_out20, k_out21, k_out22;

reg [7:0] p_00, p_01, p_02, p_03, p_04, p_05;
reg [7:0] p_10, p_11, p_12, p_13, p_14, p_15;
reg [7:0] p_20, p_21, p_22, p_23, p_24, p_25;
reg [7:0] p_30, p_31, p_32, p_33, p_34, p_35;
reg [7:0] p_40, p_41, p_42, p_43, p_44, p_45;
reg [7:0] p_50, p_51, p_52, p_53, p_54, p_55;

reg [7:0] k_00, k_01, k_02;
reg [7:0] k_10, k_11, k_12;
reg [7:0] k_20, k_21, k_22;


wire sleep_k = ( input_cnt > 8 && cg_en_d1);
wire gated_k;
GATED_OR GATED_k(.CLOCK(clk), .SLEEP_CTRL(sleep_k), .RST_N(rst_n), .CLOCK_GATED(gated_k));
always @(posedge gated_k, negedge rst_n)begin
    if(!rst_n) begin
        k_out00 <= 0;
        k_out01 <= 0;
        k_out02 <= 0;
        k_out10 <= 0;
        k_out11 <= 0;
        k_out12 <= 0;
        k_out20 <= 0;
        k_out21 <= 0;
        k_out22 <= 0;
    end
    else begin
        case(input_cnt)
            0:  k_out00 <= ker;
            1:  k_out01 <= ker;
            2:  k_out02 <= ker;
            3:  k_out10 <= ker;
            4:  k_out11 <= ker;
            5:  k_out12 <= ker;
            6:  k_out20 <= ker;
            7:  k_out21 <= ker;
            8:  k_out22 <= ker;
            37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50 ,51, 52 ,53 ,54 ,55, 56, 73, 74, 75: begin
                k_out00 <= ~k_out00;
                k_out01 <= ~k_out01;
                k_out02 <= ~k_out02;
                k_out10 <= ~k_out10;
                k_out11 <= ~k_out11;
                k_out12 <= ~k_out12;
                k_out20 <= ~k_out20;
                k_out21 <= ~k_out21;
                k_out22 <= ~k_out22;
            end
        endcase
    end
end


always @(posedge clk)begin
    if(input_cnt < 36)begin
        case(input_cnt)
            0:  p_00 <= img;
            1:  p_01 <= img;
            2:  p_02 <= img;
            3:  p_03 <= img;
            4:  p_04 <= img;
            5:  p_05 <= img;
            6:  p_10 <= img;
            7:  p_11 <= img;
            8:  p_12 <= img;
            9:  p_13 <= img;
            10: p_14 <= img;
            11: p_15 <= img;
            12: p_20 <= img;
            13: p_21 <= img;
            14: p_22 <= img;
            15: p_23 <= img;
            16: p_24 <= img;
            17: p_25 <= img;
            18: p_30 <= img;
            19: p_31 <= img;
            20: p_32 <= img;
            21: p_33 <= img;
            22: p_34 <= img;
            23: p_35 <= img;
            24: p_40 <= img;
            25: p_41 <= img;
            26: p_42 <= img;
            27: p_43 <= img;
            28: p_44 <= img;
            29: p_45 <= img;
            30: p_50 <= img;
            31: p_51 <= img;
            32: p_52 <= img;
            33: p_53 <= img;
            34: p_54 <= img;
            35: p_55 <= img;
        endcase
    end
    else begin
        case(input_cnt - 36)
            0:  p_00 <= img;
            1:  p_01 <= img;
            2:  p_02 <= img;
            3:  p_03 <= img;
            4:  p_04 <= img;
            5:  p_05 <= img;
            6:  p_10 <= img;
            7:  p_11 <= img;
            8:  p_12 <= img;
            9:  p_13 <= img;
            10: p_14 <= img;
            11: p_15 <= img;
            12: p_20 <= img;
            13: p_21 <= img;
            14: p_22 <= img;
            15: p_23 <= img;
            16: p_24 <= img;
            17: p_25 <= img;
            18: p_30 <= img;
            19: p_31 <= img;
            20: p_32 <= img;
            21: p_33 <= img;
            22: p_34 <= img;
            23: p_35 <= img;
            24: p_40 <= img;
            25: p_41 <= img;
            26: p_42 <= img;
            27: p_43 <= img;
            28: p_44 <= img;
            29: p_45 <= img;
            30: p_50 <= img;
            31: p_51 <= img;
            32: p_52 <= img;
            33: p_53 <= img;
            34: p_54 <= img;
            35: p_55 <= img;
        endcase
    end
end



always @* begin
    case(input_cnt)
        21, 57: begin
            p_out00 = p_00; p_out01 = p_01; p_out02 = p_02; 
            p_out10 = p_10; p_out11 = p_11; p_out12 = p_12; 
            p_out20 = p_20; p_out21 = p_21; p_out22 = p_22;
        end
        22, 58: begin
            p_out00 = p_01; p_out01 = p_02; p_out02 = p_03; 
            p_out10 = p_11; p_out11 = p_12; p_out12 = p_13; 
            p_out20 = p_21; p_out21 = p_22; p_out22 = p_23;
        end
        23, 59: begin
            p_out00 = p_02; p_out01 = p_03; p_out02 = p_04; 
            p_out10 = p_12; p_out11 = p_13; p_out12 = p_14; 
            p_out20 = p_22; p_out21 = p_23; p_out22 = p_24;
        end
        24, 60: begin
            p_out00 = p_03; p_out01 = p_04; p_out02 = p_05; 
            p_out10 = p_13; p_out11 = p_14; p_out12 = p_15; 
            p_out20 = p_23; p_out21 = p_24; p_out22 = p_25;
        end
        25, 61: begin
            p_out00 = p_10; p_out01 = p_11; p_out02 = p_12; 
            p_out10 = p_20; p_out11 = p_21; p_out12 = p_22; 
            p_out20 = p_30; p_out21 = p_31; p_out22 = p_32;
        end
        26, 62: begin
            p_out00 = p_11; p_out01 = p_12; p_out02 = p_13; 
            p_out10 = p_21; p_out11 = p_22; p_out12 = p_23; 
            p_out20 = p_31; p_out21 = p_32; p_out22 = p_33;
        end
        27, 63: begin
            p_out00 = p_12; p_out01 = p_13; p_out02 = p_14; 
            p_out10 = p_22; p_out11 = p_23; p_out12 = p_24; 
            p_out20 = p_32; p_out21 = p_33; p_out22 = p_34;
        end
        28, 64: begin
            p_out00 = p_13; p_out01 = p_14; p_out02 = p_15; 
            p_out10 = p_23; p_out11 = p_24; p_out12 = p_25; 
            p_out20 = p_33; p_out21 = p_34; p_out22 = p_35;
        end
        29, 65: begin
            p_out00 = p_20; p_out01 = p_21; p_out02 = p_22; 
            p_out10 = p_30; p_out11 = p_31; p_out12 = p_32; 
            p_out20 = p_40; p_out21 = p_41; p_out22 = p_42;
        end
        30, 66: begin
            p_out00 = p_21; p_out01 = p_22; p_out02 = p_23; 
            p_out10 = p_31; p_out11 = p_32; p_out12 = p_33; 
            p_out20 = p_41; p_out21 = p_42; p_out22 = p_43;
        end
        31, 67: begin
            p_out00 = p_22; p_out01 = p_23; p_out02 = p_24; 
            p_out10 = p_32; p_out11 = p_33; p_out12 = p_34; 
            p_out20 = p_42; p_out21 = p_43; p_out22 = p_44;
        end
        32, 68: begin
            p_out00 = p_23; p_out01 = p_24; p_out02 = p_25; 
            p_out10 = p_33; p_out11 = p_34; p_out12 = p_35; 
            p_out20 = p_43; p_out21 = p_44; p_out22 = p_45;
        end
        33, 69: begin
            p_out00 = p_30; p_out01 = p_31; p_out02 = p_32; 
            p_out10 = p_40; p_out11 = p_41; p_out12 = p_42; 
            p_out20 = p_50; p_out21 = p_51; p_out22 = p_52;
        end
        34, 70: begin
            p_out00 = p_31; p_out01 = p_32; p_out02 = p_33; 
            p_out10 = p_41; p_out11 = p_42; p_out12 = p_43; 
            p_out20 = p_51; p_out21 = p_52; p_out22 = p_53;
        end
        35, 71: begin
            p_out00 = p_32; p_out01 = p_33; p_out02 = p_34; 
            p_out10 = p_42; p_out11 = p_43; p_out12 = p_44; 
            p_out20 = p_52; p_out21 = p_53; p_out22 = p_54;
        end
        36, 72: begin
            p_out00 = p_33; p_out01 = p_34; p_out02 = p_35; 
            p_out10 = p_43; p_out11 = p_44; p_out12 = p_45; 
            p_out20 = p_53; p_out21 = p_54; p_out22 = p_55;
        end
        default: begin
            p_out00 = p_33; p_out01 = p_34; p_out02 = p_35; 
            p_out10 = p_43; p_out11 = p_44; p_out12 = p_45; 
            p_out20 = p_53; p_out21 = p_54; p_out22 = p_55;
        end
    endcase
end


endmodule



module Quan1(clk, rst_n, conv_out, quan_out, input_cnt);

input clk, rst_n;
input [19:0] conv_out;
input [6:0] input_cnt;
output [7:0] quan_out;

assign quan_out = conv_out / 2295;

endmodule


module Max_pooling(clk, rst_n, input_cnt, quan_out, pooling_out, cg_en_d1);

input clk, rst_n, cg_en_d1;
input [7:0] quan_out;
input [6:0] input_cnt;
output  [7:0] pooling_out;

reg [7:0] temp_pooling1, temp_pooling2;


reg [7:0] cmp_in;
always @* begin
    case(input_cnt)
        22, 23, 26, 27, 30, 31, 34, 35, 58, 59, 62, 63, 66, 67, 70, 71:  cmp_in <= temp_pooling1;
        24, 25, 28, 29, 32, 33, 36, 37, 60, 61, 64, 65, 68, 69, 72, 73:  cmp_in <= temp_pooling2;
        default:                                                         cmp_in <= temp_pooling2;
    endcase
end 

assign pooling_out = (cmp_in > quan_out) ? cmp_in : quan_out;

wire sleep_tem = ( (input_cnt < 22 ||( input_cnt > 37 && input_cnt < 58) || input_cnt > 73 ) && cg_en_d1);
wire gated_tem;
GATED_OR GATED_k(.CLOCK(clk), .SLEEP_CTRL(sleep_tem), .RST_N(rst_n), .CLOCK_GATED(gated_tem));
always @(posedge gated_tem, negedge rst_n)begin
    if(!rst_n) begin
        temp_pooling1 <= 8'b11111111;
        temp_pooling2 <= 8'b11111111;
    end
    else begin
        case(input_cnt)   
            22, 30, 58, 66: begin
                temp_pooling1 <= quan_out;
                temp_pooling2 <= temp_pooling2;
            end
            23, 26, 27, 31, 34, 35, 59, 62, 63, 67, 70, 71: begin
                temp_pooling1 <= pooling_out;
                temp_pooling2 <= temp_pooling2;
            end
            24, 32, 60, 68: begin
                temp_pooling1 <= temp_pooling1;
                temp_pooling2 <= quan_out;
            end
            25, 28, 29, 33, 36, 37, 61, 64, 65, 69, 72, 73: begin
                temp_pooling1 <= temp_pooling1;
                temp_pooling2 <= pooling_out;
            end
        endcase
    end
end
endmodule



module FC(clk, rst_n, in_valid, pooling_out, weight, input_cnt, FC_out, cg_en_d1);

input clk, rst_n, in_valid, cg_en_d1;
input [6:0] input_cnt;
input [7:0] pooling_out;
input [7:0] weight;
output reg [16:0] FC_out;

wire sleep_wei = ( (input_cnt > 3 ) && cg_en_d1);
wire gated_wei;
GATED_OR GATED_k(.CLOCK(clk), .SLEEP_CTRL(sleep_wei), .RST_N(rst_n), .CLOCK_GATED(gated_wei));
reg [7:0] w00, w01, w10, w11;
always @(posedge gated_wei)begin
    case(input_cnt)
        0: w00 <= weight;
        1: w01 <= weight;
        2: w10 <= weight;
        3: w11 <= weight;
    endcase
end

wire sleep_poolreg = ( (input_cnt < 27 || (input_cnt > 30 &&  input_cnt < 35 ) || (input_cnt > 38 &&  input_cnt < 63 ) ||(input_cnt > 66 &&  input_cnt < 71 )) && cg_en_d1);
wire gated_poolreg;
GATED_OR GATED_poolreg(.CLOCK(clk), .SLEEP_CTRL(sleep_poolreg), .RST_N(rst_n), .CLOCK_GATED(gated_poolreg));
reg [7:0] pooling_out_reg;
always @(posedge gated_poolreg, negedge rst_n)begin
    if(!rst_n) pooling_out_reg <= 0;
    else       pooling_out_reg <= pooling_out;
end

reg [7:0] w_mult;
always @* begin
    case(input_cnt)
        27, 63: w_mult = w00;
        28, 64: w_mult = w01;
        29, 65: w_mult = w10;
        30, 66: w_mult = w11;
        35, 71: w_mult = w00;
        36, 72: w_mult = w01;
        37, 73: w_mult = w10;
        38, 74: w_mult = w11;
        default: w_mult = w11;
    endcase
end

wire [7:0] pixel_mult;

assign pixel_mult = (input_cnt == 28 || input_cnt == 30 || input_cnt == 36 || input_cnt == 38 || input_cnt == 64 || input_cnt == 66 || input_cnt == 72 || input_cnt == 74) ? pooling_out_reg : pooling_out;

wire [15:0] mult_out;
assign mult_out = pixel_mult * w_mult;


wire sleep_temp_mult = (((input_cnt < 27) || (input_cnt > 28 && input_cnt < 35) || (input_cnt > 36 && input_cnt < 63) ||| (input_cnt > 64 && input_cnt < 71) || input_cnt > 72)&& cg_en_d1);
wire gated_temp_mult;
GATED_OR GATED_temp_mult(.CLOCK(clk), .SLEEP_CTRL(sleep_temp_mult), .RST_N(rst_n), .CLOCK_GATED(gated_temp_mult));
reg [15:0] temp_mult1, temp_mult2;
always @(posedge gated_temp_mult)begin
    case(input_cnt)
        27, 35, 63, 71: temp_mult1 <= mult_out;
        28, 36, 64, 72: temp_mult2 <= mult_out;
    endcase
end

wire [15:0] multout_for_plus = (input_cnt == 29 || input_cnt == 37 || input_cnt == 65 || input_cnt == 73) ? temp_mult1 : temp_mult2;

wire sleep_FC_out = ( (input_cnt < 29 || (input_cnt > 30 &&  input_cnt < 37 ) || (input_cnt > 38 && input_cnt < 65) ||(input_cnt > 66 &&  input_cnt < 73 )) && cg_en_d1);
wire gated_FC_out;
GATED_OR GATED_FC_out(.CLOCK(clk), .SLEEP_CTRL(sleep_FC_out), .RST_N(rst_n), .CLOCK_GATED(gated_FC_out));
always @(posedge gated_FC_out) FC_out <= multout_for_plus + mult_out;

endmodule


module Quan2(clk, rst_n, FC_out, quan_out_two);

input clk, rst_n;
input [16:0] FC_out;

output [7:0] quan_out_two;


assign quan_out_two = FC_out / 510;

endmodule

module Distance(clk, rst_n, quan_out_two, input_cnt, temp_out1, cg_en_d1);

input clk, rst_n, cg_en_d1;
input [6:0] input_cnt;
input [7:0] quan_out_two;
reg [9:0] temp_out;
output  [9:0] temp_out1;

reg [7:0] d0, d1, d2, d3;

wire sleep_d = ((input_cnt < 30 || (input_cnt > 31 &&  input_cnt < 38 ) || (input_cnt > 39 && input_cnt < 66) ||(input_cnt > 67 &&  input_cnt < 74 )) && cg_en_d1);
wire gated_d;
GATED_OR GATED_d(.CLOCK(clk), .SLEEP_CTRL(sleep_d), .RST_N(rst_n), .CLOCK_GATED(gated_d));
always @(posedge gated_d)begin
    case(input_cnt)
        30: d0 <= quan_out_two;
        31: d1 <= quan_out_two;
        38: d2 <= quan_out_two;
        39: d3 <= quan_out_two; 
    endcase
end

wire [7:0] cmp_out;
wire [7:0] a, b;
wire cmp;
wire [7:0] temp_cmp = (input_cnt == 66) ? d0 : (input_cnt == 67) ? d1 : (input_cnt == 74) ? d2 : d3;
assign cmp = (temp_cmp > quan_out_two);

assign a = cmp ? temp_cmp : quan_out_two ;
assign b = cmp ? quan_out_two : temp_cmp;
assign cmp_out = a - b;

assign temp_out1 = temp_out + cmp_out;


wire sleep_temp_out = ((input_cnt < 66 && input_cnt > 0) || (input_cnt > 67 && input_cnt < 74)&& cg_en_d1);
wire gated_temp_out;
GATED_OR GATED_temp_out(.CLOCK(clk), .SLEEP_CTRL(sleep_temp_out), .RST_N(rst_n), .CLOCK_GATED(gated_temp_out));
always @(posedge gated_temp_out)begin
    if(input_cnt == 66 || input_cnt == 67 || input_cnt == 74 || input_cnt == 75)begin
        temp_out <= temp_out1;
    end
    else if(input_cnt == 0)begin
        temp_out <= 0;
    end
    else begin
         temp_out <= temp_out;
    end
    
end

endmodule