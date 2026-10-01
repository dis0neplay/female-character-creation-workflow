param([string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$tracked = & git -C $RepositoryRoot -c core.quotePath=false ls-files -z
if ($LASTEXITCODE -ne 0) { throw '无法读取 Git 索引' }
$paths = @(($tracked -join "`n") -split "`0" | Where-Object { $_ })
$allowed = @(
    '^(?:\.gitattributes|\.gitignore|AGENTS\.md|README\.md|CONTRIBUTING\.md|LICENSE)$',
    '^\.github/workflows/[^/]+\.ya?ml$',
    '^docs/(?:agents|adr)/.+\.md$',
    '^女性角色创作/(?:AGENTS|README|人物规则|搭配规则|选项菜单|人物模板|搭配模板|关系网模板)\.md$',
    '^女性角色创作/工具/[^/]+\.ps1$'
)
$unexpected = @($paths | Where-Object { $_ -notmatch ($allowed -join '|') })
[ordered]@{ '通过' = ($unexpected.Count -eq 0); '不允许提交的路径' = $unexpected } | ConvertTo-Json -Compress
if ($unexpected.Count) { exit 1 }
