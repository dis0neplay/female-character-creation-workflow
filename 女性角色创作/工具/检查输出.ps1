param(
    [Parameter(Mandatory)][string]$PersonPath,
    [Parameter(Mandatory)][string]$WardrobePath,
    [switch]$RequireDetailedProfile,
    [string]$ExpectedScenes = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $PersonPath -PathType Leaf)) { $errors.Add('人物文件不存在') }
if (-not (Test-Path -LiteralPath $WardrobePath -PathType Leaf)) { $errors.Add('搭配文件不存在') }
if ($errors.Count) { @{ '通过' = $false; '错误' = $errors } | ConvertTo-Json -Compress; exit 1 }

$person = Get-Content -LiteralPath $PersonPath -Encoding UTF8 -Raw
$wardrobe = Get-Content -LiteralPath $WardrobePath -Encoding UTF8 -Raw
if ([IO.Path]::GetFileName($PersonPath) -ne [IO.Path]::GetFileName($WardrobePath)) { $errors.Add('两个文件的编号与姓名不一致') }
$number = [regex]::Match($person, '(?m)^- 编号：[ \t]*([^\r\n]+)').Groups[1].Value.Trim()
$name = [regex]::Match($person, '(?m)^- 姓名：[ \t]*([^\r\n]+)').Groups[1].Value.Trim()
$wardrobeNumber = [regex]::Match($wardrobe, '(?m)^- 编号：[ \t]*([^\r\n]+)').Groups[1].Value.Trim()
$wardrobeName = [regex]::Match($wardrobe, '(?m)^- 人物：[ \t]*([^\r\n]+)').Groups[1].Value.Trim()
if ($number -notmatch '^\d{3,}$' -or $number -ne $wardrobeNumber) { $errors.Add('人物与搭配的编号字段无效或不一致') }
if (-not $name -or $name -ne $wardrobeName) { $errors.Add('人物与搭配的姓名字段不一致') }
if ([IO.Path]::GetFileNameWithoutExtension($PersonPath) -ne "${number}-${name}") { $errors.Add('文件名与编号、姓名字段不一致') }
$hairLine = [regex]::Match($person, '(?m)^- 头发颜色与样式：(.+)$').Groups[1].Value
$shortHair = $hairLine -match '耳上短发|齐耳|齐颌|耳下短发|下巴短发|耳下'

$fields = @('编号','姓名','年龄','种族／文化背景','身高','体型','头发颜色与样式','眼睛颜色','胸部大小与形状','臀腰比例','三围','皮肤色调','独特标志')
foreach ($field in $fields) {
    if ($person -notmatch "(?m)^- $([regex]::Escape($field))：\s*\S") { $errors.Add("人物缺少：$field") }
}
if ($RequireDetailedProfile) {
    foreach ($section in @('基本信息','人物速写','行为画像','面貌','身材')) {
        if ($person -notmatch "(?m)^## $section\s*$") { $errors.Add("人物缺少分区：$section") }
    }
    $portraitMatch = [regex]::Match($person, '(?ms)^## 人物速写\s*\r?\n(.*?)(?=^## |\z)')
    $portraitText = if ($portraitMatch.Success) { $portraitMatch.Groups[1].Value.Trim() } else { '' }
    if ($portraitText -notmatch '[\p{IsCJKUnifiedIdeographs}]' -or $portraitText -match '(?m)^- ') {
        $errors.Add('人物速写须为连贯正文')
    }
    $behaviorMatch = [regex]::Match($person, '(?ms)^## 行为画像\s*\r?\n(.*?)(?=^## |\z)')
    $behaviorText = if ($behaviorMatch.Success) { $behaviorMatch.Groups[1].Value.Trim() } else { '' }
    if ($behaviorText.Length -lt 45 -or $behaviorText -notmatch '[\p{IsCJKUnifiedIdeographs}]' -or $behaviorText -match '(?m)^- ') {
        $errors.Add('行为画像须为不少于45字的连贯正文')
    }
    if ($behaviorText -notmatch '若|如果|一旦|倘若|只是|但|只是') {
        $errors.Add('行为画像须包含有条件的反差')
    }
    foreach ($field in @('面部轮廓','眉眼细节','鼻与唇','肩颈与体态','四肢与比例')) {
        if ($person -notmatch "(?m)^- $field：\s*\S") { $errors.Add("人物缺少：$field") }
    }
} elseif ($person -notmatch '(?m)^- 面部特征：\s*\S' -and $person -notmatch '(?m)^- 面部轮廓：\s*\S') {
    $errors.Add('人物缺少：面部特征或面部轮廓')
}
if ($person -match '当前穿着|换装记录|(?m)^## .*搭配|(?m)^- (内衣|发型|衣服|鞋袜|配饰)：') { $errors.Add('人物文件含穿搭内容') }
if ($person -match '<!--|(?m)^## 校验记录') { $errors.Add('人物文件含注释或校验日志') }
if ($wardrobe -match '<!--|(?m)^## 校验记录') { $errors.Add('搭配文件含注释或校验日志') }

