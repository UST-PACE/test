# **Creating a Rancher Secret with a YAML File as Data**

This guide covers how to:
- Encode a YAML file in Base64
- Create a Rancher secret with the encoded content
- Mount the secret as a file in your deployment
- Verify and deploy the configuration

---

## **Step 1: Encode the YAML File in Base64**
Rancher secrets require the content to be **Base64-encoded**.

Run the following command:

```bash
cat db.yaml | tr -d '\n' | base64 -w 0
```

✅ **Example Output (Encoded YAML Content):**
```
bmFtZTogZGF0YWJhc2UKbmFtZXNwYWNlOiB2Yy1nZW5pCnNlY3VyaXR5Q29udGV4dDoKICBydW5Bc1VzZXI6IDAKcmVwbGljYXM6IDEKZW5hYmxlZDogdHJ1ZQp...
```

---

## **Step 2: Create the Secret via API**
Use the encoded content in your API request:

```bash
curl -k \
-H "Authorization: Bearer <TOKEN>" \
-H "Content-Type: application/json" \
-X POST \
-d '{
  "type": "secret",
  "name": "db-config-secret",
  "namespaceId": "vc-geni",
  "data": {
    "db.yaml": "bmFtZTogZGF0YWJhc2UKbmFtZXNwYWNlOiB2Yy1nZW5pCnNlY3VyaXR5Q29udGV4dDoKICBydW5Bc1VzZXI6IDAKcmVwbGljYXM6IDEKZW5hYmxlZDogdHJ1ZQp..."
  }
}' \
"https://rancher.test.ustpace.com/v3/projects/<PROJECT_ID>/secrets"
```

---

## **Step 3: Mount the Secret in Your Deployment**
In your `db.yaml` manifest, mount the secret as a file:

```yaml
volumes:
  - name: db-config
    secret:
      secretName: db-config-secret

volumeMounts:
  - name: db-config
    mountPath: /etc/config
    readOnly: true
```

✅ The `db.yaml` file will now be available at `/etc/config/db.yaml` in your container.

---

## **Step 4: Verify the Secret**
To ensure the secret was created correctly:

```bash
kubectl get secret db-config-secret -n vc-geni -o yaml
```

---

## **Step 5: Deploy the Updated YAML**
Apply the updated manifest:

```bash
kubectl apply -f db.yaml
```

---

## **Key Notes**
✅ Use `base64 -w 0` for one-line encoding (important for JSON payloads).  
✅ Verify the mounted path in your container matches the desired file location.  
✅ To decode the secret later, run:  

```bash
echo "bmFtZTogZGF0YWJhc2UKbmFtZXNwYWNlOiB2Yy1nZW5p..." | base64 -d
```

If you have any questions or need further assistance, feel free to ask! 🚀

