set hive.enforce.bucketing=true;
set hive.enforce.sorting=true;
set hive.exec.dynamic.partition.mode=nonstrict;
set hive.exec.max.dynamic.partitions.pernode=100000;
set hive.exec.max.dynamic.partitions=100000;
set hive.exec.max.created.files=1000000;
set hive.exec.parallel=true;
set hive.exec.reducers.max=2000;
set hive.stats.autogather=true;

set mapred.job.reduce.input.buffer.percent=0.0;
set mapreduce.input.fileinputformat.split.minsizee=240000000;
set mapreduce.input.fileinputformat.split.minsize.per.node=240000000;
set mapreduce.input.fileinputformat.split.minsize.per.rack=240000000;

set mapreduce.map.java.opts=-Xmx9728m;
set mapreduce.reduce.java.opts=-Xmx9728m;
set mapreduce.map.memory.mb=10752;
set mapreduce.reduce.memory.mb=10752;
set io.sort.mb=1228;

set hive.exec.orc.default.buffer.size=32768;
set hive.optimize.sort.dynamic.partition=true;
set parquet.memory.pool.ratio=0.3;

