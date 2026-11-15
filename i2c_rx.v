`timescale 1ns / 1ps

module i2c_rx (
    input wire clk,           // Системний такт для синхронізації
    input wire rst,
    input wire scl,           // Тактовий сигнал від Master
    inout wire sda,           // Двонаправлена лінія даних
    output reg [7:0] rx_data, // Отримані корисні дані
    output reg rx_valid       // Флаг успішного прийому
);

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg sda_ack;
    
    // Приймач може лише притискати лінію в 0 для передачі ACK
    assign sda = sda_ack ? 1'b0 : 1'bz;
    
    // Синхронізація для виявлення фронтів SCL
    reg scl_d;
    always @(posedge clk) scl_d <= scl;
    wire scl_rising = (scl_d == 0 && scl == 1);
    wire scl_falling = (scl_d == 1 && scl == 0);

    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            sda_ack <= 0;
            rx_valid <= 0;
            bit_cnt <= 7;
        end else begin
            rx_valid <= 0; // Скидаємо флаг готовності даних
            
            // Запис бітів з лінії SDA по передньому фронту SCL
            if (scl_rising && (state == 0 || state == 2)) begin
                shift_reg <= {shift_reg[6:0], sda};
            end
            
            // Переходи між станами та генерація ACK по задньому фронту SCL
            if (scl_falling) begin
                if (state == 0 || state == 2) begin 
                    if (bit_cnt == 0) begin
                        sda_ack <= 1; // Видаємо ACK
                        state <= state + 1;
                    end else begin
                        bit_cnt <= bit_cnt - 1;
                    end
                end else if (state == 1 || state == 3) begin
                    sda_ack <= 0; // Відпускаємо лінію після ACK
                    if (state == 1) begin
                        state <= 2;     // Перехід до прийому даних
                        bit_cnt <= 7;
                    end else begin
                        state <= 0;     // Транзакція завершена
                        bit_cnt <= 7;
                        rx_data <= shift_reg; // Виводимо зібраний байт даних
                        rx_valid <= 1;
                    end
                end
            end
        end
    end
endmodule