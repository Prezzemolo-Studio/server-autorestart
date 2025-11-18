#!/bin/bash

################################################################################
# SCRIPT DI VALIDAZIONE AUTO-RESTART
################################################################################
#
# Questo script verifica che la configurazione di auto-restart sia stata
# installata correttamente e funzioni come previsto.
#
# USO:
#   sudo ./validate_autorestart.sh
#
# OPZIONI:
#   --service <nome>    Valida solo un servizio specifico
#   --skip-crash-test   Salta il test di crash simulato
#
################################################################################

set -u

# --- COLORI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- CONFIGURAZIONE ---
SKIP_CRASH_TEST=false
TARGET_SERVICE=""
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

################################################################################
# FUNZIONI UTILITY
################################################################################

print_success() {
    echo -e "${GREEN}[✓]${NC} $*"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[✗]${NC} $*"
    ((TESTS_FAILED++))
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $*"
    ((TESTS_WARNING++))
}

print_info() {
    echo -e "${BLUE}[i]${NC} $*"
}

print_test() {
    echo -e "\n${BLUE}[TEST]${NC} $*"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Questo script deve essere eseguito con privilegi di root"
        echo "Esegui: sudo $0"
        exit 1
    fi
}

################################################################################
# RILEVAMENTO SERVIZI CONFIGURATI
################################################################################

