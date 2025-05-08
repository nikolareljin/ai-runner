#!/bin/bash

source ./.env

# Specs for dialog.
DIALOG_WIDTH=60
DIALOG_HEIGHT=20

# check the dimensions dynamically. Set them to be 70% of the screen size.
DIALOG_WIDTH=$(tput cols)
DIALOG_HEIGHT=$(tput lines)
DIALOG_WIDTH=$((DIALOG_WIDTH * 70 / 100))
DIALOG_HEIGHT=$((DIALOG_HEIGHT * 70 / 100))

# Set minimum dimensions for dialog
if [ $DIALOG_WIDTH -lt 60 ]; then
    DIALOG_WIDTH=60
fi
if [ $DIALOG_HEIGHT -lt 20 ]; then
    DIALOG_HEIGHT=20
fi

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

