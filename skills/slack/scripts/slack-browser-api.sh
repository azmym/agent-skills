#!/bin/bash
# Browser-mode wrapper. Equivalent to: SLACK_MODE=browser slack-api.sh
# For the unified API with mode selection, use slack-api.sh directly.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLACK_MODE=browser exec "${SCRIPT_DIR}/slack-api.sh" "$@"
