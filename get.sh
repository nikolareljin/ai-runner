#!/bin/bash

# Download the model to a designated location.
# Uses dialog to select where to download, and a progress bar to show the download progress.

# parameters:
# -m <model>: model name
# -u <url>: model url (if not in the list)
# -d <dir>: directory to download the model to

# Default values
model="llama3"
url=""

# Parse the arguments
while getopts "m:u:d:" opt; do
    case ${opt} in
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

# Check if the directory exists
if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist. Creating..."
    mkdir -p $dir
fi

# Download the model
echo "Downloading model $model from $url to $dir"

# Download the model
curl -L $url | tar -xz -C $dir

# Check if the download was successful
if [ $? -eq 0 ]; then
    echo "Model $model downloaded successfully."
else
    echo "Error downloading model $model."
fi

# End of script
