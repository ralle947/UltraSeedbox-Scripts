#!/bin/bash

printf "\033[0;31mDisclaimer: This installer is unofficial and USB staff will not support any issues with it. Make sure to add AUTHENTICATION!\033[0m\n"
read -p "Type confirm if you wish to continue: " input
if [ ! "$input" = "confirm" ]
then
    exit
fi

#Port-Picker by XAN
app-ports show
echo "Pick any application from this list that you're not currently using."
echo "We'll be using this port for your 2nd Sonarr instance."
echo "For example, you chose SickChill so type in 'sickchill'. Please type it in full name."
echo "Type in the application below."
read -r appname
proper_app_name=$(app-ports show | grep -i "$appname" | cut -c 7-)
port=$(app-ports show | grep -i "$appname" | cut -b -5)
echo "Are you sure you want to use $proper_app_name's port? type 'confirm' to proceed."
read -r input
if [ ! "$input" = "confirm" ]
then
    exit
fi

printf "\033[0;31mWARNING: This script builds mono into your userspace. It will take a long time!\033[0m\n"
read -p "Type OK if you wish to continue: " input
if [ ! "$input" = "OK" ]
then
    exit
fi

#Install mono
PATH=$PREFIX/bin:$PATH
PREFIX="$HOME/.local"
VERSION=6.12.0.122
wget -q -O mono.tar.xz https://download.mono-project.com/sources/mono/mono-$VERSION.tar.xz
tar xvf mono.tar.xz
cd mono-$VERSION
./configure --prefix=$PREFIX
make
make install
rm -rfv "$HOME/mono-$VERSION"
rm "$HOME/mono.tar.xz"

#Get sonarr binaries
mkdir -p "$HOME"/.config/.temp; cd $_
wget -O "$HOME"/.config/.temp/sonarr.tar.gz --content-disposition 'https://services.sonarr.tv/v1/download/main/latest?version=3&os=linux'
tar -xvf sonarr.tar.gz -C "$HOME/" && cd "$HOME"
sleep 5
mv "$HOME"/Sonarr "$HOME"/.config/sonarr2
rm -rf "$HOME"/.config/.temp

#Install nginx conf
echo 'location /sonarr2 {
  proxy_pass        http://127.0.0.1:>port</sonarr2;
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-Proto https;
  proxy_redirect off;

  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $http_connection;
}
  location /sonarr2/api { auth_request off;
  proxy_pass       http://127.0.0.1:>port</sonarr2/api;
}

  location /sonarr2/Content { auth_request off;
    proxy_pass http://127.0.0.1:>port</sonarr2/Content;
 }' > "$HOME/.apps/nginx/proxy.d/sonarr2.conf"

sed -i "s/>port</$port/g" "$HOME"/.apps/nginx/proxy.d/sonarr2.conf

#Install Systemd service
cat << EOF | tee ~/.config/systemd/user/sonarr.service > /dev/null
[Unit]
Description=Sonarr Daemon
After=network-online.target
[Service]
Type=simple

ExecStart=%h/.local/bin/mono --debug %h/.config/sonarr2/Sonarr.exe -nobrowser -data=%h/.apps/sonarr2/
TimeoutStopSec=20
KillMode=process
Restart=always
[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now sonarr.service
sleep 10

#Set sonarr2 port
echo '<Config>
  <LogLevel>info</LogLevel>
  <UrlBase>/sonarr2</UrlBase>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <Branch>develop</Branch>
  <Port>temport</Port>
</Config>' > "$HOME/.apps/sonarr2/config.xml"

sed -i "s/temport/$port/g" "$HOME"/.apps/sonarr2/config.xml

systemctl --user restart sonarr.service
app-nginx restart

echo ""
echo ""
echo "Installation complete."
echo "You can access it via https://$USER.$HOSTNAME.usbx.me/sonarr2"
echo "Go to Settings -> General and setup authentication. Form login is recommended."
printf "\033[0;31mPlease do the above after first login!!! Failing to do so will keep your sonarr2 instance open to public. You WILL be compromised.\033[0m\n"

exit