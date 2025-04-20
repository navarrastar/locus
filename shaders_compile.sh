if [ $# -ne 1 ]; then
    echo "Usage: $0 <hlsl_shaders_directory>"
    exit 1
fi

HLSL_DIR="$1"
# Get the parent directory of the HLSL directory
PARENT_DIR=$(dirname "$HLSL_DIR")
# Create the MSL directory path
MSL_DIR="$PARENT_DIR/msl"

# Check if HLSL directory exists
if [ ! -d "$HLSL_DIR" ]; then
    echo "Error: HLSL directory '$HLSL_DIR' does not exist"
    exit 1
fi

# Create MSL directory if it doesn't exist
mkdir -p "$MSL_DIR"

# Loop through all .hlsl files in the HLSL directory
for hlsl_file in "$HLSL_DIR"/*.hlsl; do
    # Check if there are any .hlsl files
    if [ ! -e "$hlsl_file" ]; then
        echo "No .hlsl files found in $HLSL_DIR"
        exit 1
    fi

    # Get the base filename without the path and extension
    base_name=$(basename "$hlsl_file" .hlsl)
    # Create the output .metal filename
    metal_file="$MSL_DIR/$base_name.msl"

    echo "Converting $hlsl_file to $metal_file"

    # Run shadercross command
    # Note: Adjust the shadercross command according to your specific needs
    shadercross $hlsl_file -o "$metal_file"

    # Check if the conversion was successful
    if [ $? -eq 0 ]; then
        echo "Successfully converted $base_name"
    else
        echo "Error converting $base_name"
    fi
done

echo "Shader compilation complete!"