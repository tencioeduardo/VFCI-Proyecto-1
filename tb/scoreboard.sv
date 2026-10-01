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
        int unsigned verbose;
        forever begin
            agent_scorb_mbx.get(trans);
            if ($value$plusargs("verbose_sb=%d", verbose) && verbose)
                $display("T=%0t [SCOREBOARD] forwarding trans#%0d", $time, trans.id);
            sb2chk_mbx.put(trans);
        end
    endtask

endclass : Scoreboard

`endif // SCOREBOARD_SV
