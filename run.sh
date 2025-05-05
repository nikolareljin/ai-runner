#!/bin/bash

DEFAULT_MODEL="llama3"

# Options: 
# -i                : install, 
# -m <model>        : run specific model
# -p <prompt>       : prompt to use 

# Specs for dialog.
DIALOG_WIDTH=60
DIALOG_HEIGHT=20

# Run parameters.
run_install=0
run_model=0
run_prompt=0

# Get the options
while getopts "im:p:" opt; do
    case ${opt} in
        i)
            run_install=1
            ;;
        m)
            run_model=1
            model=$OPTARG
            ;;
        p)
            run_prompt=1
            prompt=$OPTARG
            ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            ;;
    esac
done

# Install llama and its dependencies
if [[ 1 == ${run_install} ]]; then
    # If dialog, curl and jq are not installed, install them
    if ! [ -x "$(command -v dialog)" ]; then
        echo "Dialog is not installed. Installing..."
        sudo apt-get install -y dialog
    fi

    # If curl not installed, install it
    if ! [ -x "$(command -v curl)" ]; then
        echo "Curl is not installed. Installing..."
        sudo apt-get install -y curl
    fi

    # If jq is not installed, install it
    if ! [ -x "$(command -v jq)" ]; then
        echo "jq is not installed. Installing..."
        sudo apt-get install -y jq
    fi

    # if llama is not installed, install it
    if ! [ -x "$(command -v llama)" ]; then
        echo "Llama is not installed. Installing..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi
fi

# TODO: implement pulling of avaialble models from Ollama website. Store this into models.json file.

# Process all the models from models.json file and display them as options in the Dialog. 
# Use jq to parse the json file and display the options in dialog.
# Provide the details in the options: name, parameters, memory.
# Store the selected model in a variable ${selected_model}.
options=$(jq -r '.models[] | "\(.runnable) \(.name) \(.parameters) \(.memory)"' models.json)
menu_items=()
while IFS= read -r line; do
    key=$(echo "$line" | awk '{print $1}')
    value=$(echo "$line" | awk '{$1=""; print $0}')
    menu_items+=("$key" "$value")
done <<< "$options"

selected_model=$(dialog --menu "Select a model to download" ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 5 "${menu_items[@]}" 3>&1 1>&2 2>&3)

# Create the prompt using dialog and send the curl request
if [[ 1 != ${run_prompt} ]]; then
    dialog --inputbox "Enter a prompt" ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 2> /tmp/prompt.txt
    prompt=$(cat /tmp/prompt.txt)
fi

# If empty prompt, exit
if [[ -z "$prompt" ]]; then
    echo "No prompt entered. Exiting..."
    exit 1
fi

if [[ -z "$selected_model" ]]; then
    echo "No model selected. Exiting..."
    exit 1

else 
    # Pull the selected model
    ollama pull "$selected_model"

    # Pull the model
    ollama pull ${selected_model}
    ollama run ${selected_model}
fi

# make CURL request
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"${selected_model}\",  \"prompt\":\"${prompt}\", \"stream\": false}"

# Grab the results

# Display the results with md format and show them
