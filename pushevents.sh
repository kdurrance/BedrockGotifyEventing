## SETTINGS #############################
bdspath=/Users/karldurrance/Documents/docker/minecraftbds/data/
gotifytoken=AnlT4--knUxhDSD
gotifyserver=http://192.168.0.100:8383
dockercontainer=minecraftbds
#########################################

## make sure our state file exists for last line in log
if [ ! -f ${bdspath}lastevent.txt ]; then  
    /usr/local/bin/docker logs --tail 1 ${dockercontainer} > ${bdspath}lastevent.txt	
fi

push_event () {
	curl -X POST "${gotifyserver}/message?token=${gotifytoken}" -F "title=$TITLE" -F "message=$MESSAGE" -F "priority=5"
}

while :
do

	## compare the last line to the lastevent state file
	lastevent=`cat ${bdspath}lastevent.txt` 
	lastlogline=`/usr/local/bin/docker logs --tail 1 ${dockercontainer}`

	if [ "$lastevent" == "$lastlogline" ]; then 
    		echo 'Nothing to do, exiting.' 
	else
    		# new event, lets check if we should push the event to Gotify

   		#server started
    		if [[ "$lastlogline" == *"Server started."* ]]; then
        		VERSION=`/usr/local/bin/docker logs --tail 20 ${dockercontainer} | grep "INFO] Version" | awk {'print $5'}`
			TITLE="Server started"
        		MESSAGE="Bedrock Dedicated Server v$VERSION"
        		push_event
    		fi

    		#login
    		if [[ "$lastlogline" == *"Player connected:"* ]]; then
        		USERNAME=`echo $lastlogline | awk '{print $6}'`
			XUID=`echo $lastlogline | awk '{print $8}'`
        		TITLE="${USERNAME%?} joined the game"
        		MESSAGE="XUID=$XUID"
			# save the login time in seconds for the user into a state file
			date +%s > ${bdspath}"${USERNAME%?}".txt
        		push_event
    		fi

    		#logout
    		if [[ "$lastlogline" == *"Player disconnected:"* ]]; then
        		USERNAME=`echo $lastlogline | awk '{print $6}'`
        		XUID=`echo $lastlogline | awk '{print $8}'`
        		TITLE="${USERNAME%?} left the game"
			# calculate the time online
			if [ -f ${bdspath}"${USERNAME%?}".txt ]; then
    				logintime=`cat ${bdspath}"${USERNAME%?}".txt`
                        	nowtime=`date +%s`
                        	timeonline=$(($nowtime-$logintime))
                        	minutes=$((timeonline / 60))
                        	seconds=$((timeonline % 60))
                        	MESSAGE="Time online: $minutes minutes and $seconds seconds"
				 # cleanup the user state file
                        	rm ${bdspath}"${USERNAME%?}".txt
                        	push_event
			else
				MESSAGE="Time online: unknown error"
				push_event
			fi
    		fi

    		# update the state file
    		/usr/local/bin/docker logs --tail 1 ${dockercontainer} > ${bdspath}lastevent.txt
	fi

	# sleep every iteration
	sleep 5
done
