# Скрипт для подключения deepseek-r1 через LM Studio к PowerShell
# Сохраните этот файл как deepseek_terminal.ps1 в кодировке UTF-8 с BOM

# Установка необходимых модулей
function Install-RequiredModules {
    Write-Host "Проверка и установка необходимых модулей..." -ForegroundColor Cyan
    
    if (-not (Get-Module -ListAvailable -Name PSReadLine)) {
        Write-Host "Установка PSReadLine..." -ForegroundColor Yellow
        Install-Module -Name PSReadLine -Force -SkipPublisherCheck
    }
    
    # Проверка pip и установка необходимых пакетов Python
    try {
        python -c "import sys; print(sys.executable)"
        python -m pip --version
    }
    catch {
        Write-Host "Python не установлен или не доступен в PATH. Пожалуйста, установите Python с сайта python.org" -ForegroundColor Red
        exit
    }
    
    Write-Host "Установка необходимых пакетов Python..." -ForegroundColor Cyan
    python -m pip install requests openai python-dotenv colorama
}

# Конфигурация для подключения к LM Studio
function Initialize-Config {
    $configContent = @"
# Конфигурация для LM Studio и модели deepseek-r1
LMSTUDIO_API_BASE=http://192.168.0.101:1234
MODEL_NAME=deepseek-r1
TEMPERATURE=0.7
MAX_TOKENS=4096
"@

    $configPath = Join-Path -Path $PSScriptRoot -ChildPath ".env"
    $configContent | Out-File -FilePath $configPath -Encoding utf8
    Write-Host "Файл конфигурации создан: $configPath" -ForegroundColor Green
}

