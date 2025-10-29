#!/bin/bash
# SCRIPT: prompt.sh
# DESCRIPTION: Script to run the already set up Ollama model and make a curl request to the internal endpoint. NOTE: use command ./run first to select and set the model.
# USAGE: ./prompt.sh [-h] [-p "<prompt>"]
# PARAMETERS:
# -p "<prompt>"     : prompt to use
# -h                : show help
# EXAMPLE: ./prompt.sh -p "What is the meaning of life?"
# ----------------------------------------------------

source ./include.sh
source ./.env

help() {
    display_help
    exit 1
}

prompt=""

# Get the options
while getopts "hp:" opt; do
    case ${opt} in
        h)
            help
            ;;
        p)
            prompt=$OPTARG
            ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            help
            ;;
    esac
done


if [[ -z "$prompt" ]]; then
    # Get the prompt using the dialog command.
    # single-line input box.
    # prompt=$(dialog --inputbox "Enter your prompt:" $DIALOG_HEIGHT $DIALOG_WIDTH 3>&1 1>&2 2>&3)
    
    # Multi-line input box using dialog and tmp file.
    tmpfile=$(mktemp)
    # Use dialog to create an edit box for the prompt input and store result in the temporary file
    dialog --title "Enter your prompt" --editbox "$tmpfile" $DIALOG_HEIGHT $DIALOG_WIDTH 2> "$tmpfile"
    prompt=$(cat "$tmpfile")
    # Sanitize the prompt by removing quotes and newlines
    prompt=$(echo "$prompt" | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$prompt" ]]; then
        echo "No prompt provided. Exiting..."
        exit 1
    fi
    # Remove the temporary file
    rm -f "$tmpfile"
fi

# using existing ollama service, make a query to the endpoint with the prompt and display the response.
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"${model}\",  \"prompt\":\"${prompt}\", \"stream\": false}" > ./response.json

# Read the response from the file and display it in a dialog box.
if response=$(jq -r '.response' "./response.json"); then
    echo "Response received."
else
    echo "Error receiving response."
    exit 1
fi
# Check if the response is empty
if [[ -z "$response" ]] || [[ "$response" == "null" ]]; then
    print_color $COLOR_RED "No response received. Exiting..." "Try again with a different prompt or check if the available memory is sufficient."
    exit 1
fi
# Display the response in a dialog box
dialog --title "Response" --msgbox "$response" ${DIALOG_HEIGHT} ${DIALOG_WIDTH}

# Copy the response into clipboard memory. Uses helper method from include.sh
copy_to_clipboard "$response"
