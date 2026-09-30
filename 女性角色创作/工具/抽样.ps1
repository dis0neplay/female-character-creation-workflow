param(
    [ValidateSet('sample', 'measure')][string]$Mode = 'sample',
    [int]$Count = 3,
    [string]$Seed = '',
    [int]$AgeMin = 18,
    [int]$AgeMax = 55,
    [string]$HeightBand = '',
    [string]$BodyType = '',
    [string]$Background = '',
    [string]$Temperament = '',
    [int]$Height = 0,
    [string]$BustLevel = '',
    [string]$HipLevel = '',
    [string]$Cup = '',
    [string]$RecentDirectory = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ($Seed) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Seed))
    $seedNumber = [System.BitConverter]::ToInt32($hash, 0)
} else {
    $seedBytes = [byte[]]::new(4)
    $rngObj = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rngObj.GetBytes($seedBytes)
    $seedNumber = [System.BitConverter]::ToInt32($seedBytes, 0)
}
$rng = [System.Random]::new($seedNumber)

function Pick([object[]]$Values) { return $Values[$rng.Next($Values.Count)] }

if ($Mode -eq 'measure') {
    if (-not $BustLevel) { $BustLevel = '中等' }
    if (-not $HipLevel) { $HipLevel = '常规' }
    if ($Height -lt 147 -or $Height -gt 181) { throw '量体模型只覆盖 147–181 厘米；保留作者数值，具体三围待定。' }
    if ($BodyType -notin @('纤瘦', '匀称', '丰腴')) { throw 'BodyType 必须是纤瘦、匀称或丰腴。' }
    if ($BustLevel -notin @('偏小', '中等', '偏大')) { throw 'BustLevel 必须是偏小、中等或偏大。' }
    if ($HipLevel -notin @('平缓', '常规', '明显')) { throw 'HipLevel 必须是平缓、常规或明显。' }

    $base = if ($Height -le 158) { 70 } elseif ($Height -le 168) { 74 } else { 80 }
    $adj = @{ '纤瘦' = -2; '匀称' = 0; '丰腴' = 4 }[$BodyType]
    $under = $base + $adj
    $cupPools = @{
        '纤瘦' = @{ '偏小' = @('AA','A'); '中等' = @('B'); '偏大' = @('C') }
        '匀称' = @{ '偏小' = @('B'); '中等' = @('C','D'); '偏大' = @('E') }
        '丰腴' = @{ '偏小' = @('D','E'); '中等' = @('F'); '偏大' = @('G','H') }
    }
    $allowed = $cupPools[$BodyType][$BustLevel]
    if ($Cup) {
        if ($Cup -notin $allowed) { throw "罩杯 $Cup 与体型 $BodyType、胸部档 $BustLevel 不相容。" }
        $selectedCup = $Cup
    } else { $selectedCup = Pick $allowed }
    $cupDiff = @{ 'AA' = 7.5; 'A' = 10.0; 'B' = 12.5; 'C' = 15.0; 'D' = 17.5; 'E' = 20.0; 'F' = 22.5; 'G' = 25.0; 'H' = 27.5 }[$selectedCup]
    $bust = $under + $cupDiff
    $waistFactor = @{ '纤瘦' = 0.390; '匀称' = 0.420; '丰腴' = 0.450 }[$BodyType]
    $waist = [int][math]::Round($Height * $waistFactor, 0, [MidpointRounding]::AwayFromZero)
    $ratioRanges = @{
        '纤瘦' = @{ '平缓' = @(1.38,1.393); '常规' = @(1.394,1.406); '明显' = @(1.407,1.42) }
        '匀称' = @{ '平缓' = @(1.41,1.423); '常规' = @(1.424,1.436); '明显' = @(1.437,1.45) }
        '丰腴' = @{ '平缓' = @(1.45,1.463); '常规' = @(1.464,1.476); '明显' = @(1.477,1.49) }
    }
    $range = $ratioRanges[$BodyType][$HipLevel]
    $ratio = $range[0] + $rng.NextDouble() * ($range[1] - $range[0])
    $hip = [int][math]::Round($waist * $ratio, 0, [MidpointRounding]::AwayFromZero)
    $bmiRanges = @{ '纤瘦' = @(20.0,21.6); '匀称' = @(20.2,22.2); '丰腴' = @(20.6,23.4) }
    $bmiRange = $bmiRanges[$BodyType]
    $bmi = $bmiRange[0] + $rng.NextDouble() * ($bmiRange[1] - $bmiRange[0])
    $weight = [math]::Round($bmi * [math]::Pow($Height / 100, 2), 1)
    [ordered]@{
        '身高' = $Height; '体型' = $BodyType; '胸部档' = $BustLevel; '臀腰档' = $HipLevel
        '下胸围' = $under; '罩杯' = $selectedCup; '胸围' = $bust; '腰围' = $waist
        '臀围' = $hip; '臀腰比' = [math]::Round($hip / $waist, 2)
        '体重' = $weight; 'BMI' = [math]::Round($weight / [math]::Pow($Height / 100, 2), 1)
    } | ConvertTo-Json -Compress -Depth 4
    exit 0
}

