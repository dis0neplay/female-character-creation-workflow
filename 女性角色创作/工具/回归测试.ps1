$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$packageRoot = Split-Path $PSScriptRoot -Parent
$sampler = Join-Path $PSScriptRoot '抽样.ps1'
$checker = Join-Path $PSScriptRoot '检查输出.ps1'
$groupChecker = Join-Path $PSScriptRoot '检查关系网.ps1'
$boundaryChecker = Join-Path $PSScriptRoot '检查仓库边界.ps1'
$shell = (Get-Process -Id $PID).Path
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('dsh-regression-' + [guid]::NewGuid().ToString('N'))
$testCount = 0

function Write-TestFile([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Invoke-Check([string]$Script, [string[]]$Arguments, [bool]$ShouldPass, [string]$ErrorText = '') {
    $raw = & $shell -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $result = $raw | ConvertFrom-Json
    Assert ($result.通过 -eq $ShouldPass) "检查结果不符：$raw"
    $expectedCode = if ($ShouldPass) { 0 } else { 1 }
    Assert ($code -eq $expectedCode) "检查退出码不符：$code"
    if ($ErrorText) { Assert (($result.错误 -join '；') -match [regex]::Escape($ErrorText)) "未报告预期错误：$ErrorText；$raw" }
    $script:testCount++
    return $result
}

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    # 所有数据来自空白模板和最小测试字段；不读取作者的输出目录。
    $sample = (& $sampler -Mode sample -Count 3 -Seed 'constrained-portrait' -AgeMin 24 -AgeMax 29 -HeightBand '标准' -BodyType '匀称' -Background '中国背景' -RecentDirectory $testRoot | ConvertFrom-Json).候选
    Assert ($sample.Count -eq 3) '候选数量不符'
    foreach ($candidate in $sample) {
        Assert ($candidate.年龄 -ge 24 -and $candidate.年龄 -le 29) '年龄约束未生效'
        Assert ($candidate.身高 -ge 159 -and $candidate.身高 -le 168) '身高档约束未生效'
        Assert ($candidate.体型 -eq '匀称' -and $candidate.文化背景 -eq '中国背景') '人物约束未生效'
    }
    $measure = & $sampler -Mode measure -Seed 'constrained-measure' -Height 166 -BodyType '匀称' -BustLevel '偏大' -HipLevel '明显' | ConvertFrom-Json
    Assert ($measure.罩杯 -eq 'E' -and $measure.胸围 -eq ($measure.下胸围 + 20)) '量体胸围不一致'
    Assert ([math]::Abs($measure.臀围 / $measure.腰围 - $measure.臀腰比) -lt 0.02) '量体臀腰比不一致'
    $testCount += 2

    $personDir = Join-Path $testRoot 'person'
    $wardrobeDir = Join-Path $testRoot 'wardrobe'
    New-Item -ItemType Directory -Path $personDir,$wardrobeDir | Out-Null
    $personPath = Join-Path $personDir '000-测试人物.md'
    $wardrobePath = Join-Path $wardrobeDir '000-测试人物.md'
    $person = Get-Content -LiteralPath (Join-Path $packageRoot '人物模板.md') -Encoding UTF8 -Raw
    $fields = [ordered]@{
        '编号'='000'; '姓名'='测试人物'; '年龄'='24 岁'; '种族／文化背景'='测试占位'
        '头发颜色与样式'='黑色齐肩直发'; '面部轮廓'='测试占位'; '眉眼细节'='测试占位'; '眼睛颜色'='棕色'
        '鼻与唇'='测试占位'; '皮肤色调'='测试占位'; '独特标志'='测试占位'; '身高'='166 厘米'; '体型'='匀称'
        '肩颈与体态'='测试占位'; '胸部大小与形状'='测试占位'; '臀腰比例'='测试占位'; '四肢与比例'='测试占位'
        '三围'='胸围 89 厘米；下胸围 74 厘米；C 罩杯；腰围 70 厘米；臀围 100 厘米；臀腰比 1.43；体重 58 千克'
    }
    foreach ($key in $fields.Keys) {
        $person = [regex]::Replace($person, "(?m)^- $([regex]::Escape($key))：[ \t]*\r?$", "- ${key}：$($fields[$key])")
    }
    $person = [regex]::Replace($person, '(?ms)(^## 人物速写\s*\r?\n).*?(?=^## )', '${1}此处是验证连贯正文格式的测试占位文本。' + "`n`n")
    $behavior = '这段文字只用于检查行为画像的结构，前后使用连续的中文句子。如果输入缺少条件反差，检查器应报告对应问题；测试数据不会作为人物设定交付。'
    $person = [regex]::Replace($person, '(?ms)(^## 行为画像\s*\r?\n).*?(?=^## )', '${1}' + $behavior + "`n`n")
    $wardrobe = (Get-Content -LiteralPath (Join-Path $packageRoot '搭配模板.md') -Encoding UTF8 -Raw) -split '(?m)^## 居家休闲',2 | Select-Object -First 1
    $wardrobe = $wardrobe.Replace('## 上班／学习','## 测试场景').Replace('### 方案 1｜具体场合或着装要求','### 方案 1｜冬季户外').Replace('### 方案 2｜具体场合或着装要求','### 方案 2｜夏季日常')
    $parts = [ordered]@{ '编号'='000'; '人物'='测试人物'; '整体效果'='清楚呈现整体轮廓。'; '内衣'='棉质文胸与内裤'; '发型'='自然梳理'; '衣服'='棉质上衣与长裤'; '鞋袜'='平底鞋与棉袜'; '配饰'='手表' }
    foreach ($key in $parts.Keys) { $wardrobe = [regex]::Replace($wardrobe, "(?m)^- ${key}：[^\r\n]*", "- ${key}：$($parts[$key])") }
    $wardrobe = [regex]::new('(?m)^- 衣服：[^\r\n]*').Replace($wardrobe,'- 衣服：羊毛大衣、棉质上衣与长裤',1)
    Write-TestFile $personPath $person
    Write-TestFile $wardrobePath $wardrobe
    $arguments = @('-PersonPath',$personPath,'-WardrobePath',$wardrobePath,'-RequireDetailedProfile','-ExpectedScenes','测试场景')
    $null = Invoke-Check $checker $arguments $true
    Write-TestFile $wardrobePath ($wardrobe -replace '\r?\n', "`r`n")
    $null = Invoke-Check $checker $arguments $true
    Write-TestFile $wardrobePath $wardrobe

    foreach ($age in @('未设定','17 岁','24.5 岁','-20 岁')) {
        Write-TestFile $personPath ([regex]::Replace($person,'(?m)^- 年龄：[^\r\n]*',"- 年龄：$age"))
        $null = Invoke-Check $checker $arguments $false '年龄'
    }
    Write-TestFile $personPath ($person.Replace('体重 58 千克','体重 45 千克'))
    $result = Invoke-Check $checker $arguments $true
    Assert (@($result.提示).Count -eq 1) '作者给定体重超出抽样参考区间时须提示，不能拒绝'
    foreach ($case in @(
        @{ Text=$person.Replace('体重 58 千克','体重 0 千克'); Error='身高和体重必须大于零' },
        @{ Text=$person.Replace('胸围 89 厘米','胸围 90 厘米'); Error='胸围、下胸围与罩杯不一致' },
        @{ Text=$person.Replace('臀腰比 1.43','臀腰比 1.80'); Error='臀腰比与腰围、臀围不一致' },
        @{ Text=([regex]::Replace($person,'(?ms)(^## 人物速写\s*\r?\n).*?(?=^## )','${1}- 只有条目。' + "`n`n")); Error='人物速写须为连贯正文' },
        @{ Text=$person.Replace($behavior,'- 只有条目。'); Error='行为画像须为不少于45字的连贯正文' }
    )) {
        Write-TestFile $personPath $case.Text
        $null = Invoke-Check $checker $arguments $false $case.Error
    }
    Write-TestFile $personPath $person
    Write-TestFile $wardrobePath ($wardrobe.Replace('- 人物：测试人物','- 人物：另一人物'))
    $null = Invoke-Check $checker $arguments $false '人物与搭配的姓名字段不一致'
    Write-TestFile $wardrobePath ($wardrobe.Replace('羊毛大衣、',''))
    $result = Invoke-Check $checker $arguments $false '寒冷户外缺少保暖外层'
    Assert (@($result.错误).Count -eq 1) '冬季方案的条件不能影响同场景的夏季方案'
    Write-TestFile $wardrobePath ($wardrobe.Replace('## 测试场景',"## 测试场景`n`n共同条件：冬季户外。").Replace('夏季日常','户外日常'))
    $null = Invoke-Check $checker $arguments $false '寒冷户外缺少保暖外层'

    $groupPerson = Join-Path $testRoot '人物.md'
    $groupWardrobe = Join-Path $testRoot '搭配.md'
    $groupText = "# 测试关系网`n`n## 1. 测试人物`n`n- 年龄：24 岁`n- 身份：测试占位`n- 体型：身高 166 cm；体重 58 kg；胸围 89 cm；下胸围 74 cm；罩杯 C；腰围 70 cm；臀围 100 cm；臀腰比 1.43`n- 外貌：黑色短发`n- 性格：测试占位`n- 关系：未设定`n- 日常钩子：测试占位`n"
    $groupLook = "# 测试简表`n`n## 测试人物`n`n- 日常外出：短发梳顺，衬衫、长裤，平底鞋，棉袜，手表。`n"
    Write-TestFile $groupPerson $groupText
    Write-TestFile $groupWardrobe $groupLook
    $groupArguments = @('-PersonPath',$groupPerson,'-WardrobePath',$groupWardrobe)
    $null = Invoke-Check $groupChecker $groupArguments $true
    foreach ($case in @(
        @{ Person=$groupText.Replace('24 岁','未设定'); Look=$groupLook; Error='年龄必须为明确的整数' },
        @{ Person=$groupText.Replace('胸围 89 cm','胸围 90 cm'); Look=$groupLook; Error='胸围、下胸围与罩杯不一致' },
        @{ Person=$groupText; Look=$groupLook.Replace('、长裤',''); Error='缺少下装或连身装' },
        @{ Person=$groupText; Look=$groupLook.Replace('短发梳顺','高马尾'); Error='发型超出人物发长' },
        @{ Person=$groupText; Look=$groupLook.Replace('## 测试人物','## 未知人物'); Error='搭配引用未知人物' }
    )) {
        Write-TestFile $groupPerson $case.Person
        Write-TestFile $groupWardrobe $case.Look
        $null = Invoke-Check $groupChecker $groupArguments $false $case.Error
    }

    $localChecker = Join-Path $PSScriptRoot '检查本地输出.ps1'
    $localRoot = Join-Path $testRoot 'local-output'
    $localPeople = Join-Path $localRoot '人物'
    $localWardrobes = Join-Path $localRoot '搭配'
    $null = Invoke-Check $localChecker @('-OutputRoot',$localRoot) $true
    New-Item -ItemType Directory -Path $localPeople,$localWardrobes | Out-Null
    Write-TestFile (Join-Path $localPeople '000-测试人物.md') $person
    $null = Invoke-Check $localChecker @('-OutputRoot',$localRoot) $false '缺少搭配'
    Write-TestFile (Join-Path $localWardrobes '000-测试人物.md') $wardrobe
    $null = Invoke-Check $localChecker @('-OutputRoot',$localRoot) $true
    Write-TestFile (Join-Path $localPeople '000-重复编号.md') $person
    $null = Invoke-Check $localChecker @('-OutputRoot',$localRoot) $false '编号重复'

    # 用临时索引验证强制添加生成文件也会被仓库边界检查发现。
    $repo = Join-Path $testRoot 'repository'
    New-Item -ItemType Directory -Path $repo | Out-Null
    & git init --quiet $repo
    Assert ($LASTEXITCODE -eq 0) '临时 Git 仓库初始化失败'
    Write-TestFile (Join-Path $repo 'README.md') '# 生成方法'
    & git -C $repo add README.md
    Assert ($LASTEXITCODE -eq 0) '临时索引写入失败'
    $null = Invoke-Check $boundaryChecker @('-RepositoryRoot',$repo) $true
    $outputDir = Join-Path $repo '输出'
    New-Item -ItemType Directory -Path $outputDir | Out-Null
    Write-TestFile (Join-Path $outputDir '测试.txt') '测试占位'
    & git -C $repo add --force -- 输出
    Assert ($LASTEXITCODE -eq 0) '临时生成文件索引写入失败'
    $result = Invoke-Check $boundaryChecker @('-RepositoryRoot',$repo) $false
    Assert (@($result.不允许提交的路径).Count -eq 1) '仓库边界未发现生成文件'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path $resolved -Leaf) -notlike 'dsh-regression-*') { throw '临时目录清理路径不正确' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    $global:LASTEXITCODE = 0
}
[ordered]@{ '通过' = $true; '检查项数' = $testCount; '测试数据' = '仅临时目录'; '依赖本地输出' = $false } | ConvertTo-Json -Compress
