//======================================================================
// bus_monitor_padre.sv
//----------------------------------------------------------------------
// Monitor AGREGADOR y ESTRICTAMENTE PASIVO. Su unico trabajo es:
//   1) instanciar un bus_monitor_hijo por dispositivo,
//   2) escuchar a todos los hijos en paralelo,
//   3) etiquetar cada transaccion con dev_id (= indice del hijo),
//   4) reenviarla al checker por padre2checker.
//
// NO correlaciona TX con RX, NO filtra, NO decide PASS/FAIL, NO agrega
// logica de protocolo. Toda decision es del checker.
//
// CONCURRENCIA (C4)
//   run() lanza con fork/join_none, por cada dispositivo i, DOS tareas
//   independientes: hijos[i].run() y reenviar(i). Cada reenviador se
//   bloquea solo en su propio mailbox hijos2padre[i]. Asi ningun hijo
//   espera a otro y los eventos simultaneos (p. ej. N push en un
//   broadcast) se atienden sin serializar ni perder nada.
//   Un forever secuencial sobre todos los hijos, o un try_get() en
//   bucle sin control de tiempo, violarian "escucha sin bloquearse".
//
// ORDEN EN padre2checker
//   Se preserva el orden por dispositivo. Entre dispositivos distintos
//   con el mismo t el orden NO esta definido (depende del scheduler);
//   el checker debe tratar las transacciones de igual t como un
//   conjunto sin orden y apoyarse en t y dev_id.
//
// MAILBOXES
//   hijos2padre[i] y padre2checker son NO ACOTADOS (C3). padre2checker
//   lo crea el env (el checker necesita el mismo handle) y llega por
//   constructor. hijos2padre[i] los crea este padre y los inyecta a
//   cada hijo (C8).
//
// CIERRE: no hay bandera de parada; los forever corren hasta $finish.
//   La latencia hijo -> checker es de tiempo cero (mismo paso de
//   simulacion). Al terminar un test, esperar al menos un ciclo tras
//   la ultima actividad y drenar padre2checker. No usar "disable fork"
//   en el ambito que llama a run().
//======================================================================
`ifndef BUS_MONITOR_PADRE_SV
`define BUS_MONITOR_PADRE_SV

import bus_mon_pkg::tipo_t;

class bus_monitor_padre #(int pckg_sz = 16, int drvrs = 4);

  bus_monitor_hijo #(pckg_sz)             hijos[drvrs];
  mailbox #(bus_mon_txn_hijo #(pckg_sz))  hijos2padre[drvrs];
  mailbox #(bus_mon_txn_padre #(pckg_sz)) padre2checker;      // C2
  int unsigned                            n_forwarded = 0;

  // vifs[i] debe ser la interfaz conectada al puerto i del DUT: el
  // indice del arreglo ES el ID del dispositivo (dev_id).
  function new(virtual bus_if #(pckg_sz).monitor_mp   vifs[drvrs],
               mailbox #(bus_mon_txn_padre #(pckg_sz)) padre2checker);
    this.padre2checker = padre2checker;
    for (int i = 0; i < drvrs; i++) begin
      hijos2padre[i] = new();                       // no acotado (C3)
      hijos[i]       = new(vifs[i], hijos2padre[i]);
    end
  endfunction

  // Retorna de inmediato: las tareas quedan corriendo en segundo plano.
  task run();
    for (int i = 0; i < drvrs; i++) begin
      int idx = i;    // copia automatica por iteracion: evita que todas
                      // las tareas vean el ultimo valor de i
      fork
        reenviar(idx);
        hijos[idx].run();
      join_none
    end
  endtask

  // Reenviador del dispositivo idx: get -> etiquetar -> put.
  task reenviar(int idx);
    bus_mon_txn_hijo  #(pckg_sz) h;
    bus_mon_txn_padre #(pckg_sz) p;
    forever begin
      hijos2padre[idx].get(h);        // bloquea solo a ESTA tarea
      p = new();
      p.copy_from(h);
      p.dev_id = idx;                 // TX: emisor, RX: receptor
      padre2checker.put(p);           // no acotado: no bloquea (C3)
      n_forwarded++;
    end
  endtask

endclass : bus_monitor_padre

`endif // BUS_MONITOR_PADRE_SV
