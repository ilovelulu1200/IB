//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   2021 ICLAB Spring Course
//   Lab02			: String Match Engine (SME)
//   Author         : Shiuan-Yun Ding (mirkat.ding@gmail.com)
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : SME.v
//   Module Name : SME
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module SME(
    // Input signals
    clk,
    rst_n,
    chardata,
    isstring,
    ispattern,
    // Output signals
    out_valid,
    match,
    match_index
);
//================================================================
//  INPUT AND OUTPUT DECLARATION                         
//================================================================
input clk;
input rst_n;
input [7:0] chardata;
input isstring;
input ispattern;
output reg match;
output reg [4:0] match_index;
output reg out_valid;
//================================================================
//  integer / genvar / parameters
//================================================================
integer i ;
genvar idx, jdx;
// Special charaters
parameter CHR_START = 8'h5E ;   // ^ : starting position of the string or 'space' would match
parameter CHR_ENDIN = 8'h24 ;   // $ : ending position of the string or 'space' would match
parameter CHR_ANYSG = 8'h2E ;   // . : any of a single charater would match
parameter CHR_ANYML = 8'h2A ;   // * : any of multiple characters would match
parameter CHR_SPACE = 8'h20 ;   //   : space
parameter CHR_NOTHING = 8'h00 ;   // my own definition, used in string
parameter CHR_MATCH = 8'h01 ;   // my own definition, used in pattern
//================================================================
//   Wires & Registers 
//================================================================
//  INPUT
reg f_isstring, f_ispattern;
reg [7:0] String[0:33];         // [0], [33] : for checking CHR_START/CHR_ENDIN
reg [7:0] Pattern[0:7];
reg [5:0] head_str;             // head position of the input string among string[0:33]
reg [3:0] head_ptn ;            // head position of the input pattern among pattern[0:7]
//  Handle The Fucking Annoying *
reg is_star;                    // is there a star in the input pattern
reg [3:0] pos_star;             // pattern[0~7] <--> pos_star[0~8], where 8 means no star
//local parameter
localparam IDLE = 3'b000;
localparam READ_STRING = 3'b001;
localparam READ_PATTERN = 3'b010;
localparam COMPUTE = 3'b011;
localparam FINISH = 3'b100;

reg [2:0] current_state, next_state;        //state

//no_star
reg is_match ;
// wire match_en  ;
reg match_en ;
wire cmp_flag ;
reg f_cmp_flag ;

reg [5:0] str_index ;
reg [5:0] f_str_index ; 
reg [3:0] ptn_index ;
reg [3:0] BS_count_CHR_ANYSG ;

reg [5:0] cmp_str_index ;
reg [3:0] cmp_ptn_index ;

//is_star
reg star_is_match ;
// wire star_match_en  ;
reg star_match_en  ;
wire star_cmp_flag ;
reg f_star_cmp_flag ;

reg [5:0] star_str_index ;
reg [5:0] f_star_str_index ;
reg [3:0] star_ptn_index ;

reg [5:0] cmp_star_str_index ;
reg [3:0] cmp_star_ptn_index ;
//
reg [5:0] pre_match_index;
reg unmatch ;
// reg used_CHR_START ;
reg [5:0] real_start_match ;
reg [5:0] not_char ;
// wire BS_CHR_ANYSG ;
//================================================================
//  OUTPUT : out_valid & match
//================================================================
// out_valid
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     out_valid <= 0 ;
    else begin
        if ( current_state == FINISH ) out_valid <= 1 ;
        else out_valid <= 0 ;   
    end
end

// match
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) match <= 0 ;
    else if ( current_state == IDLE ) match <= 0 ;
    // else if ( String[33] == Pattern[6] && Pattern[7] == CHR_ANYSG ) match <= 1'b1 ;
    else if ( is_star == 0 ) match <= is_match ;
    else if ( is_star == 1 && is_match == 1 && star_is_match == 1 ) match <= 1'b1 ;

    else match <= 0 ;
end
//================================================================
//  OUTPUT : match_index
//================================================================

