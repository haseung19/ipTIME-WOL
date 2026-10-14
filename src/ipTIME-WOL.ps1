[CmdletBinding()]
param(
    [switch]$WakeSaved
)

# ipTIME BE5100M, iUX 3.0 JSON-RPC client
# References: maengis/iptime_api (BE5100M 15.31.2), boxqkrtm/iptime-wol-fast
# Designed for Windows PowerShell 5.1 or later on Windows.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:ProfileFolder = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ipTIME-WOL'
$script:ProfilePath = Join-Path $script:ProfileFolder 'settings.json'
$script:MacPattern = '(?i)(?<![0-9a-f])(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}(?![0-9a-f])'
$script:RouterSession = $null
$script:LastEndpoint = ''
$script:LastUser = ''
$script:KnownProfile = $null

function Read-Profile {
    if (-not (Test-Path -LiteralPath $script:ProfilePath)) { return $null }
    try {
        $raw = [System.IO.File]::ReadAllText($script:ProfilePath, [System.Text.Encoding]::UTF8)
        return ConvertFrom-Json -InputObject $raw -ErrorAction Stop
    } catch {
        throw '설정 파일을 읽지 못했습니다. 설정 파일이 손상되었거나 접근할 수 없습니다.'
    }
}

function Protect-Password {
    param([string]$Password)
    $secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
    return ConvertFrom-SecureString -SecureString $secure
}

function Unprotect-Password {
    param([string]$ProtectedPassword)
    if ([string]::IsNullOrWhiteSpace($ProtectedPassword)) { throw '저장된 암호가 없습니다.' }
    $secure = ConvertTo-SecureString -String $ProtectedPassword -ErrorAction Stop
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        $secure.Dispose()
    }
}

function Save-Profile {
    param([string]$Endpoint, [string]$Username, [string]$Password, [string]$Mac, [string]$Name)
    if (-not (Test-Path -LiteralPath $script:ProfileFolder)) {
        [void](New-Item -ItemType Directory -Path $script:ProfileFolder -Force)
    }
    $info = [ordered]@{
        version = 1
        endpoint = $Endpoint
        username = $Username
        protectedPassword = (Protect-Password -Password $Password)
        targetMac = $Mac
        targetName = $Name
    }
    $json = ConvertTo-Json -InputObject $info -Depth 6
    [System.IO.File]::WriteAllText($script:ProfilePath, $json, [System.Text.UTF8Encoding]::new($false))
    $script:KnownProfile = Read-Profile
}

function Resolve-Endpoint {
    param([string]$Hostname, [string]$Port, [string]$Scheme)
    $hostInput = $Hostname.Trim()
    if ([string]::IsNullOrWhiteSpace($hostInput)) { throw '공유기 접속 주소를 입력하십시오.' }
    if ([string]::IsNullOrWhiteSpace($Scheme)) { $Scheme = 'http' }
    if ($hostInput -notmatch '^https?://') { $hostInput = "${Scheme}://$hostInput" }
    $uri = $null
    if (-not [Uri]::TryCreate($hostInput, [UriKind]::Absolute, [ref]$uri)) {
        throw '공유기 접속 주소 형식이 올바르지 않습니다.'
    }
    if ($uri.Scheme -notin @('http', 'https')) { throw 'HTTP 또는 HTTPS만 지원합니다.' }
    if (-not [string]::IsNullOrWhiteSpace($uri.UserInfo)) { throw '주소에 계정이나 비밀번호를 포함하지 마십시오.' }
    if ($uri.AbsolutePath -ne '/' -or -not [string]::IsNullOrWhiteSpace($uri.Query) -or -not [string]::IsNullOrWhiteSpace($uri.Fragment)) {
        throw '접속 주소에는 호스트 이름 또는 IP만 입력하십시오. 경로는 입력하지 않습니다.'
    }
    $portNumber = 0
    if (-not [int]::TryParse($Port.Trim(), [ref]$portNumber) -or $portNumber -lt 1 -or $portNumber -gt 65535) {
        throw '포트는 1~65535 범위의 숫자여야 합니다.'
    }
    $builder = [UriBuilder]::new($uri.Scheme, $uri.Host, $portNumber)
    return $builder.Uri.GetLeftPart([System.UriPartial]::Authority).TrimEnd('/')
}

