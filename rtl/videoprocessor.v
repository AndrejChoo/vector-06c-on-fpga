module videoprocessor(
	input wire pixclk,
	input wire hclk,
	input wire rst,
	input wire CRST,
	//HDMI
	output wire[2:0]tmds,
	output wire tmdsc,
	//System bus
	input wire[7:0]DIN,
	input wire[15:0]ADD,
	input wire WR,
	input wire IOWR,
	//STR INT
	output wire STRINT,
	//SCREEN
	output wire SCR,
	//Debug
	//output wire[7:0]RAZR,
	//output wire[7:0]SEG,
	input wire[7:0]RDO
);

`define DEBUG

wire[7:0]R,G,B;
wire[7:0]Rb,Gb,Bb;
wire[7:0]Rc,Gc,Bc;
wire[10:0]HCNT,VCNT;
wire VISIBLE,VS;


hdmi mhd(.pixclk(pixclk),.clk_TMDS(hclk),.n_rst(rst),.TMDSp(tmds),.TMDSp_clock(tmdsc),
			.red(R),.green(G),.blue(B),.visible(VISIBLE),.HCNT(HCNT),.VCNT(VCNT),.vs(VS));
			
						
//Video RAM
wire VR_RCLK,VR_WCLK;
wire WREN0,WREN1,WREN2,WREN3;
wire[7:0]VR_DO0,VR_DO1,VR_DO2,VR_DO3;
wire[12:0]VR_RADD;

VRAM b0(
	.data(DIN),
	.rdaddress(VR_RADD),
	.rdclock(VR_RCLK),
	.wraddress(ADD[12:0]),
	.wrclock(VR_WCLK),
	.wren(WREN0),
	.q(VR_DO0)
	);
	
VRAM b1(
	.data(DIN),
	.rdaddress(VR_RADD),
	.rdclock(VR_RCLK),
	.wraddress(ADD[12:0]),
	.wrclock(VR_WCLK),
	.wren(WREN1),
	.q(VR_DO1)
	);
	
VRAM b2(
	.data(DIN),
	.rdaddress(VR_RADD),
	.rdclock(VR_RCLK),
	.wraddress(ADD[12:0]),
	.wrclock(VR_WCLK),
	.wren(WREN2),
	.q(VR_DO2)
	);

VRAM b3(
	.data(DIN),
	.rdaddress(VR_RADD),
	.rdclock(VR_RCLK),
	.wraddress(ADD[12:0]),
	.wrclock(VR_WCLK),
	.wren(WREN3),
	.q(VR_DO3)
	);
	
assign WREN0 = (ADD[15:13] == 3'b111)? 1'b1 : 1'b0; //BANK0 E000-FFFF
assign WREN1 = (ADD[15:13] == 3'b110)? 1'b1 : 1'b0; //BANK1 C000-DFFF
assign WREN2 = (ADD[15:13] == 3'b101)? 1'b1 : 1'b0; //BANK2 A000-BFFF
assign WREN3 = (ADD[15:13] == 3'b100)? 1'b1 : 1'b0; //BANK3 8000-9FFF
assign VR_WCLK = (WR | pixclk);

//Border
wire BORDER,SCREEN;
wire[10:0]NHCNT,NVCNT;
reg[7:0]vscroll;
reg[3:0]regim;

assign BORDER = (VCNT >= 43 && VCNT < 555 && HCNT >= (145) && HCNT < (655))? 1'b1 : 1'b0;
assign SCREEN = (VCNT >= 43 && VCNT < 555)? 1'b1 : 1'b0;
assign SCR = SCREEN;
assign NHCNT = HCNT - (143 - 16);
assign NVCNT = VCNT - 43;
assign VR_RADD[7:0] = vscroll - NVCNT[8:1];// + vscroll;
assign VR_RADD[12:8] = NHCNT[8:4];

//Запрос на кадровое прерывание
assign STRINT = (VCNT == 555 && HCNT >= 1 && HCNT < 5)? 1'b1 : 1'b0; 

//Автомат чтения данных пикселей
reg[15:0]tzd[0:3],zd[0:3];
reg vclk;

always@(posedge pixclk or negedge CRST)
	begin
		if(!CRST)
			begin	
				zd[0] <= 16'h00;
				zd[1] <= 16'h00;
				zd[2] <= 16'h00;
				zd[3] <= 16'h00;
				tzd[0] <= 16'h00;
				tzd[1] <= 16'h00;
				tzd[2] <= 16'h00;
				tzd[3] <= 16'h00;
				vclk <= 0;
			end
		else
			begin
				case(NHCNT[3:0])
					1: vclk <= 1'b1;
					5: vclk <= 1'b0;
					10: 
						begin
							if(regim[0]) //512x256
								begin
									//1
									tzd[0][15:0] <= {VR_DO0[7],1'b0,VR_DO0[6],1'b0,VR_DO0[5],1'b0,VR_DO0[4],1'b0,
														  VR_DO0[3],1'b0,VR_DO0[2],1'b0,VR_DO0[1],1'b0,VR_DO0[0],1'b0};
									//2
									tzd[1][15:0] <= {VR_DO1[7],1'b0,VR_DO1[6],1'b0,VR_DO1[5],1'b0,VR_DO1[4],1'b0,
														  VR_DO1[3],1'b0,VR_DO1[2],1'b0,VR_DO1[1],1'b0,VR_DO1[0],1'b0};
									//4					  
									tzd[2][15:0] <= {1'b0,VR_DO2[7],1'b0,VR_DO2[6],1'b0,VR_DO2[5],1'b0,VR_DO2[4],
														  1'b0,VR_DO2[3],1'b0,VR_DO2[2],1'b0,VR_DO2[1],1'b0,VR_DO2[0]};
									//8
									tzd[3][15:0] <= {1'b0,VR_DO3[7],1'b0,VR_DO3[6],1'b0,VR_DO3[5],1'b0,VR_DO3[4],
														  1'b0,VR_DO3[3],1'b0,VR_DO3[2],1'b0,VR_DO3[1],1'b0,VR_DO3[0]};	
								end
							else //256x256
								begin
									tzd[0][15:0] <= {{2{VR_DO0[7]}},{2{VR_DO0[6]}},{2{VR_DO0[5]}},{2{VR_DO0[4]}},
															{2{VR_DO0[3]}},{2{VR_DO0[2]}},{2{VR_DO0[1]}},{2{VR_DO0[0]}}};
									tzd[1][15:0] <= {{2{VR_DO1[7]}},{2{VR_DO1[6]}},{2{VR_DO1[5]}},{2{VR_DO1[4]}},
															{2{VR_DO1[3]}},{2{VR_DO1[2]}},{2{VR_DO1[1]}},{2{VR_DO1[0]}}};
									tzd[2][15:0] <= {{2{VR_DO2[7]}},{2{VR_DO2[6]}},{2{VR_DO2[5]}},{2{VR_DO2[4]}},
															{2{VR_DO2[3]}},{2{VR_DO2[2]}},{2{VR_DO2[1]}},{2{VR_DO2[0]}}};
									tzd[3][15:0] <= {{2{VR_DO3[7]}},{2{VR_DO3[6]}},{2{VR_DO3[5]}},{2{VR_DO3[4]}},
															{2{VR_DO3[3]}},{2{VR_DO3[2]}},{2{VR_DO3[1]}},{2{VR_DO3[0]}}};
								end
						end
					0: 
						begin
							zd[0] <= tzd[0];
							zd[1] <= tzd[1];
							zd[2] <= tzd[2];
							zd[3] <= tzd[3];
						end
					
				endcase
			end
	end

assign VR_RCLK = ~vclk;

//ОЗУ палитры
reg[7:0]color[0:15];
wire[3:0]COL;
reg[3:0]PALET_ADD,BCLR;
reg ruslat;


//Запись цвета в регистры палитры
always@(negedge IOWR or negedge CRST)
begin
	if(!CRST)
		begin
			color[0] = ~8'b11111111;
			color[1] = ~8'b01010101;
			color[2] = ~8'b11010111;
			color[3] = ~8'b10000111;
			color[4] = ~8'b11101010;
			color[5] = ~8'b01101000;
			color[6] = ~8'b11010000;
			color[7] = ~8'b11000000;
			color[8] = ~8'b10111101;
			color[9] = ~8'b01111010;
			color[10] = ~8'b11000111;
			color[11] = ~8'b00111111;
			color[12] = ~8'b11101000;
			color[13] = ~8'b11010010;
			color[14] = ~8'b10010000;
			color[15] = ~8'b00000010;
			PALET_ADD <= 0;
			BCLR <= 0;
			vscroll <= 8'hFF;
			regim <= 4'h0;
			ruslat <= 0;
		end
	else
		begin
			case(ADD[15:8])
				8'h01: ruslat <= DIN[3];
				8'h02:
					begin						
						if(SCREEN) 
							begin
								BCLR[3:0] <= DIN[3:0];	
								regim[3:0] <= DIN[7:4];
							end
						else 
							begin
								PALET_ADD[3:0] <= DIN[3:0];	
							end
					end
				8'h03:
					begin
						if(!SCREEN) vscroll <= DIN[7:0];
					end
				8'h0C: color[(PALET_ADD[3:0])] <= DIN;
				8'h0D: color[(PALET_ADD[3:0])] <= DIN;
				8'h0E: color[(PALET_ADD[3:0])] <= DIN;
				8'h0F: color[(PALET_ADD[3:0])] <= DIN;
				default:;
			endcase
		end
end

`ifdef DEBUG
//*********************************************************************************
//Debug info
wire[7:0]ZK_DO;
wire[10:0]ZK_ADD;
wire ZK_CLK;

