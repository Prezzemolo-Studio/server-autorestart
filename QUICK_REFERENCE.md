# Quick Reference Guide - Auto-Restart Configuration

## 🚀 Comandi Rapidi

### Installazione
```bash
# Installazione completa (auto-rileva tutti i servizi)
sudo ./setup_autorestart_all.sh
```

### Verifica Stato
```bash
# Stato del servizio principale
sudo systemctl status nginx

# Stato del timer di monitoraggio
sudo systemctl status restart-nginx.timer

# Lista tutti i timer attivi
sudo systemctl list-timers --all | grep restart

# Visualizza prossime esecuzioni dei timer
sudo systemctl list-timers
```

### Visualizzazione Log
```bash
# Log del servizio principale (ultimi 50 righe + follow)
sudo journalctl -u nginx -n 50 -f

# Log completo del servizio dall'ultimo boot
sudo journalctl -u nginx -b

# Log dello script di monitoraggio
sudo tail -f /var/log/restart-nginx.log

# Log di setup
sudo cat /var/log/autorestart_setup.log

# Cerca errori nei log
sudo journalctl -u nginx -p err -n 100
```

### Test del Sistema
```bash
# Simula un crash (ATTENZIONE: causa downtime!)
sudo systemctl kill --signal=SIGKILL nginx

# Verifica dopo 15 secondi che sia ripartito
sleep 15 && sudo systemctl status nginx

# Testa manualmente lo script di monitoraggio
sudo /usr/local/bin/restart-nginx.sh
```

### Gestione Timer
```bash
# Ferma temporaneamente il monitoraggio
sudo systemctl stop restart-nginx.timer

# Riavvia il monitoraggio
sudo systemctl start restart-nginx.timer

# Disabilita permanentemente (non parte al boot)
sudo systemctl disable restart-nginx.timer

# Riabilita
sudo systemctl enable restart-nginx.timer

# Forza esecuzione immediata
sudo systemctl start restart-nginx.service
```

### Disinstallazione
```bash
# Rimuovi tutto
sudo ./uninstall_autorestart.sh

# Rimuovi solo nginx
sudo ./uninstall_autorestart.sh --service nginx

# Anteprima rimozione
sudo ./uninstall_autorestart.sh --dry-run

# Anteprima rimozione specifica
sudo ./uninstall_autorestart.sh --service mysql --dry-run
```

### Troubleshooting
```bash
# Verifica che l'override sia caricato
sudo systemctl cat nginx | grep -A 10 "99-auto-restart"

# Reset counter di riavvii falliti
sudo systemctl reset-failed nginx

# Ricarica configurazione systemd
sudo systemctl daemon-reload

# Verifica sintassi configurazione servizio
sudo nginx -t                    # Nginx
sudo apache2ctl configtest       # Apache
sudo mysqld --help --verbose     # MySQL

# Controlla memoria
free -h
sudo dmesg | grep -i "out of memory"
sudo dmesg | grep -i "killed process"

# Lista processi per uso memoria
ps aux --sort=-%mem | head -20

# Verifica swap
sudo swapon --show
```

## 📊 Interpretazione Output

### systemctl status nginx
```
● nginx.service - A high performance web server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled)
  Drop-In: /etc/systemd/system/nginx.service.d
           └─99-auto-restart.conf    ← La tua configurazione è attiva
   Active: active (running)           ← Servizio in esecuzione
   ...
```

### systemctl status restart-nginx.timer
```
● restart-nginx.timer - Esegue controllo periodico di nginx
   Loaded: loaded (/etc/systemd/system/restart-nginx.timer; enabled)
   Active: active (waiting)           ← Timer attivo, in attesa
   Trigger: Mon 2025-11-18 15:32:00  ← Prossima esecuzione
   ...
```

### journalctl output critico
```
Nov 18 15:30:00 server systemd[1]: nginx.service: Main process exited, code=killed, status=9/KILL
Nov 18 15:30:00 server systemd[1]: nginx.service: Failed with result 'oom-kill'.
                                    ↑ Il processo è stato ucciso per OOM
Nov 18 15:30:10 server systemd[1]: nginx.service: Scheduled restart job
                                    ↑ Riavvio programmato (grazie al nostro override)
Nov 18 15:30:10 server systemd[1]: Started A high performance web server.
                                    ↑ Servizio riavviato con successo
```

## 🔧 Modifiche Comuni

### Cambia frequenza di controllo
```bash
# Edita il timer
sudo nano /etc/systemd/system/restart-nginx.timer

# Modifica OnUnitActiveSec da 1min a 5min
OnUnitActiveSec=5min

# Ricarica e riavvia
sudo systemctl daemon-reload
sudo systemctl restart restart-nginx.timer
```