function New-RouterClient {
    param([string]$Endpoint)
    $jar = [System.Net.CookieContainer]::new()
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer = $jar
    $handler.UseCookies = $true
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(13)
    $client.DefaultRequestHeaders.Referrer = [Uri]($Endpoint + '/ui/')
    [void]$client.DefaultRequestHeaders.TryAddWithoutValidation('Origin', $Endpoint)
    [void]$client.DefaultRequestHeaders.TryAddWithoutValidation('Accept', 'application/json, text/plain, */*')
    [void]$client.DefaultRequestHeaders.TryAddWithoutValidation('Cache-Control', 'no-store')
    return [pscustomobject]@{ Http = $client; Cookies = $jar; Base = $Endpoint }
}

function Invoke-Rpc {
    param([object]$Router, [string]$Method, [object]$Params = $null)
    $requestBody = @{ method = $Method }
    if ($null -ne $Params) { $requestBody['params'] = $Params }
    $json = ConvertTo-Json -InputObject $requestBody -Depth 10 -Compress
    $content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
    $response = $null
    try {
        $response = $Router.Http.PostAsync(($Router.Base + '/cgi/service.cgi'), $content).GetAwaiter().GetResult()
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw "${Method}: HTTP $([int]$response.StatusCode) 오류 (접속 주소, 포트, 원격 관리 설정 확인)"
        }
        $reply = $null
        try { $reply = ConvertFrom-Json -InputObject $body -ErrorAction Stop }
        catch { throw "${Method}: 공유기에서 JSON 응답을 받지 못했습니다. 해당 포트가 ipTIME 관리 포트인지 확인하십시오." }
        if ($null -ne $reply.error -and $reply.error -ne $false) {
            $errorMessage = if ($reply.error -is [string]) { $reply.error } elseif ($reply.error.message) { $reply.error.message } else { '공유기 API 오류' }
            $errorCode = if ($null -ne $reply.error.code) { [string]$reply.error.code } else { 'unknown' }
            throw "API $Method 실패 (코드 $errorCode): $errorMessage"
        }
        if ($null -eq $reply.PSObject.Properties['result']) {
            throw "${Method}: result 필드가 없는 응답입니다."
        }
        return $reply.result
    } finally {
        if ($null -ne $response) { $response.Dispose() }
        $content.Dispose()
    }
}

function Get-Value {
    param([object]$Object, [string[]]$Names)
    if ($null -eq $Object) { return $null }
    foreach ($name in $Names) {
        if ($Object -is [System.Collections.IDictionary]) {
            if ($Object.Contains($name)) { return $Object[$name] }
        } else {
            $prop = $Object.PSObject.Properties[$name]
            if ($null -ne $prop) { return $prop.Value }
        }
    }
    return $null
}

function Format-Mac {
    param([string]$Value)
    $compact = $Value -replace '[^A-Fa-f0-9]', ''
    if ($compact -notmatch '^[0-9A-Fa-f]{12}$') { throw '유효하지 않은 MAC 주소입니다.' }
    $matches = [regex]::Matches($compact.ToUpperInvariant(), '.{2}')
    return (($matches | ForEach-Object { $_.Value }) -join ':')
}

function Add-Device {
    param([System.Collections.Generic.List[object]]$List, [string]$Mac, [string]$Name)
    try { $normalized = Format-Mac -Value $Mac }
    catch { return }
    foreach ($existing in $List) { if ($existing.Mac -eq $normalized) { return } }
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $normalized }
    [void]$List.Add([pscustomobject]@{ Name = $Name.Trim(); Mac = $normalized })
}