//real_start_match (含自己家的CHR_START)
always @( posedge match_en ) begin
    real_start_match <= str_index - 1 ;
end

//     + 1 到 非特殊字串並記數
//not_char
always @( posedge clk , negedge rst_n) begin
    if ( !rst_n ) not_char <= 0 ;
    else if ( out_valid ) not_char <= 0 ;
    else if ( match_en == 1 ) begin
        if ( String[real_start_match + not_char] == CHR_START || String[real_start_match + not_char] == CHR_ENDIN 
        ) begin
            not_char <= not_char + 1 ;
        end
    end
end


//pre_match_index // - 1 為一開始家的CHR_START
always @( posedge match_en ) begin
    // pre_match_index <= str_index - head_str  ;
    if ( str_index > head_str ) pre_match_index <= str_index - head_str - 1 ;
    else pre_match_index <= head_str - str_index - 1 ;
end

//BS_count_CHR_ANYSG
always @( posedge clk , negedge rst_n ) begin
    if ( !rst_n ) BS_count_CHR_ANYSG <= 0 ;
    else if ( out_valid ) BS_count_CHR_ANYSG <= 0 ;
    else if ( is_star != 1'b1 && chardata == CHR_ANYSG && BS_count_CHR_ANYSG <= 4'd6 ) BS_count_CHR_ANYSG <= BS_count_CHR_ANYSG + 1 ;
end

//match_index
always @( posedge clk , negedge rst_n ) begin
    if ( !rst_n ) match_index <= 0 ;
    else begin
        if ( current_state == FINISH ) begin
            if ( pos_star == head_ptn ) match_index = 0 ;
            else if ( ( pos_star - BS_count_CHR_ANYSG ) == 0 ) match_index = 0 ;//*前全是.的情況
            // else if ( String[32] == Pattern[6] && Pattern[7] == CHR_ANYSG ) match_index <= 0 ;
            else begin
                if ( is_star == 0 && is_match ) match_index <= pre_match_index + not_char  ;   
                else if ( is_star == 1 && is_match == 1 && star_is_match == 1 ) match_index <= pre_match_index + not_char  ;  
                else match_index <= 0 ;
            end 
        end
    end
end

//**************************************** NO STAR **************************************************//

assign cmp_flag = ( String[str_index] == Pattern[ptn_index] ) ? 1'b1 
: ( ( match_en == 1 ) ? 1'b1
: ( ( Pattern[ptn_index] == CHR_ANYSG && String[str_index] != CHR_ENDIN ) ? 1'b1 
: ( ( Pattern[ptn_index] == CHR_ANYML ) ? 1'b1 
: ( ( Pattern[ptn_index] == CHR_START && String[str_index] == CHR_SPACE ) ? 1'b1 
: ( ( Pattern[ptn_index] == CHR_ENDIN && String[str_index] == CHR_SPACE ) ? 1'b1 : 1'b0 ) ) ) ) ) ;

always @( * ) begin
    if ( String[cmp_str_index] == Pattern[cmp_ptn_index] ) match_en <= 1 ;
    else if ( Pattern[cmp_ptn_index] == CHR_ANYSG && String[cmp_str_index] != CHR_ENDIN ) match_en <= 1 ;
    else if ( Pattern[cmp_ptn_index] == CHR_ANYML ) match_en <= 1 ;
    else if ( Pattern[cmp_ptn_index] == CHR_START && String[cmp_str_index] == CHR_SPACE ) match_en <= 1 ;
    else if ( Pattern[cmp_ptn_index] == CHR_ENDIN && String[cmp_str_index] == CHR_SPACE ) match_en <= 1 ;
    else match_en <= 0 ;
end

// assign f_cmp_flag = ( String[f_str_index] == Pattern[ptn_index] ) ? 1'b1 : 1'b0 ;
always @( * ) begin
    if ( String[f_str_index] == Pattern[ptn_index] ) f_cmp_flag <= 1 ;
    else f_cmp_flag <= 0 ;
end

