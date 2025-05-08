#!/bin/bash

source ./include.sh
source ./.env

# Get the prompt using the dialog command.
prompt=$(dialog --inputbox "Enter your prompt:" $DIALOG_HEIGHT $DIALOG_WIDTH 3>&1 1>&2 2>&3)

# using existing ollama service, make a query to the endpoint with the prompt and display the response.
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"${model}\",  \"prompt\":\"${prompt}\", \"stream\": false}" > ./response.json

# Read the response from the file and display it in a dialog box.
response=$(jq -r '.response' response.json)
if [ $? -eq 0 ]; then
    echo "Response received successfully."
else
    echo "Error receiving response."
    exit 1
fi
# Check if the response is empty
if [[ -z "$response" ]]; then
    echo "No response received. Exiting..."
    exit 1
fi
# Display the response in a dialog box
dialog --title "Response" --msgbox "$response" ${DIALOG_HEIGHT} ${DIALOG_WIDTH}

# Copy the response into clipboard memory. Uses helper method from include.sh
copy_to_clipboard "$response"