function Parse-Devices {
    param([object]$Value, [System.Collections.Generic.List[object]]$Output, [int]$Depth = 0)
    if ($null -eq $Value -or $Depth -gt 8) { return }
    if ($Value -is [string]) {
        $text = $Value.Trim()
        if ($text.StartsWith('[') -or $text.StartsWith('{')) {
            try {
                $inner = ConvertFrom-Json -InputObject $text -ErrorAction Stop
                Parse-Devices -Value $inner -Output $Output -Depth ($Depth + 1)
                return
            } catch { }
        }
        $rows = [regex]::Matches($text, '(?is)<tr\b[^>]*>.*?</tr>')
        if ($rows.Count -gt 0) {
            foreach ($row in $rows) {
                $cells = [regex]::Matches($row.Value, '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')
                $name = ''
                $mac = ''
                foreach ($cell in $cells) {
                    $cellText = [regex]::Replace($cell.Groups[1].Value, '(?is)<[^>]+>', ' ')
                    $cellText = [System.Net.WebUtility]::HtmlDecode($cellText).Trim()
                    $candidate = [regex]::Match($cellText, $script:MacPattern)
                    if ($candidate.Success) { $mac = $candidate.Value }
                    elseif ([string]::IsNullOrWhiteSpace($name) -and $cellText.Length -gt 0) { $name = $cellText }
                }
                if ($mac) { Add-Device -List $Output -Mac $mac -Name $name }
            }
            if ($Output.Count -gt 0) { return }
        }
        foreach ($match in [regex]::Matches($text, $script:MacPattern)) {
            Add-Device -List $Output -Mac $match.Value -Name $match.Value
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [System.Collections.IDictionary]) {
        foreach ($entry in $Value) { Parse-Devices -Value $entry -Output $Output -Depth ($Depth + 1) }
        return
    }
    $mac = Get-Value -Object $Value -Names @('mac', 'macaddr', 'addr', 'mac_address', 'macAddress')
    if ($mac -is [string] -and $mac -match $script:MacPattern) {
        $name = Get-Value -Object $Value -Names @('pcname', 'name', 'hostname', 'host', 'description')
        Add-Device -List $Output -Mac $mac -Name ([string]$name)
        return
    }
    foreach ($key in @('result', 'wol', 'list', 'devices', 'rows', 'items', 'data', 'entries')) {
        $nested = Get-Value -Object $Value -Names @($key)
        if ($null -ne $nested) { Parse-Devices -Value $nested -Output $Output -Depth ($Depth + 1) }
    }
}

function Get-WolDevices {
    param([object]$Value)
    $list = [System.Collections.Generic.List[object]]::new()
    Parse-Devices -Value $Value -Output $list
    return $list.ToArray()
}

function Connect-Router {
    param([string]$Endpoint, [string]$Username, [string]$Password)
    $router = New-RouterClient -Endpoint $Endpoint
    try {
        $loginResult = Invoke-Rpc -Router $router -Method 'session/login' -Params @{ id = $Username; pw = $Password }
        if ([string]$loginResult -ne 'done') { throw '관리자 로그인에 실패했습니다. ID 및 암호 또는 관리자 로그인 제한을 확인하십시오.' }
        $sessionCookies = $router.Cookies.GetCookies([Uri]($router.Base + '/cgi/service.cgi'))
        $hasSession = $false
        foreach ($cookie in $sessionCookies) {
            if ($cookie.Name -eq 'efm_session_id' -and -not [string]::IsNullOrEmpty($cookie.Value)) { $hasSession = $true }
        }
        if (-not $hasSession) { throw '로그인 응답은 수신했지만 efm_session_id 세션 쿠키가 발급되지 않았습니다.' }

        $wolResponse = Invoke-Rpc -Router $router -Method 'wol/show'
        $devices = @(Get-WolDevices -Value $wolResponse)
        $identity = ''
        try {
            $product = Invoke-Rpc -Router $router -Method 'product/info'
            $model = [string](Get-Value -Object $product -Names @('name', 'product', 'model'))
            $version = [string](Get-Value -Object $product -Names @('version', 'firmware'))
            $identity = ($model + ' ' + $version).Trim()
        } catch { }
        return [pscustomobject]@{ Router = $router; Devices = $devices; Identity = $identity }
    } catch {
        $router.Http.Dispose()
        throw
    }
}

function Confirm-WolResponse {
    param([object]$Result)
    if ($Result -is [string] -and $Result.Trim().ToLowerInvariant() -in @('done', 'ok', 'success')) { return }
    if ($Result -is [bool] -and $Result) { return }
    $status = Get-Value -Object $Result -Names @('status', 'result')
    if ($status -is [string] -and $status.Trim().ToLowerInvariant() -in @('done', 'ok', 'success')) { return }
    throw 'WOL 요청 응답을 성공으로 판정할 수 없습니다. 공유기 응답 형식 확인이 필요합니다.'
}

function Send-Wol {
    param([object]$Router, [string]$Mac)
    $normalized = Format-Mac -Value $Mac
    $dashed = $normalized.Replace(':', '-')
    try {
        $result = Invoke-Rpc -Router $Router -Method 'wol/signal' -Params @($dashed)
    } catch {
        # Only fall back when the router explicitly says this method is unsupported.
        $detail = $_.Exception.Message
        if ($detail -notmatch '(?i)(-32601|method not found|unknown method|invalid method|no such method)') { throw }
        $result = Invoke-Rpc -Router $Router -Method 'wol/wake' -Params @{ mac = $normalized }
    }
    Confirm-WolResponse -Result $result
}

function Create-DesktopShortcut {
    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    $destination = Join-Path $desktop 'PC 켜기 (ipTIME).lnk'
    # The bundled EXE is the stable shortcut target. The embedded PS1 is temporary.
    $programPath = $env:IPTIME_WOL_EXE
    if ([string]::IsNullOrWhiteSpace($programPath) -or -not (Test-Path -LiteralPath $programPath -PathType Leaf)) {
        throw '실행 파일 경로를 확인하지 못했습니다. ipTIME-WOL.exe를 직접 실행하십시오.'
    }
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($destination)
    $link.TargetPath = $programPath
    $link.Arguments = '--wake'
    $link.WorkingDirectory = Split-Path -Parent $programPath
    $link.IconLocation = "$env:WINDIR\System32\shell32.dll,15"
    $link.Description = '선택한 PC로 ipTIME 공유기의 WOL 요청을 전송합니다.'
    $link.Save()
    return $destination
}

if ($WakeSaved) {
    $router = $null
    try {
        $profile = Read-Profile
        if ($null -eq $profile -or [string]::IsNullOrWhiteSpace([string]$profile.targetMac)) {
            throw '저장된 PC가 없습니다. ipTIME WOL 테스트 프로그램에서 먼저 PC를 선택하고 원클릭 아이콘을 생성하십시오.'
        }
        $password = Unprotect-Password -ProtectedPassword ([string]$profile.protectedPassword)
        $connection = Connect-Router -Endpoint ([string]$profile.endpoint) -Username ([string]$profile.username) -Password $password
        $router = $connection.Router
        $device = @($connection.Devices | Where-Object { $_.Mac -eq ([string]$profile.targetMac) }) | Select-Object -First 1
        if ($null -eq $device) { throw '선택했던 PC가 현재 공유기의 WOL 목록에 없습니다.' }
        Send-Wol -Router $router -Mac $device.Mac
        [void][System.Windows.Forms.MessageBox]::Show(
            "'$($device.Name)'에 WOL 명령을 전송했고, 공유기가 정상 처리 응답을 보냈습니다.`r`n`r`n실제 Windows 부팅 완료 여부까지 확인한 것은 아닙니다.",
            'ipTIME WOL 요청 완료', 'OK', 'Information'
        )
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'ipTIME WOL 오류', 'OK', 'Error')
        exit 1
    } finally {
        if ($null -ne $router) { $router.Http.Dispose() }
    }
    exit 0
}

