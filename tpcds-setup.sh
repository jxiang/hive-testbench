#!/bin/bash
set -x
function usage {
	echo "Usage: tpcds-setup.sh scale_factor [temp_directory]"
	exit 1
}

function runcommand {
  $1
}

if [ ! -f tpcds-gen/target/tpcds-gen-1.0-SNAPSHOT.jar ]; then
	echo "Please build the data generator with ./tpcds-build.sh first"
	exit 1
fi
which hive > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Script must be run where Hive is installed"
	exit 1
fi

# Tables in the TPC-DS schema.
DIMS="date_dim time_dim item customer customer_demographics household_demographics customer_address store promotion warehouse ship_mode reason income_band call_center web_page catalog_page web_site"
FACTS="store_sales store_returns web_sales web_returns catalog_sales catalog_returns inventory"

# Get the parameters.
SCALE=$1
DIR=$2
if [ "X$BUCKET_DATA" != "X" ]; then
	BUCKETS=13
	RETURN_BUCKETS=13
else
	BUCKETS=1
	RETURN_BUCKETS=1
fi
if [ "X$DEBUG_SCRIPT" != "X" ]; then
	set -x
fi

# Sanity checking.
if [ X"$SCALE" = "X" ]; then
	usage
fi
if [ X"$DIR" = "X" ]; then
	DIR=/data/hive/warehouse/tpcds_text_${SCALE}.db
fi
if [ $SCALE -eq 1 ]; then
	echo "Scale factor must be greater than 1"
	exit 1
fi

# Do the actual data load.
hdfs dfs -ls ${DIR}/ > /dev/null
if [ $? -ne 0 ]; then
  echo "Dropping tpcds_text_${SCALE} if exists"
  hive -e "drop database if exists tpcds_text_${SCALE} cascade"

	echo "Generating data at scale factor $SCALE."
  pushd tpcds-gen
	if ! hadoop jar target/*.jar -d ${DIR}/ -s ${SCALE}
  then
    echo "Data generation failed, exiting."
    exit 1
  fi
  popd
  echo "TPC-DS text data generation complete."

  # Create the text/flat tables as external tables. These will be later be converted to ORCFile.
  echo "Loading text data into external tables."
  runcommand "hive -i settings/load-flat.sql -f ddl-tpcds/text/alltables.sql -d DB=tpcds_text_${SCALE}"
fi

# Create the partitioned and bucketed tables.
if [ "X$FORMAT" = "X" ]; then
	FORMAT=orc
fi
DATABASE=tpcds_bin_partitioned_${FORMAT}_${SCALE}
hdfs dfs -ls /data/hive/warehouse/${DATABASE}.db/ > /dev/null
if [ $? -ne 0 ]; then
  echo "Dropping ${DATABASE} if exists"
  hive -e "drop database if exists ${DATABASE} cascade"

  i=1
  total=24
  for t in ${FACTS}
  do
	echo "Optimizing table $t ($i/$total)."
	COMMAND="hive -i settings/load-partitioned.sql -f ddl-tpcds/bin_partitioned/${t}.sql \
	    -d DB=tpcds_bin_partitioned_${FORMAT}_${SCALE} \
	    -d SOURCE=tpcds_text_${SCALE} -d BUCKETS=${BUCKETS} \
	    -d RETURN_BUCKETS=${RETURN_BUCKETS} -d FILE=${FORMAT}"
	runcommand "$COMMAND"
	if [ $? -ne 0 ]; then
		echo "Command failed, try 'export DEBUG_SCRIPT=ON' and re-running"
		exit 1
	fi
	i=`expr $i + 1`
  done

  # Populate the smaller tables.
  for t in ${DIMS}
  do
	echo "Optimizing table $t ($i/$total)."
	COMMAND="hive -i settings/load-partitioned.sql -f ddl-tpcds/bin_partitioned/${t}.sql \
	    -d DB=tpcds_bin_partitioned_${FORMAT}_${SCALE} -d SOURCE=tpcds_text_${SCALE} \
	    -d FILE=${FORMAT}"
	runcommand "$COMMAND"
	if [ $? -ne 0 ]; then
		echo "Command failed, try 'export DEBUG_SCRIPT=ON' and re-running"
		exit 1
	fi
	i=`expr $i + 1`
  done

  echo "Data loaded into database ${DATABASE}."
fi
