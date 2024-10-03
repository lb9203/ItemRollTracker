# Remove old packages
Remove-Item "ItemRollTracker-v*.zip"
Remove-Item "ItemRollTracker-v*.7z"

# Fetch version number
$VERSION = "X.X"
foreach ($line in Get-Content "ItemRollTracker/ItemRollTracker.toc") {
	if ($line -match "^## Version: (\d+\.\d+\.\d+)") {
		$VERSION = $Matches[1]
		break
	}
}

# Trim patch number
if ($VERSION -match "(\d+\.\d+)\.0") {
	$VERSION = $Matches[1]
}

# Copy license file into package
Copy-Item "License.md" -Destination "ItemRollTracker/License.md"

# Copy acknowledgements into package
Copy-Item "Acknowledgements.md" -Destination "ItemRollTracker/Acknowledgements.md"

# Create new packages
$PATH_7Z = "C:/Program Files/7-Zip"
&"$PATH_7Z/7z.exe" a -tzip -mmt -mx9 -r "ItemRollTracker-v$VERSION.zip" "ItemRollTracker/"
&"$PATH_7Z/7z.exe" a -t7z -mmt -mx9 -r "ItemRollTracker-v$VERSION.7z" "ItemRollTracker/"

# Cleanup license file
Remove-Item "ItemRollTracker/License.md"

# Cleanup acknowledgements file
Remove-Item "ItemRollTracker/Acknowledgements.md"
