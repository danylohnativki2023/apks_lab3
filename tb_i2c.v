`timescale 1ns / 1ps

module tb_i2c;

    // Вхідні сигнали для нашого модуля (оголошуються як reg, бо ми ними керуємо)
    reg clk;
    reg rst;
    reg start_tx;
    reg [6:0] addr;
    reg [7:0] data_in;
    
    // Вихідні сигнали (оголошуються як wire)
    wire sda;
    wire scl;
    wire ready;

    // Імітація підтягуючого резистора (Pull-up) на лінії SDA, що є стандартом для I2C
    pullup(sda);
    pullup(scl);

    // Інстанціювання нашого розробленого модуля (Підключення "віртуальних проводів")
    i2c_master uut (
        .clk(clk),
        .rst(rst),
        .start_tx(start_tx),
        .addr(addr),
        .data_in(data_in),
        .sda(sda),
        .scl(scl),
        .ready(ready)
    );

    // Генерація тактового сигналу (період 20 нс -> частота 50 МГц)
    always #10 clk = ~clk;

    // Імітація Slave-пристрою, який має відповідати нулем (ACK) на отримані дані
    // Ми "заглядаємо" всередину модуля (uut.state), щоб знати, коли саме давати ACK
    reg slave_sda_drv = 0;
    assign sda = slave_sda_drv ? 1'b0 : 1'bz;

    always @(uut.state) begin
        if (uut.state == 3'd3 || uut.state == 3'd5) begin
            slave_sda_drv <= 1; // Відправляємо ACK (притискаємо лінію до 0)
        end else begin
            slave_sda_drv <= 0; // Відпускаємо лінію
        end
    end

    // Основний блок симуляції
    initial begin
        // Налаштування для генерації файлу осцилограм (.vcd) для GTKWave
        $dumpfile("i2c_waveform.vcd");
        $dumpvars(0, tb_i2c);

        // Початкові значення
        clk = 0;
        rst = 1;
        start_tx = 0;
        addr = 7'h00;
        data_in = 8'h00;

        // Чекаємо 50 нс і знімаємо RESET
        #50;
        rst = 0;
        #50;

        // Подаємо тестові дані: адреса 0x5A (наприклад, якийсь датчик) і дані 0xC3
        addr = 7'h5A;      
        data_in = 8'hC3;   
        start_tx = 1;
        
        // Чекаємо 20 нс, щоб модуль "побачив" сигнал start_tx, і вимикаємо його
        #20;
        start_tx = 0;

        // Даємо симуляції час (1500 нс), щоб транзакція повністю завершилась
        #1500; 
        
        $display("Транзакція I2C завершена. Відкривайте осцилограми!");
        $finish;
    end

endmodule