function New-Label {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height = 24)
    $label = [System.Windows.Forms.Label]::new()
    $label.Text = $Text
    $label.Location = [System.Drawing.Point]::new($X, $Y)
    $label.Size = [System.Drawing.Size]::new($Width, $Height)
    $label.TextAlign = 'MiddleLeft'
    $label.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#243040')
    $form.Controls.Add($label)
    return $label
}

function New-TextInput {
    param([int]$X, [int]$Y, [int]$Width, [string]$Value = '')
    $input = [System.Windows.Forms.TextBox]::new()
    $input.Location = [System.Drawing.Point]::new($X, $Y)
    $input.Size = [System.Drawing.Size]::new($Width, 26)
    $input.Text = $Value
    $form.Controls.Add($input)
    return $input
}

function New-Button {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height = 38)
    $button = [System.Windows.Forms.Button]::new()
    $button.Text = $Text
    $button.Location = [System.Drawing.Point]::new($X, $Y)
    $button.Size = [System.Drawing.Size]::new($Width, $Height)
    $button.FlatStyle = 'System'
    $form.Controls.Add($button)
    return $button
}

$form = [System.Windows.Forms.Form]::new()
$form.Text = 'ipTIME WOL - BE5100M 테스트 도구'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = [System.Drawing.Size]::new(764, 600)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = [System.Drawing.Font]::new('Malgun Gothic', 10)
$form.BackColor = [System.Drawing.Color]::White

