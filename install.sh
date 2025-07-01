#!/bin/bash

# Keluar jika ada error
set -e

# URL untuk mengunduh snapshot konfigurasi Anda
SNAPSHOT_URL=https://github.com/mandelaxx/genieacsmod.git
echo "======================================================"
echo "Memulai Instalasi & Restore Otomatis GenieACS"
echo "======================================================"

# --- BAGIAN INSTALASI DEPENDENSI YANG DIPERBARUI ---
echo "--> Memeriksa dan menginstal dependensi..."

# 1. Cek dan Install Node.js v20
if command -v node >/dev/null && node -v | grep -q "^v20"; then
    echo "Node.js v20 sudah terinstall."
else
    echo "Node.js v20 tidak ditemukan. Memulai instalasi..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo "Instalasi Node.js v20 selesai."
fi

# 2. Cek dan Install MongoDB v6
if command -v mongod >/dev/null && mongod --version | grep -q "db version v6"; then
    echo "MongoDB v6 sudah terinstall."
else
    echo "MongoDB v6 tidak ditemukan. Memulai instalasi..."
    sudo apt-get install -y gnupg curl
    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl enable mongod
    echo "Instalasi MongoDB v6 selesai."
fi

# 3. Install dependensi lainnya
sudo apt-get install -y redis-server git

# --- AKHIR DARI BAGIAN YANG DIPERBARUI ---

# 4. Install GenieACS
echo "--> Menginstal GenieACS dari npm..."
sudo npm install -g genieacs

# 5. Buat user dan direktori yang diperlukan
echo "--> Membuat user dan direktori konfigurasi..."
sudo useradd --system --no-create-home --user-group genieacs || echo "User genieacs sudah ada."
sudo mkdir -p /opt/genieacs
sudo chown -R genieacs:genieacs /opt/genieacs

# 6. Buat file service Systemd
echo "--> Membuat file service Systemd..."
cat <<EOT | sudo tee /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target mongod.service redis-server.service
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-cwmp
[Install]
WantedBy=multi-user.target
EOT

cat <<EOT | sudo tee /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target mongod.service redis-server.service
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-nbi
[Install]
WantedBy=multi-user.target
EOT

cat <<EOT | sudo tee /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target mongod.service redis-server.service
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-fs
[Install]
WantedBy=multi-user.target
EOT

cat <<EOT | sudo tee /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-ui
[Install]
WantedBy=multi-user.target
EOT

# 7. Perbaiki izin eksekusi
echo "--> Memperbaiki izin file..."
sudo chmod +x /usr/bin/genieacs-*

# 8. Unduh dan Ekstrak Snapshot
echo "--> Mengunduh snapshot konfigurasi..."
wget -O snapshot.tar.gz "$SNAPSHOT_URL"
tar -xzvf snapshot.tar.gz

# 9. Restore Database
echo "--> Me-restore database MongoDB..."
mongorestore --db genieacs --drop ./genieacs_snapshot_source/db/genieacs

# 10. Restore File Konfigurasi dan GUI
echo "--> Me-restore file konfigurasi dan GUI..."
sudo cp ./genieacs_snapshot_source/config/* /opt/genieacs/
sudo cp ./genieacs_snapshot_source/gui/* /usr/lib/node_modules/genieacs/public/images/
sudo chown -R genieacs:genieacs /opt/genieacs

# 11. Aktifkan dan jalankan semua service
echo "--> Mengaktifkan dan menjalankan semua service GenieACS..."
sudo systemctl daemon-reload
sudo systemctl enable genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui
sudo systemctl start genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui

# 12. Membersihkan file sisa
echo "--> Membersihkan file instalasi..."
rm snapshot.tar.gz
rm -rf genieacs_snapshot_source

echo ""
echo "======================================================"
echo "Instalasi & Restore Selesai!"
echo "Silakan cek status service dengan: sudo systemctl status genieacs-*"
echo "======================================================"
echo "Berikan izin eksekusi: chmod +x install.sh lalu Jalankan script: sudo ./install.sh"
