#!/usr/bin/env bash
# Restrict Docker-published web ports to Cloudflare at the pre-DNAT firewall.
set -euo pipefail

CHAIN="ML_CLOUDFLARE"

configure_family() {
  local command="$1" ranges_url="$2"

  "$command" -N "$CHAIN" 2>/dev/null || true
  "$command" -F "$CHAIN"
  "$command" -C DOCKER-USER -j "$CHAIN" 2>/dev/null || \
    "$command" -I DOCKER-USER 1 -j "$CHAIN"
  "$command" -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

  while read -r cidr; do
    [[ -n "$cidr" ]] || continue
    "$command" -A "$CHAIN" -p tcp -s "$cidr" -m conntrack \
      --ctorigdstport 80 -j RETURN
    "$command" -A "$CHAIN" -p tcp -s "$cidr" -m conntrack \
      --ctorigdstport 443 -j RETURN
  done < <(curl -fsSL "$ranges_url")

  "$command" -A "$CHAIN" -p tcp -m conntrack --ctorigdstport 80 -j DROP
  "$command" -A "$CHAIN" -p tcp -m conntrack --ctorigdstport 443 -j DROP
  "$command" -A "$CHAIN" -j RETURN
}

configure_family iptables https://www.cloudflare.com/ips-v4

if ip6tables -nL DOCKER-USER >/dev/null 2>&1; then
  configure_family ip6tables https://www.cloudflare.com/ips-v6
fi
