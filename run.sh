#!/bin/bash
# SCRIPT: run.sh
# DESCRIPTION: Script to run the Ollama model and make a curl request to the endpoint.
# USAGE: ./run.sh [-h] [-i] [-m <model>] [-p <prompt>]
# PARAMETERS:
# -i                : install,
# -m <model>        : run specific model
# -p <prompt>       : prompt to use 
# -h                : show help
# EXAMPLE: ./run -i -m llama3 -p "Hello, how are you?"
# ----------------------------------------------------

source ./include.sh

DEFAULT_MODEL="llama3"

# Options: 
# -i                : install, 
# -m <model>        : run specific model
# -p <prompt>       : prompt to use 

help() {
    display_help
    exit 1
}

# Run parameters.
run_install=0
run_model=0
run_prompt=0

# Get the options
while getopts "him:p:" opt; do
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
        h)
            help
            ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            help
            ;;
    esac
done

# Install llama and its dependencies
if [[ 1 == ${run_install} ]]; then
    install_dependencies
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "No .env file found. Creating..."
    cp .env.example.txt .env
fi

# Model file path.
MODEL_FILE="./ollama-get-models/code/ollama_models.json"
if [ ! -f "$MODEL_FILE" ]; then
    echo "No models.json file found. Exiting..."
    exit 1
fi

# Re-format the model file - sort by model name.
jq -S 'sort_by(.name)' ${MODEL_FILE} > ${MODEL_FILE}.tmp
mv ${MODEL_FILE}.tmp ${MODEL_FILE}

# Alternative implementation: using manually entered models.json file.
# Process all the models from models.json file and display them as options in the Dialog.
# Drawback: This file will need manual updates. It will not include all the models currently available on ollama. Also, the models.json file is not in the same format as the one used in the rest of the script. It won't allow selection of the sizes. 
# Use jq to parse the json file and display the options in dialog.
# Provide the details in the options: name, parameters, memory.
# Store the selected model in a variable ${selected_model}.
# options=$(jq -r '.models[] | "\(.runnable) \(.name) \(.parameters) \(.memory)"' models.json)
# menu_items=()
# while IFS= read -r line; do
#     key=$(echo "$line" | awk '{print $1}')
#     value=$(echo "$line" | awk '{$1=""; print $0}')
#     menu_items+=("$key" "$value")
# done <<< "$options"

source .env

options=$(jq -r '.[] | "\(.name) sizes:\t\(.sizes)"' ${MODEL_FILE})
menu_items=()

# ----------------- MODEL -----------------
current_model=$(grep -oP '^model=\K.*' .env)
while IFS= read -r line; do
    key=$(echo "$line" | awk '{print $1}')
    value=$(echo "$line" | awk '{$1=""; print $0}')
    if [[ "$key" == "$current_model" ]]; then
        menu_items+=("$key" "$value" "on")
    else
        menu_items+=("$key" "$value" "off")
    fi
    # Preselect the current model if it matches
    if [[ "$key" == "$current_model" ]]; then
        preselected_model="$key"
    fi
done <<< "$options"

selected_model=$(dialog --radiolist "Select a model to download" ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 5 "${menu_items[@]}" 3>&1 1>&2 2>&3)

# Put selected_model into .env file.
if [ -n "$selected_model" ]; then
    echo "Selected model: $selected_model"
    # Check if the selected model is already in the .env file
    if grep -q "model=" .env; then
        # If it is, replace it
        sed -i "s/model=.*/model=${selected_model}/" .env
    else
        # If not, add it to the end of the file
        echo "model=${selected_model}" >> .env
    fi
else
    echo "No model selected. Exiting..."
    exit 1
fi

# ----------------- SIZE -----------------
# Extract sizes for the selected model using jq
sizes=$(jq -r --arg model "$selected_model" '.[] | select(.name == $model) | .sizes[]' ${MODEL_FILE})
# echo "Sizes for the selected model: $sizes"
# exit 2

# Prepare menu items for dialog
menu_items=()
while IFS= read -r size; do
    menu_items+=("$size" "$size")
done <<< "$sizes"

# in case current model has NULL (no sizes) in the json file, set default size to latest.
if [[ -z "$sizes" ]] || [[ "null" == "$sizes" ]]; then
    echo "No sizes found for the selected model. Using :latest (default)."
    selected_size="latest"
else
    # Display the sizes in a dialog menu
    selected_size=$(dialog --menu "Select a size for the model: ${selected_model}" ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 5 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    # Put selected_size into .env file
    if [ -n "$selected_size" ]; then
        echo "Selected size: $selected_size"
        # Check if the selected size is already in the .env file
        if grep -q "size=" .env; then
            # If it is, replace it
            sed -i "s/size=.*/size=${selected_size}/" .env
        else
            # If not, add it to the end of the file
            echo "size=${selected_size}" >> .env
        fi
    else
        echo "No size selected. Using :latest (default)."
        selected_size="latest"
    fi
fi

# Check if the selected size is already in the .env file
if grep -q "size=" .env; then
    # If it is, replace it
    sed -i "s/size=.*/size=${selected_size}/" .env
else
    # If not, add it to the end of the file
    echo "size=${selected_size}" >> .env
fi

# ------------- PROMPT -----------------
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

# ----------- RUN MODEL -----------------
# Check if we have selected a model.
if [[ -z "$selected_model" ]]; then
    echo "No model selected. Exiting..."
    exit 1

else 
    # Pull the selected model
    ollama pull "$selected_model:$selected_size"

    # Run the selected model
    ollama run ${selected_model}:$selected_size &
fi

# ---------- CURL request to endpoint -----------------
# make CURL request
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"${selected_model}\",  \"prompt\":\"${prompt}\", \"stream\": false}" > ./response.json

# Write the response in nice format with jq tool.
jq -r '.response' response.json > /tmp/response.txt
# Check if the response was successful
if [ $? -eq 0 ]; then
    echo "Response received successfully."
else
    echo "Error receiving response."
    exit 1
fi
# Read the response from the file
response=$(cat /tmp/response.txt)
# Check if the response is empty
if [[ -z "$response" ]]; then
    echo "No response received. Exiting..."
    exit 1
fi

# Copy the response into clipboard memory. Use helper method from include.sh
copy_to_clipboard "$response"

# Format the response to be displayed in the dialog box. Use helper method from include.sh
formatted_response=$(format_response "$response")

# Display the response in a dialog box
dialog --title "Response" --msgbox "$formatted_response" ${DIALOG_HEIGHT} ${DIALOG_WIDTH}

# Format the reponse as MD format. Use helper method from include.sh
formatted_md_response=$(format_md_response "$response")

# Display the response in a markdown format
echo "## Response" > /tmp/response.md
echo "### Model: ${selected_model}" >> /tmp/response.md
echo "### Size: ${selected_size}" >> /tmp/response.md
echo "### Prompt: ${prompt}" >> /tmp/response.md
echo "### Response:" >> /tmp/response.md
echo "$formatted_md_response" >> /tmp/response.md

# Grab the results.

# Display the results with md format and show them

# Clear old ollama models that are not being used or active.
ollama ps

# Remove the temporary prompt file
rm -f /tmp/prompt.txt

