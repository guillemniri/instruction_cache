import sargantana_icache_pkg::*;

module sargantana_icache_lru_unit #(
    parameter int unsigned P_NWAYS    = 0,
    parameter int unsigned P_WDEPTH   = 0,
    parameter type         p_array_t  = logic,
    parameter type         p_setidx_t = logic,
    parameter type         p_wayidx_t = logic
)(
    input  logic      clk_i,
    input  logic      rstn_i,
    input  logic      flush_i,
    input  logic      replace_i,
    input  logic      update_i,
    input  p_array_t  way_valid_bits_i,
    input  p_setidx_t addr_i,
    input  p_setidx_t set_idx_i,
    input  p_wayidx_t rep_way_i,
    input  p_wayidx_t upd_way_i,
    output p_wayidx_t lru_way_o                   
);

typedef logic [P_NWAYS-1:0][$clog2(P_NWAYS)-1:0] access_order_t; // structure to save the access order of one way

logic [P_WDEPTH-1:0] valid; // valid signals for aot_regs
// ACCESS ORDER TABLE
access_order_t [P_WDEPTH-1:0] aot_d;
access_order_t [P_WDEPTH-1:0] aot_q;

p_wayidx_t lru_way;

//------------------------
// LRU VALUES REGS
//------------------------

always_ff @(posedge clk_i or negedge rstn_i)
begin : regs
    if (~rstn_i | flush_i) aot_q <= '0;
    else aot_q <= valid[set_idx_i] ? aot_d : aot_q;
end

//------------------------
// LRU WAY SELECT
//------------------------

always_comb
begin : select_lru_way
    lru_way = '0;
    for (int unsigned i = 0; i < P_NWAYS; ++i) begin
        if (aot_q[addr_i][i] == P_NWAYS-1) begin
            lru_way = i[$clog2(P_NWAYS)-1:0];
            break;
        end
    end
end
assign lru_way_o = lru_way;

//------------------------
// LRU VALUES UPDATE
//------------------------

always_comb
begin : update_lru_values
    valid = '0;
    aot_d = aot_q;

    case (1'b1)
        // When replacing a cache-block, replaced block value = 0 and +1 to all other values
        replace_i: begin
            aot_d[set_idx_i][rep_way_i] = 0;
            valid[set_idx_i] = 1;
            for (int i = 0; i < P_NWAYS; ++i) begin
                if (i[$clog2(P_NWAYS)-1:0] != rep_way_i & way_valid_bits_i[i])
                    aot_d[set_idx_i][i] = aot_q[set_idx_i][i] + 1;
            end
        end

        // When accessing a cache-block, accessed block value = 0 and adjust other values
        update_i: begin
            aot_d[set_idx_i][upd_way_i] = 0;
            valid[set_idx_i] = 1;
            for (int i = 0; i < P_NWAYS; ++i) begin
                if (i[$clog2(P_NWAYS)-1:0] != upd_way_i & way_valid_bits_i[i] & aot_q[set_idx_i][i] < aot_q[set_idx_i][upd_way_i])
                    aot_d[set_idx_i][i] = aot_q[set_idx_i][i] + 1;
            end
        end

        default: begin
            // do nothing
        end
    endcase
end

endmodule