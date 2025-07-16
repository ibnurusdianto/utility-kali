# 📚 README - Koleksi Skrip Bash Kali Linux

Kumpulan skrip bash untuk Kali Linux yang berguna untuk membantu kamu mengoptimalkan sistem, jaringan, dan memperbaiki masalah umum yang sering ditemukan! 🚀🐧

---

### 1. ⚙️ `system_optimizer.sh`  
Skrip ini dirancang untuk mengoptimalkan performa Kali Linux, untuk memory 2GB dan Processor 2.  
Fitur utamanya:  
- Backup pengaturan sistem 💾  
- Optimasi parameter kernel dan konfigurasi swap 🔄  
- Menonaktifkan layanan yang kurang penting 📴  
- Optimasi boot loader GRUB ⚡  
- Tweaks khusus VMware 🖥️  

---

### 2. 🌐 `network_optimizer.sh`  
Skrip ini mengoptimalkan performa jaringan Kali Linux, terutama dalam virtualisasi VMware.  
Fitur utama:  
- Backup konfigurasi jaringan 🔍  
- Optimasi TCP/IP stack dan setting VMware 🌟  
- Penyesuaian interface jaringan dan DNS 🔄  
- Instalasi alat monitoring performa jaringan 📊  

---

### 3. 🚫 `fix_no_space_error.sh`  
Kamu mengalami error "No Space Left on Device" padahal ruang masih ada. 
Fitur:  
- Membersihkan file temporer dan log 🧹  
- Bersihkan cache user dan paket Docker/Snap 🐳📦  
- Menampilkan info disk dan inode 🗂️  
- Pilihan pembersihan cepat, penuh, atau khusus ⚙️  

---

### 4. 💀 `fix_oom_killer.sh`  
Skrip ini membantu menghindari masalah Out-Of-Memory (OOM) di Kali Linux yang dapat menyebabkan proses dihentikan secara paksa.  
Fitur:  
- Membuat swap file dan konfigurasi swap 🔄  
- Optimasi swappiness 🛠️  
- Penyesuaian konfigurasi OOM Killer agar ramah sistem 🧠  
- Pembersihan cache memori secara berkala 🧼  
- Menonaktifkan layanan yang tidak perlu 🚫  
- Membuat layanan monitoring memori 📈  
- Optimasi Zswap untuk manajemen memori efisien ♻️  

---

## 📌 Cara Penggunaan

1. Berikan izin sebelum eksekusi pada skrip-skrip tersebut.  
```bash
chmod +x system_optimizer.sh network_optimizer.sh fix_no_space_error.sh fix_oom_killer.sh
