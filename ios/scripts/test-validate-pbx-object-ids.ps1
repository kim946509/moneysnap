$ErrorActionPreference = 'Stop'

$probe = Join-Path $PSScriptRoot 'validate-pbx-object-ids.ps1'
if (-not (Test-Path -LiteralPath $probe)) {
    throw 'PBX object ID validation probe is missing.'
}
. $probe

$valid = @'
objects = {
    B00000000000000000000001 /* File.swift in Sources */ = {isa = PBXBuildFile; fileRef = F00000000000000000000001; };
    F00000000000000000000001 /* File.swift */ = {isa = PBXFileReference; path = File.swift; };
    A00000000000000000000001 = {
        isa = PBXGroup;
    };
};
'@
Assert-PbxObjectIdentifiers -Project $valid

$duplicate = @'
objects = {
    B00000000000000000000001 /* One */ = {isa = PBXBuildFile; };
    B00000000000000000000001 /* Two */ = {
        isa = PBXFileReference;
    };
};
'@
try {
    Assert-PbxObjectIdentifiers -Project $duplicate
    throw 'Duplicate single-line PBX object definitions were not rejected.'
} catch {
    if ($_.Exception.Message -eq 'Duplicate single-line PBX object definitions were not rejected.') { throw }
}

foreach ($invalid in @(
    'G00000000000000000000001 /* non-hex */ = {isa = PBXGroup; };',
    'A000000000000000001 /* 19 chars */ = {isa = PBXGroup; };',
    'A0000000000000000000001 /* 23 chars */ = {isa = PBXGroup; };',
    'A000000000000000000000001 /* 25 chars */ = {isa = PBXGroup; };',
    'A0000000000000000000000-1 /* hyphen */ = {isa = PBXGroup; };',
    'A0000000000000000000000_1 /* underscore */ = {isa = PBXGroup; };',
    'A0000000000000000000000$1 /* symbol */ = {isa = PBXGroup; };'
)) {
    try {
        Assert-PbxObjectIdentifiers -Project "objects = {`n$invalid`n};"
        throw "Invalid PBX object identifier was not rejected: $invalid"
    } catch {
        if ($_.Exception.Message -like 'Invalid PBX object identifier was not rejected:*') { throw }
    }
}

Write-Output 'PBX object ID validation regression probe: OK'
