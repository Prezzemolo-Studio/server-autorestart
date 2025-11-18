#!/bin/bash

################################################################################
# SCRIPT OMNIVALENTE PER IL RIAVVIO AUTOMATICO DI WEB SERVER E DATABASE
################################################################################
#
# Questo script rileva automaticamente i servizi presenti sul server e configura
# il riavvio automatico per ciascuno di essi utilizzando systemd.
#
# SERVIZI SUPPORTATI:
#   - Web Server: Apache (apache2), Nginx
#   - Database: MySQL, MariaDB, PostgreSQL
#
# METODI IMPLEMENTATI:
#   1. Override systemd con Restart=on-failure
#   2. Timer systemd per controllo periodico (ogni minuto)
#
# REQUISITI:
#   - Sistema operativo con systemd
#   - Privilegi di root (eseguire con sudo)
#
# USO:
#   sudo ./setup_autorestart_all.sh
#
# AUTORE: DevOps Team
# VERSIONE: 2.0
# DATA: 2025-11-18
################################################################################

set -e  # Interrompe l'esecuzione in caso di errore
set -u  # Tratta le variabili non definite come errori

# --- CONFIGURAZIONE ---
RESTART_SEC="10s"                    # Ritardo prima del riavvio
START_LIMIT_INTERVAL="300s"          # Finestra temporale per contare i fallimenti
START_LIMIT_BURST="5"                # Numero massimo di riavvii nella finestra
TIMER_INTERVAL="1min"                # Frequenza del controllo periodico

# Directory e percorsi
SYSTEMD_OVERRIDE_DIR="/etc/systemd/system"
SCRIPT_DIR="/usr/local/bin"
LOG_FILE="/var/log/autorestart_setup.log"

# --- COLORI PER OUTPUT (opzionali, rimossi se causano problemi) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# FUNZIONI UTILITY
################################################################################

# Logging con timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Output colorato
print_success() {
    echo -e "${GREEN}[OK]${NC} $*"
    log "[OK] $*"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    log "[INFO] $*"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    log "[WARN] $*"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    log "[ERROR] $*"
}

# Controlla se un servizio systemd esiste ed è attivo
service_exists_and_active() {
    local service_name=$1
    systemctl list-units --type=service --state=active | grep -q "^[[:space:]]*${service_name}.service" 2>/dev/null
}

# Controlla se un comando esiste
command_exists() {
    command -v "$1" &> /dev/null
}

################################################################################
# CONTROLLI PRELIMINARI
################################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Questo script deve essere eseguito con privilegi di root"
        echo "Esegui: sudo $0"
        exit 1
    fi
}

check_systemd() {
    if ! command_exists systemctl; then
        print_error "systemd non trovato. Questo script richiede systemd."
        exit 1
    fi
}

################################################################################
# RILEVAMENTO SERVIZI
################################################################################