//輸入完後將陣列首值給index(只在變COMPUTE時給一次
always @( current_state ) begin
    if ( current_state == COMPUTE ) begin
        if ( Pattern[head_ptn] == CHR_START ) begin
        str_index <= head_str - 2 ;
        ptn_index <= head_ptn ;    
        end
        else begin
            str_index <= head_str ;
            ptn_index <= head_ptn ;
        end
    end
end


//*前CMP_INDEX計算
always @( posedge clk, negedge rst_n ) begin
    if ( !rst_n ) begin
        cmp_str_index <= 0 ;
        cmp_ptn_index <= 0 ;
    end        
    else if ( current_state == COMPUTE ) begin
        if ( ( f_cmp_flag == 1 || cmp_flag == 1 ) && is_match != 1) begin
            cmp_str_index <= str_index  ; //CMP落後一回合且第一個自備CMP_FLAG驗證過了
            cmp_ptn_index <= ptn_index  ;
            if ( match_en == 1 )    begin
                    cmp_str_index <= cmp_str_index + 1 ;
                    cmp_ptn_index <= cmp_ptn_index + 1 ;
            end
            else if ( match_en == 0 ) begin
                str_index <= str_index + 1 ;
            end 
        end
        else if ( cmp_flag == 0 && is_match != 1 ) str_index <= str_index + 1 ;
        else if ( is_match == 1) begin
                cmp_str_index <= cmp_str_index ;
                cmp_ptn_index <= cmp_ptn_index ;
        end
    end
    else if ( out_valid ==1 ) begin
        cmp_str_index <= 0 ;
        cmp_ptn_index <= 0 ;
    end
end


//str_index
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        str_index <= 0 ;
    end
    else begin
         if ( out_valid == 1 ) begin
            str_index <= 0 ;
        end   
    end
end

//f_str_index
always @( posedge clk , negedge rst_n ) begin
    if ( !rst_n ) f_str_index <= 1 ;
    else if ( cmp_flag == 1 || f_cmp_flag == 1 ) f_str_index <= f_str_index ;
    else f_str_index <= str_index ;
end

