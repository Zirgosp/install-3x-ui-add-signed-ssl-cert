#!/bin/bash

# Устанавливаем 3x-ui панель для VLESS и сертификаты на 10 лет

##### COLOR #####

# Цвета
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m' # Сброс цвета

# Значки
CHECK_MARK="${GREEN}✅${NC}"
WARNING="${YELLOW}⚠${NC}"
CROSS="${RED}❌${NC}"
QUESTION="${CYAN}❓${NC}"

# Функция для вывода успешных сообщений
success_message() {
    echo -e "${CHECK_MARK} ${GREEN}$1${NC}"
}

# Функция для вывода предупреждений
warning_message() {
    echo -e "${WARNING} ${YELLOW}$1${NC}"
}

# Функция для вывода ошибок
error_message() {
    echo -e "${CROSS} ${RED}$1${NC}"
}

# Функция для вывода запросов
ask_message() {
    echo -e "${QUESTION} ${CYAN}$1${NC}"
}

##### END COLOR #####

# Проверяем, что скрипт выполняется с правами root
if [ "$EUID" -ne 0 ]; then
  error_message "Пожалуйста, запускайте этот скрипт с правами root."
  exit 1
fi

# Установка 3X-UI
if ! command -v x-ui &> /dev/null; then
  bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh)
  if [ $? -ne 0 ]; then
    error_message "Ошибка установки 3X-UI панели"
    exit 1
  else
    success_message "3X-UI установлен."
  fi
else
  success_message "3X-UI уже установлен."
fi

# Генерация сертификата
echo ""
ask_message "Вы хотите сгенерировать-подписать SSL сертификат и встроить его в 3X-UI ? (y/n):"
read -p answer
if [[ "$answer" == "y" ]]; then
  bash <(curl -Ls https://raw.githubusercontent.com/SibMan54/install-3x-ui-add-signed-ssl-cert/refs/heads/main/3x-ui-autossl.sh)
  if [ $? -ne 0 ]; then
    error_message "Ошибка при генерации SSL сертификата"
    exit 1
  else
    success_message "SSL сертификат успешно сгенерирован и встроин в 3X-UI панель"
  fi
fi


##### FIREWALL #####

# Функция для извлечения порта 3x-UI
get_3x_ui_port() {
    PORT=$(sudo x-ui settings | grep -i 'port' | grep -oP '\d+')
    if [[ -z "$PORT" ]]; then
        warning_message "Не удалось автоматически определить порт 3x-UI."
        ask_message "Введите номер порта 3x-UI панели:"
        read -r PORT
    fi
    echo "$PORT"
}

# Функция для извлечения порта SSH
get_ssh_port() {
    SSH_PORT=$(awk '$1 == "Port" {print $2; exit}' /etc/ssh/sshd_config)
    if [[ -z "$SSH_PORT" ]]; then
        SSH_PORT=22 # Используем порт по умолчанию
    fi
    echo "$SSH_PORT"
}

# Функция для добавления порта в список разрешённых
add_port_to_ufw() {
    local PORT=$1
    ufw allow "$PORT"/tcp > /dev/null 2>&1
    success_message "Порт $PORT добавлен в список разрешённых (или уже был добавлен)."
}

# Проверяем статус UFW
ufw_status=$(ufw status | grep -i "Status:" | awk '{print $2}')

if [[ "$ufw_status" == "active" ]]; then
    success_message "Firewall уже активен."

    # Извлекаем порт 3x-UI и добавляем его
    PORT=$(get_3x_ui_port)
    add_port_to_ufw "$PORT"

    # Извлекаем порт SSH и добавляем его
    SSH_PORT=$(get_ssh_port)
    add_port_to_ufw "$SSH_PORT"

    # Добавляем порт 443
    add_port_to_ufw 443

    # Применяем изменения
    ufw reload > /dev/null 2>&1
    ufw status numbered
else
    warning_message "Firewall не активен."
    echo ""
    ask_message "Вы хотите активировать Firewall? (y/n):"
    read -r answer
    if [[ "$answer" == "y" ]]; then
        # Активируем Firewall
        ufw enable > /dev/null 2>&1
        success_message "Firewall активирован."

        # Извлекаем порт 3x-UI и добавляем его
        PORT=$(get_3x_ui_port)
        add_port_to_ufw "$PORT"

        # Извлекаем порт SSH и добавляем его
        SSH_PORT=$(get_ssh_port)
        add_port_to_ufw "$SSH_PORT"

        # Добавляем порт 443
        add_port_to_ufw 443

        # Применяем изменения
        ufw reload > /dev/null 2>&1
        ufw status numbered
    else
        warning_message "Firewall не активирован."
    fi
fi

##### END FIREWALL #####


# Установка SpeedTest
echo ""
ask_message "Установить SpeedTest ? (y/n):"
read -p answer
if [[ "$answer" == "y" ]]; then
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    if [ $? -ne 0 ]; then
      exit 1
      error_message "Ошибка установки Speedtest CLI"
    fi
    apt install speedtest-cli
    rm -f /etc/apt/sources.list.d/ookla_speedtest-cli.list
    success_message "Speedtest CLI успешно установлен"
fi

echo ""

# Финальное сообщение
echo "============================================================================="
if [[ -f /etc/ssl/certs/3x-ui-public.key ]]; then
    success_message " Установка завершена, SSL-сертификат сгенерирован и прописан в панель 3X-UI"
    warning_message " Для применения изменений необходимо перезагрузить панель,"
    warning_message " выполнив команду sudo x-ui затем вводим 13 и жмем Enter"
else
    success_message " Установка 3X-UI панели завершена, вход в панель не защищен!"
fi
echo "============================================================================="
