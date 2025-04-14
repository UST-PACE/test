# Integrating Keycloak with OpenVPN Access Server via SAML

## Key Points

- Ensure both the OpenVPN Access Server and Keycloak Server are SSL-terminated.

## Steps

0. **Log in to the OpenVPN Access Server Admin Portal**  
   Access the admin portal using your browser:  
   `https://<openvpn-server-public-ip>:943/admin`  
   Use the admin credentials to sign in.

1. Ensure the OpenVPN Access Server host name is a **public IP address**.
2. Navigate to the **Authentication** tab and select the **SAML** option.
3. Update the **Host name** in the SAML settings.  
   _Example:_ `vpn.cicd.rest`
4. Save the settings and update the running server.
5. Make a note of the **SP Identity** and **SP ACS** values. These will be used in the Keycloak server.
6. Log in to the **Keycloak server** and select the appropriate **Realm**.
7. Click on the **Clients** option on the left sidebar and under **General Settings**, configure the following:

   - **Client type:** SAML  
   - **Client ID:** (Use the SP Identity from the OpenVPN server)  
   - **Name:** A name for the client (e.g., `kc-openvpn`)

8. Click **Next** and **Save**.
9. Go to the **Settings** tab of the client and enter the following:

   - **Root URL:** `https://vpn.cicd.rest`  
   - **Valid Redirect URIs:** `https://vpn.cicd.rest/*`  
   - **Master SAML Processing URL:** (Use the SP ACS value from OpenVPN)

10. Under **SAML Capabilities**, configure the following:

    - **Name ID Format:** `email`  
    - **Force POST Binding:** _Disabled_  
    - **Sign Assertions:** _Enabled_  
    - Click **Save**

11. Click on the **Keys** tab and turn off **Client Signature Required**.
12. Go to **Client Scopes** and remove `role_list` from the assigned client scopes.
13. Under **Client Scopes**, select your client URL from the list.  
    Configure a new **Mapper** with the following:

    - **Mapper Type:** User Property  
    - **Name:** Email  
    - **Property:** email  
    - **SAML Attribute Name:** Email  
    - **SAML Attribute Name Format:** Basic  
    - Click **Save**

14. Add another **Mapper**:

    - **Mapper Type:** User Property  
    - **Name:** firstName  
    - **Property:** firstName  
    - **SAML Attribute Name:** firstName  
    - **SAML Attribute Name Format:** Basic  
    - Click **Save**

15. Add another **Mapper**:

    - **Mapper Type:** User Property  
    - **Name:** lastName  
    - **Property:** lastName  
    - **SAML Attribute Name:** lastName  
    - **SAML Attribute Name Format:** Basic  
    - Click **Save**

16. Create a new user under the **Users** section of the realm with the following details:

    - **Username:** vpnuser  
    - **Email:** vpnuser@example.com  
    - **First Name:** VPN  
    - **Last Name:** User

    Save these details, then navigate to the **Credentials** tab, reset the password, and disable the **Temporary Password** option.

17. Go to **Realm Settings** and locate the **SAML 2.0 Identity Provider Metadata** endpoint which contains the XML descriptor and metadata URL.
18. Copy the **IDP Metadata URL**.
19. Go to the OpenVPN Access Server:

    - Click on **Authentication** → **SAML**
    - Scroll down to **Configure Identity Provider Automatically via Metadata**
