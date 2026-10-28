#!/usr/bin/env bash
set -euo pipefail

cd /workspace/tts

# Required environment variables
for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY R2_ENDPOINT R2_BUCKET; do
    if [[ -z "${!var:-}" ]]; then
        echo "Missing environment variable: $var" >&2
        exit 1
    fi
done

mkdir -p audio output

# Download audio files
aws s3 sync \
    "s3://${R2_BUCKET}/audio/" \
    ./audio/ \
    --endpoint-url "$R2_ENDPOINT"

# Restore existing subtitles
aws s3 sync \
    "s3://${R2_BUCKET}/subtitles/" \
    ./output/ \
    --endpoint-url "$R2_ENDPOINT"

shopt -s nullglob

for file in audio/*.m4a audio/*.mp3; do
    name=$(basename "${file%.*}")
    result="output/${name}.srt"

    if [[ -s "$result" ]]; then
        echo "SKIP: $name"
        continue
    fi

    echo "PROCESSING: $file"

    TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 \
    uv run whisperx "$file" \
        --device cuda \
        --compute_type float16 \
        --model large-v3 \
        --language hu \
        --batch_size 16 \
        --output_format srt \
        --output_dir ./output \
        --print_progress True

    test -s "$result"

    # Upload immediately after completion
    aws s3 cp "$result" \
        "s3://${R2_BUCKET}/subtitles/${name}.srt" \
        --endpoint-url "$R2_ENDPOINT"

    echo "DONE: $name"
done

echo "ALL DONE"
