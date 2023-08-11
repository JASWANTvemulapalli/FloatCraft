// FloatCraft_IEEE754_Arithmetic.v

`timescale 1ns / 1ps
// Module for Decimal to IEEE754 Floating Point Conversion
module iee_float (input [31:0]lhs_dec, input [31:0]rhs_dec, output signed [31:0]flt);
     // for calculating exponent value
 function [7:0] exponent_num;
 input [31:0] data;
 reg signed [31:0] result;
 integer i;
 begin
 result=-1;
 if (data[31]==0)
 begin
 for (i=31; i>=0 && result==-1; i=i-1)
 begin
 if(data[i]==1)
 begin
 result=i;
 end
 end
 end
 else if (data[31]==1)
 begin
 for (i=0; i<=31 && result==-1; i=i+1)
 begin
 if(data[i]==1)
 result=i;
 end
 end
 if(result== -1)
 begin
 result=0;
 end
 exponent_num=result;
 end
endfunction

// converting rhs decimal to binary rhs
function [31:0] conv_rhs;
input [31:0] data;
reg signed [31:0] result;
integer i;
integer dec_value;
begin
dec_value=0;
for (i=1;i<10 && dec_value==0; i=i+1)
begin
if((10**i)> data)
dec_value=(10**i);
end
result=32'b0;
for(i=0;i<=31;i=i+1)
begin
data= data*2;
result= result<<1;
if (data>=dec_value)
begin
data=data-dec_value;
result=result|1'b1;
end
else
begin
result=result|1'b0;
end
end
conv_rhs=result;
end
endfunction

// converting decimal to ieee float
function [31:0] convertion;
input [31:0] LHS_dec;
input [31:0] RHS_dec;
reg signed [31:0] out;

integer i;
integer lhs_exp;
integer rhs_exp;
integer rhs;
integer lhs_mask; // mask helps to define which bits you want to keep and clear
integer rhs_mask;// mask helps to define which bits you want to keep and constraint_mode
integer sign;
begin
if (LHS_dec[31]==1)
begin
LHS_dec= ~LHS_dec+1;
sign=1'b1;
end
else
begin
sign=1'b0;
end

rhs=conv_rhs(RHS_dec);
lhs_exp=exponent_num(LHS_dec);
rhs_exp= exponent_num(rhs);
lhs_mask=0;
rhs_mask=0;
if (LHS_dec!=0)
begin
for (i=0;i<lhs_exp;i=i+1)
begin
lhs_mask[i]=1'b1;
end

out[22:0]=(LHS_dec & lhs_mask)<<((22-lhs_exp)+1);
out[22:0]=out[22:0]|(rhs>>(lhs_exp+9));
out[31]=sign;

out[30:23]=127+lhs_exp;
end

convertion=out;
end

endfunction
assign flt=convertion(lhs_dec,rhs_dec);   
endmodule

// Module for Floating Point Adder/Subtractor
module fp_adder (input clk, input reset, input [31:0]lhs_num_1, input [31:0]rhs_num_1, input [31:0]lhs_num_2, input [31:0]rhs_num_2, output [31:0]Result);
    wire[31:0]Number1;
wire[31:0]Number2;
iee_float fn_1(.flt(Number1),.lhs_dec(lhs_num_1),.rhs_dec(rhs_num_1));
iee_float fn_2(.flt(Number2),.lhs_dec(lhs_num_2),.rhs_dec(rhs_num_2));
reg [31:0] Num_shift_80;
reg [7:0] Larger_exp_80,Final_expo_80;
reg [22:0] Small_exp_mantissa_80,S_mantissa_80,L_mantissa_80,Large_mantissa_80,Final_mant_80;
reg [23:0] Add_mant_80,Add1_mant_80;
reg [7:0] e1_80,e2_80;

reg [22:0] m1_80,m2_80;
reg s1_80,s2_80,Final_sign_80;
reg [3:0] renorm_shift_80;
integer signed renorm_exp_80;
//reg renorm_exp_80;
reg [31:0] Result_80;
assign Result = Result_80;

always @(*) begin
//stage 1
e1_80 = Number1[30:23];
e2_80 = Number2[30:23];
m1_80 = Number1[22:0];
m2_80 = Number2[22:0];
s1_80 = Number1[31];
s2_80 = Number2[31];
if (e1_80 > e2_80) begin
Num_shift_80 = e1_80 - e2_80; // number of mantissa shift
Larger_exp_80 = e1_80; // store lower exponent
Small_exp_mantissa_80 = m2_80;
Large_mantissa_80 = m1_80;
end

else begin
Num_shift_80 = e2_80 - e1_80;
Larger_exp_80 = e2_80;
Small_exp_mantissa_80 = m1_80;
Large_mantissa_80 = m2_80;
end

if (e1_80 == 0 | e2_80 ==0) begin
Num_shift_80 = 0;
end
else begin
Num_shift_80 = Num_shift_80;
end

//stage 2
//if check both for normalization then append 1 and shift
if (e1_80 != 0) begin
Small_exp_mantissa_80 = {1'b1,Small_exp_mantissa_80[22:1]};
Small_exp_mantissa_80 = (Small_exp_mantissa_80 >> Num_shift_80);
end
else begin
Small_exp_mantissa_80 = Small_exp_mantissa_80;
end

if (e2_80!= 0) begin
Large_mantissa_80 = {1'b1,Large_mantissa_80[22:1]};
end
else begin
Large_mantissa_80 = Large_mantissa_80;
end

//else do what to do for denorm field

//stage 3
//check if exponent are equal
if (Small_exp_mantissa_80 < Large_mantissa_80) begin
//Small_exp_mantissa_80 = ((~ Small_exp_mantissa_80 ) + 1'b1);
//$display("what small_exp:%b",Small_exp_mantissa_80);
S_mantissa_80 = Small_exp_mantissa_80;
L_mantissa_80 = Large_mantissa_80;
end
else begin
//Large_mantissa_80 = ((~ Large_mantissa_80 ) + 1'b1);
//$display("what large_exp:%b",Large_mantissa_80);
S_mantissa_80 = Large_mantissa_80;
L_mantissa_80 = Small_exp_mantissa_80;
end
//stage 4
//add the two mantissa's

if (e1_80!=0 & e2_80!=0) begin
if (s1_80 == s2_80) begin

Add_mant_80 = S_mantissa_80 + L_mantissa_80;
end else begin
Add_mant_80 = L_mantissa_80 - S_mantissa_80;
end
end
else begin
Add_mant_80 = L_mantissa_80;
end

//renormalization for mantissa and exponent
if (Add_mant_80[23]) begin
renorm_shift_80 = 4'd1;
renorm_exp_80 = 4'd1;
end
else if (Add_mant_80[22])begin
renorm_shift_80 = 4'd2;
renorm_exp_80 = 0;
end
else if (Add_mant_80[21])begin
renorm_shift_80 = 4'd3;
renorm_exp_80 = -1;
end
else if (Add_mant_80[20])begin
renorm_shift_80 = 4'd4;
renorm_exp_80 = -2;
end
else if (Add_mant_80[19])begin
renorm_shift_80 = 4'd5;
renorm_exp_80 = -3;
end

//stage 5
// if e1==e2, no shift for exp
Final_expo_80 = Larger_exp_80 + renorm_exp_80;
Add1_mant_80 = Add_mant_80 << renorm_shift_80;

Final_mant_80 = Add1_mant_80[23:1];

if (s1_80 == s2_80) begin
Final_sign_80 = s1_80;
end

if (e1_80 > e2_80) begin
Final_sign_80 = s1_80;
end else if (e2_80 > e1_80) begin
Final_sign_80 = s2_80;
end
else begin
if (m1_80 > m2_80) begin
Final_sign_80 = s1_80;
end else begin
Final_sign_80 = s2_80;
end
end

Result_80 = {Final_sign_80,Final_expo_80,Final_mant_80};
end

always @(posedge clk) begin
if(reset) begin
Num_shift_80 <= #1 0;
end
end
endmodule
