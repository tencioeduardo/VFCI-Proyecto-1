//============================================
// Clase Driver_controller (capa de comando)
//============================================
// Conexion al Agente por medio de: agent_drvr_mbx
// Conexion al Driver_hijo por medio de: drvr_son_mbx
// Tipo de paquetes en el mailbox: trans_bus

`ifndef DRIVER_CONTROLLER_SV
`define DRIVER_CONTROLLER_SV

class Driver_controller #(parameter pckg_sz = `PCKG_SZ);

    virtual bus_if #(.pckg_sz(pckg_sz)).driver_mp v_bif [4];
    trans_bus_mbx                       		  drvr_son_mbx [4];
    trans_bus_mbx                       		  agent_drvr_mbx;
    Driver_son                          		  children [4];

    function new(
        trans_bus_mbx                       		  agent_drvr_mbx,
        virtual bus_if #(.pckg_sz(pckg_sz)).driver_mp v_bif[4]
    );
        this.agent_drvr_mbx = agent_drvr_mbx;

        foreach (v_bif[i]) begin
            drvr_son_mbx[i] = new();
            this.v_bif[i]   = v_bif[i];
            children[i]     = new(i, v_bif[i], drvr_son_mbx[i]);
        end
    endfunction

    // ── Proceso padre: Inicia el driver controller
    task run();
        $display("T=%0t [DRIVER_CONTROLLER] Starting...", $time);

        fork
          	begin
            	foreach (children[i]) children[i].run();
          	end
            delegar_instrucciones();
        join_none
    endtask

    // ── Proceso 1: Se delegan las instrucciones a cada driver hijo
    task delegar_instrucciones();
        trans_bus trans;

        forever begin
            $display("T=%0t [DRIVER_CONTROLLER] Waiting for an instruction...", $time);

            agent_drvr_mbx.get(trans);
            drvr_son_mbx[trans.id_origen].put(trans);

            $display("T=%0t [DRIVER_CONTROLLER] Instruction sent to driver_son %0d.", $time, trans.id_origen);
        end
    endtask


    // ── Proceso 2: Se aplica reset a los drivers hijos
    task son_reset();
        $display("T=%0t [DRIVER_CONTROLLER] Starting reset...", $time);

        fork
            children[0].reset();
            children[1].reset();
            children[2].reset();
            children[3].reset();
        join

        $display("T=%0t [DRIVER_CONTROLLER] Reset completed.", $time);
    endtask
  
  // ── Proceso 3: Esperar a que las colas TX de todos los hijos queden vacías
    task wait_for_tx_empty();
        $display("T=%0t [DRIVER_CONTROLLER] Waiting for the DUT to consume the packets...", $time);
      
        wait (
            children[0].cola_tx.size() == 0 &&
            children[1].cola_tx.size() == 0 &&
            children[2].cola_tx.size() == 0 &&
            children[3].cola_tx.size() == 0
        );
        
        $display("T=%0t [DRIVER_CONTROLLER] All TX queues are empty.", $time);
    endtask

endclass : Driver_controller

`endif // DRIVER_CONTROLLER
