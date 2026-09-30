`ifndef TRANS_BUS_SV
`define TRANS_BUS_SV

// -----------------------------------------------------------------
// mon_event_e: tipo de evento que reporta el Monitor sobre una
// transacción trans_bus. Se usa en Monitor_son/Monitor_controller
// (para etiquetar lo que observan en el bus) y en Checker (para
// clasificar lo que llega por mon2chk_mbx).
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

typedef mailbox #(trans_bus) trans_bus_mbx;

class trans_bus #(parameter pckg_sz = `PCKG_SZ);
    rand bit [7 : 0]         id_origen;
    rand bit [7 : 0]         id_destino;
    rand bit [pckg_sz-9 : 0] payload;
    rand int unsigned        delay;

    int unsigned             id;
    static int unsigned      n_created = 0;
    bus_config                cfg;

    // ---- Campos añadidos para soportar Monitor/Checker ----------
    // NO son aleatorizables: los rellena el Monitor_son al observar
    // el bus, nunca el Agente/Generador.
    mon_event_e  mon_kind  = EV_NONE;
    int unsigned device_id = 0;

    function new(); cfg = bus_config::get(); endfunction

    constraint origen_range_c  { id_origen inside {[0 : cfg.drvrs-1]}; }
    constraint destino_dist_c  {
        id_destino dist {
            [0 : cfg.drvrs-1] :/ cfg.wt_destino_valido,
            cfg.id_invalido   := cfg.wt_destino_invalido,
            cfg.id_broadcast  := cfg.wt_broadcast
        };
    }
    constraint dealay_range_c  { delay inside {[cfg.min_delay : cfg.max_delay]}; }
    constraint payload_range_c { payload inside {[cfg.payload_min : cfg.payload_max]}; }

    function void pre_randomize();
        origen_range_c.constraint_mode (cfg.is_enabled("origen_range_c"));
        destino_dist_c.constraint_mode (cfg.is_enabled("destino_dist_c"));
        dealay_range_c.constraint_mode (cfg.is_enabled("dealay_range_c"));
        payload_range_c.constraint_mode(cfg.is_enabled("payload_range_c"));
    endfunction

    function void post_randomize(); id = n_created++; endfunction

    function string convert2str();
        return $sformatf("trans_bus#%0d org=%0d dst=%0d payload=0x%0h delay=%0d kind=%s dev=%0d",
                         id, id_origen, id_destino, payload, delay, mon_kind.name(), device_id);
    endfunction

endclass

`endif // TRANS_BUS_SV