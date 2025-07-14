import requests
import json
import subprocess
import os

def ask_model(prompt):
    url = "http://localhost:1234/v1/chat/completions"
    
    headers = {
        "Content-Type": "application/json"
    }
    
    data = {
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "max_tokens": 1000
    }
    
    response = requests.post(url, headers=headers, data=json.dumps(data))
    
    if response.status_code == 200:
        return response.json()["choices"][0]["message"]["content"]
    else:
        return f"Ошибка: {response.status_code}, {response.text}"

def execute_command(command):
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            return f"Команда успешно выполнена.\nВывод:\n{result.stdout}"
        else:
            return f"Ошибка при выполнении команды.\nКод ошибки: {result.returncode}\nСообщение:\n{result.stderr}"
    except Exception as e:
        return f"Исключение при выполнении команды: {str(e)}"

if __name__ == "__main__":
    print("=== Интерфейс для DeepSeek-R1 в LM Studio ===")
    print("Используйте '/cmd' для выполнения команд в терминале.")
    print("Используйте '/exit' для выхода из программы.")
    print("="*50)
    
    while True:
        user_input = input("\nВведите ваш запрос: ")
        
        if user_input.lower() == '/exit':
            break
        
        if user_input.lower().startswith('/cmd '):
            # Выполнение команды в терминале
            command = user_input[5:]  # Удаляем '/cmd ' из начала
            print("\nВыполнение команды...")
            result = execute_command(command)
            print(result)
        else:
            # Обращение к модели
            print("\nОбрабатываю запрос...")
            response = ask_model(user_input)
            print("\nОтвет модели:")
            print(response)