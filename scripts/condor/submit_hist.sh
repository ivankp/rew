#!/bin/bash

exe=/home/ivanp/work/bh_analysis/bin/hist_Hjets
dir=/msu/data/t3work2/ivanp
out=$dir/condor
histdir=$dir/hist/raw

group_size=50

mkdir -p $out
mkdir -p $histdir

db="$dir/ntuples.db"

#####################################################################

#MAA="115:135"

for jalg in AntiKt4
do

for VBF in none # hardest any
do

for set in `sqlite3 $db "
  SELECT distinct particle, njets, energy, part, wt.scales, wt.pdf, dset
  FROM bh
  JOIN wt ON bh.id = wt.bh_id
  WHERE particle = 'H' and energy = 13 and wt.pdf = 'CT10nlo' and wt.scales = 'HT2-unc' and dset = 1
"`; do

arr=(`echo $set | tr '|' ' '`)
arr[2]=`printf "%.0f" ${arr[2]}` # round real-valued energy
base="${arr[0]}${arr[1]}j_${arr[2]}TeV_${arr[3]}_${arr[4]}_${jalg}_${arr[5]}"

#base=$base"_mtop"

if [ "$VBF" != "none" ]; then
  base=$base"_VBF$VBF"
fi

if [ "$MAA" ]; then
  base=$base"_MAA"`echo $MAA | tr ':' '-'`
fi

sql="
  FROM bh
  JOIN wt ON bh.id = wt.bh_id
  WHERE particle='${arr[0]}' and njets=${arr[1]} and
        energy=${arr[2]} and part='${arr[3]}' and
        wt.scales='${arr[4]}' and wt.pdf='${arr[5]}' and
        dset=${arr[6]}
"

min=`sqlite3 $db "SELECT min(sid) $sql"`
max=`sqlite3 $db "SELECT max(sid) $sql"`

(( begin = min     ))
(( end   = min - 1 ))

while true; do # loop over sid subgroup

(( begin = end + 1 ))
(( end = begin + group_size - 1 ))

if [ `python -c "print ($max-$end) < ($group_size*0.5)"` == "True" ]; then
  (( end = max ))
fi

name="${base}_${begin}-${end}"

files="`sqlite3 $db "
  SELECT bh.dir, bh.file, wt.dir, wt.file $sql 
  and sid >= $begin and sid <= $end
" | sed 's/\(.*\)|\(.*\)|\(.*\)|\(.*\)/--bh=\1\/\2 --wt=\3\/\4/'`"

if [ -z "$files" ]; then
  continue
fi

echo $name

# Form arguments

args="-o $histdir/$name.root -j ${arr[1]} -c $jalg --cache=500 --tree-name=\"t3\""

if [ "${arr[0]}" == "AA" ]; then
  args="$args --AA"

  if [ "$MAA" ]; then
    args="$args --AA-mass-cut=$MAA"
  fi
fi

if [ "${arr[0]}" == "A" ]; then
  if [ "$VBF" != "none" ]; then
    echo $exe does not implement VBF cuts
    exit 1
  fi
else
  args="$args --VBF=$VBF"
fi

args="$args $files"

# Form temporary wrapper script

echo "#!/bin/bash" > $out/$name.sh
echo 'LD_LIBRARY_PATH=/home/ivanp/local/gcc/lib64:/home/ivanp/local/lib:$LD_LIBRARY_PATH' >> $out/$name.sh
echo 'echo $LD_LIBRARY_PATH' >> $out/$name.sh
echo "ldd $exe" >> $out/$name.sh
echo $exe $args >> $out/$name.sh
chmod +x $out/$name.sh

# Form condor script

echo "
Universe   = vanilla
Executable = $out/$name.sh
Error      = $out/$name.err
Output     = $out/$name.out
Log        = $out/$name.log
getenv = True
Queue
" | condor_submit - > /dev/null

if [ $end -ge $max ]; then break; fi

done

done
done
done

echo 'DONE!'

# notification = Complete
# notify_user  = ivanp@msu.edu


