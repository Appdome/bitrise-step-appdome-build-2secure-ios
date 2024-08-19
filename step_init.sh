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



# parameters validation:
if [[ -z $APPDOME_API_KEY ]]; then
	echo 'No APPDOME_API_KEY was provided. Exiting.'
	exit 1
fi

if [[ -z $app_location ]]; then
    echo "No App Location was provided. Exiting."
    exit 1
fi

if [[ -z $output_filename ]];then
    output_filename="_@_"
fi

if [[ -z $fusion_set_id ]];then
    echo "No Fusion Set ID was provided. Exiting."
    exit 1
fi

if [[ -z $team_id ]];then
    team_id="_@_"
fi

if [[ -z $certificate_file ]];then
    certificate_file="_@_"
else
    BK=$IFS
	IFS=""
	provisioning_profiles=$(echo $provisioning_profiles | xargs)
	provisioning_profiles=${provisioning_profiles//", "/","}
	provisioning_profiles=${provisioning_profiles//" ,"/","}
	provisioning_profiles=${provisioning_profiles//" "/"_"}
	IFS=$BK
fi
    
if [[ -z $provisioning_profiles ]];then
    provisioning_profiles="_@_"
fi

if [[ -z $entitlements ]];then
    entitlements="_@_"
else
    entitlements=$(echo $entitlements | xargs)
    entitlements=${entitlements//" "/"_@_"}
fi

branch="RealStep"
if [[ -n $APPDOME_BRANCH_IOS ]]; then
    branch=$APPDOME_BRANCH_IOS
fi

echo "Running Branch: $branch"
# step execusion
git clone --branch $branch https://github.com/Appdome/bitrise-step-appdome-build-2secure-ios.git > /dev/null
cd bitrise-step-appdome-build-2secure-ios
bash ./step.sh "$app_location" "$fusion_set_id" "$team_id" "$sign_method" "$certificate_file" "$provisioning_profiles" "$entitlements" "$build_logs" "$build_to_test" "$output_filename"
exit $(echo $?)