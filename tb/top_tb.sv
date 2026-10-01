`timescale 1ns/1ps

`include "bus_includes.sv" 

`ifndef DRVRS
    `define DRVRS 4
`endif

`ifndef BITS
    `define BITS 1
`endif

`ifndef BROADCAST
    `define BROADCAST {8{1'b1}}
`endif

module tb_top;

    // ── Generación del reloj principal
    bit clk = 0;
    always #5 clk = ~clk;


    bus_if #(.pckg_sz(`PCKG_SZ)) intf [`DRVRS] (clk);

    // ── Instancia del DUT (Wrapper)
    dut_wrapper #(
        .BITS(`BITS),
        .DRVRS(`DRVRS),
        .PCKG_SZ(`PCKG_SZ),
        .BROADCAST(`BROADCAST)
    ) dut_inst (
        .clk(clk),
        .intf(intf)
    );

    // ── Instancia de la prueba
    Test tst_inst (intf);

endmodule : tb_top
