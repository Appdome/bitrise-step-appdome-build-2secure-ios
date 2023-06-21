#!/bin/bash
set -e

# echo "This is the value specified for the input 'example_step_input': ${example_step_input}"

#
# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:
# envman add --key EXAMPLE_STEP_OUTPUT --value 'the value you want to share'
# Envman can handle piped inputs, which is useful if the text you want to
# share is complex and you don't want to deal with proper bash escaping:
#  cat file_with_complex_input | envman add --KEY EXAMPLE_STEP_OUTPUT
# You can find more usage examples on envman's GitHub page
#  at: https://github.com/bitrise-io/envman

#
# --- Exit codes:
# The exit code of your Step is very important. If you return
#  with a 0 exit code `bitrise` will register your Step as "successful".
# Any non zero exit code will be registered as "failed" by `bitrise`.

# This is step.sh file for iOS apps


download_file() {
	file_location=$1
	uri=$(echo $file_location | awk -F "?" '{print $1}')
	downloaded_file=$(basename $uri)
	curl -L $file_location --output $downloaded_file && echo $downloaded_file
}

download_files_from_url_list() {
	file_list=""
	array=$@
	i=0
	for element in ${array[@]}
	do
		file=$(download_file $element)
		cp $file $BITRISE_DEPLOY_DIR
		if [ $i -eq 0 ]; then
 		file_list=$file
 		else
 			file_list="${file_list},${file}"
 		fi
 		i=$((i+1))
	done
	echo $file_list
}

convert_env_var_to_url_list() {
	fullpath=$1
	n=$(echo $fullpath | grep -o "https:" | wc -l)
	n=$((n+1))
	url_list=""
	for ((i=2; i<=n; i++))
	do 
		url="https:"$(echo $fullpath | awk -v i=$i -F "https:" '{print $i}')
  		echo "url: $url"
		url_list="${url_list} ${url}"
	done
	echo $url_list
}

echo "This is test script"

if [[ -z $APPDOME_API_KEY ]]; then
	echo 'No APPDOME_API_KEY was provided. Exiting.'
	exit 1
fi

if [[ -z $fusion_set_id ]]; then
	echo 'No Fusion Set was provided. Exiting.'
	exit 1
fi

export APPDOME_CLIENT_HEADER="Bitrise/1.0.0"
if [[ $app_location == *"http"* ]];
then
	app_file=../$(download_file $app_location)
else
	app_file=$app_location
fi

certificate_output=$BITRISE_DEPLOY_DIR/certificate.pdf
secured_app_output=$BITRISE_DEPLOY_DIR/Appdome_$(basename $app_file)

tm=""
if [[ -n $team_id ]]; then
	tm="--team_id ${team_id}"
fi


git clone https://github.com/Appdome/appdome-api-bash.git > /dev/null
cd appdome-api-bash

echo "iOS platform detected"
# download provisioning profiles and set them in a list for later use
echo "BITRISE_PROVISION_URL: $BITRISE_PROVISION_URL"
pf=$(convert_env_var_to_url_list $BITRISE_PROVISION_URL)
echo "pf: $pf"
pf_list=$(download_files_from_url_list $pf)
echo "pf_list: $pf_list"
