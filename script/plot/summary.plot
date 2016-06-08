set term png 
set output "results-CONS-1dcs-8nodes-2benchNodes/summary_overall.png"
set title "Throughput-1-DCs-8-Nodes-2-Bench-Nodes-Branch-CONS"
#set xtics ("99.99(.01)" 1, "99(1)" 2, "90(10)" 3, "75(25)" 4, "50(50)" 5, "1(99)" 6)
set xtics ("99(1)" 1, "90(10)" 2, "75(25)" 3, "50(50)" 4)
#set xtics rotate by 90 right
set tics out
#set logscale y
set xlabel "Percentage of Read(Update) Operations"
set ylabel "Operations/Second"
plot "plots" using 1:2 title 'Total' with linespoints, \
"plots" using 1:3 title 'Successful' with linespoints, \
"plots" using 1:4 title 'Error' with linespoints
