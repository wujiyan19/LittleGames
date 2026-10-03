Add-Type -AssemblyName System.Drawing
$artReviewRoot = (Resolve-Path 'docs/device-acceptance/art-review-2026-10-03').Path
$artLabelFont = [System.Drawing.Font]::new('Arial', 17)
$artTitleFont = [System.Drawing.Font]::new('Arial', 20)
$artBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#26334d'))
foreach ($artTheme in @('light', 'dark')) {
  $artFiles = @(Get-ChildItem -LiteralPath $artReviewRoot -File -Filter ($artTheme + '-*-ready.jpeg') | Sort-Object Name)
  if ($artFiles.Count -ne 33) { continue }
  for ($artGroup = 0; $artGroup -lt 3; $artGroup++) {
    $artCanvas = [System.Drawing.Bitmap]::new(1200, 2000)
    $artGraphics = [System.Drawing.Graphics]::FromImage($artCanvas)
    $artGraphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#e8edf5'))
    $artGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $artGraphics.DrawString(('Device art review / ' + $artTheme + ' / 2026-10-03'), $artTitleFont, $artBrush, 12, 8)
    for ($artIndex = 0; $artIndex -lt 11; $artIndex++) {
      $artFile = $artFiles[$artGroup * 11 + $artIndex]
      $artX = ($artIndex % 4) * 300
      $artY = [Math]::Floor($artIndex / 4) * 650 + 45
      $artLabel = $artFile.BaseName.Replace(($artTheme + '-'), '').Replace('-ready', '')
      $artGraphics.DrawString($artLabel, $artLabelFont, $artBrush, [single]($artX + 12), [single]$artY)
      $artImage = [System.Drawing.Image]::FromFile($artFile.FullName)
      $artGraphics.DrawImage($artImage, [int]($artX + 10), [int]($artY + 28), 280, 604)
      $artImage.Dispose()
    }
    $artDestination = Join-Path $artReviewRoot ('contact-' + $artTheme + '-' + ($artGroup + 1) + '.jpeg')
    $artCanvas.Save($artDestination, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $artGraphics.Dispose()
    $artCanvas.Dispose()
    Write-Output $artDestination
  }
}
$artBrush.Dispose()
$artLabelFont.Dispose()
$artTitleFont.Dispose()
