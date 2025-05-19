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

# --------------------------------------------------
# Define colors for the text.
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_CYAN="\033[36m"
COLOR_MAGENTA="\033[35m"
COLOR_WHITE="\033[37m"
COLOR_GREY="\033[90m"
COLOR_BOLD="\033[1m"
COLOR_UNDERLINE="\033[4m"
COLOR_RESET="\033[0m"
# --------------------------------------------------
# Print the text in different colors.
# It uses ANSI escape codes to print the text in different colors.
# It supports red, green, yellow, blue, cyan, magenta, white, and grey colors.
# It also supports printing the text in bold and underlined format.
print_color() {
    # Print the text in the specified color
    local text=$1
    local color=$2
    # Second text and color combination.
    local text2=$3
    local color2=$4

    local start_color=$color
    local end_color=$color2

    # If color2 is empty, then set the GREY color for the start, and use first color for the end.
    if [[ -z "$color2" ]]; then
        start_color=$COLOR_GREY
        end_color=$color
    fi

    if [[ -z "$text2" ]]; then
        # Print the text in the specified color
        echo -e "${start_color}${text}${COLOR_RESET}"
    else
        # Print the text in the specified color with a second line
        echo -e "${start_color}${text}${COLOR_RESET}\n${end_color}${text2}${COLOR_RESET}"
    fi
}
print_grey() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_GREY

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}
print_red() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_RED

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}
print_green() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_GREEN

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}
print_yellow() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_YELLOW

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}
print_blue() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_BLUE

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}
print_cyan() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_CYAN

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}
print_magenta() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_MAGENTA

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}
print_white() {
    # Print the text in grey color
    local text=$1
    local text2=$2
    local color=$COLOR_WHITE

    if [[ -z "$text2" ]]; then
        # Print the text in grey color
        print_color "$text" "$color"
    else
        # Print the text in grey color with a second line
        print_color "$text" "$color" "$text2"
    fi
}

# --------------------------------------------------
# Display help information for the script.
# It checks if the help flag is set and displays the help information.
# It also checks if the script is run with the help flag and displays the help information.
# Make it modular so that it uses the header information from the script file itself to display the help information.
display_help() {
    # Read information from the script file. Structure is as follows:
    # #!/bin/bash
    # # SCRIPT: run.sh
    # # DESCRIPTION: Script to run the Ollama model and make a curl request to the endpoint.
    # # USAGE: ./run.sh [-i] [-m <model>] [-p <prompt>]
    # # PARAMETERS:
    # # -i                : install,
    # # -m <model>        : run specific model
    # # -p <prompt>       : prompt to use 
    # # -h                : show help
    # # EXAMPLE: ./run.sh -i -m llama3 -p "Hello, how are you?"
    # # ----------------------------------------------------
    # Get the script name
    script_name=$(grep "^# SCRIPT:" "$0" | cut -d ":" -f 2 | sed 's/^ *//g')
    # Get the script description
    script_description=$(grep "^# DESCRIPTION:" "$0" | cut -d ":" -f 2 | sed 's/^ *//g')
    # Get the script usage
    script_usage=$(grep "^# USAGE:" "$0" | cut -d ":" -f 2 | sed 's/^ *//g')
    # Get the script parameters
    script_parameters=$(awk '/^# PARAMETERS:/ {flag=1; next} /^# EXAMPLE/ {flag=0} flag {print substr($0, 3)}' "$0" | sed 's/^ *//g')
    script_example=$(grep "^# EXAMPLE:" "$0" | cut -d ":" -f 2 | sed 's/^ *//g')

    # Display the help information. Use regular echo with colors (and not dialog).
    print_green "Script Name:" " $script_name"
    print_green "Description:" " $script_description"
    print_green "Usage:" " $script_usage"
    if [[ ! -z "$script_parameters" ]]; then
        print_white "Parameters:" "$script_parameters"
    fi
    print_yellow "Example:" " $script_example"
    print_white "----------------------------------------------------"
}