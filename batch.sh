#!/usr/bin/env bash
set -euo pipefail

# Always execute from the script's directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# ---------------------------------------------
# Configuration
# ---------------------------------------------

INPUT_PREFIX="audio"
OUTPUT_PREFIX="subtitles"

MODEL="large-v3"
LANGUAGE="hu"
BATCH_SIZE=16
COMPUTE_TYPE="float16"

MODE="${1:---per-file}"
if (( $# > 1 )) || [[ "$MODE" != "--per-file" && "$MODE" != "--all" ]]; then
    echo "Usage: $0 [--per-file|--all]" >&2
    exit 2
fi

# ---------------------------------------------
# Validate environment
# ---------------------------------------------

for var in \
    AWS_ACCESS_KEY_ID \
    AWS_SECRET_ACCESS_KEY \
    R2_ENDPOINT \
    R2_BUCKET
do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: Missing environment variable: $var" >&2
        exit 1
    fi
done

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"

for cmd in aws uv ffmpeg; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Command not found: $cmd" >&2
        exit 1
    fi
done

mkdir -p audio output .work

# ---------------------------------------------
# Verify GPU
# ---------------------------------------------

uv run --no-sync python - <<'PY'
import torch
import ctranslate2

assert torch.cuda.is_available(), "CUDA is not available"

supported = ctranslate2.get_supported_compute_types("cuda")
assert "float16" in supported, f"FP16 not supported: {supported}"

print(f"GPU: {torch.cuda.get_device_name(0)}")
print(f"PyTorch: {torch.__version__}")
print(f"CUDA: {torch.version.cuda}")
print(f"Compute types: {supported}")
PY

# ---------------------------------------------
# Download audio files from R2
# ---------------------------------------------

echo "Downloading audio files from R2..."

aws s3 sync \
    "s3://${R2_BUCKET}/${INPUT_PREFIX}/" \
    ./audio/ \
    --endpoint-url "$R2_ENDPOINT" \
    --only-show-errors

# Restore previously completed subtitles
echo "Restoring existing subtitles..."

aws s3 sync \
    "s3://${R2_BUCKET}/${OUTPUT_PREFIX}/" \
    ./output/ \
    --endpoint-url "$R2_ENDPOINT" \
    --only-show-errors

# ---------------------------------------------
# Collect audio files
# ---------------------------------------------

shopt -s nullglob

files=(audio/*.m4a audio/*.mp3)

if (( ${#files[@]} == 0 )); then
    echo "ERROR: No audio files found!" >&2
    exit 1
fi

# Prevent output filename collisions
declare -A seen=()

for file in "${files[@]}"; do
    name=$(basename "${file%.*}")

    if [[ -n "${seen[$name]:-}" ]]; then
        echo "ERROR: Duplicate filename stem: $name" >&2
        exit 1
    fi

    seen[$name]=1
done

echo "Found ${#files[@]} audio files."

# ---------------------------------------------
# Transcription
# ---------------------------------------------

transcribe_files() {
    local target_dir="$1"
    shift

    TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 \
    uv run --no-sync whisperx "$@" \
        --device cuda \
        --compute_type "$COMPUTE_TYPE" \
        --model "$MODEL" \
        --language "$LANGUAGE" \
        --batch_size "$BATCH_SIZE" \
        --output_format srt \
        --output_dir "$target_dir" \
        --print_progress True
}

completed=0
skipped=0

if [[ "$MODE" == "--all" ]]; then
    missing=()
    for file in "${files[@]}"; do
        name=$(basename "${file%.*}")
        [[ -s "output/${name}.srt" ]] || missing+=("$file")
    done

    completed=${#missing[@]}
    skipped=$(( ${#files[@]} - completed ))

    if (( completed > 0 )); then
        echo "PROCESSING $completed missing files in one WhisperX process"
        start_time=$SECONDS
        tmpdir=$(mktemp -d "./.work/all.XXXXXX")

        transcribe_files "$tmpdir" "${missing[@]}"

        # Do not treat an incomplete multi-file run as successful.
        for file in "${missing[@]}"; do
            name=$(basename "${file%.*}")
            test -s "${tmpdir}/${name}.srt" || {
                echo "ERROR: Missing or empty SRT: ${tmpdir}/${name}.srt" >&2
                exit 1
            }
        done

        for file in "${missing[@]}"; do
            name=$(basename "${file%.*}")
            mv "${tmpdir}/${name}.srt" "output/${name}.srt"
        done
        rm -rf -- "$tmpdir"

        echo "Batch transcription completed in $((SECONDS - start_time))s"
    fi
fi

for file in "${files[@]}"; do
    name=$(basename "${file%.*}")
    result="output/${name}.srt"

    echo
    echo "========================================"
    echo "FILE: $file"
    echo "========================================"

    if [[ "$MODE" == "--all" ]]; then
        test -s "$result"
    elif [[ -s "$result" ]]; then
        echo "SKIP transcription: $name"
        ((skipped+=1))
    else
        echo "PROCESSING: $name"

        start_time=$SECONDS

        # Isolated temporary output directory
        tmpdir=$(mktemp -d "./.work/${name}.XXXXXX")

        transcribe_files "$tmpdir" "$file"

        temp_result="${tmpdir}/${name}.srt"

        if [[ ! -s "$temp_result" ]]; then
            echo "ERROR: Missing or empty SRT: $temp_result" >&2
            exit 1
        fi

        # Move completed result atomically
        mv "$temp_result" "$result"
        rm -rf -- "$tmpdir"

        elapsed=$((SECONDS - start_time))
        echo "Transcription completed in ${elapsed}s"

        ((completed+=1))
    fi

    # Always upload, even after a previous failed upload
    echo "Uploading: $result"

    aws s3 cp "$result" \
        "s3://${R2_BUCKET}/${OUTPUT_PREFIX}/${name}.srt" \
        --endpoint-url "$R2_ENDPOINT" \
        --only-show-errors

    echo "DONE: $name"
done

# ---------------------------------------------
# Summary
# ---------------------------------------------

echo
echo "========================================"
echo "ALL DONE"
echo "========================================"
echo "Mode: $MODE"
echo "Total files: ${#files[@]}"
echo "Processed: $completed"
echo "Skipped: $skipped"
echo "Results: s3://${R2_BUCKET}/${OUTPUT_PREFIX}/"
