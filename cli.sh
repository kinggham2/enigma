#!/usr/bin/env bash

# Color Codes
green="\033[01;32m"
greenz="\033[0m"

THIS_DIR=$(cd $(dirname $0); pwd)
cd $THIS_DIR

install() {
cd tg
sudo apt-get install g++-4.7 -y c++-4.7 -y
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install libreadline-dev -y libconfig-dev -y libssl-dev -y lua5.2 -y liblua5.2-dev -y lua-socket -y lua-sec -y lua-expat -y libevent-dev -y make unzip git redis-server autoconf g++ -y libjansson-dev -y libpython-dev -y expat libexpat1-dev -y
sudo apt-get install screen -y
sudo apt-get install tmux -y
sudo apt-get install libstdc++6 -y
sudo apt-get install lua-lgi -y
sudo apt-get install libnotify-dev -y
wget https://valtman.name/files/telegram-cli-1222
mv telegram-cli-1222 tgcli
chmod +x tgcli
cd ..
chmod +x cli.sh
chmod +x api.sh
sed -i 's/\r$//' api.sh
echo ""
echo -e "\033[01;32m    Installing Done!\033[0m,\n \033[01;34m Now you Can run your bot! \033[0m"
echo "    >> Launch in Normal Mode : ./cli.sh"
echo "    >> Launch in Screen Mode : screen ./cli.sh"
echo "    >> Launch HelperBot in Screen Mode : screen ./api.sh"
echo -e "      \033[01;30m Powered By Enigma-Team (@EnigmaTM)\033[0m\n"

exit
}

if [ "$1" = "install" ]; then
  install
else
  if [ ! -f ./tg/tgcli ]; then
    echo "Telegram-Cli (tg) not Found !"
    echo "Run $0 install"
    exit 1
  fi
  while [[ true ]]; do
    ./tg/tgcli -s ./bot/bot.lua -l 1 -E $@
    sleep 0.5
done
fi