$title = New-Label -Text 'ipTIME WOL' -X 26 -Y 17 -Width 690 -Height 39
$title.Font = [System.Drawing.Font]::new('Malgun Gothic', 18, [System.Drawing.FontStyle]::Bold)
$sub = New-Label -Text 'BE5100M / 펌웨어 15.x · 관리자 로그인 → WOL 등록 목록 → PC 깨우기' -X 27 -Y 55 -Width 705 -Height 27
$sub.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#687487')

[void](New-Label -Text '공유기 접속 주소' -X 28 -Y 105 -Width 158)
$txtHost = New-TextInput -X 189 -Y 105 -Width 320
[void](New-Label -Text '포트' -X 531 -Y 105 -Width 47)
$txtPort = New-TextInput -X 583 -Y 105 -Width 148 -Value '8080'

[void](New-Label -Text '프로토콜' -X 28 -Y 146 -Width 158)
$cboScheme = [System.Windows.Forms.ComboBox]::new()
$cboScheme.Location = [System.Drawing.Point]::new(189, 146)
$cboScheme.Size = [System.Drawing.Size]::new(145, 27)
$cboScheme.DropDownStyle = 'DropDownList'
[void]$cboScheme.Items.Add('http')
[void]$cboScheme.Items.Add('https')
$cboScheme.SelectedIndex = 0
$form.Controls.Add($cboScheme)

[void](New-Label -Text '관리자 ID' -X 28 -Y 185 -Width 158)
$txtUser = New-TextInput -X 189 -Y 185 -Width 268 -Value 'admin'
[void](New-Label -Text '관리자 암호' -X 475 -Y 185 -Width 105)
$txtPassword = New-TextInput -X 583 -Y 185 -Width 148
$txtPassword.UseSystemPasswordChar = $true

$security = New-Label -Text '주의: HTTP 원격 관리 접속은 암호가 암호화되지 않습니다. HTTPS 또는 VPN 권장.' -X 28 -Y 222 -Width 704 -Height 26
$security.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#9B5D22')

$btnConnect = New-Button -Text '1. 로그인 및 목록 조회' -X 28 -Y 263 -Width 224
$btnWake = New-Button -Text '2. 선택한 PC 켜기' -X 264 -Y 263 -Width 219
$btnShortcut = New-Button -Text '3. 원클릭 아이콘 생성' -X 495 -Y 263 -Width 236
$btnWake.Enabled = $false
$btnShortcut.Enabled = $false

