//============================================
// Clase Monitor_controller (capa de comando)
//============================================

`ifndef MONITOR_SON_SV
`define MONITOR_SON_SV

// -----------------------------------------------------------------
// Monitor_son: observa pasivamente UNA interface bus_if (la del
// dispositivo `monitor_id`) y reporta a su padre (Monitor_controller)
// cada flanco de push (RX) y cada flanco de pop (TX) que ve.
//
// Es autónomo frente a reset: lee v_bif.reset directamente y se
// auto-pausa (no filtra, no decide nada más allá de no muestrear).
//
// FIFO de recepción (cola_rx): espejo, del lado del Monitor, de lo
// que `cola_tx` es para Driver_son. Es una cola dinámica (espacio
// "infinito") que modela la FIFO de RX del dispositivo:
//   - `muestrear_eventos()` (el "transductor", bus -> cola_rx) es
//     quien LLENA cola_rx cada vez que detecta un flanco de push.
//     Su lógica de detección de flancos, reset, `last_D_pop` y el
//     reporte de EV_TX_POP no cambian.
//   - `despachar_rx()` (cola_rx -> entorno) es un proceso
//     INDEPENDIENTE de `muestrear_eventos()` que vacía cola_rx hacia
//     `mon_son_mbx`, igual que `recibir_del_padre()` en Driver_son
//     es independiente de `manejar_protocolo()`. A diferencia de
//     `manejar_protocolo()` (que sí está ligado a
//     `@(posedge v_bif.clk)`), `despachar_rx()` NO está ligado a
//     reloj: drena apenas hay algo en la cola, para no romper la
//     decisión 3.D-1 (broadcast-to-self debe reportar EV_RX_PUSH y
//     EV_TX_POP en el mismo ciclo).
//
// NOTA: v_bif se declara con el modport `monitor_mp`, igual que hace
// Driver_son con `driver_mp` y como lo entrega Monitor_controller.
// El hijo solo LEE señales.
// -----------------------------------------------------------------
class Monitor_son #(parameter pckg_sz = `PCKG_SZ);
    int                                           monitor_id;
    virtual bus_if #(.pckg_sz(pckg_sz)).monitor_mp v_bif;
    trans_bus_mbx                                 mon_son_mbx;

    bit               prev_push;
    bit               prev_pop;
    bit [pckg_sz-1:0] last_D_pop;

    // FIFO de RX: cola dinámica, espejo de cola_tx en Driver_son.
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

    task run();
      $display("T=%0t [MONITOR_SON %0d] Starting...", $time, monitor_id);
      
        fork
            muestrear_eventos();
            muestrear_D_pop();
            despachar_rx();
        join_none
    endtask

    task muestrear_eventos();
        trans_bus t;
        forever begin
            @(posedge v_bif.clk);

            // 1) Reset: el hijo se auto-pausa (no reporta, no acumula).
            if (v_bif.reset) begin
                reset();          // limpia cola_rx, last_D_pop, prev_push, prev_pop
            end
            else begin
                // Traza de diagnóstico (solo con +trace_mon).
                if ($test$plusargs("trace_mon") && (v_bif.pndng || v_bif.pop))
                    $display("T=%0t [MON%0d] posedge  pndng=%b pop=%b prev_pop=%b D_pop=0x%0h last_D_pop=0x%0h",
                             $time, monitor_id, v_bif.pndng, v_bif.pop, prev_pop, v_bif.D_pop, last_D_pop);

                // 2) (La sombra de D_pop ya no se toma aquí: la mantiene
                //    muestrear_D_pop() en negedge. Si pop se afirma este
                //    ciclo, last_D_pop ya refleja el valor del ciclo
                //    anterior, estable antes del paso 4.)

                // 3) Flanco 0->1 en push (RX). Independiente del de pop.
                //    Se encola en cola_rx (FIFO de RX); despachar_rx() es
                //    quien la vacía hacia mon_son_mbx, de forma
                //    independiente a este proceso.
                if (v_bif.push && !prev_push) begin
                    t = new();
                    t.mon_kind   = EV_RX_PUSH;
                    t.device_id  = monitor_id;
                    // id_origen no viaja en el paquete; el Checker nunca lo usa en RX (desviación 1 de NOTAS_INTEGRACION.md).
                    t.id_origen  = '0;
                    t.id_destino = v_bif.D_push[pckg_sz-1 -: 8];
                    t.payload    = v_bif.D_push[pckg_sz-9 : 0];
                    cola_rx.push_back(t);
                end

                // 4) Flanco 0->1 en pop (TX). Independiente del de push.
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

            // 5) SIEMPRE: actualizar historial de flancos al final del
            //    ciclo, haya o no reset (evita un falso EV_RX_PUSH en el
            //    primer ciclo post-reset si push se mantuvo en 1).
            prev_push = v_bif.push;
            prev_pop  = v_bif.pop;
        end
    endtask

    // Muestreo de D_pop en negedge: el Driver_son actualiza D_pop con
    // asignación bloqueante en posedge, así que si el Monitor leyera
    // D_pop en posedge habría un race delta-cycle (el Monitor podría ver
    // el valor NUEVO del paquete siguiente en lugar del actual). En
    // negedge, D_pop es estable y refleja el valor que el DUT vio durante
    // el ciclo que acaba de terminar.
    // Asume FWFT: D_pop es estable mientras pndng=1. Si el DUT retractara pndng
    // a mitad de transferencia (CAE-tempo), este muestreo necesitaría revisarse.
    task muestrear_D_pop();
        forever begin
            @(negedge v_bif.clk);
            if (v_bif.pndng) last_D_pop = v_bif.D_pop;

            // Traza de diagnóstico (solo con +trace_mon).
            if ($test$plusargs("trace_mon") && (v_bif.pndng || v_bif.pop))
                $display("T=%0t [MON%0d] negedge pndng=%b pop=%b D_pop=0x%0h last_D_pop=0x%0h",
                         $time, monitor_id, v_bif.pndng, v_bif.pop, v_bif.D_pop, last_D_pop);
        end
    endtask

    // Vacía cola_rx hacia mon_son_mbx. Proceso independiente de
    // muestrear_eventos() (igual que recibir_del_padre() es
    // independiente de manejar_protocolo() en Driver_son).
    // Deliberadamente NO está ligado a @(posedge v_bif.clk): drena
    // apenas hay algo en la cola, en el mismo ciclo en que se
    // encoló, para no romper la decisión 3.D-1 (broadcast-to-self
    // debe seguir reportando EV_RX_PUSH y EV_TX_POP en el mismo
    // ciclo que hoy).
    task despachar_rx();
        trans_bus t;
        forever begin
            wait (cola_rx.size() > 0);
            t = cola_rx.pop_front();
            mon_son_mbx.put(t);
        end
    endtask

    // Reinicia el estado interno del hijo (llamado desde
    // muestrear_eventos en reset, y disponible para uso externo).
    // También limpia cola_rx: no se arrastran eventos pendientes de
    // antes del reset.
    function void reset();
        prev_push  = 1'b0;
        prev_pop   = 1'b0;
        last_D_pop = '0;
        cola_rx.delete();
    endfunction

endclass

`endif // MONITOR_SON_SV
