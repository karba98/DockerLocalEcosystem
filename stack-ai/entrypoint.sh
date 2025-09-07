#!/bin/sh
echo "Starting ollama server..."
ollama serve &
sleep 5
echo "Pulling llama2 model..."
ollama pull llama2
echo "Waiting for background processes to finish..."
wait
echo "Done!"
