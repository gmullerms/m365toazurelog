```markdown
# Microsoft 365 Audit Log to Sentinel Ingestion

This project provides scripts and guidance to export historical Microsoft 365 Unified Audit Logs (Exchange, SharePoint, Teams, OneDrive, etc.) and ingest them into Microsoft Sentinel using the Azure Monitor Logs Ingestion API.

## Features

- Export historical audit logs from Microsoft 365 using PowerShell
- Transform logs to a custom schema
- Ingest logs into a custom table in Azure Log Analytics/Sentinel
- Supports service principal authentication for automation
- Includes robust error handling and status reporting

---

## Prerequisites

- **Azure Subscription** with Microsoft Sentinel and Log Analytics Workspace
- **Azure AD App Registration** (Service Principal) with Monitoring Metrics Publisher role
- **PowerShell 7+**
- **Modules:** [MSAL.PS](https://www.powershellgallery.com/packages/MSAL.PS), [ExchangeOnlineManagement](https://www.powershellgallery.com/packages/ExchangeOnlineManagement)

---

## Setup Guide

### 1. Create Log Analytics Workspace

1. In Azure Portal, go to **Log Analytics workspaces**.
2. Create a new workspace or use an existing one.

### 2. Create Custom Table

1. In your workspace, go to **Tables** > **Create** > **New custom log (DCR-based)**.
2. Upload a sample JSON file like:
    ```
    [
      {
        "TimeGenerated": "2025-06-03T12:00:00Z",
        "UserPrincipalName": "user@contoso.com",
        "OperationType": "FileAccessed",
        "ObjectID": "file123",
        "ClientIP": "192.168.1.1"
      }
    ]
    ```
3. Confirm the schema and complete the table creation (e.g., `M365HistoricalLogs_CL`).

### 3. Set Up Data Collection Rule (DCR)

1. Go to **Monitor > Data Collection Rules**.
2. Create a new DCR linked to your workspace and custom table.
3. In the transformation editor, use:
    ```
    source
    | extend TimeGenerated = todatetime(TimeGenerated)
    | extend UserPrincipalName = tostring(UserPrincipalName)
    | extend OperationType = tostring(OperationType)
    | extend ObjectID = tostring(ObjectID)
    | extend ClientIP = tostring(ClientIP)
    | project TimeGenerated, UserPrincipalName, OperationType, ObjectID, ClientIP
    ```

### 4. Register Azure AD App (Service Principal)

1. Register a new app in **Azure Active Directory > App registrations**.
2. Create a client secret.
3. Assign the **Monitoring Metrics Publisher** role to your app at the workspace level.

### 5. Configure and Run the Script

1. Clone this repo and open the PowerShell script.
2. Fill in your tenant ID, client ID, client secret, DCR endpoint, and table info.
3. Run the script in PowerShell 7+.

---

## Usage

```


# Example: Run the ingestion script

pwsh ./M365AuditLogIngest.ps1

```

---

## Validation

To verify successful ingestion, run this query in your Log Analytics workspace or Sentinel:

```

M365HistoricalLogs_CL
| take 10

```

---

## Retention and Cleanup

- Set retention policies on your custom table as needed.
- For targeted deletions, use the [Azure Monitor Delete Data API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/delete-data).

---

## Troubleshooting

- Ensure your DCR transformation matches your payload fields.
- The service principal must have the **Monitoring Metrics Publisher** role.
- Use the script's status messages and error output for diagnostics.

---

## License

MIT License

---

## Contributors

- [Your Name] (your.email@example.com)

---

## References

- [Microsoft Docs: Logs Ingestion API](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-ingestion-api-overview)
- [Microsoft Docs: Unified Audit Log](https://learn.microsoft.com/en-us/microsoft-365/compliance/search-the-audit-log-in-security-and-compliance)
- [MSAL.PS Module](https://www.powershellgallery.com/packages/MSAL.PS)
```