$devicesLabel = New-Label -Text '공유기에 등록된 WOL 기기' -X 28 -Y 319 -Width 475 -Height 27
$devicesLabel.Font = [System.Drawing.Font]::new('Malgun Gothic', 11, [System.Drawing.FontStyle]::Bold)
$list = [System.Windows.Forms.ListView]::new()
$list.Location = [System.Drawing.Point]::new(28, 354)
$list.Size = [System.Drawing.Size]::new(703, 135)
$list.View = 'Details'
$list.FullRowSelect = $true
$list.MultiSelect = $false
$list.GridLines = $true
$list.HideSelection = $false
[void]$list.Columns.Add('PC 이름', 410)
[void]$list.Columns.Add('MAC 주소', 250)
$form.Controls.Add($list)

$statusLabel = New-Label -Text '실행 결과' -X 28 -Y 505 -Width 690 -Height 24
$statusLabel.Font = [System.Drawing.Font]::new('Malgun Gothic', 10, [System.Drawing.FontStyle]::Bold)
$txtStatus = [System.Windows.Forms.TextBox]::new()
$txtStatus.Location = [System.Drawing.Point]::new(28, 533)
$txtStatus.Size = [System.Drawing.Size]::new(703, 47)
$txtStatus.Multiline = $true
$txtStatus.ReadOnly = $true
$txtStatus.ScrollBars = 'Vertical'
$txtStatus.Text = '주소, 포트, 관리자 ID/암호를 입력한 뒤 [로그인 및 목록 조회]를 누르십시오.'
$form.Controls.Add($txtStatus)

function Set-Status {
    param([string]$Message, [bool]$Failure = $false)
    $txtStatus.Text = $Message
    $txtStatus.ForeColor = if ($Failure) { [System.Drawing.Color]::DarkRed } else { [System.Drawing.Color]::DarkGreen }
    $form.Refresh()
}

function Read-UIConnection {
    $endpoint = Resolve-Endpoint -Hostname $txtHost.Text -Port $txtPort.Text -Scheme ([string]$cboScheme.SelectedItem)
    $username = $txtUser.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($username)) { throw '관리자 ID를 입력하십시오.' }
    $password = $txtPassword.Text
    if ([string]::IsNullOrEmpty($password) -and $null -ne $script:KnownProfile) {
        if ([string]$script:KnownProfile.endpoint -eq $endpoint -and [string]$script:KnownProfile.username -eq $username) {
            $password = Unprotect-Password -ProtectedPassword ([string]$script:KnownProfile.protectedPassword)
        }
    }
    if ([string]::IsNullOrEmpty($password)) { throw '관리자 암호를 입력하십시오.' }
    return [pscustomobject]@{ Endpoint = $endpoint; Username = $username; Password = $password }
}

function Update-ActionButtons {
    $hasSelection = ($list.SelectedItems.Count -gt 0 -and $null -ne $script:RouterSession)
    $btnWake.Enabled = $hasSelection
    $btnShortcut.Enabled = $hasSelection
}

$list.Add_SelectedIndexChanged({ Update-ActionButtons })

$btnConnect.Add_Click({
    $btnConnect.Enabled = $false
    $btnWake.Enabled = $false
    $btnShortcut.Enabled = $false
    $list.Items.Clear()
    $form.UseWaitCursor = $true
    try {
        if ($null -ne $script:RouterSession) {
            $script:RouterSession.Http.Dispose()
            $script:RouterSession = $null
        }
        $info = Read-UIConnection
        Set-Status -Message '공유기 관리자 로그인 및 WOL 목록을 조회하고 있습니다.'
        $connection = Connect-Router -Endpoint $info.Endpoint -Username $info.Username -Password $info.Password
        $script:RouterSession = $connection.Router
        $script:LastEndpoint = $info.Endpoint
        $script:LastUser = $info.Username
        foreach ($device in $connection.Devices) {
            $row = [System.Windows.Forms.ListViewItem]::new($device.Name)
            [void]$row.SubItems.Add($device.Mac)
            $row.Tag = $device
            [void]$list.Items.Add($row)
        }
        $routerLabel = if ($connection.Identity) { " / $($connection.Identity)" } else { '' }
        Set-Status -Message ("관리자 로그인 성공${routerLabel}. WOL 등록 기기: $($connection.Devices.Count)대. 기기를 선택하십시오.")
    } catch {
        Set-Status -Message ("연결/조회 실패: " + $_.Exception.Message) -Failure $true
    } finally {
        $form.UseWaitCursor = $false
        $btnConnect.Enabled = $true
        Update-ActionButtons
    }
})

