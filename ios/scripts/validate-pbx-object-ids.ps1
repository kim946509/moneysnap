function Assert-PbxObjectIdentifiers {
    param(
        [Parameter(Mandatory)]
        [string]$Project
    )

    $definitionTokens = [regex]::Matches(
        $Project,
        '(?m)^\s*(?<id>[^\s/]+)(?: /\*.*?\*/)?\s*=\s*\{\s*isa\s*='
    ) | ForEach-Object { $_.Groups['id'].Value }

    $invalid = @($definitionTokens | Where-Object { $_ -notmatch '^[A-Fa-f0-9]{24}$' } | Select-Object -Unique)
    if ($invalid) {
        throw "Invalid PBX object identifiers: $($invalid -join ', ')"
    }

    $duplicates = @(
        $definitionTokens |
            Group-Object |
            Where-Object { $_.Count -gt 1 } |
            ForEach-Object { $_.Name }
    )
    if ($duplicates) {
        throw "Duplicate PBX object definitions: $($duplicates -join ', ')"
    }
}
