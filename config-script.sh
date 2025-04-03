#!/bin/bash

echo "Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

echo "Installation des applications éducatives et outils nécessaires..."
sudo apt install -y \
  gcompris tuxpaint scratch scratch2 scratch3 kturtle tuxmath tuxtype \
  stellarium geogebra codeblocks audacity openshot pinta libreoffice \
  chromium-browser vlc gnome-software jq sqlite3 \
  logwatch msmtp msmtp-mta bsd-mailx auditd anacron

echo "Création de l'utilisateur 'mathilde'..."
sudo adduser --gecos "" mathilde
sudo deluser mathilde sudo
sudo deluser mathilde adm
sudo deluser mathilde lpadmin

echo "Verrouillage de fichiers système..."
sudo chmod o-rwx /root /etc /boot /bin /sbin /lib /lib64 /usr/sbin
echo 'alias sudo="echo -e \"❌ Accès administrateur interdit pour cet utilisateur.\""' >> /home/mathilde/.bashrc
sudo chown mathilde:mathilde /home/mathilde/.bashrc

echo "Configuration DNS CleanBrowsing..."
sudo sed -i '/^static domain_name_servers/d' /etc/dhcpcd.conf
echo "# CleanBrowsing Family DNS" | sudo tee -a /etc/dhcpcd.conf
echo "static domain_name_servers=185.228.168.168 185.228.169.168" | sudo tee -a /etc/dhcpcd.conf
sudo chattr -i /etc/resolv.conf
echo -e "nameserver 185.228.168.168\nnameserver 185.228.169.168" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf

echo "Activation du démarrage automatique de 'mathilde'..."
sudo raspi-config nonint do_boot_behaviour B2
sudo sed -i 's/^autologin-user=.*/autologin-user=mathilde/' /etc/lightdm/lightdm.conf

echo "Initialisation de Chromium..."
sudo -u mathilde chromium-browser --no-first-run about:blank &
CHROMIUM_PID=$!
sleep 10
kill "$CHROMIUM_PID" 2>/dev/null
sleep 2

echo "Blocage des moteurs recherches, reseaux sociaux et sites via /etc/hosts..."
BLOCKED=(
  google.com www.google.com bing.com www.bing.com 
  duckduckgo.com www.duckduckgo.com search.yahoo.com ecosia.org www.ecosia.org
  facebook.com www.facebook.com
  instagram.com www.instagram.com
  twitter.com www.twitter.com
  tiktok.com www.tiktok.com
  reddit.com www.reddit.com
  snapchat.com www.snapchat.com
  omegle.com www.omegle.com
  quora.com www.quora.com
  ask.fm www.ask.fm
  xvideos.com www.xvideos.com
  pornhub.com www.pornhub.com
  4chan.org www.4chan.org
  xhamster.com www.xhamster.com
  youporn.com www.youporn.com
  redtube.com www.redtube.com
  xnxx.com www.xnxx.com
  spankbang.com www.spankbang.com
  rule34.xxx www.rule34.xxx
  hentaihaven.xxx www.hentaihaven.xxx
  chatroulette.com www.chatroulette.com
  tinychat.com www.tinychat.com
  ome.tv www.ome.tv
)
for host in "${BLOCKED[@]}"; do
  echo "127.0.0.1 $host" | sudo tee -a /etc/hosts
done

echo "Forçage de YouTube en mode restreint via /etc/hosts..."
YOUTUBE_RESTRICTED_IP="216.239.38.120"
YOUTUBE_DOMAINS=(
  "www.youtube.com"
  "m.youtube.com"
  "youtube.com"
  "youtubei.googleapis.com"
  "youtube.googleapis.com"
)
for domain in "${YOUTUBE_DOMAINS[@]}"; do
  grep -q "$domain" /etc/hosts || echo "$YOUTUBE_RESTRICTED_IP $domain" | sudo tee -a /etc/hosts > /dev/null

done

echo "YouTube forcé en mode restreint."

echo "Création de /usr/local/bin/chromium-protect..."
cat <<'EOF' | sudo tee /usr/local/bin/chromium-protect
#!/bin/bash
PREF_FILE="/home/mathilde/.config/chromium/Default/Preferences"
START_PAGE="https://www.qwantjunior.com"
if [ -f "$PREF_FILE" ]; then
  jq --arg homepage "$START_PAGE" \
    '.homepage = $homepage |
     .homepage_is_newtabpage = false |
     .session.restore_on_startup = 4 |
     .session.startup_urls = [$homepage] |
     .default_search_provider = {
       "enabled": true,
       "name": "Qwant Junior",
       "keyword": "qwantjunior.com",
       "search_url": "https://www.qwantjunior.com/?q={searchTerms}",
       "suggest_url": "",
       "favicon_url": "https://www.qwantjunior.com/favicon.ico",
       "encoding": "UTF-8",
       "is_default": true
     }' "$PREF_FILE" > "$PREF_FILE.tmp" && mv "$PREF_FILE.tmp" "$PREF_FILE"
  chown mathilde:mathilde "$PREF_FILE"