//is_match
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     is_match <= 0 ;
    else begin
        if ( out_valid ) is_match <= 0 ;
        else if ( ispattern != 1 && f_ispattern != 1 ) begin
                if ( cmp_ptn_index ==4'd7 && match_en == 1  ) is_match <= 1 ;
                else if ( is_star == 1 && ( ptn_index == pos_star || cmp_ptn_index == pos_star ) ) is_match <= 1 ;
        end
    end
end


//************************** IS STAR *********************************************************************//

assign star_cmp_flag = ( String[star_str_index] == Pattern[star_ptn_index] ) ? 1'b1 
: ( ( star_match_en == 1 ) ? 1'b1 
: ( ( Pattern[star_ptn_index] == CHR_ANYSG && String[star_str_index] != CHR_ENDIN ) ? 1'b1 
: ( ( Pattern[star_ptn_index] == CHR_ANYML ) ? 1'b1 
: ( ( Pattern[star_ptn_index] == CHR_START && String[star_str_index] == CHR_SPACE ) ? 1'b1 
: ( ( Pattern[star_ptn_index] == CHR_ENDIN && String[star_str_index] == CHR_SPACE ) ? 1'b1 : 1'b0 ) ) ) ) ) ;

always @( * ) begin
    if ( String[cmp_star_str_index] == Pattern[cmp_star_ptn_index] ) star_match_en <= 1 ;
    else if ( Pattern[cmp_star_ptn_index] == CHR_ANYSG && String[cmp_star_str_index] != CHR_ENDIN ) star_match_en <= 1 ;
    else if ( Pattern[cmp_star_ptn_index] == CHR_ANYML ) star_match_en <= 1 ;
    else if ( Pattern[cmp_star_ptn_index] == CHR_START && String[cmp_star_str_index] == CHR_SPACE ) star_match_en <= 1 ;
    else if ( Pattern[cmp_star_ptn_index] == CHR_ENDIN && String[cmp_star_str_index] == CHR_SPACE ) star_match_en <= 1 ;
    else star_match_en <= 0 ;
end

always @( * ) begin
    if ( String[f_star_str_index] == Pattern[star_ptn_index] ) f_star_cmp_flag <= 1 ;
    else if ( Pattern[star_ptn_index] == CHR_ANYSG && String[star_str_index] != CHR_SPACE  ) f_star_cmp_flag <= 1 ;
    else f_star_cmp_flag <= 0 ;
end

//輸入完後將陣列首值給index(只在變COMPUTE時給一次
always @( is_match ) begin
    if ( current_state == COMPUTE ) begin
        if ( ( pos_star - BS_count_CHR_ANYSG == 0 ) && BS_count_CHR_ANYSG != 0 ) begin
            star_str_index <= str_index - 1 + BS_count_CHR_ANYSG ;
            star_ptn_index <= pos_star + 1 ;
        end
        else begin
        star_str_index <= cmp_str_index - 1  ;
        star_ptn_index <= pos_star + 1 ;
        end
    end
end

//*後CMP_STAR_INDEX計算
always @( posedge clk, negedge rst_n ) begin
    if ( !rst_n ) begin
        cmp_star_str_index <= 0 ;
        cmp_star_ptn_index <= 0 ;
    end        
    else if ( current_state == COMPUTE ) begin
        if ( (f_star_cmp_flag == 1 || star_cmp_flag == 1 ) && is_match == 1 && star_is_match != 1 ) begin
            cmp_star_str_index <= star_str_index  ; //CMP落後一回合且第一個自備CMP_FLAG驗證過了
            cmp_star_ptn_index <= star_ptn_index  ;
            if ( star_match_en == 1 )    begin
                    cmp_star_str_index <= cmp_star_str_index + 1 ;
                    cmp_star_ptn_index <= cmp_star_ptn_index + 1 ;
            end
            else if ( star_match_en == 0 ) begin
                star_str_index <= star_str_index + 1 ;
            end 
        end
        else if ( star_is_match == 1) begin
                cmp_star_str_index <= cmp_star_str_index ;
                cmp_star_ptn_index <= cmp_star_ptn_index ;
        end
    end
    else if ( out_valid ==1 ) begin
        cmp_star_str_index <= 0 ;
        cmp_star_ptn_index <= 0 ;
    end
end

//star_str_index
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     star_str_index <= 0 ;
    else begin
        if ( star_cmp_flag != 1 && star_is_match != 1 && is_match == 1 
        && current_state == COMPUTE) star_str_index <= star_str_index + 1 ;
        else if ( out_valid == 1 ) star_str_index <= 0 ;   
    end
end
//star_ptn_index
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        star_ptn_index <= 0 ;
    end
    else begin
         if ( out_valid == 1 ) begin
            star_ptn_index <= 0 ;
        end   
    end
end

//f_star_str_index
always @( posedge clk , negedge rst_n ) begin
    if ( !rst_n ) f_star_str_index <= 0 ;
    else if ( star_cmp_flag == 1 || f_star_cmp_flag == 1 ) f_star_str_index <= star_str_index ;
    else f_star_str_index <= f_star_str_index ;
end

//star_is_match
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     star_is_match <= 0 ;
    else begin
        if ( out_valid ) star_is_match <= 0 ;
        else if ( cmp_star_ptn_index == 4'd7 && star_match_en == 1  ) star_is_match <= 1 ;
        else if ( pos_star == 7 && is_match == 1 ) star_is_match <= 1 ;
        else if ( out_valid == 1 ) star_is_match <= 0 ;   
    end
end

//unmatch
always @( posedge clk , negedge rst_n ) begin
    if ( !rst_n) unmatch <= 0 ;
    else if ( str_index == 6'd34 && match_en != 1) unmatch <= 1 ;
    else if ( star_str_index == 6'd34 && star_match_en != 1 ) unmatch <= 1 ;
    else unmatch <= 0 ;
end

//****************************** FINITE STATE MACHINE ********************************//

//FSM
always @(posedge clk, negedge rst_n) begin
    if(!rst_n) current_state <= IDLE;
    else current_state <= next_state;
end

always @(*) begin
    case (current_state)
        IDLE:begin
            if(isstring)    next_state = READ_STRING;
            else if(ispattern) next_state = READ_PATTERN;
            else            next_state = IDLE;
        end
        READ_STRING:begin
            if(ispattern) next_state = READ_PATTERN;
            else next_state = READ_STRING;
        end        
        READ_PATTERN:begin
            if(!ispattern) next_state = COMPUTE;
            else next_state = READ_PATTERN;
        end
        COMPUTE:begin
            if ( is_star == 0 && is_match == 1 ) next_state = FINISH ;
            else if ( is_star == 1 && is_match == 1 && star_is_match == 1 ) next_state = FINISH ;
            else if ( unmatch == 1 ) next_state = FINISH ;
            else next_state = COMPUTE;
        end
        FINISH:begin
            next_state = IDLE;
        end
        default:
            next_state = IDLE;
    endcase
end

//****************************** STAR ********************************//

// is_star
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     is_star <= 1'b0 ;
    else begin
        if (out_valid==1'b1)    is_star <= 1'b0 ;
        else if (ispattern==1'b1 & chardata==CHR_ANYML)    is_star <= 1'b1 ;
    end
end

// pos_star
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     pos_star <= 4'd8;
    else begin
        if (ispattern==1'b1 & chardata==CHR_ANYML)
            pos_star <= pos_star - 1 ;
        else if (ispattern==1'b1 & is_star==1'b1)
            pos_star <= pos_star - 1 ;
        else if (out_valid==1'b1)
            pos_star <= 4'd8 ;
    end
end

//****************************** INPUT ********************************//

// f_isstring
always @( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) f_isstring <= 0 ;
    else f_isstring <= isstring ;
end

//string : using shift register
//33 is CHR_ENDING
always @( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        for ( i=0 ; i<34 ; i=i+1 )
            String[i] <= CHR_NOTHING ; 
    end
    else begin
        String[33] <= CHR_ENDIN ;
        if ( isstring == 1'b1 ) begin
            if ( f_isstring == 0 ) begin
            String[31] <= CHR_START ;
            String[32] <= chardata ;
            //reset : when first string input
            for ( i=0 ; i<31 ; i=i+1 )
                String[i] <= CHR_NOTHING ;
        end
        else if ( f_isstring == 1'b1 ) begin
            String[32] <= chardata ;
            for ( i=31 ; i>=0 ; i=i-1 ) begin
                String[i] <= String[i+1] ;
            end
        end
        end
    end
end

//head_str
always @( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) head_str <= 6'd32 ;
    else begin
        if ( isstring == 1'b1 ) begin
            if ( f_isstring == 1'b1 ) head_str <= head_str - 1 ;
            else head_str <= 6'd32 ;
        end
    end    
end

// f_ispattern
always @( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) f_ispattern <= 0 ;
    else f_ispattern <= ispattern ;
end

//pattern : using shift register
always @( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        for ( i=0 ; i<8 ; i=i+1 )
            Pattern[i] <= CHR_MATCH ; 
    end
    else begin
        if ( ispattern == 1'b1 ) begin
            Pattern[7] <= chardata ;
            for ( i=6 ; i>=0 ; i=i-1 )
                Pattern[i] <= Pattern [i+1] ;     
        end
        else if ( out_valid == 1'b1 ) begin
            for ( i=0 ; i<8 ; i=i+1 )
                Pattern[i] <= CHR_MATCH ; 
        end
    end
end

//head_ptn
always @( posedge clk, negedge rst_n ) begin
    if ( !rst_n ) head_ptn <= 4'd7 ;
    if ( ispattern == 1'b1 ) begin
        if ( f_ispattern == 1'b1 ) head_ptn <= head_ptn - 1 ;
        else head_ptn <= 4'd7 ;
    end
end
endmodule

