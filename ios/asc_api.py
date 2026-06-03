#!/usr/bin/env python3
import jwt
import time
import requests
import json
import sys

KEY_ID = "GMY27TPQ5P"
ISSUER_ID = "3a2b136b-dfbb-4dbc-a096-14016905ea50"
KEY_PATH = "/Users/meixulin/Desktop/AuthKey_GMY27TPQ5P.p8"

def get_token():
    with open(KEY_PATH, 'r') as f:
        private_key = f.read()
    payload = {
        'iss': ISSUER_ID,
        'iat': int(time.time()),
        'exp': int(time.time()) + 1200,
        'aud': 'appstoreconnect-v1'
    }
    token = jwt.encode(payload, private_key, algorithm='ES256', headers={'kid': KEY_ID, 'typ': 'JWT'})
    return token

def api_call(method, path, data=None):
    token = get_token()
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    url = f'https://api.appstoreconnect.apple.com/v1{path}'
    if method == 'GET':
        r = requests.get(url, headers=headers)
    elif method == 'POST':
        r = requests.post(url, headers=headers, json=data)
    return r.json()

action = sys.argv[1] if len(sys.argv) > 1 else "list_profiles"

if action == "list_bundle_ids":
    result = api_call('GET', '/bundleIds?filter[id]=com.zaine.app')
    print(json.dumps(result, indent=2))

elif action == "list_certificates":
    result = api_call('GET', '/certificates?filter[certificateType]=IOS_DISTRIBUTION')
    print(json.dumps(result, indent=2))

elif action == "list_profiles":
    result = api_call('GET', '/profiles')
    print(json.dumps(result, indent=2))

elif action == "create_profile":
    # Need bundleId and certificate IDs
    result = api_call('GET', '/bundleIds?filter[id]=com.zaine.app')
    if 'data' in result and len(result['data']) > 0:
        bundle_id_id = result['data'][0]['id']
    else:
        print("ERROR: bundle ID not found")
        print(json.dumps(result, indent=2))
        sys.exit(1)
    
    result2 = api_call('GET', '/certificates?filter[certificateType]=IOS_DISTRIBUTION')
    if 'data' in result2 and len(result2['data']) > 0:
        cert_id = result2['data'][0]['id']
    else:
        print("ERROR: No distribution certificate found")
        print(json.dumps(result2, indent=2))
        sys.exit(1)
    
    profile_data = {
        "data": {
            "type": "profiles",
            "attributes": {
                "name": "Zaine App Store Distribution",
                "profileType": "IOS_APP_STORE"
            },
            "relationships": {
                "bundleId": {
                    "data": {
                        "type": "bundleIds",
                        "id": bundle_id_id
                    }
                },
                "certificates": {
                    "data": [{
                        "type": "certificates",
                        "id": cert_id
                    }]
                }
            }
        }
    }
    
    result3 = api_call('POST', '/profiles', profile_data)
    print(json.dumps(result3, indent=2))
