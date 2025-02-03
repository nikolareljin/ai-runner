#!/bin/bash

DEFAULT_MODEL="llama3"

# Options: 
# -i                : install, 
# -m <model>        : run specific model
# -p <prompt>       : prompt to use 


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

# Download default model
ollama pull ${DEFAULT_MODEL}
ollama run ${DEFAULT_MODEL}

# Get available list of models from ollama and pull them. Display options with dialog cli tool and allow them be downloaded.
# List remote models from ollama and display available options for download
available_models=$(curl -s http://localhost:11434/api/models | jq -r '.models[] | .name')
selected_model=$(echo "$available_models" | dialog --menu "Select a model to download" 15 40 5 3>&1 1>&2 2>&3)

# Create the prompt using dialog and send the curl request
if [[ 1 != ${run_prompt} ]]; then
    dialog --inputbox "Enter a prompt" 10 40 2> /tmp/prompt.txt
    prompt=$(cat /tmp/prompt.txt)

    # make CURL request
    # curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"llama3\",  \"prompt\":\"${prompt}\", \"stream\": false}"
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

    # Pull llama3
    ollama pull ${selected_model}
    ollama run ${selected_model}
fi

# make CURL request
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"llama3\",  \"prompt\":\"${prompt}\", \"stream\": false}"

# Grab the results

# Display the results with md format and show them
