# **Rancher API Guide: Creating Secrets via API**

This guide outlines the steps to:

- Find the **Cluster ID**
- Find the **Project ID**
- Find the **Namespace ID**
- Create a **Secret**
- Verify the **Secret**

---

## **Step 1: Find the Cluster ID**
To list all available clusters:

```bash
curl -k \ 
-H "Authorization: Bearer <TOKEN>" \ 
"https://rancher.test.ustpace.com/v3/clusters" | jq '.data[] | {id: .id, name: .name}'
```

✅ **Example Output:**
```json
{
  "id": "c-m-mq886dkz",
  "name": "MyCluster"
}
```

---

## **Step 2: Find the Project ID for the Cluster**
Use the **Cluster ID** to list projects within that cluster:

```bash
curl -k \ 
-H "Authorization: Bearer <TOKEN>" \ 
"https://rancher.test.ustpace.com/v3/projects?clusterId=c-m-mq886dkz" | jq '.data[] | {id: .id, name: .name}'
```

✅ **Example Output:**
```json
{
  "id": "c-m-mq886dkz:p-2kgps",
  "name": "Production"
}
```

---

## **Step 3: Find the Namespace ID (Inside a Project)**
To list namespaces within the **Project ID**:

```bash
curl -k \ 
-H "Authorization: Bearer <TOKEN>" \ 
"https://rancher.test.ustpace.com/v3/projects/c-m-mq886dkz:p-2kgps/namespaces"
```

✅ **Example Output:**
```json
{
  "id": "xyz",
  "name": "xyz"
}
```

---

## **Step 4: Encode Secret Values in Base64**
Rancher requires secret values to be **Base64-encoded**. To encode your values:

```bash
echo -n "my-username" | base64
echo -n "my-password" | base64
```

✅ Example Output for `echo -n "my-username" | base64`:
```
bXktdXNlcm5hbWU=
```

---

## **Step 5: Create the Secret**
Use the collected **Project ID** and **Namespace ID** in the following command:

```bash
curl -k \ 
-H "Authorization: Bearer <TOKEN>" \ 
-H "Content-Type: application/json" \ 
-X POST \ 
-d '{
  "type": "secret",
  "name": "my-secret-abc-xyz",
  "namespaceId": "xyz",
  "data": {
    "username": "bXktdXNlcm5hbWU=",
    "password": "bXktcGFzc3dvcmQ="
  }
}' \ 
"https://rancher.test.ustpace.com/v3/projects/c-m-mq886dkz:p-2kgps/secrets"
```

---

## **Step 6: Verify the Secret**
To confirm the secret was created successfully:

```bash
curl -k \ 
-H "Authorization: Bearer <TOKEN>" \ 
"https://rancher.test.ustpace.com/v3/projects/c-m-mq886dkz:p-2kgps/secrets"
```

✅ The newly created secret should now be listed.

---

## **Key Notes**
✅ Use `jq` for clear and structured JSON formatting.  
✅ Verify the correct **Cluster ID**, **Project ID**, and **Namespace ID** before creating the secret.  
✅ Secrets must have **Base64-encoded** values. Use `echo -n "<value>" | base64` to encode them.  

