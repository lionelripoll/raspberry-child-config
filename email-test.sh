#!/bin/bash

echo "📤 Envoi d'un courriel de test via msmtp..."

mail -s "✅ Test courriel Raspberry Pi - Surveillance" test.test@gmail.com <<EOF
Bonjour,

Ceci est un message de test automatique envoyé depuis le Raspberry Pi 🧠🐧

Tout fonctionne correctement si tu lis ce message.

Bonne journée !

EOF