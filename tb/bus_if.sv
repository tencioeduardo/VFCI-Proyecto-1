//=====================================
// Interfaz de comunicacion con el DUT
//=====================================

interface bus_if #(parameter pckg_sz = 16)(
    input logic clk,
    input logic reset
);
    logic                 pndng;
    logic                 push;
    logic                 pop;
    logic [pckg_sz-1 : 0] D_pop;
    logic [pckg_sz-1 : 0] D_push;

    // Vista de la interfaz para el Driver
    // input  -> puede leer
    // output -> puede manejar (escribir)
    modport driver_mp (
        input  clk, reset, pop, push, D_push,
        output pndng, D_pop
    );

    // Vista de la interfaz para el Monitor
    // input  -> puede leer
    modport monitor_mp(
        input  clk, reset, pop, push, D_push, D_pop, pndng
    );

endinterface
