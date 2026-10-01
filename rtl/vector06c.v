module vector06c(
	//Common
	input wire clk,
	input wire rst,
	input wire HOLD,
	//HDMI
	output wire[2:0]tmds,
	output wire tmdsc,
	//SRAM
	output wire[18:0]ER_ADD,
	inout wire[15:0]ER_D,
	output wire ER_CS,
	output wire ER_OE,
	output wire ER_WE,
	output wire ER_BH,
	output wire ER_BL,
	//USB_Keyboard
	input wire KB_MOSI,
	input wire KB_SCK,
	input wire KB_CS,
	input wire KB_LATCH,
	//SPI Flash
	output wire SPI_CS,
	output wire MOSI,
	output wire SCK,
	input wire MISO,
	//Periferal DEV
	input wire MAG_IN,
	output wire MAG_OUT,
	//Beep
	output wire BEEP,
	//Switch
	input wire[1:0]SW,
	//Debug
	//output wire[7:0]SEG,
	//output wire[7:0]RAZR,
	output wire LED
);



//`define SRAMROM     //Загрузчик грузится со spi flash в SRAM
`define BRAMROM    //Загрузчик в блочной памяти

`define USB_KEYBOARD

//`define ROM8      //Расширенный ROM 8Kb (0000h-0FFFh,8000h-8FFFh) экспериментально
//`define PRELOADED		//Предзагруженные программы, запускать 


//PLL
wire CLK_1_5,CLK_12,CLK_36,CLK_180;

main_pll mpl(.inclk0(clk),.c0(CLK_12),.c1(CLK_36),.c2(CLK_180));

//Clock
reg[22:0] div;
always@(posedge CLK_12) div <= div + 1;

assign CLK_1_5 = div[2];

//CPU
wire[15:0]CPU_ADD;
wire[7:0]CPU_DI,CPU_DO,IO_DO;
wire CRST,KBRST;
//I8080
wire RM,WM,RIO,WIO,DBIN,WO,HLDA,SYNC,F1,F2,INT,INTE;

`ifdef SRAMROM
	assign CRST = (rst & HOLD & ~PROG & KBRST);
`else
	assign CRST = (rst & HOLD);
`endif

assign F1 = div[1] & div[0];
assign F2 = ~div[1];

//INTERRUPT Request
tm2 dff0(
	.C(STRINT), 
	.R(CRST), 
	.S(INTE), 
	.D(1'b0), 
	.Qn(INT)
);


vm80a_core mcp
(
   .pin_clk(clk),
   .pin_f1(F1),
   .pin_f2(F2),
   .pin_reset(~CRST),
   .pin_a(CPU_ADD),
   .pin_dout(CPU_DO),
   .pin_din(CPU_DI),
	.pin_ready(1'b1),
   .pin_hold(1'b0),
	.pin_int(INT),
	.pin_inte(INTE),
   .pin_wr_n(WO),
   .pin_dbin(DBIN),
	.pin_hlda(HLDA),
	.pin_sync(SYNC),
);

reg[7:0]i8080ctrl;
wire[7:0]CCTRL;

always@(negedge F1) if(SYNC == 1) i8080ctrl[7:0] <= CPU_DO[7:0];
	
assign CCTRL = i8080ctrl;

assign RIO = ~(DBIN & CCTRL[6]);
assign WIO = ~(CCTRL[4] & ~WO); 
assign RM = ~(DBIN & CCTRL[7]);
assign WM = ~(~CCTRL[4] & ~WO);

`ifdef SRAMROM 
//Programmer
wire PROG,PROGWE;
wire[18:0]PROGADD;
wire[7:0]PROGDO;

programmer mpg(
   .clk(clk),	 
   .rst(rst),	 
   .PROG(PROG),
   .SRAMADD(PROGADD),
   .SRAMDO(PROGDO),
   .SRAMWE(PROGWE),
	.SPI_CS(SPI_CS),
	.SPI_MOSI(MOSI),
	.SPI_MISO(MISO),
	.SPI_SCK(SCK)
);
`endif

wire STRINT,SCREEN;

videoprocessor mvp(
	.pixclk(CLK_36),
	.hclk(CLK_180),
	.rst(rst),
	.CRST(CRST),
	.tmds(tmds),
	.tmdsc(tmdsc),
	.DIN(CPU_DO),
	.ADD(CPU_ADD),
	.WR(WM),
	.IOWR(WIO),
	.STRINT(STRINT),
	.SCR(SCREEN),
	//Debug
	//.RAZR(RAZR),
	//.SEG(SEG),
	.RDO({4'b0000,VVOD,KPC})
);


//Connect & Disconnect ROM
reg start;	
wire R_LATCH,VVOD;


	

`ifdef ROM8
reg block8;

