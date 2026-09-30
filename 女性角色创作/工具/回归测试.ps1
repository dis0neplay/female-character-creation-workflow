$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$workRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sampler = Join-Path $PSScriptRoot '抽样.ps1'
$checker = Join-Path $PSScriptRoot '检查输出.ps1'

$sample = (& $sampler -Mode sample -Count 1 -Seed 'constrained-portrait' -AgeMin 24 -AgeMax 29 -HeightBand '标准' -BodyType '匀称' -Background '中国背景' | ConvertFrom-Json).候选[0]
Assert ($sample.年龄 -ge 24 -and $sample.年龄 -le 29) '年龄约束未生效'
Assert ($sample.身高 -ge 159 -and $sample.身高 -le 168) '身高档约束未生效'
Assert ($sample.体型 -eq '匀称') '体型约束未生效'
Assert ($sample.文化背景 -eq '中国背景') '背景约束未生效'

$measure = & $sampler -Mode measure -Seed 'constrained-measure' -Height 166 -BodyType '匀称' -BustLevel '偏大' -HipLevel '明显' | ConvertFrom-Json
Assert ($measure.罩杯 -eq 'E' -and $measure.胸围 -eq ($measure.下胸围 + 20)) '量体胸围不一致'
Assert ([math]::Abs($measure.臀围 / $measure.腰围 - $measure.臀腰比) -lt 0.02) '量体臀腰比不一致'

