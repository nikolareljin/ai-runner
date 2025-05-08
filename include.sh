#!/bin/bash

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

# ---------------------------------------------------
# Helper methods for the scripts used in the project.
# ---------------------------------------------------
# Get the OS type.
# This function checks the OS type and returns it.
# It supports Linux, MacOS, and Windows.
# It also checks if the OS is supported. If not, it exits the script.
get_os(){
    # Check if the OS is Linux
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    # Check if the OS is MacOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    # Check if the OS is Windows
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
        echo "windows"
    else
        echo "Unsupported OS. Exiting..."
        exit 1
    fi
}

# --------------------------------------------------
# Install dependencies for the project.
# This includes dialog, curl, jq, python3, pip3, and ollama.
# It also checks if the ollama-get-models directory is present. If not, it clones the repository.
# It also scrapes the models from the website and stores them in models.json file.
install_dependencies() {
    local os=$(get_os)
    
    # Check if dialog is installed
    if ! [ -x "$(command -v dialog)" ]; then
        echo "Dialog is not installed. Installing..."
        if [[ "$os" == "linux" ]]; then
            sudo apt-get install -y dialog
        elif [[ "$os" == "mac" ]]; then
            brew install dialog
        elif [[ "$os" == "windows" ]]; then
            echo "Dialog is not supported on Windows. Please install it manually."
            exit 1
        fi
    fi

    # Check if curl is installed
    if ! [ -x "$(command -v curl)" ]; then
        echo "Curl is not installed. Installing..."
        if [[ "$os" == "linux" ]]; then
            sudo apt-get install -y curl
        elif [[ "$os" == "mac" ]]; then
            brew install curl
        elif [[ "$os" == "windows" ]]; then
            echo "Curl is not supported on Windows. Please install it manually."
            exit 1
        fi
    fi

    # Check if jq is installed
    if ! [ -x "$(command -v jq)" ]; then
        echo "jq is not installed. Installing..."
        if [[ "$os" == "linux" ]]; then
            sudo apt-get install -y jq
        elif [[ "$os" == "mac" ]]; then
            brew install jq
        elif [[ "$os" == "windows" ]]; then
            echo "jq is not supported on Windows. Please install it manually."
            exit 1
        fi
    fi

    # Check if python3 is installed
    if ! [ -x "$(command -v python3)" ]; then
        echo "Python3 is not installed. Installing..."
        if [[ "$os" == "linux" ]]; then
            sudo apt-get install -y python3
        elif [[ "$os" == "mac" ]]; then
            brew install python3
        elif [[ "$os" == "windows" ]]; then
            echo "Python3 is not supported on Windows. Please install it manually."
            exit 1
        fi
    fi

    # Check if pip3 is installed
    if ! [ -x "$(command -v pip3)" ]; then
        echo "pip3 is not installed. Installing..."
        if [[ "$os" == "linux" ]]; then
            sudo apt-get install -y python3-pip
        elif [[ "$os" == "mac" ]]; then
            brew install python3-pip
        elif [[ "$os" == "windows" ]]; then
            echo "pip3 is not supported on Windows. Please install it manually."
            exit 1
        fi
    fi

    # Install Ollama
    if ! [ -x "$(command -v ollama)" ]; then
        echo "Ollama is not installed. Installing..."
        if [[ "$os" == "linux" ]]; then
            curl -fsSL https://ollama.com/install.sh | sh
        elif [[ "$os" == "mac" ]]; then
            brew install ollama/tap/ollama
        elif [[ "$os" == "windows" ]]; then
            echo "Ollama is not supported on Windows. Please install it manually."
            exit 1
        fi
    fi

    # Check if git is installed
    if ! [ -x "$(command -v git)" ]; then
        echo "Git is not installed. Installing..."
        if [[ "$os" == "linux" ]]; then
            sudo apt-get install -y git
        elif [[ "$os" == "mac" ]]; then
            brew install git
        elif [[ "$os" == "windows" ]]; then
            echo "Git is not supported on Windows. Please install it manually."
            exit 1
        fi
    fi

    # check if "ollama-get-models" directory is not present.
    # If so, clone the repository.
    if [ ! -d "ollama-get-models" ]; then
        echo "ollama-get-models directory not found. Cloning..."
        git clone git@github.com:webfarmer/ollama-get-models.git
        # GH CLI: gh repo clone webfarmer/ollama-get-models

        # Now, scrape the models from the website and store them in models.json file.
        # Check if jq is installed
        cd ollama-get-models
        # Run the python script to scrape the models
        # Now pull the models from the website and store them in models.json file.
        python3 get_ollama_models.py
        # Check if the ./code/ollama_models.json file exists
        if [ -f "./code/ollama_models.json" ]; then
            echo "Models file found."
        else
            echo "Models file not found. Exiting..."
            exit 1
        fi
    fi

    # Install the clipboard utility
    if [[ "$os" == "linux" ]]; then
        if ! [ -x "$(command -v xclip)" ]; then
            echo "xclip is not installed. Installing..."
            sudo apt-get install -y xclip
        fi
    elif [[ "$os" == "mac" ]]; then
        if ! [ -x "$(command -v pbcopy)" ]; then
            echo "pbcopy is not installed. Installing..."
            brew install pbcopy
        fi
    elif [[ "$os" == "windows" ]]; then
        echo "Clipboard utility is not supported on Windows. Please install it manually."
        exit 1
    fi
}

# --------------------------------------------------
# Copy the response into clipboard memory.
# It checks if xclip or pbcopy is installed and uses it to copy the response.
# If neither is installed, it exits the script.
copy_to_clipboard() {
    local response=$1
    if command -v xclip &> /dev/null; then
        echo "$response" | xclip -selection clipboard
        echo "Response copied to clipboard."
    elif command -v pbcopy &> /dev/null; then
        echo "$response" | pbcopy
        echo "Response copied to clipboard."
    else
        echo "No clipboard utility found. Response not copied."
        exit 1
    fi
}

# --------------------------------------------------
# Format the response to be displayed in the dialog box.
# It checks if the response is empty and exits the script if it is.
# It also checks if the response is valid JSON and exits the script if it is not.
# It formats the response to be displayed in the dialog box.
format_response() {
    local response=$1
    # Check if the response is empty
    if [[ -z "$response" ]]; then
        echo "No response received. Exiting..."
        exit 1
    fi

    # Check if the response is valid JSON
    if ! echo "$response" | jq . > /dev/null 2>&1; then
        echo "Response is not valid JSON. Exiting..."
        exit 1
    fi

    # Format the response to be displayed in the dialog box
    formatted_response=$(echo "$response" | jq -r '.response')
    echo "$formatted_response"
}

# --------------------------------------------------
# Process MD response format.
# It checks if the response is in MD format and formats it to be displayed in the dialog box.
format_md_response() {
    local response=$1
    # Check if the response is in MD format
    if [[ "$response" == *"\`\`\`"* ]]; then
        # Format the response to be displayed in the dialog box
        formatted_response=$(echo "$response" | sed "s/\`\`\`//g")
        echo "$formatted_response"
    else
        echo "$response"
    fi
}
