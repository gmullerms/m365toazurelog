# ========================
# Module Installation
# ========================
try {
    Write-Host "Installing MSAL.PS module..."
    Install-Module MSAL.PS -Scope CurrentUser -Force -ErrorAction Stop
    Import-Module MSAL.PS -ErrorAction Stop
    Write-Host "✅ MSAL.PS module installed successfully" -ForegroundColor Green
}
catch {
    Write-Error "❌ Failed to install MSAL.PS: $_"
    exit 1
}

# ========================
# Authentication
# ========================
try {
    Write-Host "`nConfiguring service principal credentials..."
	$tenantId     = "TENANT_ID"
	$clientId     = "CLIENT_ID"
	$clientSecret = "CLIENT_SECRET"
    
    $secureClientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
    Write-Host "✅ Credentials configured" -ForegroundColor Green
}
catch {
    Write-Error "❌ Credential configuration failed: $_"
    exit 1
}

try {
    Write-Host "`nAcquiring Azure Monitor access token..."
    $scope = "https://monitor.azure.com/.default"
    $tokenResponse = Get-MsalToken -TenantId $tenantId -ClientId $clientId -ClientSecret $secureClientSecret -Scope $scope
    $token = $tokenResponse.AccessToken
    Write-Host "✅ Access token acquired" -ForegroundColor Green
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
}
catch {
    Write-Error "❌ Token acquisition failed: $_"
    exit 1
}

# ========================
# Exchange Online Connection
# ========================
try {
    Write-Host "`nConnecting to Exchange Online..."
    Connect-ExchangeOnline -ErrorAction Stop
    Write-Host "✅ Successfully connected to Exchange Online" -ForegroundColor Green
}
catch {
    Write-Error "❌ Exchange Online connection failed: $_"
    exit 1
}

# ========================
# Date Validation
# ========================
try {
    Write-Host "`nValidating date range..."
    $startDate = (Get-Date).AddDays(-30).Date
    $endDate = Get-Date
    
    if ($startDate -gt $endDate) {
        Write-Warning "🔀 Start date ($startDate) is after end date ($endDate). Swapping values."
        $startDate, $endDate = $endDate, $startDate
    }
    Write-Host "✅ Valid date range: $startDate to $endDate" -ForegroundColor Green
}
catch {
    Write-Error "❌ Date validation failed: $_"
    exit 1
}

# ========================
# Log Retrieval & Ingestion
# ========================
$sessionID = New-Guid
$uri = " {Endpoint}/dataCollectionRules/{DCR Immutable ID}/streams/{Stream Name}?api-version=2023-01-01"

try {
    Write-Host "`nStarting audit log retrieval..."
    do {
        try {
            # Retrieve logs
            $auditLogs = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate `
                -SessionId $sessionID -SessionCommand ReturnLargeSet -ResultSize 5000
            
            Write-Host "📥 Retrieved $($auditLogs.Count) audit records"

            # Transform data
            $transformedData = @()
            foreach ($entry in $auditLogs) {
                try {
                    $log = $entry.AuditData | ConvertFrom-Json
                    $transformedData += [PSCustomObject]@{
                        TimeGenerated      = $log.CreationTime
                        UserPrincipalName  = $log.UserId
                        OperationType      = $log.Operation
                        ObjectID           = $log.ObjectId
                        ClientIP           = $log.ClientIPAddress
                    }
                }
                catch {
                    Write-Warning "⚠️ Failed to parse record: $_"
                }
            }

            # Skip empty batches
            if ($transformedData.Count -eq 0) {
                Write-Host "⏩ No data in batch. Skipping..."
                continue
            }

            # Prepare payload
            $body = $transformedData | ConvertTo-Json
            if ([string]::IsNullOrWhiteSpace($body) -or $body -eq '[]') {
                Write-Host "⏩ Empty JSON payload. Skipping..."
                continue
            }

            # Ingest to Sentinel
            try {
                Write-Host "📤 Sending $($transformedData.Count) records to Sentinel..."
                $response = Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers
                Write-Host "✅ Successfully ingested $($transformedData.Count) records" -ForegroundColor Green
            }
            catch {
                Write-Error "❌ Ingestion failed: $_"
            }
        }
        catch {
            Write-Error "❌ Batch processing failed: $_"
        }
    } while ($auditLogs.ResultCount -eq 5000)
}
catch {
    Write-Error "❌ Audit log retrieval failed: $_"
}
finally {
    # ========================
    # Cleanup
    # ========================
    try {
        Write-Host "`nDisconnecting from Exchange Online..."
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop
        Write-Host "✅ Successfully disconnected" -ForegroundColor Green
    }
    catch {
        Write-Warning "⚠️ Failed to disconnect from Exchange Online: $_"
    }
}

Write-Host "`nScript completed`n" -ForegroundColor Cyan
