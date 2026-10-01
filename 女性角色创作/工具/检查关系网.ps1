param(
    [Parameter(Mandatory)][string]$PersonPath,
    [Parameter(Mandatory)][string]$WardrobePath
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$errors = [Collections.Generic.List[string]]::new()
foreach ($path in @($PersonPath, $WardrobePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $errors.Add("文件不存在：$path") }
}
if ($errors.Count) { @{ '通过' = $false; '错误' = @($errors) } | ConvertTo-Json -Compress; exit 1 }
$person = Get-Content -LiteralPath $PersonPath -Encoding UTF8 -Raw
$wardrobe = Get-Content -LiteralPath $WardrobePath -Encoding UTF8 -Raw
$members = [regex]::Matches($person, '(?ms)^## (\d+)\. ([^\r\n]+)\r?\n(.*?)(?=^## |\z)')
$looks = [regex]::Matches($wardrobe, '(?ms)^## ([^\r\n]+)\r?\n(.*?)(?=^## |\z)')
$names = @($members | ForEach-Object { $_.Groups[2].Value.Trim() })
$ids = @($members | ForEach-Object { [int]$_.Groups[1].Value })
if (-not $members.Count) { $errors.Add('关系网没有人物条目') }
if (@($names | Select-Object -Unique).Count -ne $names.Count) { $errors.Add('关系网人物姓名重复') }
if (@($ids | Select-Object -Unique).Count -ne $ids.Count) { $errors.Add('关系网人物编号重复') }
$lookNames = @($looks | ForEach-Object { $_.Groups[1].Value.Trim() } | Where-Object { $_ -ne '体型适配补充' })
if (@($lookNames | Select-Object -Unique).Count -ne $lookNames.Count) { $errors.Add('关系网搭配人物重复') }
foreach ($name in $lookNames) {
    if ($name -notin $names) { $errors.Add("搭配引用未知人物：$name") }
}
$cupDiff = @{ AA = 7.5; A = 10.0; B = 12.5; C = 15.0; D = 17.5; E = 20.0; F = 22.5; G = 25.0; H = 27.5 }
$outfitCount = 0
foreach ($member in $members) {
    $name = $member.Groups[2].Value.Trim()
    $body = $member.Groups[3].Value
    $age = [regex]::Match($body, '(?m)^- 年龄：[ \t]*(\d{1,3})[ \t]*(?:岁)?[ \t]*\r?$')
    if (-not $age.Success) { $errors.Add("${name}：年龄必须为明确的整数") }
    elseif ([int]$age.Groups[1].Value -lt 18) { $errors.Add("${name}：年龄低于 18 岁") }
    foreach ($field in @('身份','体型','外貌','性格','关系','日常钩子')) {
        if ($body -notmatch "(?m)^- ${field}：[ \t]*\S") { $errors.Add("${name}：缺少$field") }
    }
    $measure = [regex]::Match($body, '(?m)^- 体型：([^\r\n]+)').Groups[1].Value
    if ($measure -and $measure -notmatch '^待定：\S') {
        $values = @{}
        foreach ($field in @('身高','体重','胸围','下胸围','腰围','臀围','臀腰比')) {
            $pattern = if ($field -eq '胸围') { '(?<!下)胸围' } else { $field }
            $match = [regex]::Match($measure, "$pattern\s+(\d+(?:\.\d+)?)")
            if (-not $match.Success) { $errors.Add("${name}：体型缺少有效$field") }
            else {
                $values[$field] = [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
                if ($values[$field] -le 0) { $errors.Add("${name}：$field 必须大于零") }
            }
        }
        $cup = [regex]::Match($measure, '罩杯\s+(AA|[A-H])(?=[；\s]|$)')
        if (-not $cup.Success) { $errors.Add("${name}：缺少有效罩杯") }
        elseif ($values.ContainsKey('胸围') -and $values.ContainsKey('下胸围') -and
                [math]::Abs($values['胸围'] - $values['下胸围'] - $cupDiff[$cup.Groups[1].Value]) -gt 0.1) {
            $errors.Add("${name}：胸围、下胸围与罩杯不一致")
        }
        if ($values['腰围'] -gt 0 -and $values.ContainsKey('臀围') -and $values.ContainsKey('臀腰比') -and
            [math]::Abs($values['臀围'] / $values['腰围'] - $values['臀腰比']) -gt 0.02) {
            $errors.Add("${name}：臀腰比与腰围、臀围不一致")
        }
    }
    $appearance = [regex]::Match($body, '(?m)^- 外貌：([^\r\n]+)').Groups[1].Value
    if ($appearance -match '短发或|短黑发或') { $errors.Add("${name}：发长留有未决选项") }
    $look = @($looks | Where-Object { $_.Groups[1].Value.Trim() -eq $name })
    if ($look.Count -ne 1) { $errors.Add("${name}：须有且仅有一份搭配条目"); continue }
    $outfits = [regex]::Matches($look[0].Groups[2].Value, '(?m)^- ([^：\r\n]+)：([^\r\n]+)')
    if (-not $outfits.Count) { $errors.Add("${name}：缺少简要搭配") }
    $scenes = @($outfits | ForEach-Object { $_.Groups[1].Value })
    if (@($scenes | Select-Object -Unique).Count -ne $scenes.Count) { $errors.Add("${name}：搭配场景重复") }
    foreach ($outfit in $outfits) {
        $label = "${name}／$($outfit.Groups[1].Value)"
        $line = $outfit.Groups[2].Value
        if ($line -notmatch '裤|裙|连体|套装|泳装|泳衣|比基尼') { $errors.Add("${label}：缺少下装或连身装") }
        if ($line -match '或|任选|二选一') { $errors.Add("${label}：留有未决选项") }
        if ($appearance -match '短发|短黑发' -and $line -match '马尾|盘发|发髻|丸子头' -and $line -notmatch '假发|接发') {
            $errors.Add("${label}：发型超出人物发长")
        }
    }
    $outfitCount += $outfits.Count
}
[ordered]@{ '通过' = ($errors.Count -eq 0); '人物数' = $members.Count; '简要搭配数' = $outfitCount; '错误' = @($errors) } | ConvertTo-Json -Compress -Depth 3
if ($errors.Count) { exit 1 }
