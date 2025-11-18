#!/bin/bash

################################################################################
# SCRIPT DI DISINSTALLAZIONE AUTO-RESTART
################################################################################
#
# Questo script rimuove completamente la configurazione di auto-restart
# per tutti i servizi configurati dallo script setup_autorestart_all.sh
#
# USO:
#   sudo ./uninstall_autorestart.sh
#
# OPZIONI:
#   sudo ./uninstall_autorestart.sh --service <nome>    # Rimuove solo un servizio specifico
#   sudo ./uninstall_autorestart.sh --dry-run           # Mostra cosa verrebbe rimosso senza farlo
#
################################################################################

set -e
set -u

# --- COLORI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- CONFIGURAZIONE ---
SYSTEMD_OVERRIDE_DIR="/etc/systemd/system"
SCRIPT_DIR="/usr/local/bin"
LOG_FILE="/var/log/autorestart_uninstall.log"
DRY_RUN=false
TARGET_SERVICE=""

################################################################################
# FUNZIONI UTILITY
################################################################################

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Questo script deve essere eseguito con privilegi di root"
        echo "Esegui: sudo $0"
        exit 1
    fi
}

################################################################################
# RILEVAMENTO SERVIZI CONFIGURATI
################################################################################

detect_configured_services() {
    local -n services_ref=$1
    
    print_info "Ricerca servizi con configurazione auto-restart..."
    
    # Cerca tutti i timer di restart
    for timer in "${SYSTEMD_OVERRIDE_DIR}"/restart-*.timer; do
        if [ -f "$timer" ]; then
            # Estrai il nome del servizio dal nome del file timer
            local timer_basename=$(basename "$timer")
            local service_name="${timer_basename#restart-}"
            service_name="${service_name%.timer}"
            
            services_ref+=("$service_name")
            print_info "Trovato: ${service_name}"
        fi
    done
    
    if [ ${#services_ref[@]} -eq 0 ]; then
        print_warning "Nessun servizio con configurazione auto-restart trovato"
        return 1
    fi
    
    print_info "Totale servizi configurati: ${#services_ref[@]}"
    return 0
}

################################################################################
# RIMOZIONE CONFIGURAZIONE
################################################################################

remove_timer() {
    local service_name=$1
    local timer_name="restart-${service_name}.timer"
    
    print_info "Rimozione timer: ${timer_name}"
    
    if $DRY_RUN; then
        print_warning "[DRY-RUN] Verrebbe fermato e disabilitato: ${timer_name}"
        return 0
    fi
    
    # Ferma il timer
    if systemctl is-active --quiet "$timer_name" 2>/dev/null; then
        systemctl stop "$timer_name"
        print_success "Timer fermato: ${timer_name}"
    fi
    
    # Disabilita il timer
    if systemctl is-enabled --quiet "$timer_name" 2>/dev/null; then
        systemctl disable "$timer_name"
        print_success "Timer disabilitato: ${timer_name}"
    fi
}

remove_files() {
    local service_name=$1
    
    print_info "Rimozione file di configurazione per: ${service_name}"
    
    local files_to_remove=(
        "${SYSTEMD_OVERRIDE_DIR}/${service_name}.service.d/99-auto-restart.conf"
        "${SCRIPT_DIR}/restart-${service_name}.sh"
        "${SYSTEMD_OVERRIDE_DIR}/restart-${service_name}.service"
        "${SYSTEMD_OVERRIDE_DIR}/restart-${service_name}.timer"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            if $DRY_RUN; then
                print_warning "[DRY-RUN] Verrebbe rimosso: ${file}"
            else
                rm -f "$file"
                print_success "Rimosso: ${file}"
            fi
        fi
    done
    
    # Rimuovi la directory di override se è vuota
    local override_dir="${SYSTEMD_OVERRIDE_DIR}/${service_name}.service.d"
    if [ -d "$override_dir" ] && [ -z "$(ls -A "$override_dir")" ]; then
        if $DRY_RUN; then
            print_warning "[DRY-RUN] Verrebbe rimossa directory vuota: ${override_dir}"
        else
            rmdir "$override_dir"
            print_success "Rimossa directory vuota: ${override_dir}"
        fi
    fi
    
    # Log del servizio (opzionale, chiedi conferma)
    local log_file="/var/log/restart-${service_name}.log"
    if [ -f "$log_file" ]; then
        if $DRY_RUN; then
            print_warning "[DRY-RUN] File di log mantenuto: ${log_file}"
        else
            read -p "Rimuovere anche il file di log ${log_file}? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -f "$log_file"
                print_success "Rimosso: ${log_file}"
            else
                print_info "File di log mantenuto: ${log_file}"
            fi
        fi
    fi
}

reload_systemd() {
    print_info "Ricaricamento configurazione systemd..."
    
    if $DRY_RUN; then
        print_warning "[DRY-RUN] Verrebbe eseguito: systemctl daemon-reload"
        return 0
    fi
    
    systemctl daemon-reload
    print_success "Configurazione systemd ricaricata"
}

################################################################################
# GESTIONE ARGOMENTI
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --service)
                TARGET_SERVICE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Argomento sconosciuto: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Script di Disinstallazione Auto-Restart

USO:
    sudo $0 [OPZIONI]

OPZIONI:
    --service <nome>    Rimuove la configurazione solo per il servizio specificato
    --dry-run           Mostra cosa verrebbe rimosso senza effettuare modifiche
    --help, -h          Mostra questo messaggio di aiuto

ESEMPI:
    # Rimuovi tutto
    sudo $0

    # Rimuovi solo nginx
    sudo $0 --service nginx

    # Anteprima senza modificare
    sudo $0 --dry-run

    # Anteprima rimozione di un servizio specifico
    sudo $0 --service mysql --dry-run
EOF
}

################################################################################
# MAIN
################################################################################

main() {
    parse_arguments "$@"
    
    echo "========================================================================"
    echo "           SCRIPT DI DISINSTALLAZIONE AUTO-RESTART                     "
    echo "========================================================================"
    echo ""
    
    if $DRY_RUN; then
        print_warning "MODALITÀ DRY-RUN: Nessuna modifica verrà effettuata"
        echo ""
    fi
    
    check_root
    
    # Inizializza log
    touch "$LOG_FILE"
    log "=== INIZIO DISINSTALLAZIONE ==="
    log "Eseguito da: $(whoami)"
    log "Dry-run: ${DRY_RUN}"
    log "Target service: ${TARGET_SERVICE:-all}"
    
    declare -a SERVICES_CONFIGURED=()
    
    # Se è specificato un servizio target, usa solo quello
    if [ -n "$TARGET_SERVICE" ]; then
        # Verifica che il servizio abbia effettivamente una configurazione
        if [ -f "${SYSTEMD_OVERRIDE_DIR}/restart-${TARGET_SERVICE}.timer" ]; then
            SERVICES_CONFIGURED+=("$TARGET_SERVICE")
            print_info "Rimozione configurazione per: ${TARGET_SERVICE}"
        else
            print_error "Nessuna configurazione auto-restart trovata per: ${TARGET_SERVICE}"
            exit 1
        fi
    else
        # Rileva tutti i servizi configurati
        if ! detect_configured_services SERVICES_CONFIGURED; then
            print_warning "Nessuna configurazione da rimuovere. Uscita."
            exit 0
        fi
    fi
    
    echo ""
    print_warning "ATTENZIONE: Stai per rimuovere la configurazione di auto-restart per:"
    for service in "${SERVICES_CONFIGURED[@]}"; do
        echo "  - ${service}"
    done
    echo ""
    
    if ! $DRY_RUN; then
        read -p "Continuare? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operazione annullata dall'utente"
            exit 0
        fi
    fi
    
    echo ""
    print_info "Inizio rimozione..."
    echo ""
    
    # Rimuovi configurazione per ogni servizio
    for service in "${SERVICES_CONFIGURED[@]}"; do
        echo "--------------------------------------------------------------------"
        print_info "Elaborazione: ${service}"
        echo "--------------------------------------------------------------------"
        
        remove_timer "$service"
        remove_files "$service"
        
        echo ""
    done
    
    # Ricarica systemd
    reload_systemd
    
    echo ""
    echo "========================================================================"
    echo "                         RIEPILOGO                                      "
    echo "========================================================================"
    echo ""
    
    if $DRY_RUN; then
        print_warning "MODALITÀ DRY-RUN: Nessuna modifica è stata effettuata"
        echo ""
        echo "Per effettuare realmente le modifiche, esegui lo script senza --dry-run"
    else
        print_success "Disinstallazione completata!"
        echo ""
        echo "La configurazione di auto-restart è stata rimossa per:"
        for service in "${SERVICES_CONFIGURED[@]}"; do
            echo "  - ${service}"
        done
        echo ""
        echo "I servizi continueranno a funzionare normalmente, ma non verranno"
        echo "più riavviati automaticamente in caso di crash."
        echo ""
        print_info "Se vuoi riconfigurare l'auto-restart, esegui nuovamente:"
        echo "  sudo ./setup_autorestart_all.sh"
    fi
    
    echo ""
    log "=== FINE DISINSTALLAZIONE ==="
}

# Esegui lo script
main "$@"
