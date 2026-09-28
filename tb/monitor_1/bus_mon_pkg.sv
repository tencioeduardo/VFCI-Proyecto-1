//======================================================================
// bus_mon_pkg.sv
//----------------------------------------------------------------------
// Declaracion UNICA de los tipos compartidos por los monitores del bus
// y por sus transacciones (y, mas adelante, por el checker).
//
// Declararlo en un solo lugar evita definiciones duplicadas de tipo_t
// en distintos archivos, que serian tipos incompatibles entre si.
//
// Tipos de evento (una transaccion por EVENTO, no por ciclo):
//   TX  : el dispositivo termino de transmitir su paquete (pop == 1).
//   RX  : el dispositivo recibio un paquete completo    (push == 1).
//   RST : cambio de nivel de reset (incluye la primera muestra valida).
//   PND : cambio de nivel de pndng (incluye la primera muestra valida).
//
// Uso recomendado fuera de este paquete: referirse a los enumeradores
// con su ambito, p. ej. bus_mon_pkg::TX, para evitar colisiones de
// nombres si se hace un import con comodin en un ambito grande.
//======================================================================
`ifndef BUS_MON_PKG_SV
`define BUS_MON_PKG_SV

package bus_mon_pkg;

  typedef enum { TX, RX, RST, PND } tipo_t;

endpackage : bus_mon_pkg

`endif // BUS_MON_PKG_SV
