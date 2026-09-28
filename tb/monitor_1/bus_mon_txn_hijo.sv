//======================================================================
// bus_mon_txn_hijo.sv
//----------------------------------------------------------------------
// Transaccion generada por bus_monitor_hijo: UN EVENTO observado en la
// interfaz de UN dispositivo. El hijo no conoce el ID del dispositivo
// (eso lo etiqueta el padre en bus_mon_txn_padre).
//
// Una transaccion representa un evento, no un ciclo de reloj. Tipos:
//   TX, RX, RST, PND (ver bus_mon_pkg.sv).
//
// SEMANTICA DE t
//   t = $time del flanco de reloj en el que se muestreo. Como el
//   muestreo usa cb_mon con skew #1step, los VALORES corresponden al
//   ciclo anterior a ese flanco; t es el instante del flanco.
//
// CAMPOS POR TIPO  (X = aplica, 0 = "no aplica / don't care" y se
// deja en '0 desde el constructor, nunca en X)
//
//   campo    | TX | RX | RST | PND | nota
//   ---------+----+----+-----+-----+--------------------------------
//   t        | X  | X  |  X  |  X  |
//   tipo     | X  | X  |  X  |  X  |
//   reset    | X  | X  |  X  |  X  | RST: nuevo nivel. Resto: nivel
//            |    |    |     |     | observado (NO se filtra).
//   pndng    | X  | 0  |  0  |  X  | PND: nuevo nivel. TX: nivel al
//            |    |    |     |     | completarse la transmision.
//   D_pop    | X  | 0  |  0  |  X  | TX: paquete transmitido.
//            |    |    |     |     | PND: paquete presentado (solo
//            |    |    |     |     | significativo si pndng subio a 1).
//   pop      | 1  | 0  |  0  |  0  |
//   push     | 0  | 1  |  0  |  0  |
//   D_push   | 0  | X  |  0  |  0  |
//
//   Un campo "no aplica" vale '0 aunque la senal real valga otra cosa
//   en ese ciclo; ese dato, si existe, viaja en la otra transaccion
//   del mismo ciclo (p. ej. pop y push coincidentes -> TX y RX).
//
// tipo por defecto en el constructor: TX (solo por ser el primer
// enumerador; el monitor siempre lo asigna explicitamente).
//======================================================================
`ifndef BUS_MON_TXN_HIJO_SV
`define BUS_MON_TXN_HIJO_SV

import bus_mon_pkg::tipo_t;

class bus_mon_txn_hijo #(int pckg_sz = 16);

  time                 t;
  logic                reset;    // logic (4 estados), no bit (C9)
  tipo_t               tipo;
  logic                pndng;
  logic [pckg_sz-1:0]  D_pop;
  logic                pop;
  logic                push;
  logic [pckg_sz-1:0]  D_push;

  // Todos los campos parten en '0 (C5): un "no aplica" nunca es X.
  function new();
    t      = 0;
    reset  = '0;
    tipo   = bus_mon_pkg::TX;
    pndng  = '0;
    D_pop  = '0;
    pop    = '0;
    push   = '0;
    D_push = '0;
  endfunction

  // Imprime solo los campos que aplican al tipo de evento.
  virtual function string convert2str();
    string s;
    case (tipo)
      bus_mon_pkg::TX:  s = $sformatf("TX  pndng=%b D_pop=0x%0h pop=%b",
                                      pndng, D_pop, pop);
      bus_mon_pkg::RX:  s = $sformatf("RX  push=%b D_push=0x%0h",
                                      push, D_push);
      bus_mon_pkg::RST: s = "RST (cambio de nivel de reset)";
      bus_mon_pkg::PND: s = $sformatf("PND pndng=%b D_pop=0x%0h",
                                      pndng, D_pop);
      default:          s = "??? tipo desconocido";
    endcase
    return $sformatf("@%0t reset=%b %s", t, reset, s);
  endfunction

endclass : bus_mon_txn_hijo

`endif // BUS_MON_TXN_HIJO_SV
