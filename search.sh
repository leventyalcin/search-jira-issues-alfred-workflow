#!/bin/sh

# Get Alfreds query parameter from CLI arguments:
query=$1

# Read config.json & prepare:
config=`cat ./config.json`
user=`echo $config | jsawk -n 'out(this.user)'`
password=`echo $config | jsawk -n 'out(this.password)'`
host=`echo $config | jsawk -n 'out(this.jiraUrl)'`
maxResults=`echo $config | jsawk -n 'out(this.maxResults)'`
cacheTTLinMins=`echo $config | jsawk -n 'out(this.cacheTTLinMins)'`
fields="id,key,project,issuetype,summary"

if [ -z "$query" ]; then
	queryJql=`echo $config | jsawk -n 'out(this.emptySearchJql)'`
else
	queryJql=`echo $config | jsawk -n 'out(this.searchJql)'`
fi
queryJql=`echo $queryJql | sed s/{query}/$query/g`
filename="cache/jira-$query.txt"

# Remove files older than five minutes
rm `find cache -mmin +${cacheTTLinMins}`

# Create directory if required
mkdir -p cache

if [ ! -f $filename ]; then
	# Call API & Generate XML Items for Alfred, if file exists
	curl -s -u $user:$password -G -H "Content-Type: application/json" --data-urlencode "jql=$queryJql" --data-urlencode "maxResults=$maxResults" --data "validateQuery=false" --data "fields=$fields" "$host/rest/api/2/search" -o $filename
else
	if [ ! -s $filename ] || test `cat $filename | jsawk 'return this.total' == 0`; then
		#defensive check for empty files or no results
		rm $filename
	fi
fi

xmlItems=`cat $filename\
		| jsawk 'return this.issues' \
		| sed 's/&/%26/g' \
		| jsawk -n 'out("<item uid=\"" + this.key + "\" valid=\"yes\" arg=\"'$host'/browse/" + this.key + "\"><title><![CDATA[" + this.fields.summary + "]]></title><subtitle><![CDATA[" + this.key + " (" + this.fields.issuetype.name + ", " + this.fields.project.name + ")]]></subtitle><icon>icons/" + this.fields.issuetype.name + ".png</icon></item>")'`

# For debugging
# echo $xmlItems > results.xml

echo "<?xml version=\"1.0\"?><items>$xmlItems</items>"
