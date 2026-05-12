#!/bin/bash

set -euo pipefail

ollama_models_dir="$HOME/.ollama"

show_menu() {
    echo ""
    echo "=== Ollama Model Manager ==="
    echo "1. List all models"
    echo "2. Pull a model"
    echo "3. Modify existing model"
    echo "4. Create new model from base"
    echo "5. Exit"
    echo ""
}

get_user_choice() {
    local prompt="$1"
    read -p "$prompt" choice
    echo "$choice"
}

get_required_input() {
    local prompt="$1"
    local input=""
    while [[ -z "$input" ]]; do
        read -p "$prompt" input
    done
    echo "$input"
}

list_models() {
    echo ""
    echo "=== Available Ollama Models ==="
    if ollama list >/dev/null 2>&1; then
        ollama list
    else
        echo "Error: Ollama is not running or not installed"
        exit 1
    fi
}

pull_model() {
    echo ""
    echo "=== Pull Ollama Model ==="
    local model_name
    model_name=$(get_required_input "Enter model name to pull (e.g., llama2): ")
    
    echo ""
    echo "Pulling model: $model_name"
    ollama pull "$model_name"
}

parse_modelfile_params() {
    local modelfile_path="$1"

    if [[ ! -f "$modelfile_path" ]]; then
        return
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^[Pp][Aa][Rr][Aa][Mm][Ee][Tt][Ee][Rr]\ +num_ctx\ +([0-9]+) ]]; then
            echo "context:${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[Pp][Aa][Rr][Aa][Mm][Ee][Tt][Ee][Rr]\ +temperature\ +([0-9.]+) ]]; then
            echo "temperature:${BASH_REMATCH[1]}"
        fi
    done < "$modelfile_path"
}

get_valid_context() {
    local default="$1"
    local input
    read -p "Context window size (default: $default): " input
    if [[ -z "$input" ]]; then
        echo "$default"
    elif ! [[ "$input" =~ ^[0-9]+$ ]] || [[ "$input" -lt 1 ]]; then
        echo "$default"
    else
        echo "$input"
    fi
}

get_valid_temperature() {
    local default="$1"
    local input
    read -p "Temperature (default: $default, range 0.0-2.0): " input
    if [[ -z "$input" ]]; then
        echo "$default"
    else
        echo "$input"
    fi
}

select_model_from_list() {
    local prompt="$1"
    local models="$2"

    if [[ -z "$models" ]]; then
        echo ""
        return 1
    fi

    local model_array=()
    while IFS= read -r model; do
        model_array+=("$model")
    done <<< "$models"

    echo "Available models:" >&2
    local i=1
    for model in "${model_array[@]}"; do
        echo "  $i. $model" >&2
        ((i++))
    done
    echo "" >&2

    local selection
    read -p "$prompt (number or name): " selection >&2

    # Check if input is a number
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        local index=$((selection - 1))
        if [[ $index -ge 0 && $index -lt ${#model_array[@]} ]]; then
            echo "${model_array[$index]}"
            return 0
        else
            echo ""
            return 1
        fi
    else
        # Input is a name, verify it exists
        if echo "$models" | grep -q "^${selection}$"; then
            echo "$selection"
            return 0
        else
            echo ""
            return 1
        fi
    fi
}

modify_model() {
    echo ""
    echo "=== Modify Existing Model ==="

    local models
    models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '<none>' || true)

    if [[ -z "$models" ]]; then
        echo "No models found. Please pull a model first."
        return
    fi

    local model_name
    model_name=$(select_model_from_list "Select model to modify" "$models")

    if [[ -z "$model_name" ]]; then
        echo "Invalid selection. Operation cancelled."
        return
    fi

    echo "Selected model: $model_name"
    echo ""

    local context_size=4096
    local temperature=0.7
    local modelfile="/tmp/Modelfile.$$"

    if ollama show "$model_name" --output-modelfile >"$modelfile" 2>/dev/null; then
        local params
        params=$(parse_modelfile_params "$modelfile")

        if echo "$params" | grep -q "^context:"; then
            context_size=$(echo "$params" | grep "^context:" | cut -d: -f2)
        fi

        if echo "$params" | grep -q "^temperature:"; then
            temperature=$(echo "$params" | grep "^temperature:" | cut -d: -f2)
        fi
    fi

    echo ""
    echo "Current parameters:"
    echo "  Context window: $context_size"
    echo "  Temperature: $temperature"
    echo ""

    context_size=$(get_valid_context "$context_size")
    temperature=$(get_valid_temperature "$temperature")

    echo ""
    echo "Creating modified model..."
    echo "from $model_name" > "$modelfile"
    echo "parameter num_ctx $context_size" >> "$modelfile"
    echo "parameter temperature $temperature" >> "$modelfile"

    local new_name="${model_name}-modified-$(date +%Y%m%d%H%M%S)"
    read -p "New model name (default: $new_name): " input
    if [[ -n "$input" ]]; then
        new_name="$input"
    fi

    echo ""
    ollama create "$new_name" -f "$modelfile"
    rm "$modelfile"

    echo ""
    echo "✓ Model created: $new_name"
    echo "  Context window: $context_size"
    echo "  Temperature: $temperature"
}

create_model() {
    echo ""
    echo "=== Create New Model ==="

    local models
    models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '<none>' || true)

    if [[ -z "$models" ]]; then
        echo "No base models found. Please pull a model first."
        return
    fi

    local base_model
    base_model=$(select_model_from_list "Select base model" "$models")

    if [[ -z "$base_model" ]]; then
        echo "Invalid selection. Operation cancelled."
        return
    fi

    echo "Selected base model: $base_model"
    echo ""

    local model_name
    model_name=$(get_required_input "Enter new model name: ")

    local context_size
    context_size=$(get_valid_context "4096")

    local temperature
    temperature=$(get_valid_temperature "0.7")

    echo ""
    echo "Creating model '$model_name' from '$base_model'..."
    echo "from $base_model" > "Modelfile"
    echo "parameter num_ctx $context_size" >> "Modelfile"
    echo "parameter temperature $temperature" >> "Modelfile"

    ollama create "$model_name" -f Modelfile
    rm Modelfile

    echo ""
    echo "✓ Model created: $model_name"
    echo "  Base model: $base_model"
    echo "  Context window: $context_size"
    echo "  Temperature: $temperature"
}

while true; do
    show_menu
    choice=$(get_user_choice "Select an option (1-5): ")
    
    case "$choice" in
        1)
            list_models
            ;;
        2)
            pull_model
            ;;
        3)
            modify_model
            ;;
        4)
            create_model
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please select 1-5."
            ;;
    esac
done
