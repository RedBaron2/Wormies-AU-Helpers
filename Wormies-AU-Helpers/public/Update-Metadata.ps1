$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Updates the metadata nuspec file with the specified information.

.DESCRIPTION
When a key and value is specified, update the metadata element with the specified key
and the corresponding value in the specified NuspecFile.

.PARAMETER key
The element that should be updated in the metadata section.

.PARAMETER value
The value to update with.

.PARAMETER NuspecFile
The metadata/nuspec file to update

.EXAMPLE
Update-Metadata -key releaseNotes -value "https://github.com/majkinetor/AU/releases/latest"

.EXAMPLE
Update-Metadata -key releaseNotes -value "https://github.com/majkinetor/AU/releases/latest" -NuspecFile ".\package.nuspec"

.EXAMPLE
Update-Metadata -data @{ title = 'My Awesome Title' }

.EXAMPLE
@{ title = 'My Awesome Title' } | Update-Metadata

.NOTES
    Will throw an exception if the specified key doesn't exist in the nuspec file.

    While the parameter `NuspecFile` accepts globbing patterns,
    it is expected to only match a single file.

.LINK
    https://wormiecorp.github.io/Wormies-AU-Helpers/docs/functions/update-metadata
#>
function Update-Metadata {
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "Single")]
        [string]$key,
        [Parameter(Mandatory = $true, ParameterSetName = "Single")]
        [string]$value,
        [Parameter(Mandatory = $true, ParameterSetName = "Multiple", ValueFromPipeline = $true)]
        [hashtable]$data = [ordered] @{$key = $value},
        [ValidateScript( { Test-Path $_ })]
        [SupportsWildcards()]
        [string]$NuspecFile = ".\*.nuspec"
    )

    $NuspecFile = Resolve-Path $NuspecFile

    $nu = New-Object xml
    $nu.PSBase.PreserveWhitespace = $true
    $nu.Load($NuspecFile)
    $data.Keys | ForEach-Object {
        switch -Regex ($_) {
            '^(file)$' {
                $metaData = "files"; $NodeGroup = $nu.package.$metaData
                $NodeData,[int]$change = $data[$_] -split (",")
                $NodeCount = $nu.package.$metaData.ChildNodes.Count; $src,$target,$exclude = $NodeData -split ("\|")
                $NodeAttributes = [ordered] @{"src" = $src;"target" = $target;"exclude" = $exclude}
                $change = @{$true="0";$false=($change - 1)}[ ([string]::IsNullOrEmpty($change)) ]
                if ($NodeCount -eq 3) { $NodeGroup = $NodeGroup."$_"; $omitted = $true } else { $NodeGroup = $NodeGroup.$_[$change] }
            }
            '^(dependency)$' {
                $MetaNode = $_ -replace("y","ies"); $metaData = "metadata"
                $NodeData,[int]$change = $data[$_] -split (",")
                $NodeGroup = $nu.package.$metaData.$MetaNode; $NodeCount = $nu.package.$metaData.$MetaNode.ChildNodes.Count
                $id,$version,$include,$exclude = $NodeData -split ("\|")
                $NodeAttributes = [ordered] @{"id" = $id;"version" = $version;"include" = $include;"exclude" = $exclude}
                $change = @{$true="0";$false=($change - 1)}[ ([string]::IsNullOrEmpty($change)) ]
                if ($NodeCount -eq 3) { $NodeGroup = $NodeGroup."$_"; $omitted = $true } else { $NodeGroup = $NodeGroup.$_[$change] }
            }
            default {
                if ( $nu.package.metadata."$_" ) {
                    $nu.package.metadata."$_" = $data[$_]
                }
                else {
                    Write-Warning "$_ does not exist on the metadata element in the nuspec file"
                }
            }
        }
        if ($_ -match '^(dependency)$|^(file)$') {
            if (($change -gt $NodeCount)) {
                Write-Warning "$change is greater than $NodeCount of $_ Nodes"
            }
            if ($omitted) {
                Write-Warning "Change has been omitted due to $_ Nodes not having $change Nodes"
            }
            foreach ( $attrib in $NodeAttributes.keys ) {
                if (!([string]::IsNullOrEmpty($NodeAttributes[$attrib])) ) {
                    if (![string]::IsNullOrEmpty( $NodeGroup.Attributes ) ) {
                        $NodeGroup.SetAttribute($attrib, $NodeAttributes[$attrib] )
                    } else { 
                        Write-Warning "Attribute(s) are not defined for $_ in the nuspec file"
                    }
                }
            }
        } 
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($NuspecFile, $nu.InnerXml, $utf8NoBom)
}
