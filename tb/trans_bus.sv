//===================================================================
// Clase trans_bus para definir tipo de mailbox: trans_bus_mbx
//===================================================================

`ifndef TRANS_BUS_SV
`define TRANS_BUS_SV

// -----------------------------------------------------------------
//   EV_NONE     -> transaccion "normal" generada por Agente/Driver
//   EV_RX_PUSH  -> el Monitor observo push=1 (recepcion) en un hijo
//   EV_TX_POP   -> el Monitor observo pop=1  (transmision) en un hijo
//   EV_RESET    -> centinela: el Monitor detecto reset en el DUT
// -----------------------------------------------------------------
typedef enum {
    EV_NONE,
    EV_RX_PUSH,
    EV_TX_POP,
    EV_RESET
} mon_event_e;

class trans_bus #(parameter pckg_sz = `PCKG_SZ);

    // ----------------------------------------------------------
    // ── Campos aleatorizables
    // ----------------------------------------------------------
    rand bit [7 : 0]         id_origen;
    rand bit [7 : 0]         id_destino;
    rand bit [pckg_sz-9 : 0] payload;
    rand int unsigned        delay;

    // ----------------------------------------------------------
    // ── Campos no aleatorizables
    // ----------------------------------------------------------
    int unsigned                 id;             // id de la transaccion
    static int unsigned          n_created = 0;  // cantidad de transacciones
    bus_config                   cfg;            // puntero al archivo de config


    // ----------------------------------------------------------
    // ── Campos para monitor y checker
    // ----------------------------------------------------------
    mon_event_e  mon_kind  = EV_NONE;
    int unsigned device_id = 0;


    function new();
        cfg = bus_config::get();
    endfunction


    // ----------------------------------------------------------
    // ── Constraints
    // ----------------------------------------------------------
    // ── Define los valores que puede tomar el id_origen
    constraint origen_range_c {
        id_origen inside {[0 : cfg.drvrs-1]};
    }

    // ── Define los valores que puede tomar id_destino
    constraint destino_dist_c {
        // ── Distribucion con peso para el id_destino
        id_destino dist {
            [0 : cfg.drvrs-1]  :/ cfg.wt_destino_valido,
            cfg.id_invalido    := cfg.wt_destino_invalido,
            cfg.id_broadcast   := cfg.wt_broadcast
        };
    }

    // ── Define los valores que puede tomar el delay
    constraint dealay_range_c {
        delay inside {[cfg.min_delay : cfg.max_delay]};
    }

    // ── Define los valores que puede tomar el payload
    constraint payload_range_c {
        payload inside {[cfg.payload_min : cfg.payload_max]};
    }


    //===================================================================
    // ── Constraint_mode() (encendido y apagado de los constraints)
    //===================================================================
    function void pre_randomize();
        origen_range_c.constraint_mode  (cfg.is_enabled("origen_range_c"));     //<-- Puede no ser necesario apagarse.
        destino_dist_c.constraint_mode  (cfg.is_enabled("destino_dist_c"));
        dealay_range_c.constraint_mode  (cfg.is_enabled("dealay_range_c"));
        payload_range_c.constraint_mode (cfg.is_enabled("payload_range_c"));
    endfunction

    // ── Maneja el id junto con la cantidad total de transacciones
    function void post_randomize();
        id = n_created++;
    endfunction

    // ── Ayuda a desplegar facilmente la informacion sobre las transacciones
    function string convert2str();
        return $sformatf("trans_bus#%0d org=%0d dst=%0d payload=0x%0h delay=%0d",
        id, id_origen, id_destino, payload, delay);
    endfunction

endclass : trans_bus

typedef mailbox #(trans_bus) trans_bus_mbx;

`endif // TRANS_BUS_SV
