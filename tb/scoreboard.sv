// -----------------------------------------------------------------
// Scoreboard: componente pasivo. Recibe del Agente (agent_scorb_mbx)
// la MISMA transacción que este envió al Driver, y la reenvía tal
// cual al Checker (sb2chk_mbx) como "lo que el ambiente espera".
//
// No inspecciona id_destino/payload: el DUT es un bus transparente
// (no transforma el paquete), así que no hay nada que "predecir" más
// allá del contenido que el Agente ya generó. La clasificación por
// tipo de destino (P2P/broadcast/inválido) y cuántas observaciones
// exigir en cada caso son responsabilidad exclusiva del Checker
// (clasificar()/intentar_matchear()); duplicarla aquí solo crearía
// dos lugares que mantener sincronizados.
//
// No reenvía una copia (trans.copy()): se revisó el flujo completo
// (Driver_son, Monitor_son, Checker) y ningún consumidor muta el
// handle después de que el Agente lo randomiza, así que no hay
// riesgo de aliasing que justifique una copia.
//
// Tampoco filtra reset: el Agente (Agente.sv) no es reset-aware y
// sigue generando estímulo aunque el DUT esté en reset, así que
// filtrar aquí dejaría al Scoreboard desincronizado de lo que el
// Driver realmente hizo. La limpieza ante reset ya está centralizada
// en el Checker, vía el centinela EV_RESET que le llega del Monitor.
// -----------------------------------------------------------------
`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

class Scoreboard;
    trans_bus_mbx agent_scorb_mbx; // entrada: transacciones del Agente
    trans_bus_mbx sb2chk_mbx;      // salida: transacciones esperadas, hacia el Checker

    function new(trans_bus_mbx agent_scorb_mbx, trans_bus_mbx sb2chk_mbx);
        this.agent_scorb_mbx = agent_scorb_mbx;
        this.sb2chk_mbx      = sb2chk_mbx;
    endfunction

    task run();
        $display("T=%0t [SCOREBOARD] Starting...", $time);
        fork
            reenviar_esperado();
        join_none
    endtask

    // Único proceso: recibe del Agente y reenvía al Checker, sin
    // transformar ni filtrar nada.
    task reenviar_esperado();
        trans_bus trans;
        forever begin
            agent_scorb_mbx.get(trans);
            sb2chk_mbx.put(trans);
        end
    endtask

endclass : Scoreboard

`endif // SCOREBOARD_SV
