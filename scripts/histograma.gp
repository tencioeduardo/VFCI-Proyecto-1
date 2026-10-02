# ─────────────────────────────────────────────────────────────────
# histogram.gp — Histograma de retardos del CSV del Checker
#
# Uso:
#   gnuplot -e "csv_file='packets.csv'; png_file='delay_histogram.png'; bin_width=10" \
#           scripts/histogram.gp
#
# Columnas del CSV (1-indexed):
#   1=src  2=dst  3=tx_time_ns  4=rx_time_ns  5=delay_ns  6=kind
# ─────────────────────────────────────────────────────────────────

if (!exists("csv_file"))  csv_file  = "packets.csv"
if (!exists("png_file"))  png_file  = "delay_histogram.png"
if (!exists("bin_width")) bin_width = 10

set datafile separator ","
set terminal pngcairo size 1200,700 enhanced font 'Verdana,11'
set output png_file
set key off
set grid ytics
set style fill solid 0.7 border -1
set boxwidth bin_width * 0.85

# ── Estadísticas (salta la cabecera con every ::1)
stats csv_file every ::1 using 5 nooutput

if (STATS_records == 0) {
    set title "Histograma de retardos — CSV vacío"
    set xlabel "Retardo (ns)"
    set ylabel "Número de paquetes"
    plot 0 notitle
    print "ADVERTENCIA: no hay filas en el CSV."
} else {
    mean = STATS_mean
    max_ = STATS_max
    n    = STATS_records
    set title sprintf("Histograma de retardos (N=%d, media=%.2f ns, max=%.2f ns, bin=%.0f ns)", \
                      n, mean, max_, bin_width)
    set xlabel "Retardo (ns)"
    set ylabel "Número de paquetes"
    bin(x,w) = w * floor(x/w)
    plot csv_file every ::1 using (bin($5,bin_width)):(1.0) \
         smooth freq with boxes lc rgb "#3060A0"
    print sprintf("N=%d  min=%.2f  max=%.2f  mean=%.2f  stddev=%.2f", \
                  STATS_records, STATS_min, STATS_max, STATS_mean, STATS_stddev)
}

set output