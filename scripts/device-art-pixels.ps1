param([Parameter(Mandatory=$true)][string]$InputPath)
# Sample only captured, rendered game pixels; do not read app data.
Add-Type -AssemblyName System.Drawing
$pixelRequest = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
$pixelImage = [System.Drawing.Bitmap]::new([string]$pixelRequest.file)
$pixelResults = [System.Collections.Generic.List[object]]::new()
$gemPalette = @(@(221,146,166), @(239,189,138), @(110,193,167), @(117,181,227), @(229,154,195), @(166,156,225))
foreach ($pixelBounds in $pixelRequest.bounds) {
  $pixelX = [int](($pixelBounds[0] + $pixelBounds[2]) / 2)
  $pixelY = [int](($pixelBounds[1] + $pixelBounds[3]) / 2)
  $pixelColor = $pixelImage.GetPixel($pixelX, $pixelY)
  if ($pixelRequest.kind -eq 'gems') {
    $gemBest = -1
    $gemDistance = [double]::PositiveInfinity
    for ($gemIndex = 0; $gemIndex -lt $gemPalette.Count; $gemIndex++) {
      $gemDifference = [Math]::Pow($gemPalette[$gemIndex][0] - $pixelColor.R, 2) + [Math]::Pow($gemPalette[$gemIndex][1] - $pixelColor.G, 2) + [Math]::Pow($gemPalette[$gemIndex][2] - $pixelColor.B, 2)
      if ($gemDifference -lt $gemDistance) { $gemDistance = $gemDifference; $gemBest = $gemIndex }
    }
    $pixelResults.Add($gemBest)
  } elseif ($pixelRequest.kind -eq 'memory') {
    $facePixels = [System.Collections.Generic.List[int]]::new()
    for ($faceRow = 0; $faceRow -lt 12; $faceRow++) {
      for ($faceCol = 0; $faceCol -lt 12; $faceCol++) {
        $faceX = [int]($pixelBounds[0] + ($pixelBounds[2] - $pixelBounds[0]) * (0.175 + ($faceCol + 0.5) / 12 * 0.65))
        $faceY = [int]($pixelBounds[1] + ($pixelBounds[3] - $pixelBounds[1]) * (0.20 + ($faceRow + 0.5) / 12 * 0.60))
        $faceColor = $pixelImage.GetPixel($faceX, $faceY)
        $facePixels.Add($faceColor.R)
        $facePixels.Add($faceColor.G)
        $facePixels.Add($faceColor.B)
      }
    }
    $pixelResults.Add($facePixels.ToArray())
  } else { $pixelResults.Add(@($pixelColor.R, $pixelColor.G, $pixelColor.B)) }
}
$pixelImage.Dispose()
ConvertTo-Json -InputObject $pixelResults.ToArray() -Depth 4 -Compress
