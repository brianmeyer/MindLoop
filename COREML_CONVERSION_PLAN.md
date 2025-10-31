# CoreML Conversion Plan for MindLoop

**Created**: October 31, 2025
**Status**: Planning Phase
**Goal**: Convert all ML models to CoreML for iPhone device testing and broader compatibility

---

## Executive Summary

MindLoop currently uses **MLX format** for all models (Qwen3-Instruct 4B, Qwen3-Embedding 0.6B). While MLX is optimized for Apple Silicon and offers superior performance, it has a critical limitation:

⚠️ **MLX requires Metal GPU and cannot run on iOS Simulator**

This blocks development velocity and testing. We need a strategy to enable device testing while maintaining the performance benefits of MLX for production.

---

## Current Model Inventory

| Model | Current Format | Size | Purpose | Status |
|-------|---------------|------|---------|--------|
| **Qwen3-Instruct 4B** (INT4) | MLX | 2.1 GB | LLM coaching responses | ✅ Downloaded (MLX) |
| **Qwen3-Embedding 0.6B** (4-bit DWQ) | MLX | 320 MB | 462-dim embeddings | ✅ Downloaded (MLX) |
| **LoRA Adapters** (tone) | SafeTensors | 45 MB | Fine-tuned response style | 📋 Planned |
| **OpenSMILE** | C++ Library | N/A | Prosody/acoustic features | ❌ Not integrated |
| **WhisperKit** | CoreML | Auto-download | Speech-to-text | ✅ Already CoreML |

**Note**: `STTService.swift` currently uses **Apple Speech Framework** (native iOS), not WhisperKit. CLAUDE.md references WhisperKit but it's not implemented yet.

---

## The CoreML Challenge: LLM Conversion Complexity

### Why Converting Qwen3 to CoreML is Non-Trivial

Unlike simple image models, large language models (LLMs) present unique conversion challenges:

1. **Model Architecture Complexity**
   - Transformer architecture with attention mechanisms
   - KV-cache for efficient autoregressive generation
   - Dynamic sequence lengths
   - Token streaming support

2. **Quantization Preservation**
   - Qwen3 is INT4 quantized (2.1GB vs ~16GB fp32)
   - CoreML quantization differs from MLX DWQ
   - May need to requantize or accept larger model size

3. **Toolchain Limitations**
   - `coremltools` has limited support for recent transformers
   - May not support all Qwen3 operations (RoPE, GQA, etc.)
   - LoRA adapters are not natively supported in CoreML

4. **Performance Trade-offs**
   - CoreML's NeuralEngine optimized for CNN/Vision, not LLMs
   - May not achieve <2s response target with CoreML
   - MLX is 2-3x faster for LLMs on Apple Silicon

---

## Recommended Strategy: Dual-Runtime Architecture

Instead of replacing MLX with CoreML, use **both** strategically:

### Option A: **MLX-First with CoreML Fallback** (Recommended)

```
Development/Simulator: CoreML runtime (slower, compatible)
Production/Device: MLX runtime (fast, Metal-dependent)
```

**Implementation**:
```swift
class ModelRuntime {
    #if targetEnvironment(simulator)
    let backend: ModelBackend = CoreMLBackend()
    #else
    let backend: ModelBackend = canUseMetal() ? MLXBackend() : CoreMLBackend()
    #endif
}
```

**Pros**:
- ✅ Simulator testing enabled
- ✅ Keep MLX performance on device
- ✅ Graceful fallback for older devices

**Cons**:
- ❌ Maintain two model formats (~5GB storage)
- ❌ Dual implementation complexity
- ❌ Conversion effort still required

---

### Option B: **Physical Device Testing Only** (Simplest)

Skip CoreML conversion entirely and require physical iPhone for testing.

**Pros**:
- ✅ No conversion work
- ✅ Single runtime to maintain
- ✅ Optimal performance always

**Cons**:
- ❌ Slower development (no simulator testing)
- ❌ Requires physical device access
- ❌ No CI/CD simulator tests

---

### Option C: **CoreML-Only** (Not Recommended)

Convert everything to CoreML and abandon MLX.

**Pros**:
- ✅ Simulator compatibility
- ✅ Single runtime

**Cons**:
- ❌ 2-3x slower LLM inference (may miss <2s target)
- ❌ Complex conversion for Qwen3
- ❌ LoRA hot-swapping not supported
- ❌ Loses MLX advantages entirely

