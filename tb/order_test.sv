//===================================================================
// Clase order_test para paquetes relacionados con el Generador
//===================================================================

`ifndef ORDER_TEST_SV
`define ORDER_TEST_SV

// ── Definicion de las ordenes dadas por el Test
//    (escenarios para capacidades y casos esquina).
typedef enum {
    scen_aleatorio_sec,
    scen_aleatorio,
    scen_arbitraje_simultaneo,
    scen_broadcast,
    scen_invalido,
    scen_dispSos,
    scen_autodirec

} orden_tipo_e;

// ── Definicion de mailbox con datos de tipo order_test
typedef mailbox #(order_test) order_test_mbx;


class order_test;

    orden_tipo_e tipo;

    int unsigned          cantidad;
    int unsigned          delay_secuencia;
    bit          [7 : 0]  terminal_origen;

endclass : order_test

`endif // ORDER_TEST_SV
