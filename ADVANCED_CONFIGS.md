# Configurazioni Avanzate e Casi d'Uso Specifici

## 📋 Indice
1. [Profili di Configurazione](#profili-di-configurazione)
2. [Notifiche](#notifiche)
3. [Integrazione con Monitoring](#integrazione-con-monitoring)
4. [Scenari Specifici](#scenari-specifici)
5. [Multi-Servizio](#multi-servizio)

---

## 1. Profili di Configurazione

### Profilo "Aggressivo" - Per servizi critici ad alta priorità
Riavvio rapido, molti tentativi, controllo frequente

```bash
# File: /etc/systemd/system/nginx.service.d/99-auto-restart.conf
[Service]
Restart=always                          # Riavvia SEMPRE (anche se esce pulito)
RestartSec=3s                           # Riavvio dopo soli 3 secondi
StartLimitIntervalSec=600s              # Finestra di 10 minuti
StartLimitBurst=15                      # Fino a 15 riavvii in 10 minuti

# File: /etc/systemd/system/restart-nginx.timer
[Timer]
OnBootSec=30s                           # Primo controllo dopo 30 sec
OnUnitActiveSec=30s                     # Controlla ogni 30 secondi
```

**Quando usarlo:**
- E-commerce ad alto traffico
- API critiche
- Servizi con SLA stringenti

**⚠️ Attenzione:** Può mascherare problemi seri. Monitora sempre!

---

### Profilo "Conservativo" - Per servizi pesanti/lenti
Riavvio lento, pochi tentativi, controllo sporadico

```bash
# File: /etc/systemd/system/mysql.service.d/99-auto-restart.conf
[Service]
Restart=on-failure                      # Solo in caso di errore
RestartSec=60s                          # Attendi 1 minuto prima di riavviare
StartLimitIntervalSec=600s              # Finestra di 10 minuti
StartLimitBurst=3                       # Solo 3 tentativi in 10 minuti

# File: /etc/systemd/system/restart-mysql.timer
[Timer]
OnBootSec=5min                          # Primo controllo dopo 5 minuti
OnUnitActiveSec=10min                   # Controlla ogni 10 minuti
```

**Quando usarlo:**
- Database di grandi dimensioni
- Servizi con startup lento (>1 min)
- Ambienti con risorse limitate

---

### Profilo "Bilanciato" - Default raccomandato
Compromesso tra reattività e stabilità

```bash
# File: /etc/systemd/system/nginx.service.d/99-auto-restart.conf
[Service]
Restart=on-failure
RestartSec=10s
StartLimitIntervalSec=300s
StartLimitBurst=5

# File: /etc/systemd/system/restart-nginx.timer
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
```

**Quando usarlo:**
- Maggior parte dei casi
- Setup iniziale
- Quando non hai requisiti particolari

---

## 2. Notifiche

### Notifica Email (con mailutils/sendmail)

```bash
# Installa prerequisiti
sudo apt-get install mailutils

# Modifica /usr/local/bin/restart-nginx.sh
#!/bin/bash

SERVICE="nginx"
LOG_FILE="/var/log/restart-${SERVICE}.log"
ALERT_EMAIL="admin@example.com"

log_and_alert() {
    local message="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    echo "$message" | mail -s "[ALERT] $SERVICE su $(hostname)" "$ALERT_EMAIL"
}

if ! systemctl is-active --quiet "$SERVICE"; then
    log_and_alert "ALERT: $SERVICE non è attivo. Tentativo di riavvio..."
    
    if systemctl restart "$SERVICE"; then
        log_and_alert "SUCCESS: $SERVICE riavviato con successo"
    else
        log_and_alert "CRITICAL: Riavvio di $SERVICE fallito!"
        exit 1
    fi
fi
```

---

### Notifica Slack/Discord (con webhook)

```bash
#!/bin/bash
SERVICE="nginx"
WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

send_slack_alert() {
    local message="$1"
    local color="$2"  # good, warning, danger
    
    curl -X POST "$WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"attachments\": [{
                \"color\": \"$color\",
                \"title\": \"Riavvio Automatico - $SERVICE\",
                \"text\": \"$message\",
                \"fields\": [
                    {
                        \"title\": \"Server\",
                        \"value\": \"$(hostname)\",
                        \"short\": true
                    },
                    {
                        \"title\": \"Timestamp\",
                        \"value\": \"$(date +'%Y-%m-%d %H:%M:%S')\",
                        \"short\": true
                    }
                ]
            }]
        }"
}

if ! systemctl is-active --quiet "$SERVICE"; then
    send_slack_alert "⚠️ $SERVICE non attivo, riavvio in corso..." "warning"
    
    if systemctl restart "$SERVICE"; then
        send_slack_alert "✅ $SERVICE riavviato con successo" "good"
    else
        send_slack_alert "🚨 CRITICO: Impossibile riavviare $SERVICE!" "danger"
    fi
fi
```

---

### Notifica Telegram (con Bot API)

```bash
#!/bin/bash
SERVICE="nginx"
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="🖥️ *$(hostname)*%0A⚙️ Servizio: *$SERVICE*%0A$message" \
        -d parse_mode="Markdown" > /dev/null
}

if ! systemctl is-active --quiet "$SERVICE"; then
    send_telegram "⚠️ Servizio DOWN - Riavvio in corso..."
    
    if systemctl restart "$SERVICE"; then
        send_telegram "✅ Servizio riavviato con successo"
    else
        send_telegram "🚨 ERRORE CRITICO - Riavvio fallito!"
    fi
fi
```

---

## 3. Integrazione con Monitoring

### Prometheus Node Exporter - Textfile Collector

```bash
#!/bin/bash
# File: /usr/local/bin/export-restart-metrics.sh

TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
mkdir -p "$TEXTFILE_DIR"

# Servizi da monitorare
SERVICES=("nginx" "mysql" "postgresql")

# File temporaneo
TEMP_FILE="$TEXTFILE_DIR/service_restarts.prom.$$"

# Genera metriche
for service in "${SERVICES[@]}"; do
    # Conta riavvii nell'ultima ora
    restarts_1h=$(journalctl -u "$service" --since "1 hour ago" 2>/dev/null | \
                  grep -c "Scheduled restart" || echo "0")
    
    # Conta riavvii nelle ultime 24 ore
    restarts_24h=$(journalctl -u "$service" --since "24 hours ago" 2>/dev/null | \
                   grep -c "Scheduled restart" || echo "0")
    
    # Stato del servizio (1 = attivo, 0 = non attivo)
    if systemctl is-active --quiet "$service"; then
        status=1
    else
        status=0
    fi
    
    # Scrivi metriche
    echo "service_restarts_total{service=\"$service\",period=\"1h\"} $restarts_1h" >> "$TEMP_FILE"
    echo "service_restarts_total{service=\"$service\",period=\"24h\"} $restarts_24h" >> "$TEMP_FILE"
    echo "service_status{service=\"$service\"} $status" >> "$TEMP_FILE"
done

# Timestamp dell'ultima generazione
echo "service_metrics_last_update $(date +%s)" >> "$TEMP_FILE"

# Sostituisci il file atomicamente
mv "$TEMP_FILE" "$TEXTFILE_DIR/service_restarts.prom"
```

**Aggiungi a crontab:**
```bash
# Esegui ogni 5 minuti
*/5 * * * * /usr/local/bin/export-restart-metrics.sh
```

**Query Prometheus:**
```promql
# Servizi riavviati nell'ultima ora
service_restarts_total{period="1h"} > 0

# Servizi down
service_status == 0

# Alert rule esempio
alert: ServiceFrequentRestarts
expr: increase(service_restarts_total{period="1h"}[1h]) > 5
for: 5m
labels:
  severity: warning
annotations:
  summary: "Servizio {{ $labels.service }} riavviato troppo frequentemente"
```

---

### Zabbix - User Parameter

```bash
# File: /etc/zabbix/zabbix_agentd.d/service_restarts.conf

# Conta riavvii di un servizio
UserParameter=service.restarts[*],journalctl -u $1 --since "1 hour ago" 2>/dev/null | grep -c "Scheduled restart" || echo 0

# Stato del servizio
UserParameter=service.status[*],systemctl is-active $1 > /dev/null 2>&1 && echo 1 || echo 0

# Ultimo riavvio (timestamp)
UserParameter=service.last_restart[*],journalctl -u $1 -n 1 --output=short-unix 2>/dev/null | grep "Started" | awk '{print $1}' || echo 0
```

**Template items Zabbix:**
```
Nome: Nginx Restarts (1h)
Chiave: service.restarts[nginx]
Tipo: Numeric (unsigned)
Trigger: {host:service.restarts[nginx].last()}>5
```

---

## 4. Scenari Specifici

### Scenario: Server con Risorse Limitate (VPS piccoli)

**Problema:** Troppe risorse consumate dal monitoring
**Soluzione:** Monitoraggio meno frequente, log ridotti

```bash
# Timer ogni 5 minuti invece di 1
[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

# Script con logging minimale
#!/bin/bash
SERVICE="nginx"

if ! systemctl is-active --quiet "$SERVICE"; then
    # Log solo i riavvii, non i controlli OK
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Riavvio $SERVICE" >> /var/log/restart-${SERVICE}.log
    systemctl restart "$SERVICE"
fi
```

---

### Scenario: Database con Backup Automatici

**Problema:** Il riavvio durante un backup può corrompere i dati
**Soluzione:** Controlla se c'è un backup in corso prima di riavviare

```bash
#!/bin/bash
SERVICE="mysql"
BACKUP_LOCK="/var/run/mysql-backup.lock"

if ! systemctl is-active --quiet "$SERVICE"; then
    # Controlla se c'è un backup in corso
    if [ -f "$BACKUP_LOCK" ]; then
        echo "[$(date)] Backup in corso, riavvio posticipato" >> /var/log/restart-${SERVICE}.log
        exit 0
    fi
    
    echo "[$(date)] Riavvio $SERVICE" >> /var/log/restart-${SERVICE}.log
    systemctl restart "$SERVICE"
fi
```

**Nel tuo script di backup:**
```bash
# All'inizio del backup
touch /var/run/mysql-backup.lock

# Alla fine del backup
rm -f /var/run/mysql-backup.lock
```

---

### Scenario: Web Server dietro Load Balancer

**Problema:** Durante il riavvio, il LB manda traffico al server down
**Soluzione:** Deregistra dal LB prima del riavvio

```bash
#!/bin/bash
SERVICE="nginx"
LB_API="http://loadbalancer/api/v1"
SERVER_ID="web01"

deregister_from_lb() {
    curl -X POST "$LB_API/deregister" -d "server=$SERVER_ID"
    sleep 5  # Attendi che il LB propaghi la modifica
}

register_to_lb() {
    curl -X POST "$LB_API/register" -d "server=$SERVER_ID"
}

if ! systemctl is-active --quiet "$SERVICE"; then
    echo "[$(date)] $SERVICE down, deregistrazione da LB..." >> /var/log/restart-${SERVICE}.log
    deregister_from_lb
    
    echo "[$(date)] Riavvio $SERVICE..." >> /var/log/restart-${SERVICE}.log
    systemctl restart "$SERVICE"
    
    # Attendi che il servizio sia completamente pronto
    sleep 10
    
    echo "[$(date)] Registrazione su LB..." >> /var/log/restart-${SERVICE}.log
    register_to_lb
fi
```

---

### Scenario: Ambiente di Sviluppo/Test

**Problema:** Troppi alert per problemi non critici
**Soluzione:** Alert solo in produzione, log verbosi in dev

```bash
#!/bin/bash
SERVICE="nginx"
ENVIRONMENT="${ENVIRONMENT:-production}"  # Leggi da variabile d'ambiente

if ! systemctl is-active --quiet "$SERVICE"; then
    if [ "$ENVIRONMENT" == "production" ]; then
        # In produzione: alert immediato
        echo "[PROD] $SERVICE down!" | mail -s "ALERT PROD" ops@example.com
    else
        # In dev/test: solo log
        echo "[$(date)] [$ENVIRONMENT] $SERVICE riavviato" >> /var/log/restart-${SERVICE}.log
    fi
    
    systemctl restart "$SERVICE"
fi
```

---

## 5. Multi-Servizio

### Riavvio con Dipendenze

**Scenario:** Nginx dipende da PHP-FPM

```bash
#!/bin/bash
PRIMARY_SERVICE="nginx"
DEPENDENT_SERVICES=("php7.4-fpm" "php8.1-fpm")

restart_with_dependencies() {
    echo "[$(date)] Riavvio $PRIMARY_SERVICE e dipendenze..." >> /var/log/restart-multi.log
    
    # Riavvia prima le dipendenze
    for dep in "${DEPENDENT_SERVICES[@]}"; do
        if systemctl is-active --quiet "$dep"; then
            systemctl restart "$dep"
            echo "  - Riavviato: $dep" >> /var/log/restart-multi.log
        fi
    done
    
    # Poi il servizio principale
    systemctl restart "$PRIMARY_SERVICE"
    echo "  - Riavviato: $PRIMARY_SERVICE" >> /var/log/restart-multi.log
}

if ! systemctl is-active --quiet "$PRIMARY_SERVICE"; then
    restart_with_dependencies
fi
```

---

### Riavvio Ordinato di Stack Completo

```bash
#!/bin/bash
# File: /usr/local/bin/restart-stack.sh
# Per stack tipo: PostgreSQL -> Redis -> API Backend -> Nginx

SERVICES_ORDERED=(
    "postgresql"
    "redis-server"
    "myapp-api"
    "nginx"
)

restart_stack() {
    echo "[$(date)] Riavvio completo dello stack..." | tee -a /var/log/restart-stack.log
    
    for service in "${SERVICES_ORDERED[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo "  [OK] $service è attivo" | tee -a /var/log/restart-stack.log
        else
            echo "  [!!] $service è down, riavvio..." | tee -a /var/log/restart-stack.log
            systemctl restart "$service"
            
            # Attendi che sia completamente pronto
            sleep 5
            
            if systemctl is-active --quiet "$service"; then
                echo "  [✓] $service riavviato con successo" | tee -a /var/log/restart-stack.log
            else
                echo "  [✗] ERRORE: $service non è ripartito!" | tee -a /var/log/restart-stack.log
                # Alert critico
                echo "Stack restart failed at $service" | mail -s "CRITICAL" ops@example.com
                return 1
            fi
        fi
    done
    
    echo "[$(date)] Stack completamente operativo" | tee -a /var/log/restart-stack.log
}

# Esegui solo se almeno un servizio è down
for service in "${SERVICES_ORDERED[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        restart_stack
        break
    fi
done
```

---

## 📝 Note Finali

Tutte queste configurazioni sono **esempi** che vanno adattati al tuo caso specifico.

**Regole d'oro:**
1. **Testa sempre** in ambiente non-produzione prima
2. **Monitora** l'effetto delle modifiche
3. **Documenta** ogni personalizzazione
4. **Risolvi** i problemi di fondo, non limitarti al riavvio automatico

**Ricorda:** Il riavvio automatico è una **protezione**, non una **soluzione**.