### Aumenta tolleranza ai riavvii
```bash
# Edita l'override
sudo nano /etc/systemd/system/nginx.service.d/99-auto-restart.conf

# Cambia StartLimitBurst da 5 a 10
StartLimitBurst=10

# Ricarica configurazione
sudo systemctl daemon-reload
```

### Aggiungi notifiche email (esempio con sendmail)
```bash
# Edita lo script di monitoraggio
sudo nano /usr/local/bin/restart-nginx.sh

# Aggiungi dopo il riavvio riuscito:
if systemctl restart "$SERVICE"; then
    log_message "SUCCESS: $SERVICE riavviato con successo"
    # Invia notifica
    echo "Il servizio $SERVICE è stato riavviato automaticamente su $(hostname)" | \
        mail -s "ALERT: $SERVICE riavviato" admin@example.com
fi
```

## 📈 Monitoraggio Avanzato

### Statistiche riavvii
```bash
# Conta i riavvii nell'ultima settimana
sudo journalctl -u nginx --since "1 week ago" | grep "Scheduled restart" | wc -l

# Mostra orari di tutti i riavvii
sudo journalctl -u nginx --since "1 week ago" | grep "Scheduled restart"

# Trova la causa degli ultimi 5 crash
sudo journalctl -u nginx -p err -n 5 --no-pager
```

### Crea script di report giornaliero
```bash
#!/bin/bash
# Salva come /usr/local/bin/daily-restart-report.sh

echo "=== Report Riavvii Automatici - $(date) ===" > /var/log/daily-restart-report.log

for service in nginx mysql; do
    count=$(journalctl -u "$service" --since "24 hours ago" | grep -c "Scheduled restart" || echo "0")
    echo "$service: $count riavvii nelle ultime 24 ore" >> /var/log/daily-restart-report.log
done

# Opzionale: invia via email
# mail -s "Report Riavvii $(hostname)" admin@example.com < /var/log/daily-restart-report.log
```

### Integrazione con monitoring (esempio Prometheus)
```bash
# Script che espone metriche per node_exporter textfile collector
#!/bin/bash
# Salva come /usr/local/bin/export-restart-metrics.sh

TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"

for service in nginx mysql; do
    count=$(journalctl -u "$service" --since "1 hour ago" | grep -c "Scheduled restart" || echo "0")
    echo "service_restarts_total{service=\"$service\"} $count" >> "$TEXTFILE_DIR/restarts.prom.$$"
done

mv "$TEXTFILE_DIR/restarts.prom.$$" "$TEXTFILE_DIR/restarts.prom"
```

## ⚠️ Situazioni di Emergenza

### Il servizio non riparte più (StartLimit raggiunto)
```bash
# 1. Reset del counter
sudo systemctl reset-failed nginx

# 2. Analizza il problema
sudo journalctl -u nginx -n 100 --no-pager

# 3. Riavvio manuale
sudo systemctl start nginx

# 4. Se continua a crashare, DEVI risolvere il problema di fondo!
```

### OOM Kill continuo
```bash
# 1. Controlla la memoria
free -h

# 2. Identifica il colpevole
sudo dmesg | grep -i "killed process"

# 3. Aggiungi swap di emergenza (temporaneo)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 4. Ottimizza la configurazione del servizio
# Per MySQL:
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# Riduci innodb_buffer_pool_size

# Per Nginx:
sudo nano /etc/nginx/nginx.conf
# Riduci worker_processes e worker_connections
```

### Disabilita temporaneamente auto-restart per manutenzione
```bash
# Ferma i timer
for service in nginx mysql; do
    sudo systemctl stop restart-${service}.timer
done

# Verifica
sudo systemctl list-timers | grep restart

# Dopo la manutenzione, riattiva
for service in nginx mysql; do
    sudo systemctl start restart-${service}.timer
done
```

## 📞 Checklist Pre-Produzione

Prima di mettere in produzione, verifica:

- [ ] Script eseguito con successo
- [ ] Tutti i servizi rilevati e configurati
- [ ] Timer attivi e funzionanti (`systemctl list-timers`)
- [ ] Test di crash simulato superato
- [ ] Log accessibili e monitorati
- [ ] Notifiche configurate (se necessario)
- [ ] Team informato della configurazione
- [ ] Documentazione aggiornata
- [ ] Piano di rollback pronto (`uninstall_autorestart.sh`)
- [ ] Problema di fondo identificato e in risoluzione

## 🔗 Link Utili

- Documentazione systemd: `man systemd.service`, `man systemd.timer`
- Log systemd: `man journalctl`
- Troubleshooting MySQL OOM: Ottimizza `innodb_buffer_pool_size`
- Monitoring: Considera Prometheus + Grafana o Zabbix
