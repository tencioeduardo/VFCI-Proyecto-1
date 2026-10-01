//======================================================================
// Archivo: tb/bus_includes.sv
// Descripción: Lista maestra de compilación para el testbench.
//======================================================================

`ifndef BUS_INCLUDES_SV
`define BUS_INCLUDES_SV

// ── Clases de configuración
`include "bus_config.sv"

// ── Interfaces físicas
`include "bus_if.sv"

// ── Objetos de datos y transacciones
`include "trans_bus.sv"
`include "instruc_gen.sv"
`include "order_test.sv"

// ── Componentes transactores (Hijos)
`include "Driver_son.sv"
`include "Monitor_son.sv"

// ── Componentes Controladores (Padres)
`include "Driver_controller.sv"
`include "Monitor_controller.sv"

// ── Componentes Controladores
`include "scoreboard.sv"
`include "Checker.sv"
`include "Agente.sv"
`include "Generador.sv"

// ── Ambiente de pruebas
`include "Ambiente.sv"

// ── Pruebas
`include "test.sv"

// ── Diseño Bajo Prueba (DUT) y Wrapper (ubicados en la carpeta src/)
`include "../src/Library.sv"
`include "../src/design.sv"

`endif // BUS_INCLUDES_SV
