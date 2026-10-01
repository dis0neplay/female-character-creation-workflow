param([string]$OutputRoot = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) '输出'))

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$errors = [Collections.Generic.List[string]]::new()
$reports = [Collections.Generic.List[object]]::new()
$shell = (Get-Process -Id $PID).Path
$personDir = Join-Path $OutputRoot '人物'
$wardrobeDir = Join-Path $OutputRoot '搭配'
$groupDir = Join-Path $OutputRoot '关系网'
$people = @(if (Test-Path -LiteralPath $personDir) { Get-ChildItem -LiteralPath $personDir -Filter '*.md' -File })
$wardrobes = @(if (Test-Path -LiteralPath $wardrobeDir) { Get-ChildItem -LiteralPath $wardrobeDir -Filter '*.md' -File })
$numbers = @{}
$pairs = 0
$groups = 0

function Invoke-LocalCheck([string]$Script, [string[]]$Arguments, [string]$Label) {
    $raw = & $shell -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    try { $result = $raw | ConvertFrom-Json }
    catch { $errors.Add("${Label}：检查器未返回有效结果"); return }
    if ($code -ne 0 -or -not $result.通过) { foreach ($errorText in $result.错误) { $errors.Add("${Label}：$errorText") } }
    $reports.Add([ordered]@{ '文件' = $Label; '通过' = ($code -eq 0 -and $result.通过); '提示' = @($result.提示 | Where-Object { $_ }) })
}

foreach ($person in $people) {
    $match = [regex]::Match($person.BaseName, '^(\d{3,})-.+$')
    if (-not $match.Success) { $errors.Add("单人文件须使用编号-姓名：$($person.Name)"); continue }
    $number = $match.Groups[1].Value.TrimStart('0')
    if ($numbers.ContainsKey($number)) { $errors.Add("编号重复：$($person.Name)、$($numbers[$number])") }
    else { $numbers[$number] = $person.Name }
    $wardrobePath = Join-Path $wardrobeDir $person.Name
    if (-not (Test-Path -LiteralPath $wardrobePath -PathType Leaf)) { $errors.Add("缺少搭配：$($person.Name)"); continue }
    # 这里只核对已有文件内部一致性；单次交付仍应传作者确认的 ExpectedScenes。
    $text = Get-Content -LiteralPath $wardrobePath -Encoding UTF8 -Raw
    $scenes = @([regex]::Matches($text, '(?m)^## ([^\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim() }) -join '|'
    $arguments = @('-PersonPath',$person.FullName,'-WardrobePath',$wardrobePath,'-RequireDetailedProfile')
    if ($scenes) { $arguments += @('-ExpectedScenes',$scenes) }
    Invoke-LocalCheck (Join-Path $PSScriptRoot '检查输出.ps1') $arguments $person.Name
    $pairs++
}
foreach ($wardrobe in $wardrobes) {
    if (-not (Test-Path -LiteralPath (Join-Path $personDir $wardrobe.Name) -PathType Leaf)) { $errors.Add("缺少人物：$($wardrobe.Name)") }
}
if (Test-Path -LiteralPath $groupDir) {
    foreach ($group in Get-ChildItem -LiteralPath $groupDir -Directory) {
        Invoke-LocalCheck (Join-Path $PSScriptRoot '检查关系网.ps1') @('-PersonPath',(Join-Path $group.FullName '人物.md'),'-WardrobePath',(Join-Path $group.FullName '搭配.md')) "关系网/$($group.Name)"
        $groups++
    }
}
[ordered]@{ '通过' = ($errors.Count -eq 0); '单人档案对数' = $pairs; '关系网数' = $groups; '错误' = @($errors); '检查结果' = @($reports) } | ConvertTo-Json -Compress -Depth 5
if ($errors.Count) { exit 1 }