$sceneMatches = [regex]::Matches($wardrobe, '(?m)^## ([^\r\n]+)\r?$')
$sceneTitles = @($sceneMatches | ForEach-Object { $_.Groups[1].Value.Trim() })
if ($ExpectedScenes) {
    $confirmedScenes = @($ExpectedScenes -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($confirmedScenes.Count -eq 0) { $errors.Add('未提供有效的已确认场景') }
    if ($sceneTitles.Count -ne $confirmedScenes.Count) { $errors.Add('搭配场景数量与确认清单不一致') }
    for ($i = 0; $i -lt [math]::Min($sceneTitles.Count, $confirmedScenes.Count); $i++) {
        if ($sceneTitles[$i] -ne $confirmedScenes[$i]) { $errors.Add("场景 $($i + 1) 与确认清单不一致：应为 $($confirmedScenes[$i])") }
    }
} elseif ($sceneMatches.Count -lt 5) {
    $errors.Add('搭配文件少于五个场景')
}
if (@($sceneTitles | Select-Object -Unique).Count -ne $sceneTitles.Count) { $errors.Add('搭配场景标题重复') }
for ($i = 0; $i -lt $sceneMatches.Count; $i++) {
    $start = $sceneMatches[$i].Index + $sceneMatches[$i].Length
    $end = if ($i + 1 -lt $sceneMatches.Count) { $sceneMatches[$i + 1].Index } else { $wardrobe.Length }
    $section = $wardrobe.Substring($start, $end - $start)
    $outfits = [regex]::Matches($section, '(?m)^### 方案 \d+[^\r\n]*\r?$')
    $sharedContext = if ($outfits.Count) { $section.Substring(0, $outfits[0].Index) } else { '' }
    if ($outfits.Count -lt 2) { $errors.Add("$($sceneTitles[$i]) 少于两套") }
    for ($j = 0; $j -lt $outfits.Count; $j++) {
        $from = $outfits[$j].Index + $outfits[$j].Length
        $to = if ($j + 1 -lt $outfits.Count) { $outfits[$j + 1].Index } else { $section.Length }
        $outfit = $section.Substring($from, $to - $from)
        if ($RequireDetailedProfile -and $outfit -notmatch '(?m)^- 整体效果：\s*\S') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 缺少：整体效果")
        }
        foreach ($part in @('内衣','发型','衣服','鞋袜','配饰')) {
            if ($outfit -notmatch "(?m)^- $part：\s*\S") { $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 缺少：$part") }
            if ($RequireDetailedProfile) {
                $partLine = [regex]::Match($outfit, "(?m)^- $part：(.+)$").Groups[1].Value
                if ($partLine -match '或|任选|二选一') { $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) $part 留有未决选项") }
            }
        }
        $underwearLine = [regex]::Match($outfit, '(?m)^- 内衣：(.+)$').Groups[1].Value
        $overallLine = [regex]::Match($outfit, '(?m)^- 整体效果：(.+)$').Groups[1].Value
        $hairStyleLine = [regex]::Match($outfit, '(?m)^- 发型：(.+)$').Groups[1].Value
        $clothesLine = [regex]::Match($outfit, '(?m)^- 衣服：(.+)$').Groups[1].Value
        $shoesLine = [regex]::Match($outfit, '(?m)^- 鞋袜：(.+)$').Groups[1].Value
        if ($RequireDetailedProfile -and $underwearLine -notmatch '内裤|平角裤|三角裤|丁字裤|泳装|泳衣|比基尼') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 内衣缺少下装或泳装说明")
        }
        if ($RequireDetailedProfile -and $overallLine -match '露(?:出)?[^，。；]{0,8}腿|腿(?:部)?[^，。；]{0,4}(?:外露|露出|裸露|露肤)|腿部可见' -and
            $shoesLine -match '不透肉|加厚丝袜|厚丝袜|厚连裤袜') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 不透肉袜与腿部露肤描述冲突")
        }
        if ($RequireDetailedProfile -and $overallLine -match '露出[^，。；]{0,8}腰(?:部|线)?|露(?:侧)?腰|腰(?:部|线|侧)[^，。；]{0,4}(?:外露|露出|裸露|露肤)' -and
            $clothesLine -match '连衣裙|连身裙' -and $clothesLine -notmatch '露腰|露脐|腰.*开口|腰.*镂空') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 连衣裙未露腰却描述腰部露肤")
        }
        if ($RequireDetailedProfile -and $overallLine -match '锁骨[^，。；]{0,8}(?:露|可见)|(?:露|外露)[^，。；]{0,8}锁骨' -and
            $clothesLine -match '立领|高领' -and $clothesLine -notmatch '解开|敞开|开领|低开口') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 立领或高领与锁骨露肤描述冲突")
        }
        if ($underwearLine -match '无钢圈' -and $underwearLine -match '软钢圈|有钢圈|(?<!无)钢圈文胸|(?<!无)钢圈罩杯') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 内衣同时写无钢圈和钢圈")
        }
        if ($shortHair -and $hairStyleLine -match '马尾|发髻|盘发|丸子头' -and $hairStyleLine -notmatch '假发|接发') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 发型超出人物发长")
        }
        $coldContext = "$($sceneTitles[$i]) $sharedContext $($outfits[$j].Value) $outfit"
        if (($coldContext -match '零下|寒冷|冰雪|大雪|严寒|低温|冬季|室外\s*[−-]\s*[0-9]{1,2}|[−-][0-9]{1,2}\s*[至到~～-]\s*[−-]?[0-9]{1,2}\s*°?C?') -and
            $clothesLine -notmatch '大衣|羽绒|棉服|风衣|厚外套|冲锋衣|派克|呢外套|皮草|保暖外套') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 寒冷户外缺少保暖外层")
        }
        if ($outfit -match '快干|速干' -and $outfit -match '亚麻|棉麻|纯棉|棉质' -and $outfit -match '涉水|下水|浮潜|游泳|湿后') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 把吸水面料写成涉水快干")
        }
        if ($outfit -match '沙滩|沙地|礁石|湿滑' -and $shoesLine -match '细跟|高跟|尖头') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 湿滑或沙地不适合细跟鞋")
        }
        if ($outfit -match '门店配发|单位规定|公司制服|学校制服|按规定穿着' -and $outfit -notmatch '建议方案|按现场要求调整') {
            $errors.Add("$($sceneTitles[$i]) 方案 $($j + 1) 把未确认的制服写成既定规定")
        }
    }
}

