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

# Активация Firewall
# Проверяем статус UFW
ufw_status=$(ufw status | grep -i "")
if [[ "$ufw_status" == *"inactive"* ]]; then
    echo ""
    read -p "Вы хотите активировать Firewall ? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        # Запрос порта 3x-UI у пользователя
        echo ""
        read -p "Введите номер порта который был выдан при установке 3X-UI панели: " PORT

        # Включаем UFW и добавляем порты в разрешенные
        ufw enable

        echo ""
        read -p "Добавить порт SSH в список разрешенных ? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
          # Запрос порта SSH
          SSH_PORT=$(grep -i "Port " /etc/ssh/sshd_config | awk '{print $2}')
          ufw allow  "$SSH_PORT"/tcp
          echo "Порт SSH: $SSH_PORT добавлен в список разрешенных Firewall"
        fi

        ufw allow $PORT/tcp
        ufw allow 443/tcp
        ufw reload
        ufw status numbered
    fi
    echo "Firewall был активен, порты $PORT и 443 добавлены в в список разрешенных"
else
    # Запрос порта 3x-UI у пользователя
    echo ""
    read -p "Введите номер порта 3X-UI панели: " PORT

    echo "Firewall уже активен, порты $PORT и 443 добавлены в в список разрешенных"
    ufw allow $PORT/tcp
    ufw allow 443/tcp
    ufw reload
    ufw status numbered
fi

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
echo " Установка завершена, SSL-сертификат сгенерирован и прописан в панель 3X-UI!"
echo " Для применения изменений необходимо перезагрузить панель, выполнив команды sudo x-ui -> 13 -> Enter"
echo "============================================================================="