wire[7:0]symb[0:15];

assign symb[0] = 8'h30;//0
assign symb[1] = 8'h31;//1
assign symb[2] = 8'h32;//2
assign symb[3] = 8'h33;//3
assign symb[4] = 8'h34;//4
assign symb[5] = 8'h35;//5
assign symb[6] = 8'h36;//6
assign symb[7] = 8'h37;//7
assign symb[8] = 8'h38;//8
assign symb[9] = 8'h39;//9
assign symb[10] = 8'h41;//A
assign symb[11] = 8'h42;//B
assign symb[12] = 8'h43;//C
assign symb[13] = 8'h44;//D
assign symb[14] = 8'h45;//E
assign symb[15] = 8'h46;//F


ZROM zkr(
	.address(ZK_ADD),
	.clock(ZK_CLK),
	.q(ZK_DO)
	);
	
wire[10:0]ZHCNT,ZNAKOMESTO;

assign ZHCNT = HCNT - 16;
assign ZNAKOMESTO = (ZHCNT[10:4]) + (VCNT[10:4] * 50);

reg zclk;
reg[7:0]znak;
reg[15:0]znd,tznd;


always@(negedge pixclk or negedge rst)
	begin
		if(!rst)
			begin					
				zclk <= 0;
				znak <= 0;
				znd <= 0;
				tznd <= 0;
			end
		else
			begin
				case(ZHCNT[3:0])
					1: 
						begin
							case(ZNAKOMESTO)
								//SS
								0: 
									begin
										if(RDO[0]) znak <= 0; //S
										else znak <= 83;
									end
								1: 
									begin
										if(RDO[0]) znak <= 0; //S
										else znak <= 83;
									end
								//US
								3: 
									begin
										if(RDO[1]) znak <= 0; //U
										else znak <= 85;
									end
								4: 
									begin
										if(RDO[1]) znak <= 0; //S
										else znak <= 83;
									end
								//RUS
								6: 
									begin
										if(!ruslat) znak <= 76; //L
										else znak <= 82; //R
									end
								7: 
									begin
										if(!ruslat) znak <= 65; //A
										else znak <= 85; //U
									end
								8: 
									begin
										if(!ruslat) znak <= 84; //T
										else znak <= 83; //S
									end
								//VVOD
								10: 
									begin
										if(RDO[3]) znak <= 66; //B
										else znak <= 0; 
									end
								11: 
									begin
										if(RDO[3]) znak <= 66; //B
										else znak <= 0;
									end
								12: 
									begin
										if(RDO[3]) znak <= 79; //O
										else znak <= 0;
									end
								13: 
									begin
										if(RDO[3]) znak <= 100; //Д
										else znak <= 0;
									end
								//Resolution
								40:
									begin
										if(regim[0]) znak <= 53; //5
										else znak <= 50; //2
									end
								41:
									begin
										if(regim[0]) znak <= 49; //1
										else znak <= 53; //5
									end
								42:
									begin
										if(regim[0]) znak <= 50; //2
										else znak <= 54; //6
									end
								43: znak <= 88; //X
								44: znak <= 50; //2
								45: znak <= 53; //5
								46: znak <= 54; //6
								
								default: znak <= 0;
							endcase							
						end
					2: zclk <= 1'b1;
					4: zclk <= 1'b0;
					6: 
						begin
							tznd <= {{2{ZK_DO[7]}},{2{ZK_DO[6]}},{2{ZK_DO[5]}},{2{ZK_DO[4]}},
												  {2{ZK_DO[3]}},{2{ZK_DO[2]}},{2{ZK_DO[1]}},{2{ZK_DO[0]}}};
						end
					0: 
						begin
							znd <= tznd;
						end
					
				endcase
			end
	end
	
