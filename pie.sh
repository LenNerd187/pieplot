#!/usr/bin/env bash

# data is expected with title in the first row
# from the second row on: 1 row = 1 slice
# label in first columns and value in second column separated by ';'
# line breaks in label are possible with \n    Example:
# Disk Usage - Data2
# Used:\n 1031 GB;1031567272
# Free:\n 345 GB;345132256

colors[0]="#008DD5"
colors[1]="#B9D7E7"
colors[2]="red"
colors[3]="orange"
colors[4]="yellow"
colors[5]="green"
colors[6]="cyan"
# create slightly darker versions for the pie wall for a better 3d effect
# only works with hexcodes
for color in ${colors[@]}; do
    if [[ $color =~ ^# ]];then
        r=$((16#${color:1:2} - 10))
        g=$((16#${color:3:2} - 10))
        b=$((16#${color:5:2} - 10))
        r=$((r < 0 ? 0 : r))
        g=$((g < 0 ? 0 : g))
        b=$((b < 0 ? 0 : b))
        colors_shadow+=($(printf "#%02X%02X%02X" $r $g $b))
    else
        colors_shadow+=($color)
    fi
done

while read -r line ; do 
    if [ -z "$title" ]; then
        title="$line"
        echo "title: $title" >&2
    else
        label=${line%%;*}
        value=${line#*;}
        if [ -n "$label" ] && [ -n "$value" ]; then
            values+=($value)
            labels+=("$label")
            ((count++))
            ((sum=sum+value))
        fi
    fi
done < "${1:-/dev/stdin}"
echo "found $count values with a sum of $sum" >&2

# gnuplot needs the values normalized, the whole pie has the value of 1
for value in ${values[@]};do
    ratios+=( $( echo "$value / $sum" | bc -l ) )
done

echo "set terminal pngcairo font \"Helvetica,18\" size 800,600"
echo "set output \"out.png\""
printf "set title \"%s\"\n" "$title"

# a:height B:label distance r:radius s:height over ground
echo "a=0.6; B=0.3; r=1.0; s=0.15"
echo "set view 60, 0; set parametric"
echo "set margin 0"
echo "unset border; unset tics; unset key; unset colorbox"
echo "set ticslevel 0"
echo "set urange [0:1]; set vrange [0:1]"
echo "set xrange [-1:1]; set yrange [-1:1]; set zrange [0:3]"
echo "set multiplot"

echo "# draw ground square (currently white because i dont like it)"
echo "set palette model RGB functions 1,1,1"
echo "splot -2+4*u, -2+4*v, 0 w pm3d"

echo "# draw pie shadow"
echo "splot cos(u*2*pi)*v, sin(u*2*pi)*v, 0 w pm3d fillcolor rgb 'dark-grey'"

# draw labels first, otherwise they are invisible (idk why)
echo "# draw labels"
d=${ratios[0]}
for ((j=0;j<count;j++)); do
    printf "set label %d \"%s\" at cos(%g*pi)*B+cos(%g*pi), sin(%g*pi)*B+sin(%g*pi), 0.7+sin(%g*pi)*B+sin(%g*pi) centre\n" $((j+1)) "${labels[j]}" $d $d $d $d $d $d
    d=$( echo "$d+${values[j]}/$sum + ${values[$((j+1))]}/$sum" | bc -l 2>/dev/null)
done

echo "# draw cylinder wall"
d=0.0
for ((j=0;j<count;j++)); do
    printf "set urange [%s:%g]\n" $d $(echo "$d+${ratios[j]}" | bc -l)
    [ "$d" != "1.0" ] && echo "splot cos(u*2*pi)*r, sin(u*2*pi)*r, s+v*a w pm3d fillcolor rgb '${colors_shadow[j]}'"
    d=$( echo "$d+${ratios[j]}" | bc -l)
done

echo "# draw cylinder top"
d=0.0;
for ((j=0;j<count;j++)); do
    printf "set urange [%s:%g]\n" $d $(echo "$d+${ratios[j]}" | bc -l)
    echo "splot cos(u*2*pi)*r*v, sin(u*2*pi)*r*v, s+a w pm3d fillcolor rgb '${colors[j]}'"
    d=$( echo "$d+${ratios[j]}" | bc -l)
done


