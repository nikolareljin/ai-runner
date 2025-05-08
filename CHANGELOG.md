# CHANGELOG

## Add shared library for functions
- Group shared functions into ./include.sh file, which will be used by the scripts
- Update installation of dependencies. Include clipboard helper to preserve the responses.

## Add ./prompt script for prompting
- add script ./prompt which allows communication with the running ollama model with curl requests

## Dynamic pull of models
- Pull all ollama available models and store them into JSON file (using git repo Python dependency: `webfarmer/ollama-get-models`)
- select model and size to run
- store values into `.env` file and update on each run

## Update models and run script
- Update models list for running small models available on ollama
- update run script and dialog options
  - add ./run symlink for simplicity
- add .env.example.txt file to allow configurable running in the future using .env file

## Initial release
- Setup scripts to install Ollama
- Run example llama3 prompt
