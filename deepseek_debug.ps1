# Скрипт для подключения deepseek-r1 через LM Studio к PowerShell с отладкой
# Сохраните этот файл как deepseek_debug.ps1 в кодировке UTF-8 с BOM

function Invoke-DeepseekDebug {
    param (
        [string]$ApiBase = "http://localhost:1234/v1",
        [string]$ModelName = "deepseek-r1",
        [double]$Temperature = 0.7,
        [int]$MaxTokens = 4096
    )
    
    $ErrorActionPreference = "Continue"
    
    try {
        Add-Type -AssemblyName System.Net.Http
        $client = New-Object System.Net.Http.HttpClient
        $client.BaseAddress = New-Object System.Uri($ApiBase)
        
        Write-Host "`n`n==========================================" -ForegroundColor Cyan
        Write-Host "   DeepSeek Debug - Отладка соединения" -ForegroundColor Cyan
        Write-Host "   Модель: $ModelName" -ForegroundColor Cyan
        Write-Host "   API: $ApiBase" -ForegroundColor Cyan
        Write-Host "==========================================`n" -ForegroundColor Cyan
        
        # 1. Проверяем соединение с LM Studio
        Write-Host "1. Проверка соединения с LM Studio API..." -ForegroundColor Cyan
        try {
            $modelsUri = "models"
            $response = $client.GetAsync($modelsUri).Result
            
            if ($response.IsSuccessStatusCode) {
                $modelsData = $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json
                Write-Host "✓ Соединение успешно. Доступные модели:" -ForegroundColor Green
                $modelsData.data | ForEach-Object {
                    Write-Host "  - $($_.id)" -ForegroundColor Green
                }
                
                # Проверяем есть ли наша модель в списке
                $modelExists = $false
                foreach ($model in $modelsData.data) {
                    if ($model.id -eq $ModelName) {
                        $modelExists = $true
                        break
                    }
                }
                
                if (-not $modelExists) {
                    Write-Host "⚠ Модель '$ModelName' не найдена в списке доступных моделей" -ForegroundColor Yellow
                    Write-Host "  Используйте одну из доступных моделей или проверьте загрузку модели в LM Studio" -ForegroundColor Yellow
                }
            } else {
                Write-Host "✗ Ошибка при получении списка моделей: $($response.StatusCode)" -ForegroundColor Red
                $errorContent = $response.Content.ReadAsStringAsync().Result
                Write-Host "  Детали: $errorContent" -ForegroundColor Red
            }
        } catch {
            Write-Host "✗ Не удалось подключиться к LM Studio API: $_" -ForegroundColor Red
            Write-Host "  Убедитесь, что LM Studio запущен и локальный сервер активен" -ForegroundColor Yellow
            return
        }
        
        # 2. Тестируем chat/completions
        Write-Host "`n2. Тестирование запроса к chat/completions..." -ForegroundColor Cyan
        
        $systemPrompt = "Ты - простой ассистент. Ответь на вопрос пользователя коротко, одним предложением."
        
        $messages = @(
            @{
                "role" = "system"
                "content" = $systemPrompt
            },
            @{
                "role" = "user"
                "content" = "Привет, как дела?"
            }
        )
        
        $requestBody = @{
            "model" = $ModelName
            "messages" = $messages
            "temperature" = $Temperature
            "max_tokens" = $MaxTokens
        }
        
        $requestJson = $requestBody | ConvertTo-Json -Depth 10
        Write-Host "Отправляемый JSON:" -ForegroundColor Blue
        Write-Host $requestJson -ForegroundColor Gray
        
        try {
            $content = New-Object System.Net.Http.StringContent($requestJson, [System.Text.Encoding]::UTF8, "application/json")
            $chatUri = "chat/completions"
            
            Write-Host "Отправка запроса к $ApiBase/$chatUri..." -ForegroundColor Blue
            $response = $client.PostAsync($chatUri, $content).Result
            
            if ($response.IsSuccessStatusCode) {
                $resultJson = $response.Content.ReadAsStringAsync().Result
                Write-Host "✓ Запрос успешно выполнен. Ответ:" -ForegroundColor Green
                Write-Host $resultJson -ForegroundColor Gray
                
                $result = $resultJson | ConvertFrom-Json
                if ($null -ne $result -and $null -ne $result.choices -and $result.choices.Count -gt 0) {
                    $modelResponse = $result.choices[0].message.content
                    Write-Host "`nРезультат запроса:" -ForegroundColor Green
                    Write-Host $modelResponse -ForegroundColor White
                } else {
                    Write-Host "⚠ Получен пустой результат или неправильная структура ответа" -ForegroundColor Yellow
                }
            } else {
                Write-Host "✗ Ошибка API: $($response.StatusCode)" -ForegroundColor Red
                $errorContent = $response.Content.ReadAsStringAsync().Result
                Write-Host "  Детали: $errorContent" -ForegroundColor Red
            }
        } catch {
            Write-Host "✗ Ошибка при выполнении запроса: $_" -ForegroundColor Red
            Write-Host "  Проверьте правильность формата запроса и доступность API" -ForegroundColor Yellow
        }
        
        # 3. Проверка параметров модели
        Write-Host "`n3. Проверка конфигурации модели в LM Studio..." -ForegroundColor Cyan
        Write-Host "• Убедитесь, что в LM Studio:" -ForegroundColor Yellow
        Write-Host "  - Модель полностью загружена и готова к использованию" -ForegroundColor Yellow
        Write-Host "  - В настройках сервера выбран API совместимый с OpenAI" -ForegroundColor Yellow
        Write-Host "  - Температура генерации не слишком низкая (рекомендуется 0.7-0.8)" -ForegroundColor Yellow
        Write-Host "  - Выбран достаточный контекст (рекомендуется 4096+)" -ForegroundColor Yellow
        
        # 4. Проверка совместимости модели
        Write-Host "`n4. Информация о совместимости..." -ForegroundColor Cyan
        Write-Host "• Некоторые модели могут требовать специфических настроек:" -ForegroundColor Yellow
        Write-Host "  - Deepseek-coder обычно лучше работает с API-совместимостью Claude" -ForegroundColor Yellow
        Write-Host "  - Убедитесь, что модель поддерживает формат чата (роли system, user, assistant)" -ForegroundColor Yellow
        Write-Host "  - Проверьте официальную документацию модели на наличие специальных требований" -ForegroundColor Yellow
        
        Write-Host "`nДиагностика завершена. Используйте эту информацию для устранения проблем." -ForegroundColor Cyan
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

# Запуск диагностики
Invoke-DeepseekDebug