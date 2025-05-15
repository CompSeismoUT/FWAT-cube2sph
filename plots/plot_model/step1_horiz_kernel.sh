#!/bin/bash
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=40
#SBATCH --time=00:12:59
#SBATCH --job-name step0
#SBATCH --output=step0.txt 
#SBATCH --mem=0
#SBATCH --partition=debug

# script runs mesher,database generation and solver
# using this example setup
#
###################################################
#module load NiaEnv/2019b
specfem_dir="${HOME}/specfem3d-cube2sph/"
cub2sph_dir=$specfem_dir/utils/cube2sph/
NPROC=8
mkdir -p grdfolder pics profiles

# run index
run_indx=`seq 0 0`
param_set="dbeta"
#param_set="hess_kernel"
#param_set="vp vs rho"

set -e 
# interpolate
module load intel 
#for param in vp vs rho;do 
for param in $param_set ;do 
for name in B1 B2;  do
  for iter in $run_indx;
  do 
      ii=`printf %02d $iter`
      jj=`echo "$iter" |bc -l`
      jj=`printf %02d $jj`
      #$specfem_dir/bin/xcreate_slice $param ../DATABASES_MPI/ ../DATABASES_MPI/ input/prof$name.txt input/prof$name.loc $param.$name.out .false.
      python ../../fwatlib/optimize/bin2h5.py ../../optimize/SUM_KERNELS_M$jj/ $param $NPROC 0
      $specfem_dir/bin/xcreate_slice $param  ../../optimize/SUM_KERNELS_M$ii/ ../../DATABASES_MPI/  \
        input/prof$name.txt input/prof$name.loc $param.$name.$ii.out .false.
      \rm ../../optimize/SUM_KERNELS_M$jj/*$param.bin
  done
done
done

# generate_grd
module load gcc gmt-6.0.0
for param in $param_set;do 
for name in B1 B2;  do
  # get grd file and plot
  info=`gmt gmtinfo -C input/prof${name}.txt`
  xmin=`echo $info | awk '{print $7}'`
  xmax=`echo $info | awk '{print $8}'`
  ymin=`echo $info | awk '{print $9}'`
  ymax=`echo $info | awk '{print $10}'`

  bounds=-R$xmin/$xmax/$ymin/$ymax 
  proj=-JM12c
  dx=`echo "$xmin $xmax" | awk '{print (-$1 + $2) / 127.}'`
  dy=`echo "$ymin $ymax" | awk '{print (-$1 + $2) / 127.}'`

  for iter in $run_indx; 
  do 
      jj=`printf %02d $iter`
      echo $jj 

      awk '{print $4,$5}' input/prof$name.txt > tmp.1 
      info=`gmt gmtinfo -C $param.$name.$jj.out`
      echo $info
      vmax=`echo $info |awk '{print $2}'`
      vmin=`echo $info |awk '{print $1}'`
      vmax=`python -c "print(max(abs($vmin),abs($vmax)))"` 
      awk -v a=$vmax '{print $1/a}' $param.$name.$jj.out > tmp.2 
      paste tmp.1 tmp.2 > tmp.3 

      # convert txt to grd
      gmt surface tmp.3 -Ggrdfolder/$param.iter$jj.prof$name.grd -I$dx/$dz $bounds
      mv tmp.3 profiles/$param.iter$jj.prof$name
      \rm tmp.1 tmp.2 $param.$name.$jj.out 
      gmt grdinfo -C grdfolder/$param.iter$jj.prof$name.grd
  done

done
done