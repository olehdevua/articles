## What is NIM

This stack lets you self-host open-weights AI models (like Llama, Mistral, or Gemma) on
your own Google Cloud infrastructure with minimal setup and maximum GPU throughput.

### The Two Core Pieces

* **NVIDIA NIM (The Engine):** Pre-built, optimized Docker containers for specific AI
  models. Instead of manually compiling models, managing CUDA dependencies, and
  configuring inference servers (like TensorRT-LLM or Triton), you pull a single NIM
  image. On startup, it detects your exact GPU hardware, pulls the optimal model weights,
  and exposes a standard **OpenAI-compatible REST API**.
* **GKE (The Infrastructure):** Google’s managed Kubernetes service. It provisions the
  virtual machines with attached NVIDIA GPUs (e.g., L4, A100, H100), automatically
  installs the host GPU drivers, routes network traffic, and scales containers up or down
  based on load.

---

### How You Actually Use It (Workflow)

1. **Spin up GPU compute in GKE:** Create a GKE cluster (Standard or Autopilot) with a GPU
   node pool.
2. **Pull the NIM container:** Get a free API key from NVIDIA NGC (their container
   registry), store it as a Kubernetes Secret, and deploy the NIM image using a standard
   Kubernetes Deployment or NVIDIA's official Helm chart.
3. **Expose the endpoint:** Put a Kubernetes Service or Load Balancer in front of the NIM
   pod.
4. **Query it from your app:** Point your existing application code (using standard OpenAI
   SDKs or `curl`) to your GKE endpoint instead of a public API.
5. **Autoscale:** Configure Kubernetes Horizontal Pod Autoscaler (HPA) using GPU/queue
   metrics so GKE spins up additional NIM replicas during traffic spikes and scales back
   down to save money when idle.

---

### Why Use This Over Public APIs (e.g., OpenAI, Gemini API)?

* **Data Privacy & Compliance:** Prompts and proprietary data never leave your Google
  Cloud VPC.
* **Cost & Throughput at Scale:** At high, sustained request volumes, paying flat hourly
  rates for dedicated GPUs is cheaper than paying per token.
* **Zero Lock-in:** Because NIM uses the OpenAI API schema, swapping models or moving the
  container to another cloud/on-prem Kubernetes cluster requires changing only the
  endpoint URL.

-----

## Gemma on NIM

To run a Gemma model locally on Linux using NVIDIA NIM, you only need the **NVIDIA GPU driver**,
**Docker**, and the **NVIDIA Container Toolkit** installed on your host
(no local CUDA toolkit required).


### 1. Authenticate & Prepare Cache

Generate a free API key at [build.nvidia.com](https://build.nvidia.com). Log Docker into NVIDIA's registry and create a
local cache directory so model weights persist across container restarts:
```bash
export NGC_API_KEY="nvapi-your-key-here"
echo "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin

export LOCAL_NIM_CACHE=~/.cache/nim
mkdir -p "$LOCAL_NIM_CACHE"
chmod -R a+w "$LOCAL_NIM_CACHE"
```

---

### 2. Run the Gemma NIM Container

Choose the image matching your available VRAM (e.g., `gemma-3-1b-it` / `gemma-2-9b-it` for
consumer GPUs, or `gemma-4-26b-a4b-it` / `gemma-4-31b-it` for high-VRAM/multi-GPU setups):

```bash
docker run -d --rm \
  --name gemma-nim \
  --gpus all \
  --ipc host \
  --shm-size=16GB \
  -e NGC_API_KEY \
  -v "$LOCAL_NIM_CACHE:/opt/nim/.cache" \
  -p 8000:8000 \
  nvcr.io/nim/google/gemma-4-26b-a4b-it:latest
```

*(Note: Some public-catalog Gemma NIM images support keyless runs without
`-e NGC_API_KEY`; adjust `--shm-size` based on model size—NVIDIA recommends `32GB` for the
31B variant.)*

On first boot, the container inspects your GPU architecture, downloads the optimal
TensorRT-LLM / vLLM engine profile into `~/.cache/nim`, and starts an OpenAI-compatible
server on port `8000`. Watch readiness via:

```bash
docker logs -f gemma-nim
```

---

### 3. Query the Local Endpoint

Once `/v1/health/ready` returns `200 OK`, query it using `curl` or any OpenAI SDK:

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-4-26b-a4b-it",
    "messages": [
      {"role": "user", "content": "Explain Kubernetes HPA in two sentences."}
    ],
    "max_tokens": 256
  }'

```

*(Verify the exact served `model` ID anytime via `curl -s http://localhost:8000/v1/models`.)*

-----


## NVIDIA NIM container on Linux

Use the docker pull command with the image path from the NVIDIA NGC registry (nvcr.io).
Most current public NIM images support keyless pulling, though gated or older versions require authentication.


### 1. Pull the NIM Container Image

Choose the command that matches the deployment type listed in the NVIDIA NIM Installation Guide:
* Model-Specific NIM. Pulls a container pre-configured for a specific model (e.g., Llama-3.1-8B-Instruct): [1]
  `docker pull nvcr.io/nim/meta/llama-3.1-8b-instruct:2.1.6`
* Model-Free NIM. Pulls a generic inference engine container (such as vLLM or SGLang) to run custom or local
  weights:
  `docker pull nvcr.io/nim/nvidia/vllm-model-free-nim:2.1.6`

### 2. Run the Container on Linux

Once pulled, launch the microservice with GPU access and a local cache directory so model weights persist across
restarts:
```bash
mkdir -p ~/.cache/nim
docker run -it --rm \
    --gpus all \
    --shm-size=16GB \
    -e NGC_API_KEY="$NGC_API_KEY" \
    -v ~/.cache/nim:/opt/nim/.cache \
    -p 8000:8000 \
    nvcr.io/nim/meta/llama-3.1-8b-instruct:2.1.6
```

### Linux Prerequisites

Before running the container, verify that your Linux host meets the baseline stack requirements:
* NVIDIA GPU Driver. Branch 580 or later.
* Docker Engine. Version 24.0 or later.
* NVIDIA Container Toolkit. Version 1.14.0 or later, configured with sudo nvidia-ctk runtime configure
  `--runtime=docker && sudo systemctl restart docker`.

If you share:
* Your GPU model (e.g., H100, L40S, RTX 4090)
* Your Linux distribution and driver version
* The specific AI model you want to deploy