detect_configured_services() {
    local -n services_ref=$1
    
    # Cerca tutti i timer di restart
    for timer in /etc/systemd/system/restart-*.timer; do
        if [ -f "$timer" ]; then
            local timer_basename=$(basename "$timer")
            local service_name="${timer_basename#restart-}"
            service_name="${service_name%.timer}"
            services_ref+=("$service_name")
        fi
    done
    
    if [ ${#services_ref[@]} -eq 0 ]; then
        print_fail "Nessun servizio con configurazione auto-restart trovato"
        print_info "Esegui prima: sudo ./setup_autorestart_all.sh"
        exit 1
    fi
}

################################################################################
# TEST FUNCTIONS
################################################################################

test_file_exists() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        print_success "$description esiste: $file"
        return 0
    else
        print_fail "$description NON trovato: $file"
        return 1
    fi
}

test_file_executable() {
    local file=$1
    
    if [ -x "$file" ]; then
        print_success "Script eseguibile: $file"
        return 0
    else
        print_fail "Script NON eseguibile: $file"
        return 1
    fi
}

test_systemd_override() {
    local service=$1
    local override_file="/etc/systemd/system/${service}.service.d/99-auto-restart.conf"
    
    print_test "Verifica override systemd per $service"
    
    test_file_exists "$override_file" "File di override"
    
    # Verifica contenuto
    if [ -f "$override_file" ]; then
        if grep -q "Restart=on-failure" "$override_file"; then
            print_success "Direttiva Restart configurata correttamente"
        else
            print_fail "Direttiva Restart NON trovata o errata"
        fi
        
        if grep -q "RestartSec=" "$override_file"; then
            print_success "Direttiva RestartSec configurata"
        else
            print_warning "Direttiva RestartSec non trovata"
        fi
    fi
    
    # Verifica che systemd abbia caricato l'override
    if systemctl cat "$service" 2>/dev/null | grep -q "99-auto-restart.conf"; then
        print_success "Override caricato da systemd"
    else
        print_fail "Override NON caricato da systemd (prova: systemctl daemon-reload)"
    fi
}

test_monitoring_script() {
    local service=$1
    local script_path="/usr/local/bin/restart-${service}.sh"
    
    print_test "Verifica script di monitoraggio per $service"
    
    test_file_exists "$script_path" "Script di monitoraggio"
    test_file_executable "$script_path"
    
    # Verifica contenuto base
    if [ -f "$script_path" ]; then
        if grep -q "systemctl is-active" "$script_path"; then
            print_success "Script contiene controllo di stato"
        else
            print_fail "Script non contiene controllo di stato"
        fi
        
        if grep -q "systemctl restart" "$script_path"; then
            print_success "Script contiene comando di riavvio"
        else
            print_fail "Script non contiene comando di riavvio"
        fi
    fi
}

test_systemd_service() {
    local service=$1
    local service_file="/etc/systemd/system/restart-${service}.service"
    
    print_test "Verifica servizio systemd per $service"
    
    test_file_exists "$service_file" "File servizio systemd"
    
    # Verifica che systemd lo riconosca
    if systemctl list-unit-files | grep -q "restart-${service}.service"; then
        print_success "Servizio riconosciuto da systemd"
    else
        print_fail "Servizio NON riconosciuto da systemd"
    fi
}

test_systemd_timer() {
    local service=$1
    local timer_file="/etc/systemd/system/restart-${service}.timer"
    local timer_name="restart-${service}.timer"
    
    print_test "Verifica timer systemd per $service"
    
    test_file_exists "$timer_file" "File timer systemd"
    
    # Verifica che sia abilitato
    if systemctl is-enabled "$timer_name" &>/dev/null; then
        print_success "Timer abilitato all'avvio"
    else
        print_warning "Timer NON abilitato all'avvio"
    fi
    
    # Verifica che sia attivo
    if systemctl is-active "$timer_name" &>/dev/null; then
        print_success "Timer attivo e in esecuzione"
    else
        print_fail "Timer NON attivo"
    fi
    
    # Mostra prossima esecuzione
    local next_run=$(systemctl list-timers --no-pager | grep "restart-${service}.timer" | awk '{print $1, $2, $3}')
    if [ -n "$next_run" ]; then
        print_info "Prossima esecuzione: $next_run"
    fi
}

test_main_service() {
    local service=$1
    
    print_test "Verifica servizio principale: $service"
    
    # Verifica che esista
    if systemctl list-unit-files | grep -q "^${service}.service"; then
        print_success "Servizio $service esiste"
    else
        print_fail "Servizio $service NON trovato"
        return 1
    fi
    
    # Verifica che sia abilitato
    if systemctl is-enabled "$service" &>/dev/null; then
        print_success "Servizio abilitato all'avvio"
    else
        print_warning "Servizio NON abilitato all'avvio"
    fi
    
    # Verifica che sia attivo
    if systemctl is-active "$service" &>/dev/null; then
        print_success "Servizio attivo e in esecuzione"
    else
        print_fail "Servizio NON attivo"
    fi
}

test_log_file() {
    local service=$1
    local log_file="/var/log/restart-${service}.log"
    
    print_test "Verifica file di log per $service"
    
    # Il file di log viene creato al primo riavvio, quindi è OK se non esiste ancora
    if [ -f "$log_file" ]; then
        print_success "File di log esiste: $log_file"
        
        # Verifica permessi
        local perms=$(stat -c "%a" "$log_file")
        if [ "$perms" = "644" ] || [ "$perms" = "640" ] || [ "$perms" = "600" ]; then
            print_success "Permessi file di log corretti: $perms"
        else
            print_warning "Permessi file di log inusuali: $perms"
        fi
    else
        print_info "File di log non ancora creato (normale se nessun riavvio)"
    fi
}

test_crash_simulation() {
    local service=$1
    
    print_test "Test di crash simulato per $service"
    
    if $SKIP_CRASH_TEST; then
        print_info "Test di crash saltato (--skip-crash-test)"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  ATTENZIONE ⚠️${NC}"
    echo "Questo test fermerà forzatamente il servizio $service per verificare"
    echo "che il riavvio automatico funzioni. Ci saranno alcuni secondi di downtime."
    echo ""
    read -p "Continuare con il test di crash? [y/N] " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Test di crash saltato dall'utente"
        return 0
    fi
    
    print_info "Fermo forzato del servizio $service..."
    systemctl kill --signal=SIGKILL "$service"
    
    print_info "Attendo 15 secondi per il riavvio automatico..."
    sleep 15
    
    if systemctl is-active "$service" &>/dev/null; then
        print_success "Servizio $service riavviato automaticamente!"
        
        # Verifica che sia stato loggato
        if journalctl -u "$service" --since "1 minute ago" | grep -q "Scheduled restart"; then
            print_success "Riavvio documentato nei log di systemd"
        else
            print_warning "Riavvio non trovato nei log (potrebbe essere troppo veloce)"
        fi
    else
        print_fail "Servizio $service NON è riavviato automaticamente"
        print_info "Tentativo di riavvio manuale..."
        systemctl start "$service"
    fi
}

################################################################################
# ARGOMENTI
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --service)
                TARGET_SERVICE="$2"
                shift 2
                ;;
            --skip-crash-test)
                SKIP_CRASH_TEST=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Argomento sconosciuto: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Script di Validazione Auto-Restart

