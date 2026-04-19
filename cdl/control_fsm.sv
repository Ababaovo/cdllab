`timescale 1ns / 10ps

typedef enum logic [3:0]{
  IDLE=0, CLEAR=1, START=2, DATA1=3, DATA0=4, OUT=5, IN=6, ACK=7, EOP_START=8, EOP_0=9, WAIT_1=10, EOP_1=11, WAIT_2=12, IDLE_VAL=13, ERROR=14, DONE=15
} state_t;


module control_fsm (
    input  logic clk,
    input  logic n_rst,
    input  logic new_pack,
    input  logic pid_error,
    input  logic data_1,
    input  logic data_0,
    input  logic out_token,
    input  logic in_token,
    input  logic ack,
    input  logic strobes_16,
    input  logic cycles_8,
    input  logic dm,
    input  logic dp,
    input  logic data_done,
    input  logic token_match,
    output logic clear_err,
    output logic en_timer,
    output logic rx_data_ready,
    output logic transfer_active,
    output logic rx_buffer_flush,
    output logic rx_data_timer_en,
    output logic eop_err,
    output logic pack_done,
    output logic timer_16,
    output logic timer_8,
    output logic [2:0] rx_packet
);

state_t state, nextstate;
state_t prev_state;

always_ff @(posedge clk, negedge n_rst) begin : track_prev_state
    if (!n_rst)
        prev_state <= IDLE;
    else
        prev_state <= state;
end

always_comb begin : nextStateLogic
    casez ({state, new_pack, pid_error, data_1, data_0, out_token, in_token, ack, strobes_16, cycles_8, dm, dp, data_done})
        {IDLE, 1'b1, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = CLEAR;
        {CLEAR, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = START;
        {START, 1'b?, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = IDLE;
        {START, 1'b?, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = DATA1;
        {START, 1'b?, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = DATA0;
        {START, 1'b?, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = OUT;
        {START, 1'b?, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = IN;
        {START, 1'b?, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = ACK;
        {OUT, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = EOP_START;
        {IN, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = EOP_START;
        {EOP_START, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = EOP_0;
        {EOP_0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b0, 1'b0, 1'b?}: nextstate = WAIT_1;
        {EOP_0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1, 1'b?}: nextstate = ERROR;
        {WAIT_1, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1, 1'b?, 1'b?, 1'b?}: nextstate = EOP_1;
        {EOP_1, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b0, 1'b0, 1'b?}: nextstate = WAIT_2;
        {EOP_1, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1, 1'b?}: nextstate = ERROR;
        {WAIT_2, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1, 1'b?, 1'b?, 1'b?}: nextstate = IDLE_VAL;
        {IDLE_VAL, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b0, 1'b1, 1'b?}: nextstate = DONE;
        {IDLE_VAL, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b0, 1'b?}: nextstate = ERROR;
        {DONE, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = IDLE;
        {ERROR, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = IDLE;
        {DATA0, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1}: nextstate = EOP_START;    
        {DATA1, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b1}: nextstate = EOP_START;
        {ACK, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?, 1'b?}: nextstate = EOP_START;    
        
        default: nextstate = state;
    endcase
end

always_ff @(posedge clk, negedge n_rst) begin : stateFF
    if (n_rst == 0) begin
        state <= IDLE;
    end
    else begin
        state <= nextstate;
    end
end

always_comb begin : outputLogic
    case(state)
        IDLE: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b0;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        CLEAR: begin
            clear_err = 1'b1;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        START: begin
            clear_err = 1'b0;
            en_timer = 1'b1;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        DATA1: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b010;
            // One-cycle pre-data flush so the buffer can accept the new host payload (USB manual).
            rx_buffer_flush  = (prev_state != DATA1) ? 1'b1 : 1'b0;
            rx_data_timer_en = 1'b1;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        DATA0: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b001;
            rx_buffer_flush  = (prev_state != DATA0) ? 1'b1 : 1'b0;
            rx_data_timer_en = 1'b1;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        OUT: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            // USB manual: only expose OUT to the SoC after token fields match device addr + EP0.
            rx_packet = (strobes_16 && token_match) ? 3'b110 : 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b1;
            timer_8 = 1'b0;
        end
        IN: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = (strobes_16 && token_match) ? 3'b111 : 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b1;
            timer_8 = 1'b0;
        end
        ACK: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b011;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        EOP_START: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        EOP_0: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        WAIT_1: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b1;
        end
        EOP_1: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        ERROR: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            // USB manual: flush data buffer after a reception-side error.
            rx_buffer_flush  = (prev_state != ERROR) ? 1'b1 : 1'b0;
            rx_data_timer_en = 1'b0;
            eop_err = 1'b1;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        WAIT_2: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b1;
        end
        IDLE_VAL: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b1;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        DONE: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b1;
            transfer_active = 1'b1; //maybe off
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
        default: begin
            clear_err = 1'b0;
            en_timer = 1'b0;
            rx_data_ready = 1'b0;
            transfer_active = 1'b0;
            rx_packet = 3'b000;
            rx_buffer_flush   = 1'b0;
            rx_data_timer_en  = 1'b0;
            eop_err = 1'b0;
            pack_done = 1'b0;
            timer_16 = 1'b0;
            timer_8 = 1'b0;
        end
    endcase
end

endmodule


