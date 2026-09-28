//======================================================================
// bus_mon_cls_pkg.sv
//----------------------------------------------------------------------
// Paquete envoltorio que agrupa las 4 clases del monitor jerarquico.
//
// POR QUE EXISTE: si cada archivo .sv se compila como su propia unidad
// de compilacion ($unit), una clase declarada en un archivo NO es
// visible desde otro (error "undeclared identifier"). Ponerlas en un
// paquete hace que el resultado no dependa de como compile la
// herramienta. Es el mismo patron de "package + include" usado en
// ambientes tipo UVM.
//
// USO
//   - Compilar (en este orden):
//       bus_if.sv, bus_mon_pkg.sv, bus_mon_cls_pkg.sv
//     con +incdir/-I apuntando a la carpeta de estos archivos.
//   - NO compilar ademas los 4 archivos de clases por separado: el
//     include guard de cada uno impediria que este paquete los recibiera.
//   - En el env/testbench:  import bus_mon_cls_pkg::*;
//   - Alternativa para herramientas de unidad unica: omitir este
//     archivo y compilar en orden bus_if, bus_mon_pkg, bus_mon_txn_hijo,
//     bus_mon_txn_padre, bus_monitor_hijo, bus_monitor_padre.
//
// El orden de los include importa: cada clase solo ve lo ya declarado.
//======================================================================
`ifndef BUS_MON_CLS_PKG_SV
`define BUS_MON_CLS_PKG_SV

package bus_mon_cls_pkg;

  import bus_mon_pkg::*;

  `include "bus_mon_txn_hijo.sv"
  `include "bus_mon_txn_padre.sv"
  `include "bus_monitor_hijo.sv"
  `include "bus_monitor_padre.sv"

endpackage : bus_mon_cls_pkg

`endif // BUS_MON_CLS_PKG_SV