# Основной скрипт для взаимодействия с моделью
function Invoke-DeepseekTerminal {
    param (
        [string]$ApiBase = "http://192.168.0.101:1234",
        [string]$ModelName = "deepseek-r1",
        [double]$Temperature = 0.7,
        [int]$MaxTokens = 4096
    )
    
    # Загрузка .env файла если он существует
    if (Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath ".env")) {
        Get-Content (Join-Path -Path $PSScriptRoot -ChildPath ".env") | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                if ($name -eq "LMSTUDIO_API_BASE") { $ApiBase = $value }
                if ($name -eq "MODEL_NAME") { $ModelName = $value }
                if ($name -eq "TEMPERATURE") { $Temperature = [double]$value }
                if ($name -eq "MAX_TOKENS") { $MaxTokens = [int]$value }
            }
        }
    }
    
    $ErrorActionPreference = "Stop"
    
    try {
        Add-Type -AssemblyName System.Net.Http
        $client = New-Object System.Net.Http.HttpClient
        $client.BaseAddress = New-Object System.Uri($ApiBase)
        
        Write-Host "`n`n==========================================" -ForegroundColor Cyan
        Write-Host "   DeepSeek Terminal - Режим выполнения кода" -ForegroundColor Cyan
        Write-Host "   Модель: $ModelName" -ForegroundColor Cyan
        Write-Host "   API: $ApiBase" -ForegroundColor Cyan
        Write-Host "   Для выхода введите 'exit'" -ForegroundColor Cyan
        Write-Host "==========================================`n" -ForegroundColor Cyan
        
        # Проверяем соединение с LM Studio
        try {
            $modelsUri = "/v1/models"
            $response = $client.GetAsync($modelsUri).Result
            
            if ($response.IsSuccessStatusCode) {
                Write-Host "✓ Подключение к LM Studio успешно установлено" -ForegroundColor Green
            } else {
                Write-Host "✗ Ошибка подключения к LM Studio: $($response.StatusCode)" -ForegroundColor Red
                Write-Host "Убедитесь, что LM Studio запущен и настроен на порт 1234 по адресу $ApiBase" -ForegroundColor Yellow
                return
            }
        } catch {
            Write-Host "✗ Не удалось подключиться к LM Studio: $_" -ForegroundColor Red
            Write-Host "Убедитесь, что LM Studio запущен с API на $ApiBase" -ForegroundColor Yellow
            return
        }
        
        $session = @()
        $userPrompt = ""
        
        while ($userPrompt -ne "exit") {
            if ($session.Count -eq 0) {
                Write-Host "`nКакой код вы хотите, чтобы модель выполнила? (введите запрос)" -ForegroundColor Yellow
            } else {
                Write-Host "`nЧто дальше? (или введите 'exit' для выхода)" -ForegroundColor Yellow
            }
            
            $userPrompt = Read-Host
            if ($userPrompt -eq "exit") { break }
            
            # Добавляем сообщение пользователя в сессию
            $session += @{
                "role" = "user"
                "content" = $userPrompt
            }
            
            $systemPrompt = "Ты - помощник по написанию и выполнению кода в PowerShell. Когда пользователь просит что-то сделать, ты пишешь код на PowerShell, а затем сразу выполняешь его, показывая результат. Всегда помечай блоки кода тройными обратными кавычками ```powershell и ```. Для выполнения кода используй функцию Execute-Code, которая у тебя уже есть."
            
            $messages = @(
                @{
                    "role" = "system"
                    "content" = $systemPrompt
                }
            )
            
            $messages += $session
            
            $requestBody = @{
                "model" = $ModelName
                "messages" = $messages
                "temperature" = $Temperature
                "max_tokens" = $MaxTokens
            } | ConvertTo-Json -Depth 10
            
            $content = New-Object System.Net.Http.StringContent($requestBody, [System.Text.Encoding]::UTF8, "application/json")
            
            Write-Host "Обработка запроса..." -ForegroundColor Cyan
            
            try {
                $chatUri = "/v1/chat/completions"
                $response = $client.PostAsync($chatUri, $content).Result
                
                if ($response.IsSuccessStatusCode) {
                    $resultJson = $response.Content.ReadAsStringAsync().Result
                    $result = $resultJson | ConvertFrom-Json
                    
                    # Проверка на null и наличие необходимых полей
                    if ($null -eq $result) {
                        Write-Host "Получен пустой ответ от API" -ForegroundColor Red
                        continue
                    }
                    
                    if ($null -eq $result.choices -or $result.choices.Count -eq 0) {
                        Write-Host "Ответ API не содержит результатов (поле choices пусто)" -ForegroundColor Red
                        Write-Host "Полученный JSON: $resultJson" -ForegroundColor Yellow
                        continue
                    }
                    
                    if ($null -eq $result.choices[0].message -or [string]::IsNullOrEmpty($result.choices[0].message.content)) {
                        Write-Host "Ответ API не содержит текстового сообщения" -ForegroundColor Red
                        Write-Host "Полученный JSON: $resultJson" -ForegroundColor Yellow
                        continue
                    }
                    
                    $modelResponse = $result.choices[0].message.content
                    
                    # Добавляем ответ модели в сессию
                    $session += @{
                        "role" = "assistant"
                        "content" = $modelResponse
                    }
                    
                    Write-Host "`n$modelResponse`n" -ForegroundColor Green
                    
                    # Находим и выполняем код в ответе модели
                    $pattern = '```(?:powershell)?(.*?)```'
                    $matches = [regex]::Matches($modelResponse, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
                    
                    foreach ($match in $matches) {
                        $code = $match.Groups[1].Value.Trim()
                        
                        Write-Host "`n--- Выполнение кода: ---" -ForegroundColor Blue
                        Write-Host "$code" -ForegroundColor DarkCyan
                        Write-Host "--- Результат: ---" -ForegroundColor Blue
                        
                        try {
                            # Безопасное выполнение кода
                            $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
                            $code | Out-File -FilePath $tempScriptPath -Encoding utf8
                            
                            # Выполнение скрипта в текущей сессии
                            & $tempScriptPath
                            
                            # Очистка
                            Remove-Item -Path $tempScriptPath -Force
                        }
                        catch {
                            Write-Host "Ошибка выполнения кода: $_" -ForegroundColor Red
                        }
                        
                        Write-Host "------------------------" -ForegroundColor Blue
                    }
                }
                else {
                    Write-Host "Ошибка API: $($response.StatusCode)" -ForegroundColor Red
                    $errorContent = $response.Content.ReadAsStringAsync().Result
                    Write-Host "Детали: $errorContent" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "Ошибка запроса: $_" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "Критическая ошибка: $_" -ForegroundColor Red
    }
    finally {
        if ($null -ne $client) {
            $client.Dispose()
        }
    }
}

# Основная логика скрипта
Write-Host "Настройка окружения для подключения deepseek-r1 через LM Studio..." -ForegroundColor Cyan

# Проверка запуска от администратора
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Рекомендуется запустить скрипт от имени администратора для установки модулей" -ForegroundColor Yellow
    $continue = Read-Host "Продолжить без прав администратора? (y/n)"
    if ($continue -ne "y") {
        exit
    }
}

# Проверка запущен ли LM Studio
try {
    $testConn = $null
    $lmStudioAddress = "192.168.0.101"
    $lmStudioPort = 1234
    
    # Проверяем доступность командлета Test-NetConnection
    if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
        $testConn = Test-NetConnection -ComputerName $lmStudioAddress -Port $lmStudioPort -InformationLevel Quiet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    } else {
        # Альтернативный метод проверки порта
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        try {
            $tcpClient.Connect($lmStudioAddress, $lmStudioPort)
            $testConn = $true
        } catch {
            $testConn = $false
        } finally {
            $tcpClient.Dispose()
        }
    }
    
    if (-not $testConn) {
        Write-Host "Внимание: LM Studio не обнаружен по адресу $lmStudioAddress на порту $lmStudioPort!" -ForegroundColor Red
        Write-Host "Пожалуйста, запустите LM Studio и убедитесь, что:" -ForegroundColor Yellow
        Write-Host "1. Модель deepseek-r1 загружена" -ForegroundColor Yellow
        Write-Host "2. Локальный сервер запущен на порту $lmStudioPort и доступен по адресу $lmStudioAddress" -ForegroundColor Yellow
        Write-Host "3. В настройках сервера выбран совместимый API (OpenAI Compatible)" -ForegroundColor Yellow
        
        $continue = Read-Host "Продолжить настройку? (y/n)"
        if ($continue -ne "y") {
            exit
        }
    }
} catch {
    Write-Host "Невозможно проверить соединение с LM Studio. Продолжаем..." -ForegroundColor Yellow
}

# Установка модулей
Install-RequiredModules

# Создание конфигурационного файла
Initialize-Config

# Запуск основного скрипта
Invoke-DeepseekTerminal

Write-Host "Завершение работы..." -ForegroundColor Cyan