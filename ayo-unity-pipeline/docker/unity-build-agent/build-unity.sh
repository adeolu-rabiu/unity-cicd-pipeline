#!/bin/bash
set -e

PROJECT_PATH=${1:-/workspace}
BUILD_TARGET=${2:-Android}
BUILD_OUTPUT=${3:-/workspace/Build}

echo "Building Unity project at: $PROJECT_PATH"
echo "Target platform: $BUILD_TARGET"
echo "Output directory: $BUILD_OUTPUT"

# Start Xvfb for headless Unity
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99

# Run Unity build
/opt/unity/editors/2022.3.12f1/Editor/Unity \
    -batchmode \
    -quit \
    -projectPath "$PROJECT_PATH" \
    -executeMethod BuildScript.CommandLineBuild \
    -buildTarget:"$BUILD_TARGET" \
    -logFile /tmp/unity-build.log

echo "Build completed. Log:"
cat /tmp/unity-build.log

# Upload to S3 if AWS credentials are available
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Uploading build artifacts to S3..."
    aws s3 sync "$BUILD_OUTPUT" "s3://$S3_BUCKET_NAME/builds/$(date +%Y%m%d-%H%M%S)/"
fi

