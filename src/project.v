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

    /* =========================================================
       VGA
       ========================================================= */

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
    assign uio_oe  = 8'b0;


    /* =========================================================
       INPUTS
       ========================================================= */

    wire key_simplify = ui_in[0];
    wire key_up       = ui_in[1];
    wire key_down     = ui_in[2];
    wire key_left     = ui_in[3];
    wire key_right    = ui_in[4];
    wire key_toggle   = ui_in[5];
    wire key_reset    = ui_in[7];

    reg prev_simplify;
    reg prev_up;
    reg prev_down;
    reg prev_left;
    reg prev_right;
    reg prev_toggle;
    reg prev_reset;

    wire simplify_press = key_simplify ^ prev_simplify;
    wire up_press       = key_up       ^ prev_up;
    wire down_press     = key_down     ^ prev_down;
    wire left_press     = key_left     ^ prev_left;
    wire right_press    = key_right    ^ prev_right;
    wire toggle_press   = key_toggle   ^ prev_toggle;
    wire reset_press    = key_reset    ^ prev_reset;


    /* =========================================================
       K-MAP STATE
       ========================================================= */

    reg [1:0] cursor_row;
    reg [1:0] cursor_col;
    reg [15:0] kmap_value;
    reg simplify_mode;


    /* =========================================================
       GRAY-CODE K-MAP MAPPING

       Gray row:
           00 -> AB = 00
           01 -> AB = 01
           11 -> AB = 10
           10 -> AB = 11

       Therefore:
           A = r[1]
           B = r[1] ^ r[0]

       Likewise:
           C = c[1]
           D = c[1] ^ c[0]
       ========================================================= */

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


    /* =========================================================
       K-MAP GEOMETRY
       ========================================================= */

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

    reg [1:0] tile_col;
    reg [1:0] tile_row;

    always @(*) begin
        if (rel_x < 10'd135)
            tile_col = 2'd0;
        else if (rel_x < 10'd270)
            tile_col = 2'd1;
        else if (rel_x < 10'd405)
            tile_col = 2'd2;
        else
            tile_col = 2'd3;

        if (rel_y < 10'd75)
            tile_row = 2'd0;
        else if (rel_y < 10'd150)
            tile_row = 2'd1;
        else if (rel_y < 10'd225)
            tile_row = 2'd2;
        else
            tile_row = 2'd3;
    end

    wire [3:0] display_minterm =
        kmap_minterm(tile_row, tile_col);

    wire display_value =
        kmap_value[display_minterm];

    wire selected_tile =
        (tile_row == cursor_row) &&
        (tile_col == cursor_col);

    reg [9:0] tile_x;
    reg [9:0] tile_y;

    always @(*) begin
        case (tile_col)
            2'd0: tile_x = rel_x;
            2'd1: tile_x = rel_x - 10'd135;
            2'd2: tile_x = rel_x - 10'd270;
            default: tile_x = rel_x - 10'd405;
        endcase

        case (tile_row)
            2'd0: tile_y = rel_y;
            2'd1: tile_y = rel_y - 10'd75;
            2'd2: tile_y = rel_y - 10'd150;
            default: tile_y = rel_y - 10'd225;
        endcase
    end


    /* =========================================================
       DIGIT DISPLAY
       ========================================================= */

    wire digit_top =
        (tile_x >= 10'd48) &&
        (tile_x < 10'd87) &&
        (tile_y >= 10'd17) &&
        (tile_y < 10'd24);

    wire digit_bottom =
        (tile_x >= 10'd48) &&
        (tile_x < 10'd87) &&
        (tile_y >= 10'd51) &&
        (tile_y < 10'd58);

    wire digit_left =
        (tile_x >= 10'd42) &&
        (tile_x < 10'd49) &&
        (tile_y >= 10'd23) &&
        (tile_y < 10'd52);

    wire digit_right =
        (tile_x >= 10'd86) &&
        (tile_x < 10'd93) &&
        (tile_y >= 10'd23) &&
        (tile_y < 10'd52);

    wire digit_on =
        display_value ?
        digit_right :
        (digit_top |
         digit_bottom |
         digit_left |
         digit_right);


    /* =========================================================
       GROUP FUNCTIONS
       ========================================================= */

    function [15:0] group16;
        begin
            group16 = 16'hFFFF;
        end
    endfunction

    function [15:0] group8;
        input integer index;
        begin
            case (index)
                0: group8 = 16'h00FF;
                1: group8 = 16'hF0F0;
                2: group8 = 16'hFF00;
                3: group8 = 16'h0F0F;
                4: group8 = 16'h3333;
                5: group8 = 16'hAAAA;
                6: group8 = 16'hCCCC;
                7: group8 = 16'h5555;
                default: group8 = 16'h0000;
            endcase
        end
    endfunction

    function [15:0] group4;
        input integer index;
        begin
            case (index)
                0:  group4 = 16'h000F;
                1:  group4 = 16'h00F0;
                2:  group4 = 16'hF000;
                3:  group4 = 16'h0F00;

                4:  group4 = 16'h1111;
                5:  group4 = 16'h2222;
                6:  group4 = 16'h8888;
                7:  group4 = 16'h4444;

                8:  group4 = 16'h0033;
                9:  group4 = 16'h00AA;
                10: group4 = 16'h00CC;
                11: group4 = 16'h0055;

                12: group4 = 16'h3030;
                13: group4 = 16'hA0A0;
                14: group4 = 16'hC0C0;
                15: group4 = 16'h5050;

                16: group4 = 16'h3300;
                17: group4 = 16'hAA00;
                18: group4 = 16'hCC00;
                19: group4 = 16'h5500;

                20: group4 = 16'h0303;
                21: group4 = 16'h0A0A;
                22: group4 = 16'h0C0C;
                23: group4 = 16'h0505;

                default: group4 = 16'h0000;
            endcase
        end
    endfunction

    function [15:0] group2;
        input integer index;
        begin
            case (index)
                0:  group2 = 16'h0003;
                1:  group2 = 16'h000A;
                2:  group2 = 16'h000C;
                3:  group2 = 16'h0005;

                4:  group2 = 16'h0030;
                5:  group2 = 16'h00A0;
                6:  group2 = 16'h00C0;
                7:  group2 = 16'h0050;

                8:  group2 = 16'h3000;
                9:  group2 = 16'hA000;
                10: group2 = 16'hC000;
                11: group2 = 16'h5000;

                12: group2 = 16'h0300;
                13: group2 = 16'h0A00;
                14: group2 = 16'h0C00;
                15: group2 = 16'h0500;

                16: group2 = 16'h0011;
                17: group2 = 16'h0022;
                18: group2 = 16'h0088;
                19: group2 = 16'h0044;

                20: group2 = 16'h1010;
                21: group2 = 16'h2020;
                22: group2 = 16'h8080;
                23: group2 = 16'h4040;

                24: group2 = 16'h1100;
                25: group2 = 16'h2200;
                26: group2 = 16'h8800;
                27: group2 = 16'h4400;

                28: group2 = 16'h0101;
                29: group2 = 16'h0202;
                30: group2 = 16'h0808;
                31: group2 = 16'h0404;

                default: group2 = 16'h0000;
            endcase
        end
    endfunction

    function [15:0] group1;
        input integer index;
        begin
            case (index)
                0:  group1 = 16'h0001;
                1:  group1 = 16'h0002;
                2:  group1 = 16'h0008;
                3:  group1 = 16'h0004;

                4:  group1 = 16'h0010;
                5:  group1 = 16'h0020;
                6:  group1 = 16'h0080;
                7:  group1 = 16'h0040;

                8:  group1 = 16'h1000;
                9:  group1 = 16'h2000;
                10: group1 = 16'h8000;
                11: group1 = 16'h4000;

                12: group1 = 16'h0100;
                13: group1 = 16'h0200;
                14: group1 = 16'h0800;
                15: group1 = 16'h0400;

                default: group1 = 16'h0000;
            endcase
        end
    endfunction


    /* =========================================================
       GROUP COLOR

       Same color sequence as original:
       0 blue
       1 green
       2 cyan
       3 red
       4 magenta
       5 yellow
       6 blue
       7 green
       ========================================================= */

    function [2:0] group_color;
        input [2:0] index;
        begin
            case (index)
                3'd0: group_color = 3'b001;
                3'd1: group_color = 3'b010;
                3'd2: group_color = 3'b011;
                3'd3: group_color = 3'b100;
                3'd4: group_color = 3'b101;
                3'd5: group_color = 3'b110;
                3'd6: group_color = 3'b001;
                3'd7: group_color = 3'b010;
                default: group_color = 3'b001;
            endcase
        end
    endfunction


    /* =========================================================
       GROUPING ENGINE

       Important area reduction:
       At most 8 groups are stored.

       The grouping order remains:
       16 -> 8 -> 4 -> 2 -> 1
       ========================================================= */

    reg [15:0] selected_group_mask [0:7];

    reg [3:0] selected_group_count;
    reg [15:0] covered_minterms;
    reg [15:0] candidate_mask;

    integer gi;
    integer gidx;

    always @(*) begin
        for (gi = 0; gi < 8; gi = gi + 1)
            selected_group_mask[gi] = 16'b0;

        selected_group_count = 4'd0;
        covered_minterms = 16'b0;
        candidate_mask = 16'b0;


        /* GROUP 16 */

        candidate_mask = group16();

        if ((kmap_value & candidate_mask) == candidate_mask) begin
            if ((candidate_mask & ~covered_minterms) != 16'b0) begin
                selected_group_mask[0] = candidate_mask;
                selected_group_count = 4'd1;
                covered_minterms =
                    covered_minterms | candidate_mask;
            end
        end


        /* GROUP 8 */

        for (gidx = 0; gidx < 8; gidx = gidx + 1) begin
            candidate_mask = group8(gidx);

            if ((kmap_value & candidate_mask) == candidate_mask) begin
                if ((candidate_mask & ~covered_minterms) != 16'b0) begin
                    if (selected_group_count < 4'd8) begin

                        selected_group_mask[
                            selected_group_count[2:0]
                        ] = candidate_mask;

                        selected_group_count =
                            selected_group_count + 4'd1;

                        covered_minterms =
                            covered_minterms | candidate_mask;
                    end
                end
            end
        end


        /* GROUP 4 */

        for (gidx = 0; gidx < 24; gidx = gidx + 1) begin
            candidate_mask = group4(gidx);

            if ((kmap_value & candidate_mask) == candidate_mask) begin
                if ((candidate_mask & ~covered_minterms) != 16'b0) begin
                    if (selected_group_count < 4'd8) begin

                        selected_group_mask[
                            selected_group_count[2:0]
                        ] = candidate_mask;

                        selected_group_count =
                            selected_group_count + 4'd1;

                        covered_minterms =
                            covered_minterms | candidate_mask;
                    end
                end
            end
        end


        /* GROUP 2 */

        for (gidx = 0; gidx < 32; gidx = gidx + 1) begin
            candidate_mask = group2(gidx);

            if ((kmap_value & candidate_mask) == candidate_mask) begin
                if ((candidate_mask & ~covered_minterms) != 16'b0) begin
                    if (selected_group_count < 4'd8) begin

                        selected_group_mask[
                            selected_group_count[2:0]
                        ] = candidate_mask;

                        selected_group_count =
                            selected_group_count + 4'd1;

                        covered_minterms =
                            covered_minterms | candidate_mask;
                    end
                end
            end
        end


        /* GROUP 1 */

        for (gidx = 0; gidx < 16; gidx = gidx + 1) begin
            candidate_mask = group1(gidx);

            if ((kmap_value & candidate_mask) == candidate_mask) begin
                if ((candidate_mask & ~covered_minterms) != 16'b0) begin
                    if (selected_group_count < 4'd8) begin

                        selected_group_mask[
                            selected_group_count[2:0]
                        ] = candidate_mask;

                        selected_group_count =
                            selected_group_count + 4'd1;

                        covered_minterms =
                            covered_minterms | candidate_mask;
                    end
                end
            end
        end
    end


    /* =========================================================
       NEIGHBOR MINTERMS
       ========================================================= */

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


    /* =========================================================
       BORDER COLORS

       Scan only the maximum 8 selected groups.
       ========================================================= */

    reg [2:0] top_border_color;
    reg [2:0] bottom_border_color;
    reg [2:0] left_border_color;
    reg [2:0] right_border_color;

    reg top_found;
    reg bottom_found;
    reg left_found;
    reg right_found;

    integer bi;

    always @(*) begin
        top_border_color = 3'b000;
        bottom_border_color = 3'b000;
        left_border_color = 3'b000;
        right_border_color = 3'b000;

        top_found = 1'b0;
        bottom_found = 1'b0;
        left_found = 1'b0;
        right_found = 1'b0;

        for (bi = 0; bi < 8; bi = bi + 1) begin
            if (bi < selected_group_count) begin

                if (!top_found &&
                    selected_group_mask[bi][display_minterm] &&
                    !selected_group_mask[bi][top_minterm]) begin

                    top_border_color =
                        group_color(bi[2:0]);

                    top_found = 1'b1;
                end

                if (!bottom_found &&
                    selected_group_mask[bi][display_minterm] &&
                    !selected_group_mask[bi][bottom_minterm]) begin

                    bottom_border_color =
                        group_color(bi[2:0]);

                    bottom_found = 1'b1;
                end

                if (!left_found &&
                    selected_group_mask[bi][display_minterm] &&
                    !selected_group_mask[bi][left_minterm]) begin

                    left_border_color =
                        group_color(bi[2:0]);

                    left_found = 1'b1;
                end

                if (!right_found &&
                    selected_group_mask[bi][display_minterm] &&
                    !selected_group_mask[bi][right_minterm]) begin

                    right_border_color =
                        group_color(bi[2:0]);

                    right_found = 1'b1;
                end
            end
        end
    end


    /* =========================================================
       A/B/C/D LABELS
       ========================================================= */

    localparam TEXT_SCALE  = 2;
    localparam TEXT_CHAR_W = 12;
    localparam TEXT_CHAR_H = 14;

    localparam COL_TEXT_Y = 76;

    localparam COL1_X = 137;
    localparam COL2_X = 272;
    localparam COL3_X = 407;
    localparam COL4_X = 542;

    localparam ROW_TEXT_X = 30;

    localparam ROW1_Y = 125;
    localparam ROW2_Y = 200;
    localparam ROW3_Y = 275;
    localparam ROW4_Y = 350;


    wire inside_col1 =
        (hpos >= COL1_X) &&
        (hpos < COL1_X + 4 * TEXT_CHAR_W) &&
        (vpos >= COL_TEXT_Y) &&
        (vpos < COL_TEXT_Y + TEXT_CHAR_H);

    wire inside_col2 =
        (hpos >= COL2_X) &&
        (hpos < COL2_X + 3 * TEXT_CHAR_W) &&
        (vpos >= COL_TEXT_Y) &&
        (vpos < COL_TEXT_Y + TEXT_CHAR_H);

    wire inside_col3 =
        (hpos >= COL3_X) &&
        (hpos < COL3_X + 2 * TEXT_CHAR_W) &&
        (vpos >= COL_TEXT_Y) &&
        (vpos < COL_TEXT_Y + TEXT_CHAR_H);

    wire inside_col4 =
        (hpos >= COL4_X) &&
        (hpos < COL4_X + 3 * TEXT_CHAR_W) &&
        (vpos >= COL_TEXT_Y) &&
        (vpos < COL_TEXT_Y + TEXT_CHAR_H);

    wire inside_row1 =
        (hpos >= ROW_TEXT_X) &&
        (hpos < ROW_TEXT_X + 4 * TEXT_CHAR_W) &&
        (vpos >= ROW1_Y) &&
        (vpos < ROW1_Y + TEXT_CHAR_H);

    wire inside_row2 =
        (hpos >= ROW_TEXT_X) &&
        (hpos < ROW_TEXT_X + 3 * TEXT_CHAR_W) &&
        (vpos >= ROW2_Y) &&
        (vpos < ROW2_Y + TEXT_CHAR_H);

    wire inside_row3 =
        (hpos >= ROW_TEXT_X) &&
        (hpos < ROW_TEXT_X + 2 * TEXT_CHAR_W) &&
        (vpos >= ROW3_Y) &&
        (vpos < ROW3_Y + TEXT_CHAR_H);

    wire inside_row4 =
        (hpos >= ROW_TEXT_X) &&
        (hpos < ROW_TEXT_X + 3 * TEXT_CHAR_W) &&
        (vpos >= ROW4_Y) &&
        (vpos < ROW4_Y + TEXT_CHAR_H);

    wire inside_any_text =
        inside_col1 |
        inside_col2 |
        inside_col3 |
        inside_col4 |
        inside_row1 |
        inside_row2 |
        inside_row3 |
        inside_row4;


    /* =========================================================
       TEXT COORDINATES
       ========================================================= */

    reg [9:0] text_local_x;
    reg [3:0] text_local_y;

    always @(*) begin
        text_local_x = 10'd0;
        text_local_y = 4'd0;

        if (inside_col1) begin
            text_local_x = hpos - COL1_X;
            text_local_y = vpos - COL_TEXT_Y;
        end
        else if (inside_col2) begin
            text_local_x = hpos - COL2_X;
            text_local_y = vpos - COL_TEXT_Y;
        end
        else if (inside_col3) begin
            text_local_x = hpos - COL3_X;
            text_local_y = vpos - COL_TEXT_Y;
        end
        else if (inside_col4) begin
            text_local_x = hpos - COL4_X;
            text_local_y = vpos - COL_TEXT_Y;
        end
        else if (inside_row1) begin
            text_local_x = hpos - ROW_TEXT_X;
            text_local_y = vpos - ROW1_Y;
        end
        else if (inside_row2) begin
            text_local_x = hpos - ROW_TEXT_X;
            text_local_y = vpos - ROW2_Y;
        end
        else if (inside_row3) begin
            text_local_x = hpos - ROW_TEXT_X;
            text_local_y = vpos - ROW3_Y;
        end
        else if (inside_row4) begin
            text_local_x = hpos - ROW_TEXT_X;
            text_local_y = vpos - ROW4_Y;
        end
    end


    /* =========================================================
       CHARACTER POSITION

       12-pixel character width:
           0..11  = character 0
          12..23  = character 1
          24..35  = character 2
          36..47  = character 3
       ========================================================= */

    reg [1:0] char_pos;
    reg [3:0] char_x;

    always @(*) begin
        if (text_local_x < 10'd12) begin
            char_pos = 2'd0;
            char_x = text_local_x[3:0];
        end
        else if (text_local_x < 10'd24) begin
            char_pos = 2'd1;
            char_x = text_local_x - 10'd12;
        end
        else if (text_local_x < 10'd36) begin
            char_pos = 2'd2;
            char_x = text_local_x - 10'd24;
        end
        else begin
            char_pos = 2'd3;
            char_x = text_local_x - 10'd36;
        end
    end


    /* =========================================================
       FONT ROW

       Because the character height is 14 and the scale is 2,
       font row is simply text_local_y >> 1.
       ========================================================= */

    wire [3:0] font_y =
        text_local_y[3:1];


    /* =========================================================
       LABEL CHARACTER SELECTION
       ========================================================= */

    reg [7:0] control_char;

    always @(*) begin
        control_char = " ";

        if (inside_col1) begin
            case (char_pos)
                2'd0: control_char = "C";
                2'd1: control_char = "'";
                2'd2: control_char = "D";
                2'd3: control_char = "'";
                default: control_char = " ";
            endcase
        end

        else if (inside_col2) begin
            case (char_pos)
                2'd0: control_char = "C";
                2'd1: control_char = "'";
                2'd2: control_char = "D";
                default: control_char = " ";
            endcase
        end

        else if (inside_col3) begin
            case (char_pos)
                2'd0: control_char = "C";
                2'd1: control_char = "D";
                default: control_char = " ";
            endcase
        end

        else if (inside_col4) begin
            case (char_pos)
                2'd0: control_char = "C";
                2'd1: control_char = "D";
                2'd2: control_char = "'";
                default: control_char = " ";
            endcase
        end

        else if (inside_row1) begin
            case (char_pos)
                2'd0: control_char = "A";
                2'd1: control_char = "'";
                2'd2: control_char = "B";
                2'd3: control_char = "'";
                default: control_char = " ";
            endcase
        end

        else if (inside_row2) begin
            case (char_pos)
                2'd0: control_char = "A";
                2'd1: control_char = "'";
                2'd2: control_char = "B";
                default: control_char = " ";
            endcase
        end

        else if (inside_row3) begin
            case (char_pos)
                2'd0: control_char = "A";
                2'd1: control_char = "B";
                default: control_char = " ";
            endcase
        end

        else if (inside_row4) begin
            case (char_pos)
                2'd0: control_char = "A";
                2'd1: control_char = "B";
                2'd2: control_char = "'";
                default: control_char = " ";
            endcase
        end
    end


    /* =========================================================
       5x7 FONT
       ========================================================= */

    function [4:0] font_row;
        input [7:0] ch;
        input [3:0] y;

        begin
            case (ch)

                "A": begin
                    case (y)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b11111;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        6: font_row = 5'b10001;
                        default: font_row = 5'b00000;
                    endcase
                end

                "B": begin
                    case (y)
                        0: font_row = 5'b11110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b11110;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        6: font_row = 5'b11110;
                        default: font_row = 5'b00000;
                    endcase
                end

                "C": begin
                    case (y)
                        0: font_row = 5'b01110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10000;
                        3: font_row = 5'b10000;
                        4: font_row = 5'b10000;
                        5: font_row = 5'b10001;
                        6: font_row = 5'b01110;
                        default: font_row = 5'b00000;
                    endcase
                end

                "D": begin
                    case (y)
                        0: font_row = 5'b11110;
                        1: font_row = 5'b10001;
                        2: font_row = 5'b10001;
                        3: font_row = 5'b10001;
                        4: font_row = 5'b10001;
                        5: font_row = 5'b10001;
                        6: font_row = 5'b11110;
                        default: font_row = 5'b00000;
                    endcase
                end

                "'": begin
                    case (y)
                        0: font_row = 5'b00100;
                        1: font_row = 5'b00100;
                        default: font_row = 5'b00000;
                    endcase
                end

                default:
                    font_row = 5'b00000;

            endcase
        end
    endfunction


    wire [4:0] font_bits =
        font_row(control_char, font_y);

    wire font_pixel =
        (char_x < 10) ?
        font_bits[4 - char_x[3:1]] :
        1'b0;


    /* =========================================================
       MAIN CONTROL
       ========================================================= */

    always @(posedge clk) begin
        if (!rst_n) begin
            cursor_row <= 2'd0;
            cursor_col <= 2'd0;
            kmap_value <= 16'b0;
            simplify_mode <= 1'b0;

            prev_simplify <= 1'b0;
            prev_up       <= 1'b0;
            prev_down     <= 1'b0;
            prev_left     <= 1'b0;
            prev_right    <= 1'b0;
            prev_toggle   <= 1'b0;
            prev_reset    <= 1'b0;
        end
        else begin
            prev_simplify <= key_simplify;
            prev_up       <= key_up;
            prev_down     <= key_down;
            prev_left     <= key_left;
            prev_right    <= key_right;
            prev_toggle   <= key_toggle;
            prev_reset    <= key_reset;

            if (reset_press) begin
                cursor_row <= 2'd0;
                cursor_col <= 2'd0;
                kmap_value <= 16'b0;
                simplify_mode <= 1'b0;
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

                if (simplify_press)
                    simplify_mode <= 1'b1;
            end
        end
    end


    /* =========================================================
       RGB OUTPUT
       ========================================================= */

    reg red;
    reg green;
    reg blue;

    always @(*) begin
        red   = 1'b0;
        green = 1'b0;
        blue  = 1'b0;

        if (display_on) begin

            if (inside_grid) begin

                if (simplify_mode) begin

                    if ((tile_y < BORDER) &&
                        (top_border_color != 3'b000)) begin

                        red   = top_border_color[2];
                        green = top_border_color[1];
                        blue  = top_border_color[0];

                    end
                    else if ((tile_y >= TILE_H - BORDER) &&
                             (bottom_border_color != 3'b000)) begin

                        red   = bottom_border_color[2];
                        green = bottom_border_color[1];
                        blue  = bottom_border_color[0];

                    end
                    else if ((tile_x < BORDER) &&
                             (left_border_color != 3'b000)) begin

                        red   = left_border_color[2];
                        green = left_border_color[1];
                        blue  = left_border_color[0];

                    end
                    else if ((tile_x >= TILE_W - BORDER) &&
                             (right_border_color != 3'b000)) begin

                        red   = right_border_color[2];
                        green = right_border_color[1];
                        blue  = right_border_color[0];

                    end
                    else if (digit_on) begin

                        red   = 1'b1;
                        green = 1'b1;
                        blue  = 1'b1;

                    end

                end

                else begin

                    if ((tile_x < BORDER) ||
                        (tile_x >= TILE_W - BORDER) ||
                        (tile_y < BORDER) ||
                        (tile_y >= TILE_H - BORDER)) begin

                        if (selected_tile) begin
                            red   = 1'b1;
                            green = 1'b1;
                            blue  = 1'b0;
                        end
                        else begin
                            red   = 1'b1;
                            green = 1'b1;
                            blue  = 1'b1;
                        end

                    end
                    else if (digit_on) begin
                        red   = 1'b1;
                        green = 1'b1;
                        blue  = 1'b1;
                    end

                end

            end
            else if (inside_any_text && font_pixel) begin
                red   = 1'b1;
                green = 1'b1;
                blue  = 1'b1;
            end
        end
    end


    /* =========================================================
       TINY TAPEOUT VGA OUTPUTS
       ========================================================= */

    assign uo_out[7] = hsync;
    assign uo_out[3] = vsync;

    assign uo_out[6] = red;
    assign uo_out[5] = green;
    assign uo_out[4] = blue;

    assign uo_out[2] = red;
    assign uo_out[1] = green;
    assign uo_out[0] = blue;

endmodule