always@(negedge RIO or negedge CRST)
	begin
		if(!CRST) block8 <= 0;
		else
			begin
				if(CPU_ADD[15:8]==8'h0F) block8 <= 1;
			end
	end

assign R_LATCH = (CPU_ADD[14] | CPU_ADD[13] | CPU_ADD[12] | block8);		
`else
assign R_LATCH = (CPU_ADD[14] | CPU_ADD[14] | CPU_ADD[13] | CPU_ADD[12]);	
`endif		  


always@(negedge CRST)
	begin
		start <= VVOD;
	end

	
//SRAM
wire[18:0]MON_ADD;

/***********************************************************************
	После сброса подключаем ROM с загрузчиком на чтение в окно 0000h,
	запись продолжаем в RAM.
	Как только на обной из линий адреса CPU A[15:12] появится единица,
	отключаем ROM и работаем только с RAM.
	ROM расположен в первых 64Kb SRAM, RAM - в следующих 64Kb.
************************************************************************/
`ifdef SRAMROM //

wire[15:0] ER_DI;
`ifdef PRELOADED
assign MON_ADD[18:0] = {1'b0,SW[1:0],CPU_ADD[15:0]};
`else
assign MON_ADD[18:0] = (R_LATCH | start)? {3'b001,CPU_ADD[15:0]} : ((RM)? {3'b001,CPU_ADD[15:0]} : {3'b000,CPU_ADD[15:0]});
`endif
assign ER_ADD[18:0] = (PROG)? PROGADD[18:0] : MON_ADD[18:0];
assign ER_D = (ER_WE == 0)? ER_DI : 16'bzzzzzzzzzzzzzzzz;
assign ER_DI[7:0] = (PROG)? PROGDO : CPU_DO;
assign ER_DI[15:8] = 8'hFF;
assign ER_WE = (PROG)? PROGWE : WM;
assign ER_OE = (PROG)? 1'b1 : RM;
assign ER_CS = (PROG)? 1'b0 : (RM & WM);
assign ER_BH = 1'b1;
assign ER_BL = 1'b0;

`endif

`ifdef BRAMROM //BRAM ROM

assign ER_ADD[18:0] = {3'b000,CPU_ADD[15:0]};
assign ER_D[7:0] = (ER_WE == 0)? CPU_DO[7:0] : 8'bzzzzzzzz;
assign ER_WE = WM;
assign ER_OE = RM;
assign ER_CS = (RM & WM);
assign ER_BH = 1'b1;
assign ER_BL = 1'b0;

//Loader ROM
wire[7:0] LOAD_DO;

`ifdef ROM8
LOADER8 lrom(
	.address({CPU_ADD[15],CPU_ADD[11:0]}),
	.clock(RM | CLK_12),
	.q(LOAD_DO)
	);
`else
LOADER lrom(
	.address({CPU_ADD[10:0]}),
	.clock(RM | CLK_12),
	.q(LOAD_DO)
	);
`endif
	
`endif


//Keyboard
wire[7:0]KPA;
wire[7:0]KPB;
wire[2:0]KPC;

`ifdef PS2_KEYBOARD
keyboard  mkbp(
	.clk(CLK_36),
	.rst(rst),
	.clock(PS2_CLK),
	.dat(PS_DAT),
	.PA(KPA),
	.PC(KPC),
	.PB(KPB),
	.LED(LED)
	);
`endif

`ifdef USB_KEYBOARD

keyboard_usb  mkbu(
	.rst(rst),
	.MOSI(KB_MOSI),
	.SCK(KB_SCK),
	.CS(KB_CS),
	.LATCH(KB_LATCH),
	.PA(KPA), //SCAN ADDRESS PORT
	.PC(KPC), //DOB BUTTON PORT: {SS,UST,RUS}
	.PB(KPB), //KEY DATA PORT
	.VVOD(VVOD),
	.RESET(KBRST),
	.LED(LED) //Debug
);

`endif

wire[7:0]VI53_DO;
wire[2:0]VI53_OUT;
wire VI53_WR,VI53_RD;

assign VI53_WR = (CPU_ADD[15:8] == 8'h08)? WIO : 1'b1;
assign VI53_RD = (CPU_ADD[15:8] == 8'h08)? RIO : 1'b1;

k580vi53 pwm(
	// CPU bus
	.reset(rst),
	.clk_sys(clk),
	.addr(CPU_ADD[1:0]),
	.din(CPU_DO),
	.dout(VI53_DO),
	.wr(VI53_WR),
	.rd(VI53_RD),
	.clk_timer({CLK_1_5,CLK_1_5,CLK_1_5}),
	.gate(3'b111),
	.out(VI53_OUT)
);

assign BEEP = VI53_OUT[0];

//IO Ports
reg[7:0]kpa;

always@(negedge CRST or negedge WIO)
	begin
		if(!CRST)
			begin
				kpa <= 8'hFF;
			end
		else
			begin
				case(CPU_ADD[15:8])
					8'h03:
						begin
							if(!SCREEN) kpa <= CPU_DO;
						end
				endcase
			end
	end
	
assign KPA = kpa;

reg[7:0]dio;

always@(negedge CRST or negedge RIO)
	begin
		if(!CRST) dio <= 8'hFF;
		else
			begin
				case(CPU_ADD[15:8])
					8'h01: dio <= {KPC[2:0],~MAG_IN,4'b1111};
					8'h02:
						begin
							if(!SCREEN) dio <= KPB;
						end
					8'h08: dio <= VI53_DO;
					default:  dio <= 8'hFF;
				endcase
			end
	end

//CPU DATA IN	
assign IO_DO = dio;

`ifdef SRAMROM
	assign CPU_DI = (~RM)? ER_D[7:0] : ((~RIO)? IO_DO : 8'hFF);
`endif

`ifdef BRAMROM
	assign CPU_DI = (~RM)? ((R_LATCH | start)? ER_D[7:0] : LOAD_DO[7:0]) : ((RIO==0)? IO_DO : 8'hFF);
`endif


endmodule


module tm2(
	input wire C, 
	input wire R, 
	input wire S,
	input wire D, 
	output wire Q,
	output wire Qn
);

reg q;
wire RS;
assign RS = R & S;

always@(posedge C or negedge RS)
	begin
		if(!RS)
			begin
				if(R==0) q <= 0;
				if(S==0) q <= 1;
			end
		else q <= D;
   end

		
	assign Q = q;
	assign Qn = ~q;

endmodule

