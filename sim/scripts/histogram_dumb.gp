# ─────────────────────────────────────────────────────────────────
# histogram_dumb.gp — Histograma de retardos en ASCII (terminal dumb)
# ─────────────────────────────────────────────────────────────────

if (!exists("csv_file"))  csv_file  = "packets.csv"
if (!exists("bin_width")) bin_width = 10

set datafile separator ","
set terminal dumb size 100,30
set key off
set grid ytics

stats csv_file every ::1 using 5 nooutput

if (STATS_records == 0) {
    print "ADVERTENCIA: no hay filas en el CSV."
} else {
    set title sprintf("Histograma retardos (N=%d, media=%.2f ns, max=%.2f ns, bin=%.0f ns)", \
                      STATS_records, STATS_mean, STATS_max, bin_width)
    set xlabel "Retardo (ns)"
    set ylabel "Paquetes"

    bin(x,w) = w * floor(x/w)
    plot csv_file every ::1 using (bin($5,bin_width)):(1.0) \
         smooth freq with boxes

    print ""
    print sprintf("N=%d  min=%.2f  max=%.2f  mean=%.2f  stddev=%.2f", \
                  STATS_records, STATS_min, STATS_max, STATS_mean, STATS_stddev)
}
