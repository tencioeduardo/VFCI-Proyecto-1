//============================================
// Clase Monitor_controller (capa de comando)
//============================================

`ifndef MONITOR_CONTROLLER_SV
`define MONITOR_CONTROLLER_SV

class Monitor_controller #(parameter pckg_sz = `PCKG_SZ);
  virtual bus_if #(.pckg_sz(pckg_sz)).monitor_mp v_bif [4];
    trans_bus_mbx                       mon_son_mbx [4];
    trans_bus_mbx                       mon2chk_mbx;
    Monitor_son #(pckg_sz)              children [4];
    bit                                 reset_sent;

    function new(trans_bus_mbx mon2chk_mbx,
                 virtual bus_if #(.pckg_sz(pckg_sz)).monitor_mp v_bif [4]);
        this.mon2chk_mbx = mon2chk_mbx;
        this.reset_sent  = 1'b0;
        foreach (v_bif[i]) begin
            this.v_bif[i]  = v_bif[i];
            mon_son_mbx[i] = new();
            children[i]    = new(i, v_bif[i], mon_son_mbx[i]);
        end
    endfunction

    // ── Proceso padre: Inicia el monitor controller
    task run();
      $display("T=%0t [MONITOR_CONTROLLER] Starting...", $time);
      
        fork
            begin
                foreach (children[i]) children[i].run();
            end
            recolectar_hijos();
            watchdog_reset();
        join_none
    endtask

    // ── Proceso 1: Recolecta eventos de cada monitor hijo
    task recolectar_hijos();
        foreach (mon_son_mbx[i]) begin
            automatic int idx = i;
            fork
                begin
                    trans_bus t;
                    forever begin
                        mon_son_mbx[idx].get(t);
                        mon2chk_mbx.put(t);
                    end
                end
            join_none
        end
    endtask

    // ── Proceso 2: Reporta reset global una sola vez
    task watchdog_reset();
        trans_bus t;
        forever begin
            @(posedge v_bif[0].clk);
            // Reset global compartido por las 4 interfaces.
            if (v_bif[0].reset && !reset_sent) begin
                reset_sent  = 1'b1;
                t           = new();
                t.mon_kind  = EV_RESET;
                t.device_id = 0;
                mon2chk_mbx.put(t);
            end
            else if (!v_bif[0].reset) begin
                reset_sent = 1'b0;
            end
        end
    endtask

endclass

`endif // MONITOR_CONTROLLER_SV