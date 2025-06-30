#!/bin/bash

source ./include.sh
source ./.env

curl http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "deepseek-coder:1.3b",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": "Write a Python script to calculate the factorial of a number."
            }
        ]
    }'