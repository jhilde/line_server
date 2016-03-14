if [ "$1" == "" ]; then
    echo "usage: run.sh file [cache_strategy NONE | RR | MRU | LRU]"
else
    if [ "$2" == "" ]; then
    	ruby line_server.rb $1 NONE
    else
    	ruby line_server.rb $1 $2
    fi
fi
