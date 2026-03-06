#!/usr/bin/env bash
# =============================================================
# Kinsma Corporation — Azure Static Website Deploy Script
# Prereqs: Azure CLI installed + logged in (az login)
# Run: chmod +x deploy.sh && ./deploy.sh
# =============================================================

set -euo pipefail

# ---- CONFIG (edit if needed) ----
RESOURCE_GROUP="kinsma-web-rg"
LOCATION="westus2"
STORAGE_ACCOUNT="kinsmawebsite"      # must be globally unique, lowercase, 3-24 chars
CDN_PROFILE="kinsma-cdn"
CDN_ENDPOINT="kinsma"               # becomes kinsma.azureedge.net
CUSTOM_DOMAIN_WWW="www.kinsma.com"
SITE_DIR="$(dirname "$0")"          # same folder as this script

# ---- COLORS ----
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${CYAN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
note() { echo -e "${YELLOW}→ $1${NC}"; }

echo ""
echo "================================================="
echo "  Kinsma Corporation — Azure Static Site Deploy"
echo "================================================="

# ---- 1. Resource Group ----
step "Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
ok "Resource group ready"

# ---- 2. Storage Account ----
step "Creating storage account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access true \
  --output none
ok "Storage account created"

# ---- 3. Enable Static Website ----
step "Enabling static website hosting"
az storage blob service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --static-website \
  --index-document index.html \
  --404-document index.html \
  --output none
ok "Static website enabled"

# ---- 4. Upload site files ----
step "Uploading site files"
az storage blob upload-batch \
  --account-name "$STORAGE_ACCOUNT" \
  --source "$SITE_DIR" \
  --destination '$web' \
  --pattern "*.html" \
  --content-type "text/html" \
  --overwrite true \
  --output none

az storage blob upload-batch \
  --account-name "$STORAGE_ACCOUNT" \
  --source "$SITE_DIR" \
  --destination '$web' \
  --pattern "*.css" \
  --content-type "text/css" \
  --overwrite true \
  --output none

az storage blob upload-batch \
  --account-name "$STORAGE_ACCOUNT" \
  --source "$SITE_DIR" \
  --destination '$web' \
  --pattern "*.js" \
  --content-type "application/javascript" \
  --overwrite true \
  --output none
ok "Site files uploaded"

# ---- 5. Get static website endpoint ----
STATIC_ENDPOINT=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query "primaryEndpoints.web" \
  --output tsv | sed 's|https://||' | sed 's|/||')

ok "Static endpoint: $STATIC_ENDPOINT"

# ---- 6. CDN Profile ----
step "Creating CDN profile (Standard Microsoft)"
az cdn profile create \
  --name "$CDN_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Standard_Microsoft \
  --output none
ok "CDN profile created"

# ---- 7. CDN Endpoint ----
step "Creating CDN endpoint: ${CDN_ENDPOINT}.azureedge.net"
az cdn endpoint create \
  --name "$CDN_ENDPOINT" \
  --profile-name "$CDN_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --origin "$STATIC_ENDPOINT" \
  --origin-host-header "$STATIC_ENDPOINT" \
  --enable-compression true \
  --output none
ok "CDN endpoint created"

CDN_HOSTNAME="${CDN_ENDPOINT}.azureedge.net"

# ---- 8. Add custom domain (www) ----
step "Adding custom domain: $CUSTOM_DOMAIN_WWW"
note "You must add this DNS record FIRST for this step to succeed:"
note "  CNAME  www  →  ${CDN_HOSTNAME}"
note ""
read -rp "  Press ENTER once the DNS record is live (may take a few minutes)..."

az cdn custom-domain create \
  --name "www-kinsma-com" \
  --profile-name "$CDN_PROFILE" \
  --endpoint-name "$CDN_ENDPOINT" \
  --resource-group "$RESOURCE_GROUP" \
  --hostname "$CUSTOM_DOMAIN_WWW" \
  --output none
ok "Custom domain added"

# ---- 9. Enable HTTPS on custom domain ----
step "Enabling HTTPS (free managed certificate — takes ~10 min)"
az cdn custom-domain enable-https \
  --name "www-kinsma-com" \
  --profile-name "$CDN_PROFILE" \
  --endpoint-name "$CDN_ENDPOINT" \
  --resource-group "$RESOURCE_GROUP" \
  --output none
ok "HTTPS certificate requested (will auto-provision)"

# ---- DONE ----
echo ""
echo "================================================="
echo -e "${GREEN}  ALL DONE!${NC}"
echo "================================================="
echo ""
echo "  CDN endpoint:    https://${CDN_HOSTNAME}"
echo "  Your site (www): https://${CUSTOM_DOMAIN_WWW}  ← live once cert provisions"
echo ""
echo "  DNS records to add:"
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │  Type   Host   Value                                    │"
echo "  │  CNAME  www    ${CDN_HOSTNAME}        │"
echo "  │                                                         │"
echo "  │  For apex (kinsma.com → www.kinsma.com):               │"
echo "  │  If registrar supports ALIAS/ANAME:                     │"
echo "  │    ALIAS  @    ${CDN_HOSTNAME}        │"
echo "  │  Otherwise add a URL redirect: kinsma.com → www         │"
echo "  └─────────────────────────────────────────────────────────┘"
echo ""
echo "  HTTPS cert auto-provisions within ~10 minutes."
echo "  To redeploy site files later, just re-run this script."
echo ""
