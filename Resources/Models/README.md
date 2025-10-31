# ML Models for MindLoop

**Required Models** (2.4GB total - all MLX format):

## 1. Qwen3-Instruct 4B (INT4 quantized)
**Source**: https://huggingface.co/lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit
**Size**: ~2.1GB
**Format**: MLX (ready for MLX Swift)
**Purpose**: Coach response generation

```bash
# Download using hf (huggingface-cli)
hf download lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit \
  --local-dir qwen3-4b-instruct-mlx
```

## 2. Qwen3-Embedding-0.6B (4-bit DWQ)
**Source**: https://huggingface.co/mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ
**Size**: ~320MB
**Format**: MLX (official mlx-community conversion)
**Purpose**: Vector embeddings (462-dim, <200ms latency)
**Output**: 462-dimensional vectors for semantic search

```bash
# Download using hf
hf download mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ \
  --local-dir qwen3-embedding-0.6b-4bit
```

## 3. WhisperKit Model
**Source**: Auto-downloaded by WhisperKit framework
**Size**: Varies by model size
**Format**: CoreML
**Purpose**: Speech-to-text

Note: WhisperKit downloads models automatically on first use.

---

## Installation

1. Create Resources/Models directory
2. Download models using scripts above
3. Generate SHA-256 checksums:
```bash
shasum -a 256 qwen3-instruct-4b-mlx/* > checksums.sha256
```
4. Add to Xcode project

## Verification

All models downloaded successfully:
```
Resources/Models/
├── qwen3-4b-instruct-mlx/        # ✅ Downloaded (2.1GB)
│   ├── model.safetensors
│   ├── tokenizer.json
│   └── config.json
└── qwen3-embedding-0.6b-4bit/    # ✅ Downloaded (~320MB)
    ├── model.safetensors
    ├── tokenizer.json
    └── config.json
```

**Total Size**: ~2.4GB (all MLX format for optimal Apple Silicon performance)

## Architecture: Single Embedding Model

**Why Qwen3-Embedding-0.6B for all embeddings?**
- **Fast enough**: <200ms for 462-dim embeddings (acceptable for real-time)
- **Consistent**: Single embedding space (no mixing different models)
- **Quality**: Better than tiny models, trained on multilingual data
- **Efficient**: 4-bit quantization, only 320MB memory
- **Unified**: Same MLX runtime as LLM

Previous architecture used dual-mode (fast 384-dim + quality 768-dim), but the single 462-dim model provides better consistency and simplicity while meeting latency requirements.