assign ZK_ADD = (znak * 8) + VCNT[3:1];
assign ZK_CLK = ~zclk;

//*********************************************************************************

//Бордюр
wire[7:0]CBr,CBg,CBb;

assign CBr = {{2{color[BCLR][2]}},{2{color[BCLR][1]}},{2{color[BCLR][0]}},2'b00};
assign CBg = {{2{color[BCLR][5]}},{2{color[BCLR][4]}},{2{color[BCLR][3]}},2'b00};
assign CBb = {{3{color[BCLR][7]}},{3{color[BCLR][6]}},2'b00};

//Debug
assign Rc = (BORDER)? Rb : ((znd[(15-HCNT[3:0])])? CBr : ~CBr);
assign Gc = (BORDER)? Gb : ((znd[(15-HCNT[3:0])])? CBg : ~CBg);
assign Bc = (BORDER)? Bb : ((znd[(15-HCNT[3:0])])? CBb : ~CBb);
`else
assign Rc = (BORDER)? Rb : {{2{color[BCLR][2]}},{2{color[BCLR][1]}},{2{color[BCLR][0]}},2'b00};
assign Gc = (BORDER)? Gb : {{2{color[BCLR][5]}},{2{color[BCLR][4]}},{2{color[BCLR][3]}},2'b00};
assign Bc = (BORDER)? Bb : {{3{color[BCLR][7]}},{3{color[BCLR][6]}},2'b00};
`endif

//Гашение
assign R = (VISIBLE)? Rc : 8'h00;	
assign G = (VISIBLE)? Gc : 8'h00;	
assign B = (VISIBLE)? Bc : 8'h00;

assign COL[3:0] = {zd[3][(15-HCNT[3:0])],zd[2][(15-HCNT[3:0])],zd[1][(15-HCNT[3:0])],zd[0][(15-HCNT[3:0])]};

assign Rb[7:0] = {{2{color[COL][2]}},{2{color[COL][1]}},{2{color[COL][0]}},2'b00};
assign Gb[7:0] = {{2{color[COL][5]}},{2{color[COL][4]}},{2{color[COL][3]}},2'b00};
assign Bb[7:0] = {{3{color[COL][7]}},{3{color[COL][6]}},2'b00};

/*
//Debug
din7seg md7s(
.clk(pixclk),
.I0(color[0][3:0]),
.I1(color[0][7:4]),
.I2(color[1][3:0]),
.I3(color[1][7:4]),
.I4(color[2][3:0]),
.I5(color[2][7:4]),
.I6(color[3][3:0]),
.I7(color[3][7:4]),
.SEG(SEG),
.RAZR(RAZR)
);
*/

endmodule