$ageMatch = [regex]::Match($person, '(?m)^- 年龄：[ \t]*(\d{1,3})[ \t]*(?:岁)?[ \t]*\r?$')
if (-not $ageMatch.Success) { $errors.Add('人物年龄必须为明确的整数') }
elseif ([int]$ageMatch.Groups[1].Value -lt 18) { $errors.Add('人物年龄低于 18 岁') }
$measureMatch = [regex]::Match($person, '(?m)^- 三围：(.+)$')
if ($RequireDetailedProfile -and $measureMatch.Success -and $measureMatch.Groups[1].Value -notmatch '待定') {
    $measureLine = $measureMatch.Groups[1].Value
    foreach ($item in @(
        @('胸围','(?<!下)胸围\s*[\d.]+'),
        @('下胸围','下胸围\s*[\d.]+'),
        @('罩杯','(?:AA|A|B|C|D|E|F|G|H)\s*罩杯'),
        @('腰围','腰围\s*[\d.]+'),
        @('臀围','臀围\s*[\d.]+'),
        @('臀腰比','臀腰比\s*[\d.]+'),
        @('体重','体重约?\s*[\d.]+')
    )) {
        if ($measureLine -notmatch $item[1]) { $errors.Add("三围缺少：$($item[0])") }
    }
}
if ($measureMatch.Success -and $measureMatch.Groups[1].Value -notmatch '待定') {
    $line = $measureMatch.Groups[1].Value
    $underMatch = [regex]::Match($line, '下胸围\s*([\d.]+)')
    $bustMatch = [regex]::Match($line, '(?<!下)胸围\s*([\d.]+)')
    $cupMatch = [regex]::Match($line, '(AA|A|B|C|D|E|F|G|H)\s*罩杯')
    if ($underMatch.Success -and $bustMatch.Success -and $cupMatch.Success) {
        $diff = @{ 'AA' = 7.5; 'A' = 10.0; 'B' = 12.5; 'C' = 15.0; 'D' = 17.5; 'E' = 20.0; 'F' = 22.5; 'G' = 25.0; 'H' = 27.5 }[$cupMatch.Groups[1].Value]
        $under = [double]::Parse($underMatch.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        $bust = [double]::Parse($bustMatch.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        if ([math]::Abs($under + $diff - $bust) -gt 0.1) { $errors.Add('胸围、下胸围与罩杯不一致') }
    }
    $waistMatch = [regex]::Match($line, '腰围\s*([\d.]+)')
    $hipMatch = [regex]::Match($line, '臀围\s*([\d.]+)')
    $ratioMatch = [regex]::Match($person, '臀腰比\s*([\d.]+)')
    if ($waistMatch.Success -and $hipMatch.Success -and $ratioMatch.Success) {
        $waist = [double]::Parse($waistMatch.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        $hip = [double]::Parse($hipMatch.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        $ratio = [double]::Parse($ratioMatch.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        if ($waist -le 0 -or [math]::Abs($hip / $waist - $ratio) -gt 0.02) { $errors.Add('臀腰比与腰围、臀围不一致') }
    }
    $weightMatch = [regex]::Match($line, '体重约?\s*([\d.]+)')
    $heightMatch = [regex]::Match($person, '(?m)^- 身高：\s*([\d.]+)')
    $bodyMatch = [regex]::Match($person, '(?m)^- 体型：\s*(纤瘦|匀称|丰腴)')
    if ($weightMatch.Success -and $heightMatch.Success -and $bodyMatch.Success) {
        $weight = [double]::Parse($weightMatch.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        $height = [double]::Parse($heightMatch.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) / 100
        if ($height -le 0 -or $weight -le 0) { $errors.Add('身高和体重必须大于零') }
        else {
            $bmi = $weight / ($height * $height)
            $bmiRanges = @{ '纤瘦' = @(20.0,21.6); '匀称' = @(20.2,22.2); '丰腴' = @(20.6,23.4) }
            $range = $bmiRanges[$bodyMatch.Groups[1].Value]
            if ($bmi -lt $range[0] - 0.1 -or $bmi -gt $range[1] + 0.1) { $warnings.Add('体重超出抽样参考区间；核对作者设定，不自动改写') }
        }
    }
}

@{ '通过' = ($errors.Count -eq 0); '错误' = @($errors); '提示' = @($warnings) } | ConvertTo-Json -Compress -Depth 3
if ($errors.Count) { exit 1 }
