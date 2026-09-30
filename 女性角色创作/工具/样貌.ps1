param(
    [string]$Seed = '',
    [int]$Count = 3
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

[ordered]@{
    '种子' = $seedNumber
    '发色' = Pick @('黑色','深棕色','栗色','红棕色','浅棕色','金色','银灰色')
    '发型' = Pick @('耳下短发','齐颌直发','齐肩微卷','锁骨发','低马尾','高马尾','松散长卷发','单侧编发','盘发')
    '瞳色' = Pick @('深褐色','灰褐色','琥珀色','浅棕色','灰色','绿色','蓝色')
    '面部' = Pick @('圆脸、平直眉','鹅蛋脸、弧形眉','长脸、清晰下颌线','方圆脸、宽颧骨','心形脸、窄下巴','椭圆脸、直鼻梁')
    '肤色' = Pick @('暖调浅色','冷调浅色','中性浅麦色','暖调小麦色','深棕色','中性棕色')
    '标志' = Pick @('左眉尾浅疤','右眼下小痣','鼻梁细雀斑','左颊酒窝','右耳后胎记','手背浅色疤痕','眉峰缺口','锁骨附近小痣')
} | ConvertTo-Json -Compress -Depth 3
