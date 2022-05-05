echo "Make sure that Redis is installed aka env vars are set"
echo "Start at $(date)"
FILE=$1
stats_collecting_cycle=$2
maxmemory=$3

if [ -z "$FILE" ] || [ -z "$stats_collecting_cycle" ] || [ -z "$maxmemory" ]
then
    echo "Require input file name and stats_collecting_cycle value"
    echo "bash ./run_banchmark <filename> <stats_collecting_cycle_value> <maxmemory>"
    echo "bash ./run_banchmark ./hm_1.csv 5000 4M"
    exit
else
    echo $FILE
fi

redis-server&

REDIS_SERVER_PID=$!
sleep 5

# Config max-memory to test replacement policy
redis-cli config set maxmemory $maxmemory
redis-cli config set maxmemory-policy allkeys-lru

# Process csv file
# Timestamp,Hostname,DiskNumber,Type,Offset,Size,ResponseTime

# ulimit -s 100000000000

ch='.'
OLDIFS=$IFS
IFS=','
log_file="info_$(date +"%Y%m%d_%H%M%S").txt"
linecount=0
touch $log_file
while read timestamp hostname disk type offset size responsetime
do
    # echo "timestamp ${timestamp}"
    # echo "type ${type}"
    # echo "response_time #{responsetime}"
    # echo --------------------------------
    # val=`eval printf "${ch}%.0s" {1..$size}`

    size=200
    if [ "$type" = "Write" ];
    then
	# echo "write ${type}"
    	# echo $val
	# echo "set ${offset} ${val}"
	dd if=/dev/urandom of=input.txt bs=${size} count=1 status=none
    	redis-cli -x set $offset < ./input.txt >/dev/null
    else
	# echo "read ${type}"
	# read
	signal=`redis-cli get $offset`
	if [ -z "$signal" ]
	then
	    echo "miss"
	    dd if=/dev/urandom of=input.txt bs=${size} count=1 status=none
	    redis-cli set $offset < ./input.txt >/dev/null
	fi
    fi

    # Print every 5000th reference
    if [ "$((linecount%$stats_collecting_cycle))" -eq "0" ]
    then
	redis-cli info >> $log_file
    fi
    ((linecount++))
done < $FILE
IFS=$OLDIFS
kill $REDIS_SERVER_PID

echo "End at ${date}"