USO:
    sudo $0 [OPZIONI]

OPZIONI:
    --service <nome>      Valida solo il servizio specificato
    --skip-crash-test     Salta il test di crash simulato (consigliato in produzione)
    --help, -h            Mostra questo messaggio

ESEMPI:
    # Validazione completa
    sudo $0

    # Valida solo nginx
    sudo $0 --service nginx

    # Validazione senza crash test (per produzione)
    sudo $0 --skip-crash-test

    # Valida nginx senza crash test
    sudo $0 --service nginx --skip-crash-test
EOF
}

################################################################################
# MAIN
################################################################################

main() {
    parse_arguments "$@"
    
    echo "========================================================================"
    echo "              SCRIPT DI VALIDAZIONE AUTO-RESTART                        "
    echo "========================================================================"
    echo ""
    
    check_root
    
    declare -a SERVICES=()
    
    if [ -n "$TARGET_SERVICE" ]; then
        # Valida solo il servizio specificato
        if [ -f "/etc/systemd/system/restart-${TARGET_SERVICE}.timer" ]; then
            SERVICES+=("$TARGET_SERVICE")
            print_info "Validazione per: $TARGET_SERVICE"
        else
            print_fail "Nessuna configurazione auto-restart trovata per: $TARGET_SERVICE"
            exit 1
        fi
    else
        # Rileva tutti i servizi configurati
        print_info "Rilevamento servizi configurati..."
        detect_configured_services SERVICES
        print_info "Servizi trovati: ${SERVICES[*]}"
    fi
    
    echo ""
    print_info "Inizio validazione..."
    echo ""
    
    # Test per ogni servizio
    for service in "${SERVICES[@]}"; do
        echo ""
        echo "===================================================================="
        echo "  SERVIZIO: $service"
        echo "===================================================================="
        
        # Test del servizio principale
        test_main_service "$service"
        
        # Test override systemd (Metodo 1)
        test_systemd_override "$service"
        
        # Test script di monitoraggio (Metodo 2)
        test_monitoring_script "$service"
        test_systemd_service "$service"
        test_systemd_timer "$service"
        
        # Test log
        test_log_file "$service"
        
        # Test di crash (opzionale)
        if ! $SKIP_CRASH_TEST; then
            test_crash_simulation "$service"
        fi
    done
    
    # Riepilogo finale
    echo ""
    echo "========================================================================"
    echo "                           RIEPILOGO                                    "
    echo "========================================================================"
    echo ""
    echo -e "Test superati:      ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Test falliti:       ${RED}$TESTS_FAILED${NC}"
    echo -e "Warning:            ${YELLOW}$TESTS_WARNING${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ VALIDAZIONE COMPLETATA CON SUCCESSO${NC}"
        echo ""
        echo "La configurazione di auto-restart è installata correttamente"
        echo "e funziona come previsto."
        
        if [ $TESTS_WARNING -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}Nota: Ci sono alcuni warning non critici da rivedere.${NC}"
        fi
        
        exit 0
    else
        echo -e "${RED}✗ VALIDAZIONE FALLITA${NC}"
        echo ""
        echo "Alcuni test sono falliti. Verifica i messaggi di errore sopra"
        echo "e correggi i problemi prima di mettere in produzione."
        echo ""
        echo "Suggerimenti:"
        echo "  1. Esegui: sudo systemctl daemon-reload"
        echo "  2. Riavvia i timer: sudo systemctl restart restart-*.timer"
        echo "  3. Controlla i log: sudo journalctl -xe"
        echo "  4. Ri-esegui lo script di setup: sudo ./setup_autorestart_all.sh"
        
        exit 1
    fi
}

# Esegui lo script
main "$@"