$cases = @(
    @{ Name = '001-结城澪.md'; Scenes = '上班／学习|居家休闲|出门约会|运动／出行|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 21 },
    @{ Name = '002-鹭沢栖.md'; Scenes = '上班／学习|居家休闲|出门约会|运动／出行|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 18 },
    @{ Name = '003-罗萨莉娅·维塔莱.md'; Scenes = '面包店工作|居家休闲|出门约会|游泳|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 19 },
    @{ Name = '004-温静姝.md'; Scenes = '家务与出门办事|居家休闲|夫妻约会|见情人|游泳|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 21 },
    @{ Name = '005-伊内斯·罗梅罗.md'; Scenes = '东京日常外出|居家休闲|出门约会|运动训练|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 18 },
    @{ Name = '006-林予棠.md'; Scenes = '日常外出|居家休闲|出门约会|运动／出行|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 18 },
    @{ Name = '007-林予宁.md'; Scenes = '书店／图书馆阅读|居家阅读与休闲|出门约会|逛展／城市出行|晚间聚会／正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 18 },
    @{ Name = '008-顾清宁.md'; Scenes = '日常外出|居家休闲|出门约会|运动／出行|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 18 },
    @{ Name = '009-顾清扬.md'; Scenes = '日常外出|居家休闲|出门约会|运动／出行|正式活动|雨天日常外出|季节户外／短途旅行|社交／文化活动'; Outfits = 18 }
)

Assert (@(Get-ChildItem -LiteralPath (Join-Path $workRoot '输出\人物') -Filter '*.md' -File).Count -eq $cases.Count) '人物文件数量与回归清单不一致'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $workRoot '输出\搭配') -Filter '*.md' -File).Count -eq $cases.Count) '搭配文件数量与回归清单不一致'

$totalOutfits = 0
$totalScenes = 0
foreach ($case in $cases) {
    $personPath = Join-Path (Join-Path $workRoot '输出\人物') $case.Name
    $wardrobePath = Join-Path (Join-Path $workRoot '输出\搭配') $case.Name
    $result = & $checker -PersonPath $personPath -WardrobePath $wardrobePath -RequireDetailedProfile -ExpectedScenes $case.Scenes | ConvertFrom-Json
    Assert $result.通过 "$($case.Name) 未通过输出检查：$($result.错误 -join '；')"
    $outfitCount = [regex]::Matches((Get-Content -LiteralPath $wardrobePath -Encoding UTF8 -Raw), '(?m)^### 方案 \d+').Count
    Assert ($outfitCount -eq $case.Outfits) "$($case.Name) 的搭配套数发生变化"
    $wardrobeText = Get-Content -LiteralPath $wardrobePath -Encoding UTF8 -Raw
    $sockFamilies = 0
    foreach ($sockPattern in @('丝袜|连裤袜', '长筒丝袜|及膝丝袜|短丝袜|过膝针织袜', '棉袜|棉质|羊毛|罗纹|运动袜|跑步袜|工作袜|船袜|隐形袜', '不穿袜|裸足|光脚')) {
        if ($wardrobeText -match $sockPattern) { $sockFamilies++ }
    }
    Assert ($sockFamilies -ge 3) "$($case.Name) 的袜型变化不足三类"
    $totalOutfits += $outfitCount
    $totalScenes += @($case.Scenes -split '\|').Count
}

$negativeDir = Join-Path ([IO.Path]::GetTempPath()) ('female-profile-check-' + [guid]::NewGuid().ToString('N'))
$negativePerson = Join-Path $negativeDir '007-林予宁.md'
New-Item -ItemType Directory -Path $negativeDir | Out-Null
try {
    $validPerson = Get-Content -LiteralPath (Join-Path (Join-Path $workRoot '输出\人物') '007-林予宁.md') -Encoding UTF8 -Raw
    $invalidPerson = [regex]::Replace($validPerson, '(?ms)^## 人物速写.*?(?=^## 面貌)', "## 人物速写`r`n`r`n- 只有条目。`r`n`r`n")
    [IO.File]::WriteAllText($negativePerson, $invalidPerson, [Text.UTF8Encoding]::new($false))
    $wardrobe007 = Join-Path (Join-Path $workRoot '输出\搭配') '007-林予宁.md'
    $negativeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -PersonPath $negativePerson -WardrobePath $wardrobe007 -RequireDetailedProfile 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1 -and $negativeOutput -match '人物速写须为连贯正文') '检查工具未拒绝条目式速写'
}
finally {
    Remove-Item -LiteralPath $negativePerson -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $negativeDir -ErrorAction SilentlyContinue
}

$behaviorNegativeDir = Join-Path ([IO.Path]::GetTempPath()) ('female-behavior-check-' + [guid]::NewGuid().ToString('N'))
$behaviorNegativePerson = Join-Path $behaviorNegativeDir '008-顾清宁.md'
New-Item -ItemType Directory -Path $behaviorNegativeDir | Out-Null
try {
    $validBehaviorPerson = Get-Content -LiteralPath (Join-Path (Join-Path $workRoot '输出\人物') '008-顾清宁.md') -Encoding UTF8 -Raw
    $invalidBehaviorPerson = [regex]::Replace($validBehaviorPerson, '(?ms)^## 行为画像.*?(?=^## 面貌)', "## 行为画像`r`n`r`n- 先观察。`r`n- 再回答。`r`n`r`n")
    [IO.File]::WriteAllText($behaviorNegativePerson, $invalidBehaviorPerson, [Text.UTF8Encoding]::new($false))
    $wardrobe008 = Join-Path (Join-Path $workRoot '输出\搭配') '008-顾清宁.md'
    $behaviorNegativeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -PersonPath $behaviorNegativePerson -WardrobePath $wardrobe008 -RequireDetailedProfile 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1 -and $behaviorNegativeOutput -match '行为画像须为不少于45字的连贯正文') '检查工具未拒绝条目式行为画像'
}
finally {
    Remove-Item -LiteralPath $behaviorNegativePerson -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $behaviorNegativeDir -ErrorAction SilentlyContinue
}

[ordered]@{ '通过' = $true; '人物与搭配对数' = $cases.Count; '已检场景数' = $totalScenes; '搭配套数' = $totalOutfits; '抽样与量体约束' = '通过'; '条目式速写反向测试' = '通过'; '条目式行为画像反向测试' = '通过' } | ConvertTo-Json -Compress
