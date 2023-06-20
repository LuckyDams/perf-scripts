#!/usr/bin/env bash

## fio bench script


now=$(date +"%F_%H-%M-%S")
TEST_PATH='/data/tmp'
LOG_FILE="fio-bench_${now}.log"

## FIO settings for sequential job
# IO block size
seq_block_size=1m
# IO queue depth
seq_io_depth=8
# number of jobs to run in parallel
seq_num_jobs=1
# total size to use for a job
seq_job_size=8g
# amount of IO to perform during a job in size unit or % (use job_size if empty)
seq_job_io_size=
# maximum time to run the test
seq_runtime=30s

## FIO settings for random job
rand_block_size=4k
rand_io_depth=1
rand_num_jobs=8
rand_job_size=8g
rand_job_io_size=
rand_runtime=30s

# wait time in seconds between jobs (pause)
wait_sec=5

# validate vars
if ! which fio &>/dev/null; then
  echo "ERROR: FIO tool is required to run this script." 1>&2
  exit 1
fi

if ! [[ -d ${TEST_PATH} && -w ${TEST_PATH} ]]; then
  echo "ERROR: Path '${TEST_PATH}' is not a directory or writable."
  exit 1
fi
TEST_FILE="${TEST_PATH}/fio-bench.tmp"

[[ -n ${seq_job_io_size} ]] || seq_job_io_size="${seq_job_size}"
[[ -n ${rand_job_io_size} ]] || rand_job_io_size="${rand_job_size}"


# Jobs
echo | tee -a "${LOG_FILE}"
echo ">>> Running FIO bench on: ${TEST_PATH}   (${now})" | tee "${LOG_FILE}"
echo >> "${LOG_FILE}"


# start jobs
echo "Running jobs..." | tee -a "${LOG_FILE}"

echo --- | tee -a "${LOG_FILE}"
fio --name SEQ_WRITE --eta=always --eta-newline=5s --filename="${TEST_FILE}" --rw=write --size="${seq_job_size}" --io_size="${seq_job_io_size}" --blocksize="${seq_block_size}" --ioengine=libaio --fsync=10000 --iodepth="${seq_io_depth}" --direct=1 --numjobs="${seq_num_jobs}" --runtime="${seq_runtime}" --group_reporting | tee -a "${LOG_FILE}"
sleep ${wait_sec}

echo --- | tee -a "${LOG_FILE}"
fio --name SEQ_READ --eta=always --eta-newline=5s --filename="${TEST_FILE}" --rw=read --size="${seq_job_size}" --io_size="${seq_job_io_size}" --blocksize="${seq_block_size}" --ioengine=libaio --fsync=10000 --iodepth="${seq_io_depth}" --direct=1 --numjobs="${seq_num_jobs}" --runtime="${seq_runtime}" --group_reporting | tee -a "${LOG_FILE}"
sleep ${wait_sec}

echo --- | tee -a "${LOG_FILE}"
fio --name RAND_WRITE --eta=always --eta-newline=5s --filename="${TEST_FILE}" --rw=randwrite --size="${rand_job_size}" --io_size="${rand_job_io_size}" --blocksize="${rand_block_size}" --ioengine=libaio --fsync=1 --iodepth="${rand_io_depth}" --direct=1 --numjobs="${rand_num_jobs}" --runtime="${rand_runtime}" --group_reporting | tee -a "${LOG_FILE}"
sleep ${wait_sec}

echo --- | tee -a "${LOG_FILE}"
fio --name RAND_READ --eta=always --eta-newline=5s --filename="${TEST_FILE}" --rw=randread --size="${rand_job_size}" --io_size="${rand_job_io_size}" --blocksize="${rand_block_size}" --ioengine=libaio --fsync=1 --iodepth="${rand_io_depth}" --direct=1 --numjobs="${rand_num_jobs}" --runtime="${rand_runtime}" --group_reporting | tee -a "${LOG_FILE}"
sleep ${wait_sec}

echo --- | tee -a "${LOG_FILE}"
fio --name RAND_MIX --eta=always --eta-newline=5s --filename="${TEST_FILE}" --rw=randrw --size="${rand_job_size}" --io_size="${rand_job_io_size}" --blocksize="${rand_block_size}" --ioengine=libaio --fsync=1 --iodepth="${rand_io_depth}" --direct=1 --numjobs="${rand_num_jobs}" --runtime="${rand_runtime}" --group_reporting | tee -a "${LOG_FILE}"
echo --- | tee -a "${LOG_FILE}"


rm -f ${TEST_FILE}
echo "All jobs completed." | tee -a "${LOG_FILE}"
