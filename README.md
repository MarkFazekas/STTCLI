# Install from this for CPU

```shell
mkdir -p ~/_fr/
git clone https://github.com/MarkFazekas/TTSCLI.git
cd ~/_fr/TTSCLI

sudo apt update -y
sudo apt install -y ffmpeg

uv python install 3.11
uv sync --locked
```

# Usage

```shell
ffmpeg -i video2271575718.mp4 -map 0:a:0 -c:a copy video2271575718.m4a
cp output.m4a ~/_fr/tts/input.m4a
```

## GPU Batch on Runpod

```shell
apt-get update
apt-get install -y git curl ffmpeg

curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

cd /root
git clone https://github.com/MarkFazekas/TTSCLI.git
cd TTSCLI

uv python install 3.11

sed -i \
  -e 's/pytorch-cpu/pytorch-cu128/g' \
  -e 's|https://download.pytorch.org/whl/cpu|https://download.pytorch.org/whl/cu128|g' \
  pyproject.toml

uv lock
uv sync --locked

uv tool install awscli
```

```shell
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY" \
       AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY" \
       AWS_DEFAULT_REGION="auto" \
       R2_ENDPOINT="https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com" \
       R2_BUCKET="YOUR_BUCKET"
```

```shell
chmod +x batch.sh
./batch.sh 2>&1 | tee batch.log
```

## High CPU

```shell
TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 \
uv run whisperx input.m4a \
  --device cpu \
  --compute_type float32 \
  --model large-v3 \
  --language hu \
  --threads 8 \
  --batch_size 4 \
  --output_format srt \
  --output_dir ./output \
  --print_progress True
```

## Low CPU

```shell
TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 \
uv run whisperx input.m4a \
  --device cpu \
  --compute_type int8 \
  --model large-v3-turbo \
  --language hu \
  --threads 6 \
  --batch_size 4 \
  --output_format srt \
  --output_dir ./output \
  --print_progress True
```

# First install

```shell
mkdir ~/_fr/tts
cd ~/_fr/tts
```

## Project ini

```shell
uv init --bare --python 3.11
uv python pin 3.11
```

## CPU-only PyTorch

```shell
uv add \
  "torch==2.8.0" \
  "torchaudio==2.8.0" \
  "torchvision==0.23.0" \
  --index pytorch-cpu=https://download.pytorch.org/whl/cpu
```
## WhisperX and dependencies

```shell
uv add whisperx

sudo apt install -y ffmpeg
```

# Usage

```shell
ffmpeg -i input.mp4 -map 0:a:0 -c:a copy output.m4a

TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 \
uv run whisperx input.m4a \
  --device cpu \
  --compute_type int8 \
  --model large-v3-turbo \
  --language hu \
  --threads 6 \
  --batch_size 4 \
  --output_format srt \
  --output_dir ./output \
  --print_progress True
```
