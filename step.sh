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

print_all_params() {
	echo "Appdome Build-2Secure parameters:"
	echo "App location: $app_location"
	echo "Appdome API key: $APPDOME_API_KEY"
	echo "Fusion set ID: $fusion_set_id"
	echo "Team ID: $team_id"
	echo "Sign Method: $sign_method"
	echo "Certificate file: $keystore_file" 
	echo "Provisioning profiles: $pf_list" 
	echo "Entitelments: $ef_list"
	echo "Build with test: $build_logs" 
	echo "Secured app output: $secured_app_output"
	echo "-----------------------------------------"
}

download_file() {
	file_location=$1
	uri=$(echo $file_location | awk -F "?" '{print $1}')
	downloaded_file=$(basename $uri)
	curl -L $file_location --output $downloaded_file 
	new_name=${downloaded_file//"%20"/"_"}
	mv $downloaded_file $new_name && echo $new_name
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

get_custom_cert() {
	BK=$IFS
	files_list=""
	cert=$1
	IFS=","
	read -ra files_array <<< "$cf_list"
	IFS=$BK
	found=false
	file_index=0			
	for cert_file in ${files_array[@]};
	do
		if [[ $cert_file == $cert ]]; then
			found=true
			break
		fi
		file_index=$((file_index+1))
	done
	if [[ $found == false ]]; then
		echo "Could not find the certificate ${cert} in Code Signing & Files. Please re-check your input."
		exit 1
	fi
}

create_custom_provisioning_list() {
	BK=$IFS
	IFS=","
	provision_list=""
	prov_array=$@
	read -r -a files_array <<< "$pf_list"
	IFS=$BK
	for prov in ${prov_array[@]};
	do
		echo checking.... $prov
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
			echo "Could not find the provisioning ${prov} in Code Signing & Files. Please re-check your input."
            exit 1
		fi
	done
	if [[ $provision_list == "" ]]; then
		echo "Could not find the given provisioning profiles among those uploaded to Code Signing & Files."
		exit 1
    fi
}

echo "Internal version: i-1.0.14"

args="$@"
args=${args//"_@_"/""}
i=1
for arg in ${args[@]}
do
	args[i]=$arg
   	i=$((i+1))
done

app_location=${args[1]}
fusion_set_id=${args[2]}
team_id=${args[3]}
sign_method=${args[4]}
certificate_file=${args[5]}
provisioning_profiles=${args[6]}
entitlements=${args[7]}
build_logs=${args[8]}

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

pf=$(convert_env_var_to_url_list $BITRISE_PROVISION_URL)
pf_list=$(download_files_from_url_list $pf)

if [[ -n $provisioning_profiles ]]; then
	BK=$IFS
	IFS=""
	provisioning_profiles=$(echo $provisioning_profiles | xargs)
	provisioning_profiles=${provisioning_profiles//", "/","}
	provisioning_profiles=${provisioning_profiles//" ,"/","}
	provisioning_profiles=${provisioning_profiles//" "/"_"}
	IFS=$BK
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
"Private-Signing")		
						print_all_params
						echo "Private Signing"						
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app $app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--private_signing \
							--provisioning_profiles $pf_list \
							$en \
							$bl \
							--output "$secured_app_output" \
							--certificate_output $certificate_output 
							
						;;
"Auto-Dev-Signing")		
						print_all_params
						echo "Auto Dev Signing"
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app $app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--auto_dev_private_signing \
							--provisioning_profiles $pf_list \
							$en \
							$bl \
							--output "$secured_app_output" \
							--certificate_output $certificate_output 
							
						;;
"On-Appdome")			
						cf=$(convert_env_var_to_url_list $BITRISE_CERTIFICATE_URL)
						cf_list=$(download_files_from_url_list $cf)
						BK=$IFS
						IFS=","
						read -ra keystore <<< "$cf_list"
						IFS="|"
						read -ra passwords <<< "$BITRISE_CERTIFICATE_PASSPHRASE"
						IFS=$BK
						if [[ -z $certificate_file ]]; then
							keystore_file=${keystore[0]}
							keystore_pass=${passwords[0]}
						else
							BK=$IFS
							IFS=""
							certificate_file=${certificate_file//" "/"_"}
							IFS=$BK
							get_custom_cert $certificate_file	# returns $cert_file and file_index of $certificate in $cf_list
							keystore_file=$cert_file
							keystore_pass=${passwords[file_index]}
						fi
						print_all_params
						echo "On Appdome Signing"
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app $app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--sign_on_appdome \
							--keystore "$keystore_file" \
							--keystore_pass "$keystore_pass" \
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