---

## Detailed Conversion Plans by Model

### 1. Qwen3-Instruct 4B → CoreML

**Difficulty**: ⚠️ **High**
**Estimated Effort**: 20-30 hours
**Recommended Approach**: Use Hugging Face `transformers` + `coremltools`

#### Step-by-Step Conversion:

```bash
# 1. Install conversion tools
pip install coremltools transformers torch

# 2. Download Qwen3 from Hugging Face (fp16 version)
git lfs install
git clone https://huggingface.co/Qwen/Qwen3-4B-Instruct

# 3. Convert to CoreML using Python script
python convert_qwen3_to_coreml.py

# 4. Quantize to INT8 or FP16 (INT4 may not be supported)
coremltools quantize --model qwen3-4b.mlpackage --output qwen3-4b-int8.mlpackage

# 5. Test inference
python test_coreml_inference.py
```

**Conversion Script Template** (`convert_qwen3_to_coreml.py`):
```python
import coremltools as ct
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

# Load model
model = AutoModelForCausalLM.from_pretrained(
    "Qwen/Qwen3-4B-Instruct",
    torch_dtype=torch.float16,
    trust_remote_code=True
)
tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3-4B-Instruct")

# Trace model (requires example input)
example_input = tokenizer("Hello", return_tensors="pt").input_ids

traced_model = torch.jit.trace(model, example_input)

# Convert to CoreML
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="input_ids", shape=(1, ct.RangeDim(1, 512)))],
    outputs=[ct.TensorType(name="logits")],
    minimum_deployment_target=ct.target.iOS18,
    compute_units=ct.ComputeUnit.ALL
)

# Save
mlmodel.save("qwen3-4b-coreml.mlpackage")
```

**Challenges**:
- ⚠️ May fail if Qwen3 uses unsupported ops (RoPE embeddings, GQA)
- ⚠️ Autoregressive generation requires KV-cache (complex to implement)
- ⚠️ Token streaming requires custom wrapper

**Alternative**: Use a **smaller, CoreML-friendly model** for simulator testing only:
- **GPT-2** (already has CoreML conversions available)
- **DistilGPT-2** (faster, smaller)
- Accept reduced quality for dev/test

---

### 2. Qwen3-Embedding 0.6B → CoreML

**Difficulty**: ⭐ **Medium**
**Estimated Effort**: 4-6 hours
**Recommended Approach**: Use sentence-transformers export

#### Conversion Steps:

```bash
# 1. Install tools
pip install sentence-transformers coremltools

# 2. Convert using sentence-transformers
python convert_embeddings_to_coreml.py
```

**Conversion Script** (`convert_embeddings_to_coreml.py`):
```python
import coremltools as ct
from sentence_transformers import SentenceTransformer
import torch

# Load model (may need to use compatible alternative)
# Qwen3-Embedding might not be in sentence-transformers
# Alternative: Use all-MiniLM-L6-v2 (384-dim, already has CoreML conversions)

model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

# Trace encoder
example_input = {
    'input_ids': torch.randint(0, 30000, (1, 128)),
    'attention_mask': torch.ones((1, 128), dtype=torch.long)
}

traced_model = torch.jit.trace(model[0], example_input)

# Convert to CoreML
mlmodel = ct.convert(
    traced_model,
    inputs=[
        ct.TensorType(name="input_ids", shape=(1, ct.RangeDim(1, 512))),
        ct.TensorType(name="attention_mask", shape=(1, ct.RangeDim(1, 512)))
    ],
    minimum_deployment_target=ct.target.iOS18
)

mlmodel.save("embeddings-coreml.mlpackage")
```

**Easier Alternative**: Use pre-converted CoreML embeddings:
- **MiniLM-L6** (384-dim, 80MB) - Already has CoreML versions
- **MPNet** (768-dim, 420MB) - Higher quality, still CoreML-compatible
- Accept different dimensions than 462-dim Qwen3

---

### 3. LoRA Adapters → CoreML

**Difficulty**: ⚠️ **Very High**
**Status**: ❌ **Not Supported in CoreML**

CoreML does not natively support LoRA (Low-Rank Adaptation) hot-swapping. Options:

