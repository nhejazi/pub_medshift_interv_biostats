#!/bin/bash
# Job name:
#SBATCH --job-name=medshift_interv_sims
#
# Working directory:
#SBATCH --chdir=/global/home/users/nhejazi/
#
# Account:
#SBATCH --account=co_biostat
#
# Quality of Service:
#SBATCH --qos=biostat_savio3_normal
#
# Partition:
#SBATCH --partition=savio3
#
# Processors (1 node = 20 cores):
#SBATCH --nodes=1
#SBATCH --exclusive
#
# Wall clock limit ('0' for unlimited):
#SBATCH --time=96:00:00
#
# Mail type:
#SBATCH --mail-type=all
#
# Mail user:
#SBATCH --mail-user=nhejazi@berkeley.edu
#
# Job output:
#SBATCH --output=slurm.out
#SBATCH --error=slurm.out
#
## Command(s) to run:
export TMPDIR='/global/scratch/nhejazi/rtmp'  # resolve update issues for compiled packages as per https://github.com/r-lib/devtools/issues/32
module unload gcc/6.3.0
module load gcc/7.4.0 cmake/3.22.0 r/4.0.3 r-packages/default
cd ~/medshift_interv_meta/simulations/


R CMD BATCH --no-save --no-restore --vanilla \
  R/03_run_simulation.R logs/run_simulation_$(date +"%Y%m%d").Rout
