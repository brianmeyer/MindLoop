# ML Models for MindLoop

**Required Models** (~1.1GB total - all MLX format):

## 1. Gemma 4 E2B-it (4-bit quantized)
**Source**: https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit
**Size**: ~1GB
**Format**: MLX 4-bit
**Purpose**: Coach response generation (any-to-any multimodal)
**License**: Apache 2.0

```bash
huggingface-cli download mlx-community/gemma-4-e2b-it-4bit \
  --local-dir gemma-4-e2b-it-4bit
```

## 2. gte-small (4-bit quantized)
**Source**: https://huggingface.co/mlx-community/gte-small
**Size**: ~15MB
**Format**: MLX 4-bit
**Purpose**: Text embeddings (384-dim, <50ms latency)

```bash
huggingface-cli download mlx-community/gte-small \
  --local-dir gte-small-4bit
```

## STT
Uses iOS 26 native SpeechAnalyzer — no model download needed.

---

## Installation

1. Download models using commands above
2. Place in `Resources/Models/`:
```
Resources/Models/
├── gemma-4-e2b-it-4bit/
│   ├── model.safetensors
│   ├── tokenizer.json
│   └── config.json
└── gte-small-4bit/
    ├── model.safetensors
    ├── tokenizer.json
    └── config.json
```
3. Add to Xcode project (ensure "Copy Bundle Resources")
4. Models are gitignored (too large for git)

## Memory Budget

| Model | Resident Memory |
|-------|----------------|
| Gemma 4 E2B (4-bit) | ~1.5GB |
| gte-small (4-bit) | ~50MB |
| **Total** | **~1.6GB** |
