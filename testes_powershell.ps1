param(
    [Parameter(Mandatory=$true)][string]$input_file,   # Arquivo de código-fonte (.py, .c, .cpp)
    [Parameter(Mandatory=$true)][string]$tests_dir,    # Diretório contendo arquivos de entrada e saída (.in, .out)
    [int]$error_limit = 0  # Limite de erros para interromper a execução (0 = sem limite)
)

# Função para identificar a linguagem
function Get-Language {
    param ($file)
    $extension = [System.IO.Path]::GetExtension($file)
    switch ($extension) {
        ".py" { return "python" }
        ".c" { return "c" }
        ".cpp" { return "cpp" }
        default { throw "Unsupported file extension: $extension" }
    }
}

# Função para compilar (se necessário)
function Compile-Code {
    param ($language, $file)
    
    if ($language -eq "c") {
        return "gcc $file -o a.out"
    } elseif ($language -eq "cpp") {
        return "g++ $file -o a.out"
    } else {
        return $null  # Sem compilação para Python
    }
}

# Função para executar o código
function Run-Test {
    param ($language, $file, $input, $output)
    
    if ($language -eq "python") {
        $cmd = "python $file < $input > $output"
    } elseif ($language -eq "c" -or $language -eq "cpp") {
        $cmd = "./a.out < $input > $output"
    }
    
    Invoke-Expression $cmd
}

# Função para comparar as saídas
function Compare-Output {
    param ($expected_output, $generated_output)
    
    $diff = Compare-Object (Get-Content $expected_output) (Get-Content $generated_output)
    return $diff.Count -eq 0
}

# Função para gerar relatório CSV
function Write-Report {
    param ($results, $total_tests, $passed_tests, $failed_tests)
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $csv_content = @("timestamp, test_name, result")

    foreach ($result in $results) {
        $csv_content += "$timestamp, $($result.test_name), $($result.result)"
    }

    $csv_content += "Total tests: $total_tests, Passed: $passed_tests, Failed: $failed_tests"
    $csv_content | Out-File -Append report.csv
}

# Função principal
function Main {
    $language = Get-Language $input_file
    $compile_cmd = Compile-Code $language $input_file
    
    # Compilar se necessário
    if ($compile_cmd) {
        Invoke-Expression $compile_cmd
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Compilation failed!" -ForegroundColor Red
            return
        }
    }

    $test_files = Get-ChildItem "$tests_dir/*.in"
    $total_tests = 0
    $passed_tests = 0
    $failed_tests = 0
    $error_count = 0
    $results = @()

    foreach ($test_file in $test_files) {
        $total_tests++
        $input = $test_file.FullName
        $output = [System.IO.Path]::ChangeExtension($input, ".out")
        $expected_output = "$tests_dir\$($test_file.BaseName).out"

        Run-Test $language $input_file $input $output
        if (Compare-Output $expected_output $output) {
            Write-Host "$($test_file.BaseName): Test passed" -ForegroundColor Green
            $passed_tests++
            $results += [pscustomobject]@{ test_name = $test_file.BaseName; result = "passed" }
        } else {
            Write-Host "$($test_file.BaseName): Test failed" -ForegroundColor Red
            $failed_tests++
            $error_count++
            $results += [pscustomobject]@{ test_name = $test_file.BaseName; result = "failed" }
            
            # Se o limite de erros for atingido
            if ($error_limit -gt 0 -and $error_count -ge $error_limit) {
                Write-Host "Error limit reached, stopping tests." -ForegroundColor Yellow
                break
            }
        }
    }

    # Gerar relatório
    Write-Report $results $total_tests $passed_tests $failed_tests
    Write-Host "Test results saved to report.csv"
}

# Executar a função principal
Main