**Option 1: Merge LoRA into Base Model**
- Merge each LoRA adapter into Qwen3 base weights
- Convert merged model to CoreML
- Result: Multiple 2GB+ models instead of one base + small adapters
- ❌ Loses hot-swap capability

**Option 2: Skip LoRA for CoreML**
- Only use LoRA with MLX backend
- CoreML backend uses base model only
- ✅ Acceptable for testing

**Option 3: Manual Implementation**
- Implement LoRA math in Swift using Accelerate
- Apply low-rank updates at runtime
- ⚠️ Complex, error-prone, likely slower

**Recommendation**: **Skip LoRA for CoreML backend** (Option 2)

---

### 4. OpenSMILE (Prosody Analysis)

**Type**: C++ Library (not a model)
**Status**: Not integrated yet
**No conversion needed** - this is a signal processing library

#### Integration Options:

**Option A: Swift Wrapper Around OpenSMILE C++**
```swift
// Create Swift → C++ bridge
@_cdecl("extractProsody")
func extractProsody(_ audio: UnsafePointer<Float>, _ length: Int) -> ProsodyFeatures
```

**Option B: Pure Swift Implementation**
- Use Accelerate framework for FFT, windowing
- Implement pitch detection (autocorrelation or cepstrum)
- Extract energy, zero-crossing rate

**Option C: Skip Prosody for MVP**
- Use text sentiment only (from LLM)
- Add prosody in Phase 4+

**Recommendation**: **Option C** (defer prosody to later phase)

---

### 5. WhisperKit (Already CoreML)

**Status**: ✅ **No action needed**

WhisperKit already provides CoreML models. However, current code uses **Apple Speech Framework** instead.

**Current**: `STTService.swift` uses `SFSpeechRecognizer` (native iOS)
**Documented**: CLAUDE.md references WhisperKit

**Recommendation**: **Keep Apple Speech Framework** (simpler, on-device, no model download)

---

## Recommended Implementation Plan

### Phase 1: Enable Device Testing (This Week)

**Goal**: Get basic testing working on physical iPhone

1. ✅ **Use physical device for now** (skip CoreML conversion)
2. ✅ **Download MLX models** to device via Xcode
3. ✅ **Run ModelRuntimeTests** on iPhone
4. ✅ **Fix embedding extraction** (current placeholder)

**Time**: 4-6 hours
**Blocker Removed**: Can test Phases 3-4 on device

---

### Phase 2: Minimal CoreML for Simulator (Next Week)

**Goal**: Enable basic simulator testing without full model conversion

1. **Replace Qwen3-Instruct with GPT-2** (simulator only)
   - Download pre-converted GPT-2 CoreML model
   - Accept lower quality for dev/test
   - ~1.5GB instead of 2.1GB

2. **Use MiniLM for embeddings** (simulator only)
   - 384-dim instead of 462-dim
   - Pre-converted CoreML available
   - ~80MB

3. **Feature flag runtime selection**:
   ```swift
   #if targetEnvironment(simulator)
   let modelPath = "gpt2-coreml.mlpackage"
   #else
   let modelPath = "qwen3-4b-instruct-mlx"
   #endif
   ```

**Time**: 8-12 hours
**Result**: Simulator tests work, device uses production models

---

### Phase 3: Full Qwen3 CoreML (Optional, Month 2+)

**Only if needed** for:
- CI/CD simulator tests
- Older devices without Metal 3
- TestFlight beta testing

**Time**: 20-30 hours
**Risk**: May not achieve <2s latency target

---

## Model Storage Strategy

With dual-runtime, bundle structure:

```
Resources/Models/
├── mlx/                                    # Production (device only)
│   ├── qwen3-4b-instruct-mlx/              # 2.1GB
│   └── qwen3-embedding-0.6b-4bit/          # 320MB
├── coreml/                                 # Development (simulator)
│   ├── gpt2-small.mlpackage                # 500MB (temporary dev model)
│   └── minilm-embeddings.mlpackage         # 80MB
└── README.md

Total Size:
- MLX only: 2.4GB
- CoreML only: 580MB
- Dual (if both bundled): ~3GB
```

**Shipping**: Only include MLX models in production app (exclude CoreML from release build)

---

## Testing Requirements

### Device Testing (MLX Backend)

**Required Hardware**: iPhone 15 Pro or later (Metal 3 GPU)
**iOS Version**: iOS 18.0+
**Xcode**: 16.0+

