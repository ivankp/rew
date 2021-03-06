#!/bin/bash

db=plots.db

if [ ! -f $db ]; then

sqlite3 $db "create table plots (
  particle TEXT,
  njets INTEGER,
  energy TEXT,
  part TEXT,
  scales TEXT,
  jalg TEXT,
  pdf TEXT,
  vbf TEXT,
  maa TEXT,
  eta TEXT
);"

#ls ~/disk2/hist/plots | sed 's/\_/\", \"/g;s/\.pdf/\" ],/;s/^/[ \"/' | column -t

for f in `ls ~/disk2/hist/plots | sed 's/\.pdf//'`; do

  arr=(`echo $f | tr '_' ' '`)
  pj=(`echo ${arr[0]} | sed 's/\([a-zA-Z]*\)\([0-9]*\)j/\1 \2/'`)

  vbf="none"
  maa="none"
  eta="4.4"

  for i in {6..8}; do
    for cut in "VBF" "MAA" "eta"; do
      match=`echo ${arr[i]} | sed -n "s/^$cut//p"`
      if [ "$match" ]; then
        if [ "$cut" == "VBF" ]; then
          vbf=$match
        elif [ "$cut" == "MAA" ]; then
          maa=$match
        elif [ "$cut" == "eta" ]; then
          eta=$match
        fi
      fi
    done
  done

  sqlite3 $db "insert into plots
    (particle,njets,energy,part,scales,jalg,pdf,vbf,maa,eta)
    values
    ('${pj[0]}','${pj[1]}','${arr[1]}','${arr[2]}','${arr[3]}','${arr[4]}','${arr[5]}','$vbf','$maa','$eta');"

  printf '.'

done
echo ""

fi

sqlite3 -separator ' '  $db "select particle, njets, energy, scales, jalg, pdf, vbf, maa, eta, part from plots
  order by
    CASE WHEN particle = 'H'  THEN 0
         WHEN particle = 'AA' THEN 1 END,
    njets,
    CASE WHEN energy =  '7TeV' THEN  7
         WHEN energy =  '8TeV' THEN  8
         WHEN energy = '13TeV' THEN 13 END,
    scales,
    jalg,
    CASE WHEN vbf = 'none' THEN 0 
         WHEN vbf = 'hardest' THEN 1 
         WHEN vbf = 'any' THEN 2 END,
    CASE WHEN maa = 'none' THEN 0 ELSE 1 END,
    CASE WHEN part like 'B%' THEN 0 
         WHEN part like 'RS%' THEN 1 
         WHEN part like 'V%' THEN 2
         WHEN part like 'I%' THEN 3
         WHEN part = 'NLO' THEN 4
         WHEN part = 'ES' THEN 5 END
" | sed 's/ /\", \"/g;s/^/[ \"/;s/$/\" ],/' | column -t

