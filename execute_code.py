import os

def run_model_command(command):
    model_path = "C:\\Users\\DELL\\.cache\\lm-studio\\models\\lmstudio-community\\DeepSeek-R1-Distill-Qwen-7B-GGUF"
    # Найдите файл модели в этой директории
    model_files = [f for f in os.listdir(model_path) if f.endswith('.gguf')]
    if not model_files:
        print("Файлы модели с расширением .gguf не найдены!")
        return
    
    model_file = model_files[0]  # Берем первый найденный файл
    full_model_path = os.path.join(model_path, model_file)
    
    # Используем полный путь к Python с установленными библиотеками
    python_path = "C:\\voice-pro-1.6.7\\voice-pro-1.6.7\\installer_files\\conda\\python.exe"
    
    cmd = f'echo {command} | "{python_path}" -m transformers.pipeline --model "{full_model_path}" --tokenizer "{full_model_path}" --interactive'
    print(f"Выполняется команда: {cmd}")
    result = os.system(cmd)
    return result

if __name__ == "__main__":
    user_input = input("Введите команду для выполнения: ")
    run_model_command(user_input)