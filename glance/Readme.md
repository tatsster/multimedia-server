## How to get PVE & PBS Api Key
You need to generate an API token for it, follow the steps below if you don't have one

1. Navigate to the Proxmox portal, click on Datacenter
2. Expand Permissions, click on Groups
3. Click the Create button
4. Name the group something informative, like `api-ro-users` ("ro" for read-only)
5. Click on the Permissions "folder"
6. Click Add -> Group Permission
    - Path: /
    - Group: group from bullet 4 above
    - Role: PVEAuditor
    - Propagate: Checked
7. Expand Permissions, click on Users
8. Click the Add button
    - User name: something informative like `api`
    - Realm: Linux PAM standard authentication
    - Group: group from bullet 4 above
9. Expand Permissions, click on API Tokens
10. Click the Add button
    - User: user from bullet 8 above
    - Token ID: something informative like the application or purpose like for general use `shared` or for specific `glance`
    - Privilege Separation: Checked
11. Go back to the "Permissions" menu
12. Click Add -> API Token Permission
    - Path: /
    - API Token: select the Token ID created in Step 10
    - Role: PVE Auditor
    - Propagate: Checked

Your key should look like `<username>@pam!<tokenID>=<secret>`

example:
```
api@pam!shared=some-random-secret-value-here
```

source: [gethomepage's documentation](https://github.com/gethomepage/homepage/blob/main/docs/widgets/services/proxmox.md)
