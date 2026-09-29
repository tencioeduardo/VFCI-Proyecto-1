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
// NOTA: v_bif se declara sin sufijo de modport, igual que hace
// Driver_son con `driver_mp`, para mantener el mismo estilo del
// código existente. Conceptualmente el hijo solo LEE señales, lo
// que corresponde a `monitor_mp`.
// -----------------------------------------------------------------
class Monitor_son #(parameter pckg_sz = 16);
    int                                  monitor_id;
    virtual bus_if #(.pckg_sz(pckg_sz))  v_bif;
    trans_bus_mbx                        mon_son_mbx;

    bit               prev_push;
    bit               prev_pop;
    bit [pckg_sz-1:0] last_D_pop;

    // FIFO de RX: cola dinámica, espejo de cola_tx en Driver_son.
    trans_bus cola_rx [$];

    function new(int monitor_id,
                 virtual bus_if #(.pckg_sz(pckg_sz)) v_bif,
                 trans_bus_mbx mon_son_mbx);
        this.monitor_id  = monitor_id;
        this.v_bif       = v_bif;
        this.mon_son_mbx = mon_son_mbx;
        this.prev_push   = 1'b0;
        this.prev_pop    = 1'b0;
        this.last_D_pop  = '0;
    endfunction

    task run();
        fork
            muestrear_eventos();
            despachar_rx();
        join_none
    endtask

    task muestrear_eventos();
        trans_bus t;
        forever begin
            @(posedge v_bif.clk);

            // 1) Reset: el hijo se auto-pausa (no reporta, no acumula).
            if (v_bif.reset) begin
                reset();
                continue;
            end

            // 2) Sombra de D_pop mientras hay pendencia. D_push/D_pop
            //    son estables durante el ciclo activo (CAP-19), así
            //    que si pop se afirma este mismo ciclo, last_D_pop ya
            //    quedó actualizado con el valor correcto antes del
            //    paso 4.
            if (v_bif.pndng) begin
                last_D_pop = v_bif.D_pop;
            end

            // 3) Flanco 0->1 en push (RX). Independiente del de pop.
            //    Se encola en cola_rx (FIFO de RX); despachar_rx() es
            //    quien la vacía hacia mon_son_mbx, de forma
            //    independiente a este proceso.
            if (v_bif.push && !prev_push) begin
                t = new();
                t.mon_kind   = EV_RX_PUSH;
                t.device_id  = monitor_id;
                t.id_origen  = '0; // ver DESVIACIONES en NOTAS_INTEGRACION.md
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

            // 5) Actualizar historial de flancos.
            prev_push = v_bif.push;
            prev_pop  = v_bif.pop;
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