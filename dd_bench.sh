#!/usr/bin/env bash

## dd bench script: WRITE/READ testing with multiple dd running in parallel


# destination path
TEST_PATH='./'
# IO block size
BLOCK_SIZE=1M
# IO count for each jobs
IO_COUNT=100
# number of jobs to run in parallel
NUM_JOBS=4
# wait time in seconds between jobs (pause)
WAIT_SEC=5


# usage (help display)
usage() {
  echo
  echo "DD bench script: WRITE/READ testing with multiple dd running in parallel"
  echo
  echo "  Usage: ${0##*/} [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  -d PATH               Destination directory path (default: ./)"
  echo "  -b BLOCK_SIZE         IO block size in bytes (default: 1M)"
  echo "                        Supports dd multiplicative suffixes: b,K,M,G..."
  echo "  -c IO_COUNT           Number of IO to perform per jobs (default: 100)"
  echo "  -n NUM_JOBS           Number of jobs to run in parallel (default: 4)"
  echo
  echo "  -h | --help           This help message"
  echo
}

while [ "$1" != "" ]; do
  case $1 in

    -d | --dest | --destination )
      shift
      TEST_PATH=${1-}
      ;;

    -b | -bs | --block_size )
      shift
      BLOCK_SIZE=${1-}
      ;;

    -c | --count | --io_count )
      shift
      IO_COUNT=${1-}
      ;;

    -n | --num | --num_jobs )
      shift
      NUM_JOBS=${1-}
      ;;

    h | -h | help | --help )
      usage
      exit
      ;;

    * )
      usage 1>&2
      echo "ERROR: Unknown option '${1-}'" 1>&2
      echo 1>&2
      exit 1

  esac
  shift
done


# cleanup on exit (kill dd subprocess & delete tmp files)
clean_exit() {
  echo
  echo "Cleaning jobs on interrupt..."
  killall -n $$ dd 2>/dev/null
  sleep 0.1
  rm -f "${TEST_PATH}/"dd*.tmp
  exit 1
}

# display dd stats every 5s
monitor_dd_stats() {
  # display dd stats every 5s
  sleep 1
  while killall -s USR1 -n $$ dd; do
    sleep 5
    echo "--- $(date +"%FT%T")"
    sleep 0.001
  done
}


# run cleanup on interrupt: ctrl-C or SIGTERM
trap clean_exit SIGINT SIGTERM

# validate vars
if ! which dd &>/dev/null; then
  echo "ERROR: dd utility is required to run this script." 1>&2
  exit 1
fi

if ! [[ -d ${TEST_PATH} && -w ${TEST_PATH} ]]; then
  echo "ERROR: Path '${TEST_PATH}' is not a directory or writable."
  exit 1
fi


# Jobs
echo
echo ">>> Running DD bench: d=${TEST_PATH}  b=${BLOCK_SIZE}  c=${IO_COUNT}  n=${NUM_JOBS}   ($(date +"%FT%T"))"

# WRITE jobs
echo
echo ">> Running WRITE jobs..."
for ((i=1; i <= NUM_JOBS; i++)); do
  (dd if=/dev/zero of="${TEST_PATH}/dd${i}.tmp" bs="${BLOCK_SIZE}" count="${IO_COUNT}" oflag=dsync,noatime iflag=fullblock 2>&1 | sed -nE "s/\\r/\\n/g; /records/!{ s/(.*)/dd-${i}: \1/p }" &)
  sleep 0.1
done
monitor_dd_stats
echo "(waiting ${WAIT_SEC} sec...)"
sleep ${WAIT_SEC}

# READ jobs
echo
echo ">> Running READ jobs..."
for ((i=1; i <= NUM_JOBS; i++)); do
  (dd if="${TEST_PATH}/dd${i}.tmp" of=/dev/null bs="${BLOCK_SIZE}" count="${IO_COUNT}" iflag=dsync,noatime,nocache 2>&1 | sed -nE "s/\\r/\\n/g; /records/!{ s/(.*)/dd-${i}: \1/p }" &)
  sleep 0.1
done
monitor_dd_stats

# wait any subprocess & remove tmp files
echo
wait
rm -f "${TEST_PATH}/"dd*.tmp
echo "All jobs completed."