fi
exec /usr/bin/chromium-browser "$@"
EOF
sudo chmod +x /usr/local/bin/chromium-protect

echo "Raccourci personnalisé pour Chromium sécurisé..."
CHROME_DESKTOP="/home/mathilde/.local/share/applications/chromium-browser.desktop"
sudo -u mathilde mkdir -p "$(dirname "$CHROME_DESKTOP")"
cat <<EOF | sudo -u mathilde tee "$CHROME_DESKTOP"
[Desktop Entry]
Name=Chromium Web (Sécurisé)
Exec=/usr/local/bin/chromium-protect %U
Terminal=false
Type=Application
Icon=chromium-browser
Categories=Network;WebBrowser;
EOF

echo "Configuration msmtp pour envoi par courriel..."
cat <<EOF | sudo tee /etc/msmtprc
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /var/log/msmtp.log

account gmail
host smtp.gmail.com
port 587
from YOUR_EMAIL_ADRESS
user YOUR_EMAIL_ADRESS
passwordeval "cat /etc/msmtp-password"

account default : gmail
EOF

sudo chmod 600 /etc/msmtprc
sudo chown root:root /etc/msmtprc

echo 'YOUR_APP_PASSWORD' | sudo tee /etc/msmtp-password > /dev/null && sudo chmod 600 /etc/msmtp-password

echo "Configuration de Logwatch..."
mkdir -p /etc/logwatch/conf
cat <<EOF | sudo tee /etc/logwatch/conf/logwatch.conf
MailTo = ripoll.lionel@gmail.com
MailFrom = raspberry@maison.local
Range = yesterday
Detail = High
Format = text
Service = All
EOF

echo "Configuration d’auditd..."
sudo systemctl enable auditd
sudo systemctl start auditd
sudo auditctl -w /etc/passwd -p rwxa -k fichiers_sensibles
sudo auditctl -w /home/mathilde/Documents -p rwxa -k documents_enfant

echo "Script de rapport personnalisé..."
cat <<'EOF' | sudo tee /usr/local/bin/daily-report.sh
#!/bin/bash
REPORT="/tmp/surveillance_report.txt"
USER=mathilde

echo "=== Rapport surveillance - $(date) ===" > "$REPORT"

echo -e "Applications récemment utilisées :" >> "$REPORT"
ps -u "$USER" -o pid,cmd --sort=start_time | tail -n 15 >> "$REPORT"

echo -e "Logiciels installés récemment :" >> "$REPORT"
grep "install " /var/log/apt/history.log | tail -n 10 >> "$REPORT"

echo -e "Activité terminale :" >> "$REPORT"
tail -n 10 "/home/$USER/.bash_history" >> "$REPORT"

echo -e "Derniers sites visités dans Chromium :" >> "$REPORT"
HIST_FILE="/home/$USER/.config/chromium/Default/History"
if [ -f "$HIST_FILE" ]; then
  cp "$HIST_FILE" /tmp/history_copy.db
  chmod 644 /tmp/history_copy.db
  sqlite3 /tmp/history_copy.db "SELECT datetime(last_visit_time/1000000-11644473600,'unixepoch'), url FROM urls ORDER BY last_visit_time DESC LIMIT 10;" >> "$REPORT"
  rm /tmp/history_copy.db
else
  echo "Aucun historique disponible." >> "$REPORT"
fi

echo -e "Accès à des fichiers sensibles :" >> "$REPORT"
ausearch -k fichiers_sensibles --format short | tail -n 10 >> "$REPORT"
ausearch -k documents_enfant --format short | tail -n 10 >> "$REPORT"

mail -s "Rapport surveillance Raspberry Pi" ripoll.lionel@gmail.com < "$REPORT"
rm "$REPORT"
EOF

sudo chmod +x /usr/local/bin/daily-report.sh

echo "Planification quotidienne avec anacron..."
cat <<EOF | sudo tee /etc/cron.daily/daily-report
#!/bin/bash
/usr/local/bin/daily-report.sh
EOF

sudo chmod +x /etc/cron.daily/daily-report

echo "🔄 Activation des services cron et anacron..."
sudo systemctl enable cron
sudo systemctl enable anacron
sudo systemctl start cron
sudo systemctl start anacron

echo "🎉 Configuration complète terminée !"
