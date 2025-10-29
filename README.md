# AI Runner

Runner for AI models in the local system.
Allows to quickly run models available on ollama website with a single command.

Models available at: https://ollama.com/search


# Run the model and install

Run the command:

`./run [-i] [-m <model>] [-p]`

Parameters: 

- `-i`          : install dependencies and ollama
- `-m <model>`  : define the model to use
- `-p <prompt>` : run the prompt command right away

Example:

```sh
./run
```

If NO MODEL was selected, a selector will be displayed - so you can pick one that is available on Ollama:

<img width="1121" height="566" alt="image" src="https://github.com/user-attachments/assets/661c89a0-a6cb-46e7-8b8c-fdf89c95d95e" />


# Run the prompt in existing model

If you already set up the model, size and have run the steps under `./run`, you can run the prompt directly, using the Curl request and see the results in the dialog:

```
./prompt
```

![image](https://github.com/user-attachments/assets/eb3512a6-c13f-467e-8fc4-04d406d97ec9)


# Only download the models

You can also only download the models for your use and later access them from your local.

TBD

# Run prompts as CURL

You can run prompts against the running model via curl commands:

Example:

```
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"llama3\",  \"prompt\":\"Tell me about the meaning of life.\", \"stream\": false}"
``` 

# Endpoints

- http://localhost:11434/api/tags
- http://localhost:11434/api/generate


Check parameters of the currently installed model:

First, check what is the installed (and running) model. It should reflect what's in the `.env` file.

Run:

```
source .env
ollama show --modelfile $MODEL
```

