# Install from this

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
ffmpeg -i video1906971204.mp4 -map 0:a:0 -c:a copy output.m4a
cp output.m4a ~/_fr/tts/input.m4a
```

## High CPU

```shell
TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 \
uv run whisperx input.m4a \
  --device cpu \
  --compute_type float32 \
  --model large-v3 \
  --language hu \
  --threads 12 \
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
