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

