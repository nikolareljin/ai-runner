#!/bin/bash

DEFAULT_MODEL="llama3"

# Install llama and its dependencies
sudo apt-get update
sudo apt-get install -y dialog curl jq

# Install llama with curl request
curl -fsSL https://ollama.com/install.sh | sh

# Download default model
ollama pull ${DEFAULT_MODEL}
ollama run ${DEFAULT_MODEL}

# Get available list of models from ollama and pull them. Display options with dialog cli tool and allow them be downloaded.
# List remote models from ollama and display available options for download
available_models=$(curl -s http://localhost:11434/api/models | jq -r '.models[] | .name')
selected_model=$(echo "$available_models" | dialog --menu "Select a model to download" 15 40 5 3>&1 1>&2 2>&3)

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

# Create the prompt using dialog and send the curl request
dialog --inputbox "Enter a prompt" 10 40 2> /tmp/prompt.txt
prompt=$(cat /tmp/prompt.txt)

# make CURL request
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"llama3\",  \"prompt\":\"${prompt}\", \"stream\": false}"

# Grab the results

# Display the results with md format and show them
