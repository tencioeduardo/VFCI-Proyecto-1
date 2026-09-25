//===================================================================
// Clase order_test para paquetes relacionados con el Generador
//===================================================================

`ifndef ORDER_TEST_SV
`define ORDER_TEST_SV

// ── Definicion de las ordenes dadas por el Test
typedef enum data_type {

    // --------------------------------------------------
    // ── Escenarios para capacidades (CAP-01 a CAP-25)
    // --------------------------------------------------
    scen_aleatorio_sec,
    scen_aleatorio,
    scen_arbitraje_simultaneo,
    scen_broadcast,
    scen_invalido,
    scen_pckg_sz,
    scen_reset,     // <-- Tentativo

    // --------------------------------------------------
    // ── Escenarios para casos esquina ()
    // --------------------------------------------------
    scenEsq_disponibilidad,
    scenEsq_autodirec,
    scenEsq_tempo

} orden_tipo_e;

// ── Definicion de mailbox con datos de tipo order_test
typedef mailbox #(order_test) order_test_mbx;


class order_test #(parameter pckg_sz = 16);

    orden_tipo_e orden;
    int unsigned cantidad;

endclass

`endif // ORDER_TEST_SV
