﻿# Build the chocolatey package based on the latest module built in ..\.build folder

$buildPath = Resolve-Path $PSScriptRoot/../.build
$version = Get-ChildItem $buildPath | Sort-Object CreationDate -Descending | Select-Object -First 1 -Expand Name
$version = $version.ToString()
if (!$version) { throw "Latest module build can not be found" }
$modulePath = "$buildPath/$version/Wormies-AU-Helpers"

. $modulePath/private/Test-ValidVersion.ps1
if (!(Test-ValidVersion -version $version)) {
    throw "Latest module is not a valid version."
}

$nuspecPath = "$PSScriptRoot/wormies-au-helpers.nuspec"

"`n==| Building Chocolatey package for Wormies-AU-Helpers $version at '$modulePath'`n"

"Setting description"
$readmePath = Resolve-Path "$PSScriptRoot/../README.md"
$readme = Get-Content $readmePath -Raw
$res = $readme -match "## Features(.|\n)+?(?=\n##)"
if (!$res) { throw "Can't find markdown header 'Features' in the README.md" }

$features = $Matches[0]
"Updating nuspec file"
$repo = git remote get-url origin | % { $_ -replace '\.git$' }
$nuspecBuildPath = $nuspecPath -replace "\.nuspec$", "_build.nuspec"
[xml]$au = Get-Content $nuspecPath -Encoding UTF8
$description = $au.package.metadata.summary + ".`n`n" + $features
$au.package.metadata.version = $version
$au.package.metadata.description = $description
$au.package.metadata.licenseUrl = "${repo}/blob/develop/LICENSE"
$au.package.metadata.projectUrl = $repo
$au.package.metadata.projectSourceUrl = $repo
$au.package.metadata.bugTrackerUrl = "${repo}/issues"
$au.package.metadata.docsUrl = "${repo}/wiki"
$au.package.metadata.packageSourceUrl = "${repo}/tree/develop/chocolatey"

if (Test-Path "$PSScriptRoot/CHANGELOG.md") {
    [string]$changelog = Get-Content "$PSScriptRoot/CHANGELOG.md" -Encoding UTF8 | Out-String
    $au.package.metadata.releaseNotes = $changelog
}
else {
    $au.package.metadata.releaseNotes = "$repo/releases/tag/" + $version
}
$au.Save($nuspecBuildPath)

"Copying 7z archive"
$archive = Get-ChildItem "$buildPath/$version/*${version}.7z" | % FullName
Copy-Item $archive $PSScriptRoot/tools/Wormies-AU-Helpers.7z
Copy-Item $PSScriptRoot/../LICENSE $PSScriptRoot/legal/LICENSE.txt

$checksum = Get-FileHash $archive -Algorithm SHA256 | % Hash

$content = Get-Content $PSScriptRoot/legal/VERIFICATION.txt -Encoding UTF8 | % {
    $_ -replace "\<.*\/tag\/[^\>]*\>", "<$repo/releases/tag/${version}>" `
        -replace "(checksum\:).*", "`${1} ${checksum}" `
        -replace "\<.*LICENSE\>", "<$($au.package.metadata.licenseUrl)>"
}

$content | Out-File $PSScriptRoot/legal/VERIFICATION.txt -Encoding utf8

Remove-Item $PSScriptRoot/*.nupkg
choco pack -r $nuspecBuildPath --outputdirectory $PSScriptRoot
Remove-Item $nuspecBuildPath -ErrorAction Ignore