**Test Plan**:
1. ✅ Model loading (<3s)
2. ✅ Embedding generation (<200ms for 462-dim)
3. ✅ LLM generation (<2s for 120 tokens)
4. ✅ Memory usage (<3.5GB resident)
5. ✅ Streaming token output

### Simulator Testing (CoreML Backend)

**Simulators**: iPhone 16 Pro, iPhone 15, iPad Pro
**Acceptance Criteria**: Tests pass, latency not critical (dev only)

---

## Key Decisions Needed

Before proceeding, confirm:

1. **Do we need simulator support?**
   - [ ] Yes → Implement dual-runtime (Phase 2)
   - [ ] No → Physical device only (Phase 1)

2. **CoreML conversion priority?**
   - [ ] High (start this week)
   - [ ] Medium (after Phase 3 agents work)
   - [ ] Low (defer to Month 2+)

3. **Accept temporary dev models?**
   - [ ] Yes → Use GPT-2 + MiniLM for simulator
   - [ ] No → Full Qwen3 conversion required

4. **OpenSMILE prosody integration?**
   - [ ] Implement now (adds 1-2 weeks)
   - [ ] Defer to Phase 4+
   - [ ] Skip entirely (text sentiment only)

---

## Conversion Tools & Resources

### Required Software:
```bash
# Python environment
pip install coremltools torch transformers sentence-transformers

# Hugging Face CLI
pip install huggingface-hub
huggingface-cli login

# MLX (already installed via SPM)
# No additional tools needed for MLX
```

### Useful Resources:
- **CoreML Conversion Guide**: https://apple.github.io/coremltools/docs-guides/source/convert-pytorch.html
- **Qwen3 Model Card**: https://huggingface.co/Qwen/Qwen3-4B-Instruct
- **Pre-converted CoreML Models**: https://huggingface.co/apple (Apple's official models)
- **MLX Swift Examples**: https://github.com/ml-explore/mlx-swift-examples

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Qwen3 conversion fails | High | Use GPT-2 for simulator testing |
| CoreML too slow (<2s) | Medium | Keep MLX for production, CoreML for dev only |
| Model size bloat (>3GB) | Medium | Ship MLX only, exclude CoreML from release |
| OpenSMILE integration complex | Low | Defer prosody, use text sentiment only |
| LoRA not supported in CoreML | Low | Skip LoRA for CoreML backend |

---

## Next Steps (Immediate)

1. **Decide on strategy** (Option A, B, or C above)
2. **Download MLX models** to physical device
3. **Test ModelRuntime** on iPhone
4. **Fix embedding extraction** (replace placeholder)
5. **Run Phase 2 tests** on device

**After device testing works:**
6. Decide if CoreML conversion is needed
7. If yes, start with embeddings (easier)
8. Consider GPT-2 temp model for simulator

---

## Estimated Timeline

| Task | Duration | Dependencies |
|------|----------|--------------|
| **Device testing (MLX)** | 4-6 hours | Physical iPhone 15+ |
| **Fix embedding extraction** | 2-4 hours | Device testing working |
| **Embedding → CoreML** | 4-6 hours | Python + coremltools |
| **LLM → CoreML (Qwen3)** | 20-30 hours | Conversion expertise |
| **LLM → CoreML (GPT-2)** | 2-4 hours | Use pre-converted |
| **Dual-runtime architecture** | 8-12 hours | Both model formats ready |
| **OpenSMILE integration** | 15-20 hours | C++ bridge + testing |

**Critical Path**: Device testing → Embedding fix → Phase 3 agents (no CoreML needed)

---

## Recommendation

**Start with Option B** (Physical Device Testing Only):

1. ✅ Test on iPhone this week
2. ✅ Fix embedding extraction
3. ✅ Complete Phase 3 (Core Agents) on device
4. ⏳ Defer CoreML conversion until after MVP works

**Rationale**:
- Fastest path to working prototype
- MLX is required for production anyway
- CoreML conversion is risky and time-consuming
- Simulator testing is "nice to have" not "must have"
- Can always add CoreML later if needed

**If simulator support is critical**, implement **Option A** (Dual-Runtime) with temporary dev models (GPT-2 + MiniLM).

---

**Author**: Claude Code
**Review Status**: Pending user decision on strategy
**Last Updated**: October 31, 2025
