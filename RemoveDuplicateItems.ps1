$totalItems = 0
$processedItems = 0

# This function finds and removes duplicate items in the given path
function FindAndRemoveDuplicateItems($rootPath, $fieldName) {
    $hash = New-Object "System.Collections.Generic.Dictionary``2[System.String,System.Collections.Generic.Dictionary``2[System.String,PSObject]]"
    $root = Get-Item -Path $rootPath
    $status = Get-Duplicates $root $fieldName

    return $status + " for $rootPath"
}

# This function creates an item info object for the given item
function CreateItemInfo($item) {
    return @{
        ID       = $item.ID
        Updated  = [DateTime]::ParseExact($item.Fields["__Updated"], "yyyyMMdd'T'HHmmss'Z'", $null)
        Path     = $item.Paths.Path
    }
}

# This function recursively finds duplicates based on the specified field name
function Get-Duplicates($item, $fieldName) {
    $exist = Test-Path -Path $item.Paths.Path

    if ($exist) {
        $children = Get-ChildItem -Path $item.Paths.Path
        $duplicates = $false

        foreach ($child in $children) {
            $irId = $child.Fields[$fieldName]

            if ($hash.ContainsKey($irId)) {
                $duplicates = $true
                $itemInfo = CreateItemInfo($child)
                $hash[$irId][$itemInfo.ID] = $itemInfo
            } else {
                $hash.Add($irId, (New-Object "System.Collections.Generic.Dictionary``2[System.String,PSObject]"))
                $hash[$irId][$child.ID] = CreateItemInfo($child)
            }

            $childResult = Get-Duplicates $child $fieldName

            if ($childResult -eq "PASS") {
                return $childResult
            }
        }

        if ($duplicates) {
            Write-Host "Removing old duplicates"
            RemoveOldDuplicates $hash
            return "Duplication Deletion Complete"
        } else {
            return "No duplicates found"
        }
    }
}

# This function removes old duplicates from the items stored in the hash
function RemoveOldDuplicates($hash) {
    $totalItems = $hash.Count
    $processedItems = 0

    foreach ($key in $hash.Keys) {
        $newestItem = $null

        foreach ($itemInfo in $hash[$key].Values) {
            if ($null -eq $newestItem -or $itemInfo.Updated -gt $newestItem.Updated) {
                $newestItem = $itemInfo
            }
        }

        foreach ($itemInfo in $hash[$key].Values) {
            if ($itemInfo.ID -ne $newestItem.ID) {
                Write-Host "Removing item id: $($itemInfo.ID) because it is an older duplicate"
                Remove-Item -Path $itemInfo.Path
            }
        }

        $processedItems++
        $percentComplete = ($processedItems / $totalItems) * 100
        Write-Progress -Activity "Removing items" -Status "$processedItems of $totalItems removed" -PercentComplete $percentComplete
    }
}

# Use this function to find and remove duplicate items by passing the root path and the field to compare by
FindAndRemoveDuplicateItems "/sitecore/content/DMC/DMCGlobal/Data/IR Direct News Articles new duplicates" "Id"
