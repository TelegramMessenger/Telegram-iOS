#!/bin/sh

# Default directories
OUTPUT_DIR=""
INPUT_DIR=""
BINARY_PATH=""

# Parse command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --binary)
            BINARY_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --input)
            INPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate output directory
if [ -z "$OUTPUT_DIR" ]; then
    echo "Error: --output argument is required"
    exit 1
fi

# Validate output directory
if [ -z "$BINARY_PATH" ]; then
    echo "Error: --binary argument is required"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Validate input directory
if [ -z "$INPUT_DIR" ]; then
    echo "Error: --input argument is required"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory does not exist: $INPUT_DIR"
    exit 1
fi

# Remove existing Swift files from output directory
rm -f "$OUTPUT_DIR"/*.swift

# Get all .fbs files in Models directory
models=$(ls "$INPUT_DIR"/*.fbs)

# Initialize empty flatc_input
flatc_input=""

# Build space-separated list of model paths
for model in $models; do
    flatc_input="$flatc_input $model"
done

$BINARY_PATH --require-explicit-ids --swift -o "$OUTPUT_DIR" ${flatc_input}
