#!/bin/bash

# Устанавливаем 3x-ui панель для VLESS и сертификаты на 10 лет

# Проверяем, что скрипт выполняется с правами root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запускайте этот скрипт с правами root."
  exit 1
fi



# Установка 3X-UI
if ! command -v x-ui &> /dev/null; then
  bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh)
  if [ $? -ne 0 ]; then
    exit 1
  else
    echo "3X-UI установлен."
  fi
else
  echo "3X-UI уже установлен."
fi

# Генерация сертификата
echo ""
read -p "Вы хотите сгенерировать-подписать SSL сертификат и встроить его в 3X-UI ? (y/n): " answer

if [[ "$answer" == "y" ]]; then
  bash <(curl -Ls https://raw.githubusercontent.com/SibMan54/install-3x-ui-add-signed-ssl-cert/refs/heads/main/3x-ui-autossl.sh)
  if [ $? -ne 0 ]; then
    exit 1
  fi
fi


##### FIREWALL #####

# Функция для извлечения порта 3x-UI
get_3x_ui_port() {
    PORT=$(sudo x-ui settings | grep -i 'port' | grep -oP '\d+')
    if [[ -z "$PORT" ]]; then
        echo "Не удалось автоматически определить порт 3x-UI. Пожалуйста, введите порт вручную."
        read -p "Введите номер порта 3x-UI панели: " PORT
    fi
    echo "$PORT"
}

# Функция для извлечения порта SSH
get_ssh_port() {
    # SSH_PORT=$(grep -i "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    SSH_PORT=$(awk '$1 == "Port" {print $2; exit}' /etc/ssh/sshd_config)
    if [[ -z "$SSH_PORT" ]]; then
        SSH_PORT=22 # Используем порт по умолчанию
    fi
    echo "$SSH_PORT"
}

# Функция для добавления порта в список разрешённых
add_port_to_ufw() {
    local PORT=$1
    ufw allow "$PORT"/tcp
    echo "Порт $PORT добавлен в список разрешённых (или уже был добавлен)."
}

# Проверяем статус UFW
ufw_status=$(ufw status | grep -i "Status:" | awk '{print $2}')

if [[ "$ufw_status" == "active" ]]; then
    echo "Firewall уже активен."

    # Извлекаем порт 3x-UI и добавляем его
    PORT=$(get_3x_ui_port)
    add_port_to_ufw "$PORT"

    # Извлекаем порт SSH и добавляем его
    SSH_PORT=$(get_ssh_port)
    add_port_to_ufw "$SSH_PORT"

    # Добавляем порт 443
    add_port_to_ufw 443

    # Применяем изменения
    ufw reload
    ufw status numbered
else
    echo "Firewall не активен."
    read -p "Вы хотите активировать Firewall? (y/n): " answer

    if [[ "$answer" == "y" ]]; then
        # Активируем Firewall
        ufw enable

        # Извлекаем порт 3x-UI и добавляем его
        PORT=$(get_3x_ui_port)
        add_port_to_ufw "$PORT"

        # Извлекаем порт SSH и добавляем его
        SSH_PORT=$(get_ssh_port)
        add_port_to_ufw "$SSH_PORT"

        # Добавляем порт 443
        add_port_to_ufw 443

        # Применяем изменения
        ufw reload
        ufw status numbered
    else
        echo "Firewall не активирован."
    fi
fi

##### END FIREWALL #####


# Установка SpeedTest
echo ""
read -p "Установить SpeedTest ? (y/n): " answer
if [[ "$answer" == "y" ]]; then
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    if [ $? -ne 0 ]; then
      exit 1
    fi
    apt install speedtest-cli
    rm -f /etc/apt/sources.list.d/ookla_speedtest-cli.list
    echo "Speedtest CLI установлен"
fi

echo ""

# Финальное сообщение
echo "============================================================================="
if [[ -f /etc/ssl/certs/3x-ui-public.key ]]; then
    echo " Установка завершена, SSL-сертификат сгенерирован и прописан в панель 3X-UI"
    echo " Для применения изменений необходимо перезагрузить панель, выполнив команду sudo x-ui затем вводим 13 и жмем Enter"
else
    echo " Установка 3X-UI панели завершена, вход в панель не защищен!"
fi
echo "============================================================================="
