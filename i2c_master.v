`timescale 1ns / 1ps

module i2c_master (
    input wire clk,           // Системний тактовий сигнал (наприклад, 50 МГц)
    input wire rst,           // Сигнал скидання (активний високий)
    input wire start_tx,      // Сигнал початку передачі транзакції
    input wire [6:0] addr,    // 7-бітна адреса Slave-пристрою
    input wire [7:0] data_in, // 8-бітні дані для передачі
    
    inout wire sda,           // Двонаправлена лінія даних I2C
    output wire scl,          // Тактовий сигнал I2C (генерується Master-ом)
    output reg ready          // Флаг готовності модуля (1 - вільний, 0 - зайнятий)
);

    // =========================================================================
    // Визначення станів скінченного автомата (FSM)
    // =========================================================================
    localparam STATE_IDLE    = 3'd0;
    localparam STATE_START   = 3'd1;
    localparam STATE_ADDR    = 3'd2;
    localparam STATE_ACK1    = 3'd3;
    localparam STATE_DATA    = 3'd4;
    localparam STATE_ACK2    = 3'd5;
    localparam STATE_STOP    = 3'd6;

    reg [2:0] state;          // Поточний стан FSM
    reg [3:0] bit_cnt;        // Лічильник переданих бітів (від 7 до 0)
    reg [7:0] shift_reg;      // Зсувний регістр для адреси або даних

    // =========================================================================
    // Регістри для керування лініями SCL та SDA
    // =========================================================================
    reg scl_out;              // Внутрішній регістр для генерації SCL
    reg sda_out;              // Значення, яке виставляється на SDA
    reg sda_dir;              // Напрямок SDA: 1 - вихід (Master Tx), 0 - вхід (Master Rx)

    // Керування двонаправленою лінією SDA (Open-Drain імітація)
    // Якщо sda_dir = 1, лінія керується sda_out. Якщо 0 - переходить у стан високого імпедансу (Z).
    assign sda = (sda_dir) ? sda_out : 1'bz;
    assign scl = scl_out;

    // =========================================================================
    // Спрощена логіка FSM (в реальності тут ще має бути дільник частоти для SCL)
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
            ready <= 1'b1;
            scl_out <= 1'b1;
            sda_out <= 1'b1;
            sda_dir <= 1'b1;
            bit_cnt <= 4'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    ready <= 1'b1;
                    scl_out <= 1'b1;
                    sda_out <= 1'b1;
                    sda_dir <= 1'b1;
                    if (start_tx) begin
                        ready <= 1'b0;
                        // Формуємо байт адреси: 7 біт адреси + 1 біт Write (0)
                        shift_reg <= {addr, 1'b0}; 
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    // Умова START: SDA падає в 0, поки SCL = 1
                    sda_out <= 1'b0;
                    if (sda_out == 1'b0) begin
                        scl_out <= 1'b0; // Опускаємо SCL для підготовки до передачі
                        bit_cnt <= 4'd7;
                        state <= STATE_ADDR;
                    end
                end

                STATE_ADDR: begin
                    // Виставляємо старший біт на SDA
                    sda_out <= shift_reg[bit_cnt];
                    scl_out <= ~scl_out; // Проста генерація меандру (перемикання SCL)
                    
                    // По спаду SCL зсуваємо регістр або переходимо далі
                    if (scl_out == 1'b1) begin 
                        if (bit_cnt == 0) begin
                            state <= STATE_ACK1;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                STATE_ACK1: begin
                    // Відпускаємо SDA, щоб Slave міг притягнути його до 0 (ACK)
                    sda_dir <= 1'b0; 
                    scl_out <= ~scl_out;
                    if (scl_out == 1'b1) begin
                        shift_reg <= data_in; // Завантажуємо дані для передачі
                        bit_cnt <= 4'd7;
                        state <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    sda_dir <= 1'b1; // Знову забираємо контроль над SDA
                    sda_out <= shift_reg[bit_cnt];
                    scl_out <= ~scl_out;
                    if (scl_out == 1'b1) begin
                        if (bit_cnt == 0) begin
                            state <= STATE_ACK2;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                STATE_ACK2: begin
                    sda_dir <= 1'b0; // Чекаємо ACK після даних
                    scl_out <= ~scl_out;
                    if (scl_out == 1'b1) begin
                        state <= STATE_STOP;
                    end
                end

                STATE_STOP: begin
                    sda_dir <= 1'b1;
                    scl_out <= 1'b1;
                    sda_out <= 1'b0; // Готуємо SDA до підйому
                    // Умова STOP: SDA піднімається в 1, коли SCL = 1
                    if (scl_out == 1'b1) begin
                        sda_out <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule