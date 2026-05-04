#!/usr/bin/env bash
# Import/update an API in Azure API Management and ensure it is attached to the Unlimited product.
set -euo pipefail

# Configuration (environment variables)
RESOURCE_GROUP="${RESOURCEGROUP_NAME:?RESOURCEGROUP_NAME is not set}"
APIM_SERVICE_NAME="${APIM_NAME:?APIM_NAME is not set}"
API_ID="${DEPLOYMENT_NAME:?DEPLOYMENT_NAME is not set}"
API_PATH="${DEPLOYMENT_NAME:?DEPLOYMENT_NAME is not set}"
DISPLAY_NAME="${API_DISPLAYNAME:?API_DISPLAYNAME is not set}"
AKS_BACKEND_URL="${AKS_BACKEND_URL:?AKS_BACKEND_URL is not set}"
AGENT_RELEASEDIRECTORY="${AGENT_RELEASEDIRECTORY:?AGENT_RELEASEDIRECTORY is not set}"
SWAGGER_MANIFEST_PATH="${SWAGGER_MANIFEST_PATH:?SWAGGER_MANIFEST_PATH is not set}"

BACKEND_URL="${AKS_BACKEND_URL}/${DEPLOYMENT_NAME}"
SWAGGER_PATH="${AGENT_RELEASEDIRECTORY}/${SWAGGER_MANIFEST_PATH}"

PRODUCT_ID="Unlimited"

echo "APIM API '${API_ID}' importing..."

az apim api import \
  --resource-group "${RESOURCE_GROUP}" \
  --service-name "${APIM_SERVICE_NAME}" \
  --api-id "${API_ID}" \
  --path "${API_PATH}" \
  --display-name "${DISPLAY_NAME}" \
  --specification-format OpenApiJson \
  --specification-path "${SWAGGER_PATH}" \
  --subscription-required false \
  --service-url "${BACKEND_URL}" \
  --api-type http

if ! product_exist="$(az apim product api list \
  --resource-group "${RESOURCE_GROUP}" \
  --service-name "${APIM_SERVICE_NAME}" \
  --product-id "${PRODUCT_ID}" \
  --query "[?name=='${API_ID}'] | length(@)" \
  -o tsv 2>/dev/null)"; then
  echo "Failed to query APIM product API list. Check APIM service health." >&2
  exit 1
fi

if [[ -z "${product_exist}" ]]; then
  echo "Failed to query APIM product API list. Check APIM service health." >&2
  exit 1
fi

if ! [[ "${product_exist}" =~ ^[0-9]+$ ]]; then
  echo "Unexpected response from APIM product API list: '${product_exist}'" >&2
  exit 1
fi

if [[ "${product_exist}" -eq 0 ]]; then
  echo "API not attached. Attaching API to Product..."
  if ! az apim product api add \
    --resource-group "${RESOURCE_GROUP}" \
    --service-name "${APIM_SERVICE_NAME}" \
    --product-id "${PRODUCT_ID}" \
    --api-id "${API_ID}"; then
    echo "Failed to attach API '${API_ID}' to product." >&2
    exit 1
  fi
  echo "Successfully attached '${API_ID}' to Unlimited product."
else
  echo "API '${API_ID}' is already attached to the Unlimited product."
fi

echo "API imported or updated successfully."
exit 0


###########################
#!/usr/bin/env bash
# Ensures an Azure API Management product exists and is published.
set -euo pipefail

# Configuration (same env vars as the PowerShell script)
RESOURCE_GROUP="${RG_EASTUS_DEV:?RG_EASTUS_DEV is not set}"
APIM_NAME="${APIM_EASTUS_DEV:?APIM_EASTUS_DEV is not set}"
PRODUCT_NAME="${APIM_PRODUCT:?APIM_PRODUCT is not set}"

echo "Ensuring APIM product '${PRODUCT_NAME}' exists..."

if az apim product show \
  --resource-group "${RESOURCE_GROUP}" \
  --service-name "${APIM_NAME}" \
  --product-id "${PRODUCT_NAME}" \
  >/dev/null 2>&1; then
  echo "Product exists → updating"
  az apim product update \
    --resource-group "${RESOURCE_GROUP}" \
    --service-name "${APIM_NAME}" \
    --product-id "${PRODUCT_NAME}" \
    --state published
else
  echo "Product does not exist → creating"
  az apim product create \
    --resource-group "${RESOURCE_GROUP}" \
    --service-name "${APIM_NAME}" \
    --product-id "${PRODUCT_NAME}" \
    --product-name "${PRODUCT_NAME}" \
    --state published
fi

echo "APIM product '${PRODUCT_NAME}' ensured successfully."