$btnWake.Add_Click({
    if ($list.SelectedItems.Count -eq 0 -or $null -eq $script:RouterSession) { return }
    $btnWake.Enabled = $false
    $form.UseWaitCursor = $true
    try {
        $device = $list.SelectedItems[0].Tag
        Set-Status -Message "'$($device.Name)'로 WOL 요청을 보내고 있습니다."
        Send-Wol -Router $script:RouterSession -Mac $device.Mac
        Set-Status -Message "WOL 요청 정상 처리: $($device.Name) ($($device.Mac)). 실제 부팅 완료 여부는 별도 확인이 필요합니다."
    } catch {
        Set-Status -Message ("WOL 전송 실패: " + $_.Exception.Message) -Failure $true
    } finally {
        $form.UseWaitCursor = $false
        Update-ActionButtons
    }
})

$btnShortcut.Add_Click({
    if ($list.SelectedItems.Count -eq 0 -or $null -eq $script:RouterSession) { return }
    try {
        $connection = Read-UIConnection
        if ($connection.Endpoint -ne $script:LastEndpoint -or $connection.Username -ne $script:LastUser) {
            throw '접속 정보가 변경되었습니다. 먼저 [로그인 및 목록 조회]를 다시 실행하십시오.'
        }
        $device = $list.SelectedItems[0].Tag
        Save-Profile -Endpoint $connection.Endpoint -Username $connection.Username -Password $connection.Password -Mac $device.Mac -Name $device.Name
        $shortcutPath = Create-DesktopShortcut
        $txtPassword.Clear()
        Set-Status -Message "원클릭 바로가기 생성 완료: $shortcutPath. 같은 Windows 계정에서 바로가기를 더블클릭하면 $($device.Name)에 WOL을 보냅니다."
    } catch {
        Set-Status -Message ("바로가기 생성 실패: " + $_.Exception.Message) -Failure $true
    }
})

$cboScheme.Add_SelectedIndexChanged({
    if ([string]$cboScheme.SelectedItem -eq 'http') {
        $security.Text = '주의: HTTP 원격 관리 접속은 암호가 암호화되지 않습니다. HTTPS 또는 VPN 권장.'
    } else {
        $security.Text = 'HTTPS 인증서 오류는 우회하지 않습니다. 공유기의 정상 인증서를 사용하십시오.'
    }
})

try {
    $script:KnownProfile = Read-Profile
    if ($null -ne $script:KnownProfile) {
        $uri = [Uri]([string]$script:KnownProfile.endpoint)
        $txtHost.Text = $uri.Host
        $txtPort.Text = [string]$uri.Port
        $cboScheme.SelectedItem = $uri.Scheme
        $txtUser.Text = [string]$script:KnownProfile.username
        $txtStatus.Text = "저장된 공유기 설정이 있습니다. 암호는 현재 Windows 사용자에게 암호화되어 있으며, 빈 암호칸 그대로 연결할 수 있습니다. 선택된 PC: $($script:KnownProfile.targetName)"
    }
} catch {
    $txtStatus.Text = '기존 설정을 불러올 수 없습니다: ' + $_.Exception.Message
}

$form.Add_FormClosing({
    if ($null -ne $script:RouterSession) {
        $script:RouterSession.Http.Dispose()
        $script:RouterSession = $null
    }
})
[void]$form.ShowDialog()
$form.Dispose()
