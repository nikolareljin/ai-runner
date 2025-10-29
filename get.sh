#!/bin/bash
# SCRIPT: get.sh
# DESCRIPTION: Script to download a model from the Ollama website.
# USAGE: ./get.sh [-m <model>] [-u <url>] [-d <dir>]
# PARAMETERS:
# -m <model>        : model name (default: llama3)
# -u <url>          : model url (if not in the list)
# -d <dir>          : directory to download the model to (default: current directory)
# EXAMPLE: ./get.sh -m llama3 -d /path/to/download
# ----------------------------------------------------
# This script downloads a model from the Ollama website.
# It uses curl to download the model and tar to extract it.

source ./include.sh
source ./.env

# Download the model to a designated location.
# Uses dialog to select where to download, and a progress bar to show the download progress.

# Default values
model="llama3"
url=""
dir="."

help() {
    display_help
    exit 1
}

# Parse the arguments
while getopts "hm:u:d:" opt; do
    case ${opt} in
        h)
            help
            ;;
        m )
            model=$OPTARG
            url="https://ollama.com/models/${model}.tar.gz"
            ;;
        u )
            url=$OPTARG
            ;;
        d )
            dir=$OPTARG
            ;;
        \? )
            echo "Usage: cmd [-m <model>] [-u <url>] [-d <dir>]"
            exit 1
            ;;
    esac
done

# Validate input
if [[ -z "$url" ]]; then
    print_error "No download URL provided. Use -m <model> or -u <url>."
    exit 1
fi

# Check if the directory exists
if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist. Creating..."
    mkdir -p "$dir"
fi

# Download the model
echo "Downloading model $model from $url to $dir"

# Download the model
curl -L "$url" | tar -xz -C "$dir"

# Check if the download was successful
if [ $? -eq 0 ]; then
    echo "Model $model downloaded successfully."
else
    echo "Error downloading model $model."
fi

# End of script
