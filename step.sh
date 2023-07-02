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
	fullpath=${fullpath//"|"/" "}
	n=$(echo $fullpath | grep -o "https:" | wc -l)
	n=$((n+1))
	url_list=""
	for ((i=2; i<=n; i++))
	do 
		url="https:"$(echo $fullpath | awk -v i=$i -F "https:" '{print $i}')
		url_list="${url_list} ${url}"
	done
	echo $url_list
}

create_custom_provisioning_list() {
	BK=$IFS
	provision_list=""
	prov_array=$@
	IFS=","
	read -r -a files_array <<< "$pf_list"
	IFS=$BK
	for prov in ${prov_array[@]};
	do
		found=false
		for file in ${files_array[@]};
		do
			filename="${file%.*}"
			if [[ $filename == $prov ]]; then
				found=true
				if [[ $provision_list == "" ]]; then
					provision_list=$file
				else
					provision_list="${provision_list},${file}"
				fi
				break
			fi
		done
		if [[ $found == false ]]; then
			echo "Could not find the file ${prov} in Code Signing & Files. Please re-check your input."
            exit 1
		fi
	done
	if [[ $provision_list == "" ]]; then
		echo "Could not find the given provisioning profiles among those uploaded to Code Signing & Files."
		exit 1
    fi
}


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

app_slug=$BITRISE_APP_URL
app_slug="1ae96b85-0026-4448-9d68-10f01a6b0344"
build_slug=$BITRISE_BUILD_SLUG
bt_api_key="ut8pqJXiLR_28V9rVcpd2Ci8kpCJdBWQu4fcyGgcEEUtVE7udyV7fl06Bvy19VRcvwPCYzTpHBbk_HzFRrrabg"
base_url="https://api.bitrise.io/v0.1"

echo app_slug: $app_slug
echo build_slug: $build_slug
echo 1.0

curl $base_url/apps

exit 0

# download provisioning profiles and set them in a list for later use

pf=$(convert_env_var_to_url_list $BITRISE_PROVISION_URL)
pf_list=$(download_files_from_url_list $pf)

if [[ -n $provisioning_profiles ]]; then
	create_custom_provisioning_list $provisioning_profiles	# returns provision_list
	pf_list=$provision_list
fi

ef=$(echo $entitlements)
ef_list=$(download_files_from_url_list $ef)
# ls -al
en=""
if [[ -n $entitlements ]]; then
	en="--entitlements ${ef_list}"
fi

bl=""
if [[ $build_logs == "true" ]]; then
	bl="-bl"
fi

case $sign_method in
"Private-Signing")		echo "Private Signing"						
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app $app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--private_signing \
							--provisioning_profiles $pf_list \
							$en \
							$bl \
							--output $secured_app_output \
							--certificate_output $certificate_output 
							
						;;
"Auto-Dev-Signing")		echo "Auto Dev Signing"
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app $app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--auto_dev_private_signing \
							--provisioning_profiles $pf_list \
							$en \
							$bl \
							--output $secured_app_output \
							--certificate_output $certificate_output 
							
						;;
"On-Appdome")			echo "On Appdome Signing"
						keystore_file=$(download_file $BITRISE_CERTIFICATE_URL)
						keystore_pass=$BITRISE_CERTIFICATE_PASSPHRASE
						
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app $app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--sign_on_appdome \
							--keystore $keystore_file \
							--keystore_pass $keystore_pass \
							--provisioning_profiles $pf_list \
							$en \
							$bl \
							--output $secured_app_output \
							--certificate_output $certificate_output 
							
						;;
esac

if [[ $secured_app_output == *.sh ]]; then
	envman add --key APPDOME_PRIVATE_SIGN_SCRIPT_PATH --value $secured_app_output
else
	envman add --key APPDOME_SECURED_IPA_PATH --value $secured_app_output
fi
envman add --key APPDOME_CERTIFICATE_PATH --value $certificate_output

