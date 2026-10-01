//============================================
// Clase Agente (capa funcional)
//============================================
// Conexion al Generador por medio de: gen_agent_mbx
// Conexion al Scoreboard por medio de: agent_scorb_mbx
// Conexion al Driver_controller por medio de: agent_drvr_mbx

`ifndef AGENTE_SV
`define AGENTE_SV

class Agente;

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
      	instruc_gen instruc;    // <-- Objeto de instruccion proveniente del generador
        $display("T=%0t [AGENTE] Starting...", $time);
        

        forever begin
            $display("T=%0t [AGENTE] Waiting for an instruction...", $time);

            gen_agent_mbx.get(instruc);

            case (instruc.tipo)
                trans_aleatoria:  generar_aleatoria();
                trans_dirigida:   generar_dirigida(instruc);
                trans_secuencial: generar_secuencia(instruc);

                default: generar_aleatoria();
            endcase
        end
    endtask


    // ── Proceso 1: Se generan transacciones de forma aleatoria
    //               (delega por completo a la aleatorizacion).
    task generar_aleatoria();
      	trans_bus trans = new();        // <-- Crea nueva instruccion de tipo trans_bus
        $display("T=%0t [AGENTE] Random transaction requested.", $time);

        if(!trans.randomize()) begin
      	    // ── Aborta la simulacion en caso de fallo en la aleatorizacion.
      	    $fatal(1, "T=%0t [AGENTE] Random transaction failed (randomization error).", $time);
        end
							
        agent_drvr_mbx.put(trans);      // <-- Se envia al Driver_controller
        agent_scorb_mbx.put(trans);     // <-- Se envia al Scoreboard
    endtask


    // ── Proceso 2: Se generan transacciones de forma dirigida
    //               (permite delegar algunos campos a la aleatorizacion).
    task generar_dirigida(instruc_gen t);
      	trans_bus trans = new();
        $display("T=%0t [AGENTE] Specific transaction requested.", $time);
      	
      	if (!trans.randomize() with {
            t.set_id_origen  -> id_origen  == t.id_origen;
            t.set_id_destino -> id_destino == t.id_destino;
            t.set_payload    -> payload    == t.payload;
            t.set_delay      -> delay      == t.delay;
        }) begin
          	// ── Aborta la simulacion en caso de fallo en la aleatorizacion.
        	$fatal(1, "T=%0t [AGENTE] Specific transaction failed (randomization error).", $time);
        end

        agent_drvr_mbx.put(trans);
        agent_scorb_mbx.put(trans);
    endtask


    // ── Proceso 3: Se genera una secuencia de transacciones de forma aleatoria
    //               (delega por completo a la aleatorizacion).
    task generar_secuencia(instruc_gen t);
        $display("T=%0t [AGENTE] Sequence of %0d random transactions requested.", $time,
                t.cantidad);

        repeat(t.cantidad) begin
            trans_bus trans = new();

            if(!trans.randomize() with {
                t.set_delay -> delay == t.delay;
            }) begin
              	// ── Aborta la simulacion en caso de fallo en la aleatorizacion.
            	$fatal(1, "T=%0t [AGENTE] Random transaction failed (randomization error).", $time);
            end

            agent_drvr_mbx.put(trans);
            agent_scorb_mbx.put(trans);
        end
    endtask

endclass : Agente

`endif // AGENTE_SV
