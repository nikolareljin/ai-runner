#!/bin/bash

# Install llama and its dependencies
sudo apt-get update
sudo apt-get install -y dialog curl jq

# Install llama with curl request
curl -fsSL https://ollama.com/install.sh | sh

# Pull llama3
ollama run llama3
ollama list
ollama pull llama3

# Create the prompt using dialog and send the curl request
dialog 

# make CURL request
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"llama3\",  \"prompt\":\"Tell me a fact about Llama?\", \"stream\": false}"

# Grab the results

# Display the results with md format and show them