if ($Count -lt 1 -or $Count -gt 6) { throw 'Count 必须是 1–6。' }
if ($AgeMin -lt 18 -or $AgeMax -lt $AgeMin -or $AgeMax -gt 100) { throw '年龄范围必须在 18–100 岁内。' }
if ($HeightBand -and $HeightBand -notin @('娇小','标准','高挑')) { throw 'HeightBand 必须是娇小、标准或高挑。' }
if ($BodyType -and $BodyType -notin @('纤瘦','匀称','丰腴')) { throw 'BodyType 必须是纤瘦、匀称或丰腴。' }
if ($Height -and ($Height -lt 147 -or $Height -gt 181)) { throw '精确身高超出抽样模型范围；保留作者数值并单独处理。' }
if ($Height -and $HeightBand) {
    $actualBand = if ($Height -le 158) { '娇小' } elseif ($Height -le 168) { '标准' } else { '高挑' }
    if ($actualBand -ne $HeightBand) { throw '精确身高与身高档冲突，请作者裁定。' }
}
if ($BustLevel -and $BustLevel -notin @('偏小','中等','偏大')) { throw 'BustLevel 必须是偏小、中等或偏大。' }
if ($HipLevel -and $HipLevel -notin @('平缓','常规','明显')) { throw 'HipLevel 必须是平缓、常规或明显。' }

$bands = @{
    '娇小' = @(147,158); '标准' = @(159,168); '高挑' = @(169,181)
}
$backgrounds = @('中国背景','日本背景','韩国背景','南亚背景','欧洲背景','拉美背景','西亚或北非背景','混合背景')
$temperaments = @('娇怯','俏皮','爽朗','慵懒','温婉','沉静','知性','利落','端庄','飒爽','凌厉','野性','清冷','妩媚','明艳')
$hairColors = @('乌黑','柔黑','黑茶色','深棕色','栗棕色','巧克力棕','红棕色','铜棕色','浅棕色','深金色','浅金色','银灰色')
$hairLengths = @('耳上短发','耳下短发','齐颌短发','齐肩发','锁骨发','及胸长发','及背长发')
$hairTextures = @('细软直发','浓密直发','自然微卷','松散波浪卷','浓密卷发')
$eyes = @('深褐色','棕黑色','灰褐色','琥珀色','浅棕色','榛绿色','灰绿色','灰色','蓝色')
$faces = @('圆脸','鹅蛋脸','长脸','方圆脸','心形脸','菱形脸','宽额窄颌脸','窄额宽颌脸')
$jawPools = @{
    '圆脸' = @('柔和圆颌','短圆下巴','下颌线轻微内收')
    '鹅蛋脸' = @('柔和圆颌','下颌线清晰','下巴微尖')
    '长脸' = @('下颌线清晰','窄而平的下巴','下巴微尖')
    '方圆脸' = @('清晰方颌','宽而平的下颌','圆钝下颌角')
    '心形脸' = @('窄尖下巴','下巴微尖','下颌线轻微内收')
    '菱形脸' = @('窄尖下巴','下颌线清晰','下巴微尖')
    '宽额窄颌脸' = @('窄尖下巴','下巴微尖','下颌线轻微内收')
    '窄额宽颌脸' = @('清晰方颌','宽而平的下颌','圆钝下颌角')
}
$brows = @('平直浓眉','细平眉','自然弧眉','高挑眉','短粗眉','眉峰清晰的长眉','眉尾下垂的柔眉')
$eyeShapes = @('圆眼','狭长眼','杏眼','上挑眼','眼尾微垂','椭圆眼','细长单眼皮')
$noses = @('高直鼻梁、窄鼻尖','低直鼻梁、圆鼻尖','鼻梁微弯、窄鼻翼','鼻根浅、鼻头圆钝','鼻梁宽、鼻翼舒展','短鼻梁、微翘鼻尖')
$lips = @('薄唇、清晰唇峰','饱满下唇、平缓嘴角','上下唇均匀、唇峰柔和','宽唇形、嘴角上扬','小唇形、下唇饱满','上唇较薄、唇角微垂')
$skins = @('冷调浅色','暖调浅色','中性浅色','冷调浅麦色','暖调小麦色','橄榄色','中性棕色','暖调棕色','深棕色','冷调深棕色')
$skinDetails = @('鼻梁有淡雀斑','脸颊易泛红','肤面细腻均匀','两颊有浅痘印','鼻翼有细小毛孔','肤面有零星浅斑')
$matureSkinDetails = @('额头有细纹','眼下有淡细纹')
$marks = @('左眉尾浅疤','右眼下小痣','左颊酒窝','右颊酒窝','眉峰缺口','下巴左侧小痣','左耳垂小痣','右手背浅疤','鼻侧小痣','颈侧小痣','无明显独特标志')
$postures = @('肩线平直、站姿端正','窄肩、颈线修长','肩略宽、站姿舒展','圆肩、习惯微微前倾','肩线下斜、站姿松弛','颈短肩圆、重心平稳','肩背挺直、步态轻快')
$limbPools = @{
    '纤瘦' = @('腿长于躯干、手臂修长','躯干略长、四肢纤细','腿部比例均衡、腕踝纤细','小腿修长、手指细长','手臂纤细、大腿线条柔和')
    '匀称' = @('腿长于躯干、手臂修长','躯干略长、四肢匀称','腿部比例均衡、手指细长','小腿修长、肩臂结实','手臂纤细、大腿较有量感')
    '丰腴' = @('上臂丰满、腿部线条圆润','手臂柔软、大腿有量感','躯干略长、四肢圆润','肩臂结实、小腿线条饱满','腿长于躯干、大腿饱满')
}

