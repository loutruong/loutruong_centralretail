# ===== General curl skeleton =====
curl \
  `# 1. Options (How curl behaves: silent, fail on error, follow redirects)` \
  -sS --fail-with-body -L \
  `# 2. Request method (GET, POST, PUT, PATCH, DELETE), Endpoint url` \
  -X {METHOD} https://base_url/version/resource/id?param_1=value_1 \
  `# 3. Headers authorization (Who you are)` \
  -H "Authorization: Bearer {BEARER_TOKEN}" \
  `# 4. Headers content type (Data type sending)` \
  -H "Content-Type: application/json" \
  `# 5. Headers accept (Data type wanted back)` \
  -H "Accept: application/json" \
  `# 6. Body content / Payload (Only for POST, PUT, PATCH)` \
  -d '{
    "key_1": "key_value_1",
    "key_2": "key_value_2"
  }'