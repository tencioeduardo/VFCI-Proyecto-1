#=======================================================================
# Makefile - Proyecto de Verificación Funcional (Usando VCS)
#-----------------------------------------------------------------------
#   make comp               Compila el diseño y el testbench
#   make run                Ejecuta la simulación con valores por defecto
#   make run_csv            Ejecuta la simulación generando el CSV
#   make plot               Genera el histograma desde el CSV existente
#   make replot             Re-plot del histograma (cambiar BIN_WIDTH)
#   make all                run_csv + plot
#   make clean              Elimina archivos temporales de compilación
#=======================================================================

VCS      = vcs
SIMV     = ./simv


# --- Parámetro estructural (requiere recompilación si cambia)
PCKG_SZ        ?= 16


# --- Parámetros de control general del test
SEED           ?= automatic
TIMEOUT        ?= 10000
DRAIN_CYCLES   ?= 500


# --- Parámetros de campos aleatorizables
DRVRS                  ?= 4
WT_DESTINO_VALIDO      ?= 70
WT_DESTINO_INVALIDO    ?= 20
WT_BROADCAST           ?= 10
MIN_DELAY              ?= 0
MAX_DELAY              ?= 5
PAYLOAD_MIN            ?= 0
PAYLOAD_MAX            ?= 255

# --- Parámetros de escenarios dirigidos del test
BROADCAST_ORIGEN     ?= 0
ACAPARADOR_ORIGEN    ?= 1
AUTOENVIO_ORIGEN     ?= 2
ACAPARADOR_CANTIDAD  ?= 7
N_SOAK               ?= 15
SOAK_DELAY           ?= 2


# --- Parámetros del reporte CSV y del histograma
CSV_OUT        ?= packets.csv
CSV_PNG        ?= delay_histogram.png
BIN_WIDTH      ?= 10


# --- Opción de compilación
VCS_OPTS = -full64 -sverilog -timescale=1ns/1ps \
           -debug_access+all -assert svaext \
           +incdir+../tb +incdir+../src \
           +define+PCKG_SZ=$(PCKG_SZ) \
           -top tb_top \
           ../tb/bus_includes.sv \
           ../tb/top_tb.sv \
           -o simv


 # --- Opciones de ejecución
ifeq ($(SEED),automatic)
    RUN_OPTS = +ntb_random_seed_automatic \
               +timeout=$(TIMEOUT) \
               +drain_cycles=$(DRAIN_CYCLES) \
               +drvrs=$(DRVRS) \
               +wt_destino_valido=$(WT_DESTINO_VALIDO) \
               +wt_destino_invalido=$(WT_DESTINO_INVALIDO) \
               +wt_broadcast=$(WT_BROADCAST) \
               +min_delay=$(MIN_DELAY) \
               +max_delay=$(MAX_DELAY) \
               +payload_min=$(PAYLOAD_MIN) \
               +payload_max=$(PAYLOAD_MAX) \
               +broadcast_origen=$(BROADCAST_ORIGEN) \
               +acaparador_origen=$(ACAPARADOR_ORIGEN) \
               +autoenvio_origen=$(AUTOENVIO_ORIGEN) \
               +acaparador_cantidad=$(ACAPARADOR_CANTIDAD) \
               +n_soak=$(N_SOAK) \
               +soak_delay=$(SOAK_DELAY)
else
    RUN_OPTS = +ntb_random_seed=$(SEED) \
               +timeout=$(TIMEOUT) \
               +drain_cycles=$(DRAIN_CYCLES) \
               +drvrs=$(DRVRS) \
               +wt_destino_valido=$(WT_DESTINO_VALIDO) \
               +wt_destino_invalido=$(WT_DESTINO_INVALIDO) \
               +wt_broadcast=$(WT_BROADCAST) \
               +min_delay=$(MIN_DELAY) \
               +max_delay=$(MAX_DELAY) \
               +payload_min=$(PAYLOAD_MIN) \
               +payload_max=$(PAYLOAD_MAX) \
               +broadcast_origen=$(BROADCAST_ORIGEN) \
               +acaparador_origen=$(ACAPARADOR_ORIGEN) \
               +autoenvio_origen=$(AUTOENVIO_ORIGEN) \
               +acaparador_cantidad=$(ACAPARADOR_CANTIDAD) \
               +n_soak=$(N_SOAK) \
               +soak_delay=$(SOAK_DELAY)
endif

# --- Plusarg del Checker: común a ambas ramas del ifeq
RUN_OPTS += +csv_out=$(CSV_OUT)

# --- Reglas para uso del Makefile
comp:
	$(VCS) $(VCS_OPTS) -l comp.log


run: comp
	$(SIMV) $(RUN_OPTS) -l sim.log


# --- Simulación generando CSV
run_csv: comp
	$(SIMV) $(RUN_OPTS) -l sim.log
	@echo "[MAKE] CSV generado: $(CSV_OUT)"


# --- Genera el histograma desde el CSV existente
plot:
	gnuplot -e "csv_file='$(CSV_OUT)'; png_file='$(CSV_PNG)'; bin_width=$(BIN_WIDTH)" \
	        scripts/histogram.gp
	@echo "[MAKE] Histograma: $(CSV_PNG)"


# --- Re-plot sin re-simular (cambiar BIN_WIDTH: make replot BIN_WIDTH=5)
replot:
	gnuplot -e "csv_file='$(CSV_OUT)'; png_file='$(CSV_PNG)'; bin_width=$(BIN_WIDTH)" \
	        scripts/histogram.gp


# --- Flujo completo
all: run_csv plot


clean:
	rm -rf simv* csrc *.log *.vpd *.vdb urgReport DVEfiles ucli.key .vcs* *.csv *.png

.PHONY: comp run run_csv plot replot all clean