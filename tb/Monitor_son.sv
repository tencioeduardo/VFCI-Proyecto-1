//============================================
// Clase Monitor_son (capa de comando)
//============================================
// Observa pasivamente una interface bus_if y reporta eventos RX/TX.
// Conexion al Monitor_controller por medio de: mon_son_mbx
// Tipo de paquetes en el mailbox: trans_bus

`ifndef MONITOR_SON_SV
`define MONITOR_SON_SV

class Monitor_son #(parameter pckg_sz = `PCKG_SZ);
    int                                           monitor_id;
    virtual bus_if #(.pckg_sz(pckg_sz)).monitor_mp v_bif;
    trans_bus_mbx                                 mon_son_mbx;

    bit               prev_push;
    bit               prev_pop;
    bit [pckg_sz-1:0] last_D_pop;

    // ── FIFO de RX: espejo de cola_tx en Driver_son
    trans_bus cola_rx [$];

    function new(int monitor_id,
                 virtual bus_if #(.pckg_sz(pckg_sz)).monitor_mp v_bif,
                 trans_bus_mbx mon_son_mbx);
        this.monitor_id  = monitor_id;
        this.v_bif       = v_bif;
        this.mon_son_mbx = mon_son_mbx;
        this.prev_push   = 1'b0;
        this.prev_pop    = 1'b0;
        this.last_D_pop  = '0;
    endfunction

    // ── Proceso padre: Inicia el monitor hijo
    task run();
      $display("T=%0t [MONITOR_SON %0d] Starting...", $time, monitor_id);
      
        fork
            muestrear_eventos();
            muestrear_D_pop();
            despachar_rx();
        join_none
    endtask

    // ── Proceso 1: Muestrea push/pop en posedge
    task muestrear_eventos();
        trans_bus t;
        forever begin
            @(posedge v_bif.clk);

            // Reset: auto-pausa sin reportar.
            if (v_bif.reset) begin
                reset();
            end
            else begin
                // Traza de diagnostico (+trace_mon).
                if ($test$plusargs("trace_mon") && (v_bif.pndng || v_bif.pop))
                    $display("T=%0t [MON%0d] posedge  pndng=%b pop=%b prev_pop=%b D_pop=0x%0h last_D_pop=0x%0h",
                             $time, monitor_id, v_bif.pndng, v_bif.pop, prev_pop, v_bif.D_pop, last_D_pop);

                // Flanco 0->1 en push (RX).
                if (v_bif.push && !prev_push) begin
                    t = new();
                    t.mon_kind   = EV_RX_PUSH;
                    t.device_id  = monitor_id;
                    t.id_origen  = '0;
                    t.id_destino = v_bif.D_push[pckg_sz-1 -: 8];
                    t.payload    = v_bif.D_push[pckg_sz-9 : 0];
                    cola_rx.push_back(t);
                end

                // Flanco 0->1 en pop (TX).
                if (v_bif.pop && !prev_pop) begin
                    t = new();
                    t.mon_kind   = EV_TX_POP;
                    t.device_id  = monitor_id;
                    t.id_origen  = monitor_id;
                    t.id_destino = last_D_pop[pckg_sz-1 -: 8];
                    t.payload    = last_D_pop[pckg_sz-9 : 0];
                    mon_son_mbx.put(t);
                end
            end

            // Actualiza historial de flancos.
            prev_push = v_bif.push;
            prev_pop  = v_bif.pop;
        end
    endtask

    // ── Proceso 2: Muestrea D_pop en negedge
    task muestrear_D_pop();
        forever begin
            @(negedge v_bif.clk);
            if (v_bif.pndng) last_D_pop = v_bif.D_pop;

            // Traza de diagnostico (+trace_mon).
            if ($test$plusargs("trace_mon") && (v_bif.pndng || v_bif.pop))
                $display("T=%0t [MON%0d] negedge pndng=%b pop=%b D_pop=0x%0h last_D_pop=0x%0h",
                         $time, monitor_id, v_bif.pndng, v_bif.pop, v_bif.D_pop, last_D_pop);
        end
    endtask

    // ── Proceso 3: Drena cola_rx hacia mon_son_mbx
    task despachar_rx();
        trans_bus t;
        forever begin
            wait (cola_rx.size() > 0);
            t = cola_rx.pop_front();
            mon_son_mbx.put(t);
        end
    endtask

    // ── Reinicia el estado interno
    function void reset();
        prev_push  = 1'b0;
        prev_pop   = 1'b0;
        last_D_pop = '0;
        cola_rx.delete();
    endfunction

endclass

`endif // MONITOR_SON_SV