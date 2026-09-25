//===================================================================
// Clase instruc_gen para paquetes relacionados con el Agente
//===================================================================

`ifndef INSTRUC_GEN_SV
`define INSTRUC_GEN_SV

// ── Definicion de los tipos de transacciones especificadas por el Generador
typedef enum {generar_aleatoria, generar_dirigida, generar_secuencia} instruc_tipo_e;

// ── Definicion de mailbox con datos de tipo instruc_gen
typedef mailbox #(instruc_gen) instruc_gen_mbx;

class instruc_gen #(parameter pckg_sz = 16);

    instruc_tipo_e tipo;    // <-- Definido por el Generador

    // ----------------------------------------------------------
    // ── Datos para transacciones dirigidas
    // ----------------------------------------------------------
    bit [7 : 0]         id_destino;
    bit [7 : 0]         id_origen;
    bit [pckg_sz-9 : 0] payload;

    int unsigned        delay;


    // ----------------------------------------------------------
    // ── Dato para transacciones secuenciales (aleatorias)
    // ----------------------------------------------------------
    int unsigned cantidad;

endclass : instruc_gen

`endif // INSTRUC_GEN_SV
