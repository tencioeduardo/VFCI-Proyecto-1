//============================================
// Clase Agente (capa funcional)
//============================================
// Conexion al Generador por medio de: gen_agent_mbx
// Conexion al Scoreboard por medio de: agent_scorb_mbx
// Conexion al Driver_controller por medio de: agent_drvr_mbx

`ifndef AGENTE_SV
`define AGENTE_SV

class Agente #(parameter pckg_sz = 16);

    instruc_gen_mbx gen_agent_mbx;
    trans_bus_mbx   agent_scorb_mbx;
    trans_bus_mbx   agent_drvr_mbx;

    function new(
        instruc_gen_mbx gen_agent_mbx,
        trans_bus_mbx   agent_scorb_mbx,
        trans_bus_mbx   agent_drvr_mbx
    );
        this.gen_agent_mbx   = gen_agent_mbx;
        this.agent_scorb_mbx = agent_scorb_mbx;
        this.agent_drvr_mbx  = agent_drvr_mbx;
    endfunction


    // ── Proceso padre: Inicia el agente (clasifica las instrucciones)
    task run();
        $display("T=%0t [AGENTE] Starting...", $time);

        instruc_gen instruc;    // <-- Objeto de instruccion proveniente del generador

        forever begin
            $display("T=%0t [AGENTE] Waiting for an instruction...", $time);

            gen_agent_mbx.get(instruc);

            case (instruc.tipo)
                trans_aleatoria:  generar_aleatoria();
                trans_dirigida:   generar_dirigida(instruc);
                trans_secuencial: generar_secuencia(instruc.cantidad);

                default: generar_aleatoria();
            endcase
        end
    endtask

    // ── Proceso 1: Se generan transacciones de forma aleatoria
    task generar_aleatoria();
        $display("T=%0t [AGENTE] Random transaction requested.", $time);

        trans_bus trans = new();        // <-- Crea nueva instruccion de tipo trans_bus
        if(!trans.randomize()) $display("T=%0t [AGENTE] Random transaction failed.", $time);

        agent_drvr_mbx.put(trans);      // <-- Se envia al Driver_controller
        agent_scorb_mbx.put(trans);     // <-- Se envia al Scoreboard
    endtask

    // ── Proceso 2: Se generan transacciones de forma dirigida
    task generar_dirigida(instruc_gen t);
        $display("T=%0t [AGENTE] Specific transaction requested.", $time);

        trans_bus trans = new();        // <-- Crea nueva instruccion de tipo trans_bus

        trans.id_destino = t.id_destino;
        trans.id_origen  = t.id_origen;
        trans.payload    = t.payload;
        trans.delay      = t.delay;

        agent_drvr_mbx.put(trans);      // <-- Se envia al Driver_controller
        agent_scorb_mbx.put(trans);     // <-- Se envia al Scoreboard
    endtask

    // ── Proceso 3: Se genera una secuencia de transacciones de forma aleatoria
    task generar_secuencia(int unsigned n);
        $display("T=%0t [AGENTE] Sequence of %0d random transactions requested.", $time, n);

        repeat(n) begin
            trans_bus trans = new();        // <-- Crea nueva instruccion de tipo trans_bus

            if(!trans.randomize()) $display("T=%0t [AGENTE] Random transaction failed.", $time);

            agent_drvr_mbx.put(trans);      // <-- Se envia al Driver_controller
            agent_scorb_mbx.put(trans);     // <-- Se envia al Scoreboard
        end
    endtask

endclass : Agente

`endif // AGENTE_SV