if (-not $RecentDirectory) { $RecentDirectory = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) '输出\人物' }
$recent = @()
if (Test-Path -LiteralPath $RecentDirectory) {
    $recent = @(Get-ChildItem -LiteralPath $RecentDirectory -Filter '*.md' -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 3 |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Encoding UTF8 -Raw })
}
$recentNames = @($recent | ForEach-Object {
    $match = [regex]::Match($_, '(?m)^- 姓名：\s*(.+)$')
    if ($match.Success) { $match.Groups[1].Value.Trim() }
})

$candidates = @()
for ($attempt = 0; $attempt -lt 300 -and $candidates.Count -lt $Count; $attempt++) {
    $band = if ($HeightBand) { $HeightBand } else { Pick @('娇小','标准','高挑') }
    $heightRange = $bands[$band]
    $face = Pick $faces
    $body = if ($BodyType) { $BodyType } else { Pick @('纤瘦','匀称','丰腴') }
    $age = $rng.Next($AgeMin, $AgeMax + 1)
    $candidate = [ordered]@{
        '年龄' = $age
        '文化背景' = if ($Background) { $Background } else { Pick $backgrounds }
        '身高' = if ($Height) { $Height } else { $rng.Next($heightRange[0], $heightRange[1] + 1) }
        '体型' = $body
        '气质' = if ($Temperament) { $Temperament } else { Pick $temperaments }
        '发色' = Pick $hairColors
        '发型' = "$(Pick $hairLengths)、$(Pick $hairTextures)"
        '瞳色' = Pick $eyes
        '脸型' = $face
        '颌线' = Pick $jawPools[$face]
        '眉形' = Pick $brows
        '眼形' = Pick $eyeShapes
        '鼻形' = Pick $noses
        '唇形' = Pick $lips
        '肤色' = Pick $skins
        '肤质' = Pick $(if ($age -ge 30) { $skinDetails + $matureSkinDetails } else { $skinDetails })
        '标志' = Pick $marks
        '肩颈体态' = Pick $postures
        '四肢比例' = Pick $limbPools[$body]
        '胸部档' = if ($BustLevel) { $BustLevel } else { Pick @('偏小','中等','偏大') }
        '臀腰档' = if ($HipLevel) { $HipLevel } else { Pick @('平缓','常规','明显') }
    }
    $coreKeys = @('发色','发型','瞳色','脸型','肤色')
    $visualKeys = @('发色','发型','瞳色','脸型','颌线','眉形','眼形','肤色','标志')
    $tooSimilar = $false
    foreach ($prior in $candidates) {
        $difference = @($visualKeys | Where-Object { $prior[$_] -ne $candidate[$_] }).Count
        $coreDifference = @($coreKeys | Where-Object { $prior[$_] -ne $candidate[$_] }).Count
        if ($difference -lt 5 -or $coreDifference -lt 3) { $tooSimilar = $true; break }
    }
    if ($tooSimilar) { continue }
    foreach ($card in $recent) {
        $overlap = @($visualKeys | Where-Object { $card.Contains([string]$candidate[$_]) }).Count
        $coreOverlap = @($coreKeys | Where-Object { $card.Contains([string]$candidate[$_]) }).Count
        if ($overlap -ge 5 -and $coreOverlap -ge 3) { $tooSimilar = $true; break }
    }
    if (-not $tooSimilar) { $candidates += ,$candidate }
}
if ($candidates.Count -ne $Count) { throw '无法生成足够多的差异化候选；请减少锁定条件或候选数。' }
[ordered]@{ '种子' = $seedNumber; '近期姓名' = $recentNames; '候选' = $candidates } | ConvertTo-Json -Compress -Depth 5
