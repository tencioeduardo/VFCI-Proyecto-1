//======================================================================
// bus_monitor_hijo.sv
//----------------------------------------------------------------------
// Monitor ESTRICTAMENTE PASIVO de la interfaz de UN dispositivo.
// En cada flanco de reloj muestrea la interfaz y emite una transaccion
// por cada EVENTO detectado (no una por ciclo) hacia el padre.
//
// EVENTOS
//   RST : reset cambio de nivel (deteccion por cambio, no por flanco
//         especifico: sube o baja). Incluye la primera muestra conocida.
//   PND : pndng cambio de nivel (idem).
//   TX  : pop  == 1 en este ciclo  -> el dispositivo termino de transmitir.
//   RX  : push == 1 en este ciclo  -> el dispositivo recibio un paquete.
//   pop y push se detectan por NIVEL en cada ciclo, no por flanco: si
//   un pulso dura 2 ciclos o hay dos pulsos seguidos, salen 2 eventos
//   y el checker puede verificar que el pulso es de un solo ciclo.
//
// ORDEN DE EMISION dentro de un mismo ciclo (C11), fijo y reproducible:
//       RST -> PND -> TX -> RX
//   - RST primero: es el contexto que aplica al resto de eventos.
//   - TX antes que RX: causalmente el dato sale antes de llegar. Aplica
//     al self-send (CAP-25) y, si el DUT entrega el broadcast al propio
//     emisor, tambien al broadcast. Todas comparten el mismo t.
//
// COMENTARIOS OBLIGATORIOS DE DISENO
//
// (a) MUESTREO POR vif.cb_mon. Todas las lecturas se hacen por el
//     clocking block para evitar la carrera con el device model, que
//     conduce pndng/D_pop por cb_drv. Si se agregan senales a la
//     interfaz, deben agregarse tambien a cb_mon (y a este monitor).
//
// (b) NO SE FILTRA EL RESET. El monitor es pasivo: no decide validez.
//     El nivel de reset viaja como campo de cada transaccion y ademas
//     los cambios de reset se reportan como eventos RST. El checker es
//     quien decide que hacer con lo ocurrido durante reset.
//
// (c) CAMPOS "NO APLICA". Cada tipo de transaccion solo llena los
//     campos que le corresponden; el resto queda en '0 (ver la tabla
//     en bus_mon_txn_hijo.sv).
//
// MAILBOX: mon2padre es NO ACOTADO (new() sin tamano, C3). Un put() en
// un mailbox acotado bloquea al llegar al limite y el monitor dejaria
// de muestrear el bus: perderia eventos. Un monitor pasivo no puede
// perder eventos.
//======================================================================
`ifndef BUS_MONITOR_HIJO_SV
`define BUS_MONITOR_HIJO_SV

import bus_mon_pkg::tipo_t;

class bus_monitor_hijo #(int pckg_sz = 16);

  virtual bus_if #(pckg_sz).monitor_mp   vif;
  mailbox #(bus_mon_txn_hijo #(pckg_sz)) mon2padre;   // C2: con #(pckg_sz)
  int unsigned                           n_forwarded = 0;

  // Nivel previo de reset/pndng. Parten en X: la primera muestra con
  // valor conocido difiere de X y por eso genera el evento inicial.
  // Se compara con !== para tratar bien las transiciones desde/hacia X.
  local logic prev_reset = 1'bx;
  local logic prev_pndng = 1'bx;

  // vif y mon2padre se inyectan por constructor. Lo normal es que el
  // padre cree el mailbox (no acotado) y lo pase; si llega null se crea
  // uno no acotado para poder usar el hijo de forma aislada.
  function new(virtual bus_if #(pckg_sz).monitor_mp   vif,
               mailbox #(bus_mon_txn_hijo #(pckg_sz)) mon2padre);
    this.vif = vif;
    if (mon2padre == null) this.mon2padre = new();   // no acotado (C3)
    else                   this.mon2padre = mon2padre;
  endfunction

  // Un solo punto de salida: put() en mailbox no acotado nunca bloquea.
  local task enviar(bus_mon_txn_hijo #(pckg_sz) m);
    mon2padre.put(m);
    n_forwarded++;
  endtask

  task run();
    bus_mon_txn_hijo #(pckg_sz) m;
    logic                       s_reset, s_pndng, s_pop, s_push;
    logic [pckg_sz-1:0]         s_D_pop, s_D_push;

    forever begin
      @(vif.cb_mon);                 // una muestra por flanco, para siempre

      // Snapshot unico: todas las decisiones usan los mismos valores.
      s_reset  = vif.cb_mon.reset;
      s_pndng  = vif.cb_mon.pndng;
      s_pop    = vif.cb_mon.pop;
      s_push   = vif.cb_mon.push;
      s_D_pop  = vif.cb_mon.D_pop;
      s_D_push = vif.cb_mon.D_push;

      // 1) RST: cambio de nivel de reset (sin filtrar nada).
      if (s_reset !== prev_reset) begin
        m       = new();
        m.t     = $time;
        m.tipo  = bus_mon_pkg::RST;
        m.reset = s_reset;
        enviar(m);
      end

      // 2) PND: cambio de nivel de pndng.
      if (s_pndng !== prev_pndng) begin
        m       = new();
        m.t     = $time;
        m.tipo  = bus_mon_pkg::PND;
        m.reset = s_reset;
        m.pndng = s_pndng;
        m.D_pop = s_D_pop;
        enviar(m);
      end

      // 3) TX: pop activo en este ciclo (por nivel). Antes que RX (C11).
      if (s_pop === 1'b1) begin
        m       = new();
        m.t     = $time;
        m.tipo  = bus_mon_pkg::TX;
        m.reset = s_reset;
        m.pndng = s_pndng;
        m.D_pop = s_D_pop;
        m.pop   = s_pop;
        enviar(m);
      end

      // 4) RX: push activo en este ciclo (por nivel).
      if (s_push === 1'b1) begin
        m        = new();
        m.t      = $time;
        m.tipo   = bus_mon_pkg::RX;
        m.reset  = s_reset;
        m.push   = s_push;
        m.D_push = s_D_push;
        enviar(m);
      end

      prev_reset = s_reset;
      prev_pndng = s_pndng;
    end
  endtask

endclass : bus_monitor_hijo

`endif // BUS_MONITOR_HIJO_SV
