param(
    [string]$SourceRoot = "asset_generator\expected_output\assets\icons",
    [string]$DestRoot = "assets\icons",
    [int]$Size = 64,
    [int]$Margin = 5,
    [int]$AlphaThreshold = 32,
    [string]$OnlyCategory = "",
    [string]$OnlyDest = ""
)

Add-Type -AssemblyName System.Drawing

$IconMap = @(
    @{ Source = "weapons\weapon_knife.png"; Dest = "weapons\knife.png"; VisualScale = 0.90 },
    @{ Source = "weapons\weapon_pistol.png"; Dest = "weapons\pistol.png"; VisualScale = 0.78 },
    @{ Source = "weapons\weapon_ar.png"; Dest = "weapons\ar.png"; VisualScale = 1.08 },
    @{ Source = "weapons\weapon_shotgun.png"; Dest = "weapons\shotgun.png"; VisualScale = 1.12 },
    @{ Source = "weapons\weapon_railgun.png"; Dest = "weapons\railgun.png"; VisualScale = 1.05 },
    @{ Source = "ammo\ammo_pistol.png"; Dest = "ammo\pistol.png" },
    @{ Source = "ammo\ammo_ar.png"; Dest = "ammo\ar.png" },
    @{ Source = "ammo\ammo_shotgun.png"; Dest = "ammo\shotgun.png" },
    @{ Source = "ammo\ammo_railgun.png"; Dest = "ammo\railgun.png" },
    @{ Source = "items\item_heal.png"; Dest = "items\heal.png" },
    @{ Source = "items\item_armor.png"; Dest = "items\armor.png" },
    @{ Source = "artifacts\artifact.red_trigger.png"; Dest = "artifacts\red_trigger.png" },
    @{ Source = "artifacts\artifact.armor_sponge.png"; Dest = "artifacts\armor_sponge.png" },
    @{ Source = "artifacts\artifact.silent_core.png"; Dest = "artifacts\silent_core.png" },
    @{ Source = "artifacts\artifact.zone_battery.png"; Dest = "artifacts\zone_battery.png" },
    @{ Source = "artifacts\artifact.emergency_shell.png"; Dest = "artifacts\emergency_shell.png" },
    @{ Source = "artifacts\artifact.ghost_grass.png"; Dest = "artifacts\ghost_grass.png" }
)

function Get-AlphaBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Threshold
    )

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $alpha = $Bitmap.GetPixel($x, $y).A
            if ($alpha -gt $Threshold) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -lt 0 -or $maxY -lt 0) {
        return [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    }

    return [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1)
}

function Get-NormalizedBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Threshold
    )

    $bounds = Get-AlphaBounds -Bitmap $Bitmap -Threshold $Threshold
    $nearlyFull = $bounds.Width -ge ($Bitmap.Width - 4) -or $bounds.Height -ge ($Bitmap.Height - 4)
    if ($nearlyFull -and $Threshold -lt 220) {
        $strongBounds = Get-AlphaBounds -Bitmap $Bitmap -Threshold 220
        if ($strongBounds.Width -gt 8 -and $strongBounds.Height -gt 8) {
            return $strongBounds
        }
    }
    return $bounds
}

function Export-Icon {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int]$OutputSize,
        [int]$OutputMargin,
        [int]$Threshold,
        [double]$VisualScale
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        Write-Warning "missing source icon: $SourcePath"
        return
    }

    $destDir = Split-Path -Path $DestPath -Parent
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    $source = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $SourcePath).Path)
    $target = [System.Drawing.Bitmap]::new($OutputSize, $OutputSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($target)

    try {
        $bounds = Get-NormalizedBounds -Bitmap $source -Threshold $Threshold
        $innerSize = [Math]::Max(1, $OutputSize - ($OutputMargin * 2))
        $baseScale = [Math]::Min($innerSize / $bounds.Width, $innerSize / $bounds.Height)
        $maxDrawSize = [Math]::Max(1, $OutputSize - 2)
        $maxScale = [Math]::Min($maxDrawSize / $bounds.Width, $maxDrawSize / $bounds.Height)
        $scale = [Math]::Min($baseScale * $VisualScale, $maxScale)
        $drawW = [Math]::Max(1, [int][Math]::Round($bounds.Width * $scale))
        $drawH = [Math]::Max(1, [int][Math]::Round($bounds.Height * $scale))
        $drawX = [int][Math]::Floor(($OutputSize - $drawW) / 2)
        $drawY = [int][Math]::Floor(($OutputSize - $drawH) / 2)

        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage(
            $source,
            [System.Drawing.Rectangle]::new($drawX, $drawY, $drawW, $drawH),
            $bounds,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        $target.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $target.Dispose()
        $source.Dispose()
    }
}

foreach ($icon in $IconMap) {
    if ($OnlyCategory -ne "" -and -not $icon.Dest.StartsWith("$OnlyCategory\")) {
        continue
    }
    if ($OnlyDest -ne "" -and $icon.Dest -ne $OnlyDest) {
        continue
    }
    $src = Join-Path $SourceRoot $icon.Source
    $dst = Join-Path $DestRoot $icon.Dest
    $visualScale = 1.0
    if ($icon.ContainsKey("VisualScale")) {
        $visualScale = [double]$icon.VisualScale
    }
    Export-Icon -SourcePath $src -DestPath $dst -OutputSize $Size -OutputMargin $Margin -Threshold $AlphaThreshold -VisualScale $visualScale
    Write-Host "synced $($icon.Dest)"
}
