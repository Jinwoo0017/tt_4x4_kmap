`default_nettype none

module tt_um_vga_4x4_kmap (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena,
    input wire clk,
    input wire rst_n
);

    wire hsync;
    wire vsync;
    wire display_on;
    wire [9:0] hpos;
    wire [9:0] vpos;

    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(!rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(display_on),
        .hpos(hpos),
        .vpos(vpos)
    );

    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;

    wire key_simplify = ui_in[0];
    wire key_up = ui_in[1];
    wire key_down = ui_in[2];
    wire key_left = ui_in[3];
    wire key_right = ui_in[4];
    wire key_toggle = ui_in[5];
    wire key_reset = ui_in[7];

    reg prev_simplify;
    reg prev_up;
    reg prev_down;
    reg prev_left;
    reg prev_right;
    reg prev_toggle;
    reg prev_reset;

    wire simplify_press = key_simplify ^ prev_simplify;
    wire up_press = key_up ^ prev_up;
    wire down_press = key_down ^ prev_down;
    wire left_press = key_left ^ prev_left;
    wire right_press = key_right ^ prev_right;
    wire toggle_press = key_toggle ^ prev_toggle;
    wire reset_press = key_reset ^ prev_reset;

    reg [1:0] cursor_row;
    reg [1:0] cursor_col;
    reg [15:0] kmap_value;
    reg simplify_mode;

    function [3:0] kmap_minterm;
        input [1:0] r;
        input [1:0] c;
        begin
            kmap_minterm = {
                r[1],
                r[1] ^ r[0],
                c[1],
                c[1] ^ c[0]
            };
        end
    endfunction

    wire [3:0] selected_minterm =
        kmap_minterm(cursor_row, cursor_col);

    localparam GRID_X = 90;
    localparam GRID_Y = 100;
    localparam TILE_W = 135;
    localparam TILE_H = 75;
    localparam GRID_W = 540;
    localparam GRID_H = 300;
    localparam BORDER = 4;

    wire inside_grid =
        (hpos >= GRID_X) &&
        (hpos < GRID_X + GRID_W) &&
        (vpos >= GRID_Y) &&
        (vpos < GRID_Y + GRID_H);

    wire [9:0] rel_x = hpos - GRID_X;
    wire [9:0] rel_y = vpos - GRID_Y;

    wire [1:0] tile_col =
        (rel_x < 10'd135) ? 2'd0 :
        (rel_x < 10'd270) ? 2'd1 :
        (rel_x < 10'd405) ? 2'd2 :
                            2'd3;

    wire [1:0] tile_row =
        (rel_y < 10'd75) ? 2'd0 :
        (rel_y < 10'd150) ? 2'd1 :
        (rel_y < 10'd225) ? 2'd2 :
                            2'd3;

    wire [9:0] tile_x =
        (tile_col == 2'd0) ? rel_x :
        (tile_col == 2'd1) ? rel_x - 10'd135 :
        (tile_col == 2'd2) ? rel_x - 10'd270 :
                             rel_x - 10'd405;

    wire [9:0] tile_y =
        (tile_row == 2'd0) ? rel_y :
        (tile_row == 2'd1) ? rel_y - 10'd75 :
        (tile_row == 2'd2) ? rel_y - 10'd150 :
                             rel_y - 10'd225;

    wire [3:0] display_minterm =
        kmap_minterm(tile_row, tile_col);

    wire display_value =
        kmap_value[display_minterm];

    wire selected_tile =
        (tile_row == cursor_row) &&
        (tile_col == cursor_col);

    wire digit_top =
        (tile_x >= 10'd53) &&
        (tile_x < 10'd82) &&
        (tile_y >= 10'd22) &&
        (tile_y < 10'd27);

    wire digit_bottom =
        (tile_x >= 10'd53) &&
        (tile_x < 10'd82) &&
        (tile_y >= 10'd48) &&
        (tile_y < 10'd53);

    wire digit_left =
        (tile_x >= 10'd49) &&
        (tile_x < 10'd54) &&
        (tile_y >= 10'd26) &&
        (tile_y < 10'd49);

    wire digit_right =
        (tile_x >= 10'd81) &&
        (tile_x < 10'd86) &&
        (tile_y >= 10'd26) &&
        (tile_y < 10'd49);

    wire digit_on =
        display_value ?
            digit_right :
            (digit_top |
             digit_bottom |
             digit_left |
             digit_right);

    reg [15:0] group_mask [0:7];
    reg [6:0] solve_index;
    reg solving;
    reg [15:0] candidate_mask;
    reg [15:0] covered_minterms;
    reg [3:0] selected_group_count;

    integer sg;

    always @(*) begin
        case (solve_index)
            7'd0:  candidate_mask = 16'hFFFF;

            7'd1:  candidate_mask = 16'h00FF;
            7'd2:  candidate_mask = 16'hF0F0;
            7'd3:  candidate_mask = 16'hFF00;
            7'd4:  candidate_mask = 16'h0F0F;
            7'd5:  candidate_mask = 16'h3333;
            7'd6:  candidate_mask = 16'hAAAA;
            7'd7:  candidate_mask = 16'hCCCC;
            7'd8:  candidate_mask = 16'h5555;

            7'd9:  candidate_mask = 16'h000F;
            7'd10: candidate_mask = 16'h00F0;
            7'd11: candidate_mask = 16'hF000;
            7'd12: candidate_mask = 16'h0F00;
            7'd13: candidate_mask = 16'h1111;
            7'd14: candidate_mask = 16'h2222;
            7'd15: candidate_mask = 16'h8888;
            7'd16: candidate_mask = 16'h4444;

            7'd17: candidate_mask = 16'h0033;
            7'd18: candidate_mask = 16'h00AA;
            7'd19: candidate_mask = 16'h00CC;
            7'd20: candidate_mask = 16'h0055;
            7'd21: candidate_mask = 16'h3030;
            7'd22: candidate_mask = 16'hA0A0;
            7'd23: candidate_mask = 16'hC0C0;
            7'd24: candidate_mask = 16'h5050;
            7'd25: candidate_mask = 16'h3300;
            7'd26: candidate_mask = 16'hAA00;
            7'd27: candidate_mask = 16'hCC00;
            7'd28: candidate_mask = 16'h5500;
            7'd29: candidate_mask = 16'h0303;
            7'd30: candidate_mask = 16'h0A0A;
            7'd31: candidate_mask = 16'h0C0C;
            7'd32: candidate_mask = 16'h0505;

            7'd33: candidate_mask = 16'h0003;
            7'd34: candidate_mask = 16'h000A;
            7'd35: candidate_mask = 16'h000C;
            7'd36: candidate_mask = 16'h0005;
            7'd37: candidate_mask = 16'h0030;
            7'd38: candidate_mask = 16'h00A0;
            7'd39: candidate_mask = 16'h00C0;
            7'd40: candidate_mask = 16'h0050;
            7'd41: candidate_mask = 16'h3000;
            7'd42: candidate_mask = 16'hA000;
            7'd43: candidate_mask = 16'hC000;
            7'd44: candidate_mask = 16'h5000;
            7'd45: candidate_mask = 16'h0300;
            7'd46: candidate_mask = 16'h0A00;
            7'd47: candidate_mask = 16'h0C00;
            7'd48: candidate_mask = 16'h0500;

            7'd49: candidate_mask = 16'h0011;
            7'd50: candidate_mask = 16'h0022;
            7'd51: candidate_mask = 16'h0088;
            7'd52: candidate_mask = 16'h0044;
            7'd53: candidate_mask = 16'h1010;
            7'd54: candidate_mask = 16'h2020;
            7'd55: candidate_mask = 16'h8080;
            7'd56: candidate_mask = 16'h4040;
            7'd57: candidate_mask = 16'h1100;
            7'd58: candidate_mask = 16'h2200;
            7'd59: candidate_mask = 16'h8800;
            7'd60: candidate_mask = 16'h4400;
            7'd61: candidate_mask = 16'h0101;
            7'd62: candidate_mask = 16'h0202;
            7'd63: candidate_mask = 16'h0808;
            7'd64: candidate_mask = 16'h0404;

            7'd65: candidate_mask = 16'h0001;
            7'd66: candidate_mask = 16'h0002;
            7'd67: candidate_mask = 16'h0008;
            7'd68: candidate_mask = 16'h0004;
            7'd69: candidate_mask = 16'h0010;
            7'd70: candidate_mask = 16'h0020;
            7'd71: candidate_mask = 16'h0080;
            7'd72: candidate_mask = 16'h0040;
            7'd73: candidate_mask = 16'h1000;
            7'd74: candidate_mask = 16'h2000;
            7'd75: candidate_mask = 16'h8000;
            7'd76: candidate_mask = 16'h4000;
            7'd77: candidate_mask = 16'h0100;
            7'd78: candidate_mask = 16'h0200;
            7'd79: candidate_mask = 16'h0800;
            7'd80: candidate_mask = 16'h0400;

            default: candidate_mask = 16'b0;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cursor_row <= 2'd0;
            cursor_col <= 2'd0;
            kmap_value <= 16'b0;
            simplify_mode <= 1'b0;

            prev_simplify <= 1'b0;
            prev_up <= 1'b0;
            prev_down <= 1'b0;
            prev_left <= 1'b0;
            prev_right <= 1'b0;
            prev_toggle <= 1'b0;
            prev_reset <= 1'b0;

            selected_group_count <= 4'd0;
            covered_minterms <= 16'b0;
            solve_index <= 7'd0;
            solving <= 1'b0;

            for (sg = 0; sg < 8; sg = sg + 1)
                group_mask[sg] <= 16'b0;
        end
        else begin
            prev_simplify <= key_simplify;
            prev_up <= key_up;
            prev_down <= key_down;
            prev_left <= key_left;
            prev_right <= key_right;
            prev_toggle <= key_toggle;
            prev_reset <= key_reset;

            if (reset_press) begin
                cursor_row <= 2'd0;
                cursor_col <= 2'd0;
                kmap_value <= 16'b0;
                simplify_mode <= 1'b0;

                selected_group_count <= 4'd0;
                covered_minterms <= 16'b0;
                solve_index <= 7'd0;
                solving <= 1'b0;

                for (sg = 0; sg < 8; sg = sg + 1)
                    group_mask[sg] <= 16'b0;
            end
            else if (solving) begin
                if ((kmap_value & candidate_mask) == candidate_mask) begin
                    if ((candidate_mask & ~covered_minterms) != 16'b0) begin
                        if (selected_group_count < 4'd8) begin
                            group_mask[selected_group_count[2:0]] <= candidate_mask;
                            selected_group_count <= selected_group_count + 4'd1;
                            covered_minterms <= covered_minterms | candidate_mask;
                        end
                    end
                end

                if (solve_index == 7'd80) begin
                    solving <= 1'b0;
                    simplify_mode <= 1'b1;
                end
                else begin
                    solve_index <= solve_index + 7'd1;
                end
            end
            else if (!simplify_mode) begin
                if (up_press) begin
                    if (cursor_row == 2'd0)
                        cursor_row <= 2'd3;
                    else
                        cursor_row <= cursor_row - 2'd1;
                end

                if (down_press) begin
                    if (cursor_row == 2'd3)
                        cursor_row <= 2'd0;
                    else
                        cursor_row <= cursor_row + 2'd1;
                end

                if (left_press) begin
                    if (cursor_col == 2'd0)
                        cursor_col <= 2'd3;
                    else
                        cursor_col <= cursor_col - 2'd1;
                end

                if (right_press) begin
                    if (cursor_col == 2'd3)
                        cursor_col <= 2'd0;
                    else
                        cursor_col <= cursor_col + 2'd1;
                end

                if (toggle_press)
                    kmap_value[selected_minterm] <=
                        ~kmap_value[selected_minterm];

                if (simplify_press) begin
                    selected_group_count <= 4'd0;
                    covered_minterms <= 16'b0;
                    solve_index <= 7'd0;
                    solving <= 1'b1;

                    for (sg = 0; sg < 8; sg = sg + 1)
                        group_mask[sg] <= 16'b0;
                end
            end
        end
    end

    wire [1:0] top_row =
        (tile_row == 2'd0) ? 2'd3 :
        tile_row - 2'd1;

    wire [1:0] bottom_row =
        (tile_row == 2'd3) ? 2'd0 :
        tile_row + 2'd1;

    wire [1:0] left_col =
        (tile_col == 2'd0) ? 2'd3 :
        tile_col - 2'd1;

    wire [1:0] right_col =
        (tile_col == 2'd3) ? 2'd0 :
        tile_col + 2'd1;

    wire [3:0] top_minterm =
        kmap_minterm(top_row, tile_col);

    wire [3:0] bottom_minterm =
        kmap_minterm(bottom_row, tile_col);

    wire [3:0] left_minterm =
        kmap_minterm(tile_row, left_col);

    wire [3:0] right_minterm =
        kmap_minterm(tile_row, right_col);

    wire [7:0] current_groups = {
        group_mask[7][display_minterm],
        group_mask[6][display_minterm],
        group_mask[5][display_minterm],
        group_mask[4][display_minterm],
        group_mask[3][display_minterm],
        group_mask[2][display_minterm],
        group_mask[1][display_minterm],
        group_mask[0][display_minterm]
    };

    wire [7:0] top_groups = {
        group_mask[7][top_minterm],
        group_mask[6][top_minterm],
        group_mask[5][top_minterm],
        group_mask[4][top_minterm],
        group_mask[3][top_minterm],
        group_mask[2][top_minterm],
        group_mask[1][top_minterm],
        group_mask[0][top_minterm]
    };

    wire [7:0] bottom_groups = {
        group_mask[7][bottom_minterm],
        group_mask[6][bottom_minterm],
        group_mask[5][bottom_minterm],
        group_mask[4][bottom_minterm],
        group_mask[3][bottom_minterm],
        group_mask[2][bottom_minterm],
        group_mask[1][bottom_minterm],
        group_mask[0][bottom_minterm]
    };

    wire [7:0] left_groups = {
        group_mask[7][left_minterm],
        group_mask[6][left_minterm],
        group_mask[5][left_minterm],
        group_mask[4][left_minterm],
        group_mask[3][left_minterm],
        group_mask[2][left_minterm],
        group_mask[1][left_minterm],
        group_mask[0][left_minterm]
    };

    wire [7:0] right_groups = {
        group_mask[7][right_minterm],
        group_mask[6][right_minterm],
        group_mask[5][right_minterm],
        group_mask[4][right_minterm],
        group_mask[3][right_minterm],
        group_mask[2][right_minterm],
        group_mask[1][right_minterm],
        group_mask[0][right_minterm]
    };

    wire [7:0] top_hits =
        current_groups & ~top_groups;

    wire [7:0] bottom_hits =
        current_groups & ~bottom_groups;

    wire [7:0] left_hits =
        current_groups & ~left_groups;

    wire [7:0] right_hits =
        current_groups & ~right_groups;

    function [2:0] border_color;
        input [7:0] hits;
        begin
            if (hits[0])
                border_color = 3'b001;
            else if (hits[1])
                border_color = 3'b010;
            else if (hits[2])
                border_color = 3'b011;
            else if (hits[3])
                border_color = 3'b100;
            else if (hits[4])
                border_color = 3'b101;
            else if (hits[5])
                border_color = 3'b110;
            else if (hits[6])
                border_color = 3'b001;
            else if (hits[7])
                border_color = 3'b010;
            else
                border_color = 3'b000;
        end
    endfunction

    wire [2:0] top_border_color =
        border_color(top_hits);

    wire [2:0] bottom_border_color =
        border_color(bottom_hits);

    wire [2:0] left_border_color =
        border_color(left_hits);

    wire [2:0] right_border_color =
        border_color(right_hits);

    reg red;
    reg green;
    reg blue;

    wire border_top_on =
        tile_y < BORDER;

    wire border_bottom_on =
        tile_y >= TILE_H - BORDER;

    wire border_left_on =
        tile_x < BORDER;

    wire border_right_on =
        tile_x >= TILE_W - BORDER;

    always @(*) begin
        red = 1'b0;
        green = 1'b0;
        blue = 1'b0;

        if (display_on && inside_grid) begin
            if (simplify_mode) begin
                if (border_top_on && (top_border_color != 3'b000)) begin
                    red = top_border_color[2];
                    green = top_border_color[1];
                    blue = top_border_color[0];
                end
                else if (border_bottom_on &&
                         (bottom_border_color != 3'b000)) begin
                    red = bottom_border_color[2];
                    green = bottom_border_color[1];
                    blue = bottom_border_color[0];
                end
                else if (border_left_on &&
                         (left_border_color != 3'b000)) begin
                    red = left_border_color[2];
                    green = left_border_color[1];
                    blue = left_border_color[0];
                end
                else if (border_right_on &&
                         (right_border_color != 3'b000)) begin
                    red = right_border_color[2];
                    green = right_border_color[1];
                    blue = right_border_color[0];
                end
                else if (digit_on) begin
                    red = 1'b1;
                    green = 1'b1;
                    blue = 1'b1;
                end
            end
            else begin
                if (border_left_on ||
                    border_right_on ||
                    border_top_on ||
                    border_bottom_on) begin
                    if (selected_tile) begin
                        red = 1'b1;
                        green = 1'b1;
                        blue = 1'b0;
                    end
                    else begin
                        red = 1'b1;
                        green = 1'b1;
                        blue = 1'b1;
                    end
                end
                else if (digit_on) begin
                    red = 1'b1;
                    green = 1'b1;
                    blue = 1'b1;
                end
            end
        end
    end

    assign uo_out[7] = hsync;
    assign uo_out[3] = vsync;

    assign uo_out[6] = red;
    assign uo_out[5] = green;
    assign uo_out[4] = blue;

    assign uo_out[2] = red;
    assign uo_out[1] = green;
    assign uo_out[0] = blue;

endmodule
