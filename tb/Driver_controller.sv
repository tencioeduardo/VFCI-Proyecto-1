//============================================
// Clase Driver_controlador (capa de comando)
//============================================
// Conexion al Agente por medio de: agent_drvr_mbx
// Conexion al Driver_hijo por medio de: drvr_son_mbx
// Tipo de paquetes en el mailbox: trans_bus

`ifndef DRIVER_CONTROLLER
`define DRIVER_CONTROLLER

class Driver_controller #(parameter pckg_sz = 16);

    virtual bus_if #(.pckg_sz(pckg_sz)) v_bif [4];              // Externo x
    trans_bus_mbx                       drvr_son_mbx [4];       // Propio
    trans_bus_mbx                       agent_drvr_mbx;         // Externo x
    Driver_son                          children [4];           // Propio

    function new(
        trans_bus_mbx                       agent_drvr_mbx,
        virtual bus_if #(.pckg_sz(pckg_sz)) v_bif[4]
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


endclass : Driver_controller

`endif // DRIVER_CONTROLLER