detect_services() {
    local -n services_ref=$1
    
    print_info "Scansione dei servizi attivi sul server..."
    
    # Web Server
    if command_exists apache2 && service_exists_and_active apache2; then
        services_ref+=("apache2")
        print_success "Rilevato: Apache (apache2)"
    fi
    
    if command_exists nginx && service_exists_and_active nginx; then
        services_ref+=("nginx")
        print_success "Rilevato: Nginx"
    fi
    
    # Database - MySQL
    if service_exists_and_active mysql; then
        services_ref+=("mysql")
        print_success "Rilevato: MySQL"
    elif service_exists_and_active mysqld; then
        services_ref+=("mysqld")
        print_success "Rilevato: MySQL (mysqld)"
    fi
    
    # Database - MariaDB (potrebbe essere un alias di mysql)
    if service_exists_and_active mariadb && ! service_exists_and_active mysql; then
        services_ref+=("mariadb")
        print_success "Rilevato: MariaDB"
    fi
    
    # Database - PostgreSQL
    if service_exists_and_active postgresql; then
        services_ref+=("postgresql")
        print_success "Rilevato: PostgreSQL"
    fi
    
    # Conta i servizi trovati
    if [ ${#services_ref[@]} -eq 0 ]; then
        print_warning "Nessun servizio supportato trovato in esecuzione"
        print_info "Servizi supportati: apache2, nginx, mysql, mariadb, postgresql"
        return 1
    fi
    
    print_info "Totale servizi rilevati: ${#services_ref[@]}"
    return 0
}

################################################################################
# CONFIGURAZIONE METODO 1: OVERRIDE SYSTEMD
################################################################################

configure_systemd_override() {
    local service_name=$1
    local override_dir="${SYSTEMD_OVERRIDE_DIR}/${service_name}.service.d"
    local override_file="${override_dir}/99-auto-restart.conf"
    
    print_info "[Metodo 1] Configurazione override systemd per ${service_name}"
    
    # Crea directory se non esiste
    if [ ! -d "$override_dir" ]; then
        mkdir -p "$override_dir"
        print_info "Creata directory: ${override_dir}"
    fi
    
    # Controlla se il file esiste già
    if [ -f "$override_file" ]; then
        print_info "File di override esistente, aggiornamento in corso..."
    else
        print_info "Creazione nuovo file di override..."
    fi
    
    # Crea/aggiorna il file di configurazione
    cat > "$override_file" << EOF
# Auto-generato da setup_autorestart_all.sh
# Data: $(date +'%Y-%m-%d %H:%M:%S')
#
# Questa configurazione fa sì che systemd riavvii automaticamente
# il servizio in caso di fallimento (crash, OOM kill, etc.)

[Service]
# Riavvia il servizio solo in caso di uscita con errore
Restart=on-failure

# Attendi ${RESTART_SEC} prima di riavviare
RestartSec=${RESTART_SEC}

# Finestra temporale per contare i tentativi di riavvio
StartLimitIntervalSec=${START_LIMIT_INTERVAL}

# Numero massimo di riavvii nella finestra temporale
# Se superato, il servizio entra in stato 'failed'
StartLimitBurst=${START_LIMIT_BURST}
EOF
    
    print_success "Override systemd configurato: ${override_file}"
}

################################################################################
# CONFIGURAZIONE METODO 2: SCRIPT + TIMER
################################################################################

configure_monitoring_script() {
    local service_name=$1
    local script_path="${SCRIPT_DIR}/restart-${service_name}.sh"
    
    print_info "[Metodo 2] Creazione script di monitoraggio per ${service_name}"
    
    # Controlla se lo script esiste già
    if [ -f "$script_path" ]; then
        print_info "Script esistente, aggiornamento in corso..."
    else
        print_info "Creazione nuovo script..."
    fi
    
    # Crea lo script di monitoraggio
    cat > "$script_path" << 'EOF'
#!/bin/bash
#
# Script di monitoraggio e riavvio automatico
# Generato da: setup_autorestart_all.sh
# Servizio: SERVICE_NAME_PLACEHOLDER
#

SERVICE="SERVICE_NAME_PLACEHOLDER"
LOG_FILE="/var/log/restart-${SERVICE}.log"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Controlla se il servizio è attivo
if ! systemctl is-active --quiet "$SERVICE"; then
    log_message "ALERT: $SERVICE non è attivo. Tentativo di riavvio..."
    
    # Tenta il riavvio
    if systemctl restart "$SERVICE"; then
        log_message "SUCCESS: $SERVICE riavviato con successo"
    else
        log_message "ERROR: Riavvio di $SERVICE fallito"
        exit 1
    fi
else
    # Servizio attivo, nessuna azione necessaria
    # Decommenta la riga sotto per logging verboso
    # log_message "OK: $SERVICE è attivo"
    :
fi
EOF
    
    # Sostituisci il placeholder con il nome del servizio reale
    sed -i "s/SERVICE_NAME_PLACEHOLDER/${service_name}/g" "$script_path"
    
    # Rendi lo script eseguibile
    chmod +x "$script_path"
    
    print_success "Script di monitoraggio creato: ${script_path}"
}

configure_systemd_service() {
    local service_name=$1
    local service_file="${SYSTEMD_OVERRIDE_DIR}/restart-${service_name}.service"
    local script_path="${SCRIPT_DIR}/restart-${service_name}.sh"
    
    print_info "[Metodo 2] Creazione servizio systemd per ${service_name}"
    
    cat > "$service_file" << EOF
# Auto-generato da setup_autorestart_all.sh
# Data: $(date +'%Y-%m-%d %H:%M:%S')

[Unit]
Description=Controlla e riavvia ${service_name} se non è in esecuzione
After=network.target

[Service]
Type=oneshot
ExecStart=${script_path}
StandardOutput=journal
StandardError=journal

# Timeout per l'esecuzione dello script
TimeoutStartSec=30s
EOF
    
    print_success "Servizio systemd creato: ${service_file}"
}

configure_systemd_timer() {
    local service_name=$1
    local timer_file="${SYSTEMD_OVERRIDE_DIR}/restart-${service_name}.timer"
    
    print_info "[Metodo 2] Creazione timer systemd per ${service_name}"
    
    cat > "$timer_file" << EOF
# Auto-generato da setup_autorestart_all.sh
# Data: $(date +'%Y-%m-%d %H:%M:%S')

[Unit]
Description=Esegue controllo periodico di ${service_name}
Requires=restart-${service_name}.service

[Timer]
# Esegui il primo controllo 1 minuto dopo il boot
OnBootSec=${TIMER_INTERVAL}

# Esegui controlli periodici ogni minuto
OnUnitActiveSec=${TIMER_INTERVAL}

# Servizio da eseguire
Unit=restart-${service_name}.service

# Evita di accumulare esecuzioni se il sistema è inattivo
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF
    
    print_success "Timer systemd creato: ${timer_file}"
}

################################################################################
# APPLICAZIONE CONFIGURAZIONE
################################################################################

apply_configuration() {
    local service_name=$1
    
    print_info "Applicazione configurazione per ${service_name}..."
    
    # Ricarica systemd per riconoscere i nuovi file
    systemctl daemon-reload
    
    # Abilita e avvia il timer
    local timer_name="restart-${service_name}.timer"
    
    if systemctl enable "$timer_name" 2>/dev/null; then
        print_success "Timer abilitato all'avvio: ${timer_name}"
    else
        print_warning "Impossibile abilitare il timer: ${timer_name}"
    fi
    
    if systemctl start "$timer_name" 2>/dev/null; then
        print_success "Timer avviato: ${timer_name}"
    else
        print_warning "Impossibile avviare il timer: ${timer_name}"
    fi
    
    # Riavvia il servizio principale per applicare le modifiche
    print_info "Riavvio del servizio ${service_name} per applicare le modifiche..."
    if systemctl restart "$service_name" 2>/dev/null; then
        print_success "Servizio ${service_name} riavviato con successo"
    else
        print_warning "Impossibile riavviare ${service_name} - verificare manualmente"
    fi
}

################################################################################
# VERIFICA CONFIGURAZIONE
################################################################################

verify_configuration() {
    local service_name=$1
    local timer_name="restart-${service_name}.timer"
    
    print_info "Verifica configurazione per ${service_name}..."
    
    # Verifica che il servizio principale sia attivo
    if systemctl is-active --quiet "$service_name"; then
        print_success "Servizio ${service_name}: ATTIVO"
    else
        print_error "Servizio ${service_name}: NON ATTIVO"
        return 1
    fi
    
    # Verifica che il timer sia attivo
    if systemctl is-active --quiet "$timer_name"; then
        print_success "Timer ${timer_name}: ATTIVO"
    else
        print_warning "Timer ${timer_name}: NON ATTIVO"
    fi
    
    # Verifica che il timer sia abilitato
    if systemctl is-enabled --quiet "$timer_name"; then
        print_success "Timer ${timer_name}: ABILITATO all'avvio"
    else
        print_warning "Timer ${timer_name}: NON ABILITATO all'avvio"
    fi
}

################################################################################
# RIEPILOGO FINALE
################################################################################

print_summary() {
    local services=("$@")
    
    echo ""
    echo "========================================================================"
    echo "                    RIEPILOGO CONFIGURAZIONE                            "
    echo "========================================================================"
    echo ""
    echo "Servizi configurati per il riavvio automatico:"
    for service in "${services[@]}"; do
        echo "  - ${service}"
    done
    echo ""
    echo "File creati/modificati per ciascun servizio:"
    echo "  - /etc/systemd/system/\${service}.service.d/99-auto-restart.conf"
    echo "  - /usr/local/bin/restart-\${service}.sh"
    echo "  - /etc/systemd/system/restart-\${service}.service"
    echo "  - /etc/systemd/system/restart-\${service}.timer"
    echo ""
    echo "Comandi utili per verificare lo stato:"
    echo "  - systemctl status \${service}"
    echo "  - systemctl status restart-\${service}.timer"
    echo "  - systemctl list-timers --all | grep restart"
    echo "  - journalctl -u \${service} -f"
    echo "  - tail -f /var/log/restart-\${service}.log"
    echo ""
    echo "Log di questo script: ${LOG_FILE}"
    echo ""
    echo "========================================================================"
}

################################################################################
# MAIN
################################################################################

main() {
    echo "========================================================================"
    echo "     SCRIPT OMNIVALENTE PER AUTO-RESTART DI WEB SERVER E DATABASE      "
    echo "========================================================================"
    echo ""
    
    # Controlli preliminari
    check_root
    check_systemd
    
    # Inizializza log
    touch "$LOG_FILE"
    log "=== INIZIO ESECUZIONE SCRIPT ==="
    log "Versione: 2.0"
    log "Eseguito da: $(whoami)"
    log "Hostname: $(hostname)"
    
    # Array per memorizzare i servizi rilevati
    declare -a SERVICES_FOUND=()
    
    # Rileva servizi
    if ! detect_services SERVICES_FOUND; then
        print_warning "Nessun servizio da configurare. Uscita."
        exit 0
    fi
    
    echo ""
    print_info "Inizio configurazione per ${#SERVICES_FOUND[@]} servizio/i..."
    echo ""
    
    # Configura ogni servizio rilevato
    for service in "${SERVICES_FOUND[@]}"; do
        echo "--------------------------------------------------------------------"
        print_info "Elaborazione: ${service}"
        echo "--------------------------------------------------------------------"
        
        # Metodo 1: Override systemd
        configure_systemd_override "$service"
        
        # Metodo 2: Script + Timer
        configure_monitoring_script "$service"
        configure_systemd_service "$service"
        configure_systemd_timer "$service"
        
        # Applica configurazione
        apply_configuration "$service"
        
        # Verifica configurazione
        verify_configuration "$service"
        
        echo ""
    done
    
    # Riepilogo finale
    print_summary "${SERVICES_FOUND[@]}"
    
    print_success "Configurazione completata con successo!"
    log "=== FINE ESECUZIONE SCRIPT ==="
    
    echo ""
    echo "NOTA IMPORTANTE:"
    echo "Questa configurazione NON risolve i problemi alla radice (es. OOM kill)."
    echo "E' fortemente consigliato investigare e risolvere le cause dei crash:"
    echo "  - Per OOM: ottimizzare configurazione memoria, aggiungere swap"
    echo "  - Per crash: analizzare i log del servizio"
    echo ""
}

# Esegui lo script
main "$@"
