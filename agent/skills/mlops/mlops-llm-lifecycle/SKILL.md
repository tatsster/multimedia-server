---
name: mlops-llm-lifecycle
description: "Class-level ML/LLM operations: Hub access, inference serving, fine-tuning, evaluation, experiment tracking, structured generation, and model utilities."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [MLOps, LLMs, HuggingFace, Fine-Tuning, Inference, Evaluation, Experiment-Tracking]
---

# MLOps and LLM Lifecycle

Use this umbrella when the user asks for model discovery/download/upload, local or hosted LLM inference, fine-tuning, evaluation, experiment tracking, structured generation, or model/image utility workflows.

## Hub and artifact management

Use Hugging Face Hub workflows for searching, downloading, uploading, and versioning models/datasets. Confirm auth and storage paths; avoid downloading large artifacts without checking disk and model size.

## Inference and serving

- `llama.cpp` for local GGUF inference and CPU/GPU local testing.
- `vLLM` for high-throughput OpenAI-compatible serving, batching, quantization, and deployment-style inference.
- Structured generation tools such as Outlines when the output must conform to JSON, regex, or Pydantic-like schemas.

## Declarative LM programming and optimization

For DSPy-style declarative LM programs, signatures/modules, prompt optimization, RAG pipelines, and data-driven eval loops, treat them as part of the model lifecycle. The archived `dspy` package contains detailed module, optimizer, and example references; restore/re-home it if exact DSPy API snippets are needed.

## Fine-tuning and adaptation

Use Axolotl, TRL, or Unsloth depending on training style and hardware: YAML-driven LoRA/DPO/GRPO, RLHF-style workflows, or faster low-VRAM LoRA/QLoRA. Always capture dataset, base model, adapter/output path, hyperparameters, and eval plan.

## Evaluation and tracking

Use lm-evaluation-harness for benchmark suites such as MMLU/GSM8K. Use Weights & Biases for experiment logging, sweeps, model registry, and dashboards. Make results reproducible with exact command lines and config files.

## Model and media utilities

Use Segment Anything for zero-shot segmentation with points/boxes/masks. Use AudioCraft for MusicGen/AudioGen-style generation if the task is model-operation focused; use the media umbrella when the user is asking creatively.

## Safety and verification

Check hardware, VRAM, disk, licenses, and model access before running. For long jobs, run in tracked background sessions with completion notifications. Return verifiable outputs: config path, run ID, model/adaptor path, benchmark table, or server health endpoint.
