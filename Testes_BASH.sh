#!/bin/bash

# Load configuration from JSON file
config_file="Untitled-1.json"
config=$(cat "$config_file")

# Function to run a test
run_test() {
    local language=$1
    local file=$2
    local input_file=$3
    local expected_output_file=$4

    local lang_config=$(echo "$config" | jq -r ".languages[\"$language\"]")
    local output_file="output.txt"
    local compile_cmd=$(echo "$lang_config" | jq -r ".compile // empty")
    local execute_cmd=$(echo "$lang_config" | jq -r ".execute" | sed "s/{file}/$file/g; s/{input}/$input_file/g; s/{output}/$output_file/g; s/{output_executable}/a.out/g")

    # Compile if necessary
    if [ -n "$compile_cmd" ]; then
        compile_cmd=$(echo "$compile_cmd" | sed "s/{file}/$file/g; s/{output_executable}/a.out/g")
        compile_output=$(eval "$compile_cmd" 2>&1)
        if [ $? -ne 0 ]; then
            echo "error,$compile_output"
            return
        fi
    fi

    # Execute the program
    execute_output=$(eval "$execute_cmd" 2>&1)
    if [ $? -ne 0 ]; then
        echo "error,$execute_output"
        return
    fi

    # Compare output
    output=$(cat "$output_file")
    expected_output=$(cat "$expected_output_file")

    if [ "$output" == "$expected_output" ]; then
        echo "success,"
    else
        diff=$(diff <(echo "$expected_output") <(echo "$output"))
        echo "failure,$diff"
    fi
}

# Main function
main() {
    results=()
    languages=$(echo "$config" | jq -r '.languages | keys[]')
    for language in $languages; do
        lang_config=$(echo "$config" | jq -r ".languages[\"$language\"]")
        input_pattern=$(echo "$config" | jq -r '.test_cases.input_pattern')
        for input_file in $(ls $input_pattern); do
            test_name=$(basename "$input_file" .in)
            expected_output_file="${test_name}.out"
            result=$(run_test "$language" "${test_name}$(echo "$lang_config" | jq -r '.extension')" "$input_file" "$expected_output_file")
            results+=("$test_name,$language,$result")
        done
    done

    # Generate report
    timestamp=$(date -Iseconds)
    {
        echo "timestamp,test,language,result,details"
        for result in "${results[@]}"; do
            echo "$timestamp,$result"
        done
    } >> report.csv
}
