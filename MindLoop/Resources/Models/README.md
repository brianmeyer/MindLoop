# MindLoop Models

Models are not checked into git (too large). Download them with the script below.

## Models

| Model | HuggingFace ID | Size | Purpose |
|-------|---------------|------|---------|
| bge-small-en-v1.5 | BAAI/bge-small-en-v1.5 | ~35MB (quantized) | Embeddings (384-dim, MTEB 58.6) |
| Gemma 4 E2B-it 4bit | mlx-community/gemma-4-e2b-it-4bit | ~1GB | LLM (coaching, transcription) |

## Download

```bash
# Install HuggingFace CLI if needed
brew install huggingface-cli

# Download embedding model
hf download BAAI/bge-small-en-v1.5 --local-dir MindLoop/Resources/Models/bge-small-en-v1.5

# Download LLM
hf download mlx-community/gemma-4-e2b-it-4bit --local-dir MindLoop/Resources/Models/gemma-4-e2b-it-4bit
```

## Verification

After download, verify the directories exist:
```
MindLoop/Resources/Models/
├── bge-small-en-v1.5/
│   ├── config.json
│   ├── model.safetensors
│   └── tokenizer.json
├── gemma-4-e2b-it-4bit/
│   ├── config.json
│   ├── model*.safetensors
│   └── tokenizer.json
└── README.md
```
