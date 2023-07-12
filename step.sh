#!/bin/bash
set -e

# echo "This is the value specified for the input 'example_step_input': ${example_step_input}"

#
# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:
# nvman add --key EXAMPLE_STEP_OUTPUT --value 'the value you want to share'
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

# This is step.sh file for Android apps

debug () {
	echo "Debugger:" > $BITRISE_DEPLOY_DIR/debug.txt
	echo "Keystore file: $keystore_file" >> $BITRISE_DEPLOY_DIR/debug.txt
	echo "Keystore alias: $keystore_alias" >> $BITRISE_DEPLOY_DIR/debug.txt
	echo "FP: $gp" >> $BITRISE_DEPLOY_DIR/debug.txt
	echo "SF: $sf" >> $BITRISE_DEPLOY_DIR/debug.txt 
	echo "BL: $bl" >> $BITRISE_DEPLOY_DIR/debug.txt 
	echo "BTV: $btv" >> $BITRISE_DEPLOY_DIR/debug.txt 
	echo "SO: $so" >> $BITRISE_DEPLOY_DIR/debug.txt 

	ls -al >> $BITRISE_DEPLOY_DIR/debug.txt
	ls -al .. >> $BITRISE_DEPLOY_DIR/debug.txt
	echo >> $BITRISE_DEPLOY_DIR/debug.txt
	echo --api_key $APPDOME_API_KEY \
		--app $app_file \
		--fusion_set_id $fusion_set_id \
		$tm \
		--sign_on_appdome \
		--keystore $keystore_file \
		--keystore_pass $keystore_pass \
		--keystore_alias $keystore_alias \
		$gp \
		$sf \
		$bl \
		$btv \
		$so \
		--key_pass $key_pass \
		--output $secured_app_output \
		--certificate_output $certificate_output >> $BITRISE_DEPLOY_DIR/debug.txt
}

print_all_params() {
	echo "Appdome Build-2Secure parameters:"
	echo "=================================="
	echo "App location: $app_location"
	echo "Team ID: $team_id"
	echo "Sign Method: $sign_method"
	echo "Keystore file: $keystore_file" 
	echo "Keystore alias: $keystore_alias" 
	echo "Google Play Singing: $gp_signing"
	echo "Google Fingerprint: $GOOGLE_SIGN_FINGERPRINT" 
	echo "Sign Fingerprint: $SIGN_FINGERPRINT"
	echo "Build with logs: $build_logs" 
	echo "Build to test: $build_to_test" 
	echo "Secured app output: $secured_app_output"
	echo "Certificate output: $certificate_output"
	echo "Secondary output: $secured_so_app_output"
	echo "-----------------------------------------"
}

download_file() {
	file_location=$1
	uri=$(echo $file_location | awk -F "?" '{print $1}')
	downloaded_file=$(basename $uri)
	curl -L $file_location --output $downloaded_file && echo $downloaded_file
}

internal_version="RS-A-2.0.0"
echo "Internal version: $internal_version"
export APPDOME_CLIENT_HEADER="Bitrise/1.0.0"

app_location=$1
fusion_set_id=$2
team_id=$3
sign_method=$4
gp_signing=$5
google_fingerprint=$6
fingerprint=$7
build_logs=$8
build_to_test=$9
secondary_output=${10}
build_to_test=$(echo "$build_to_test" | tr '[:upper:]' '[:lower:]')

if [[ -z $APPDOME_API_KEY ]]; then
	echo 'APPDOME_API_KEY must be provided as a Secret. Exiting.'
	exit 1
fi

if [[ $app_location == *"http"* ]];
then
	app_file=../$(download_file $app_location)
else
	app_file=$app_location
fi

so=""
secured_so_app_output="none"
extension=${app_file##*.}
if [[ $extension == "aab" && $secondary_output == "true" ]]; then
	secured_so_app_output="$BITRISE_DEPLOY_DIR/Appdome_Universal.apk"
	so="--second_output $secured_so_app_output"
fi

certificate_output=$BITRISE_DEPLOY_DIR/certificate.pdf
secured_app_output=$BITRISE_DEPLOY_DIR/Appdome_$(basename $app_file)

if [[ $team_id == "_@_" ]]; then
	team_id=""
	tm=""
else
	tm="--team_id ${team_id}"
fi

git clone https://github.com/Appdome/appdome-api-bash.git > /dev/null
cd appdome-api-bash

echo "Android platform detected"

sf=""
if [[ -n $fingerprint ]]; then
	sf="--signing_fingerprint ${fingerprint}"
fi

gp=""
if [[ $gp_signing == "true" ]]; then
	if [[ -z $google_fingerprint ]]; then
		if [[ -z $fingerprint ]]; then
			echo "Google Sign Fingerprint must be provided for Google Play signing. Exiting."
			exit 1
		else
			echo "Google Sign Fingerprint was not provided, will be using Sign Fringerprint instead."
			google_fingerprint=$fingerprint
		fi
	fi
	gp="--google_play_signing --signing_fingerprint ${google_fingerprint}"
	sf=""
fi

bl=""
if [[ $build_logs == "true" ]]; then
	bl="--build_logs"
fi

btv=""
if [[ $build_to_test != "none" ]]; then
	btv="--build_to_test_vendor  $build_to_test"
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
							$gp \
							$sf \
							$bl \
							$btv \
							$so \
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
							$gp \
							$sf \
							$bl \
							$btv \
							--output "$secured_app_output" \
							--certificate_output $certificate_output 
						;;
"On-Appdome")			
						keystore_file=$(download_file $BITRISEIO_ANDROID_KEYSTORE_URL)
						keystore_pass=$BITRISEIO_ANDROID_KEYSTORE_PASSWORD
						keystore_alias=$BITRISEIO_ANDROID_KEYSTORE_ALIAS
						key_pass=$BITRISEIO_ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD
						print_all_params
						echo "On Appdome Signing"
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app $app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--sign_on_appdome \
							--keystore $keystore_file \
							--keystore_pass "$keystore_pass" \
							--keystore_alias "$keystore_alias" \
							$gp \
							$bl \
							$btv \
							$so \
							--key_pass "$key_pass" \
							--output "$secured_app_output" \
							--certificate_output $certificate_output 
						;;
esac


# rm -rf appdome-api-bash
if [[ $secured_app_output == *.sh ]]; then
	envman add --key APPDOME_PRIVATE_SIGN_SCRIPT_PATH --value $secured_app_output
elif [[ $secured_app_output == *.apk ]]; then
	envman add --key APPDOME_SECURED_APK_PATH --value $secured_app_output
else
	envman add --key APPDOME_SECURED_AAB_PATH --value $secured_app_output
	if [[ -n $so ]]; then
		envman add --key APPDOME_SECURED_SO_PATH --value $secured_so_app_output
	fi
fi
envman add --key APPDOME_CERTIFICATE_PATH --value $certificate_output
