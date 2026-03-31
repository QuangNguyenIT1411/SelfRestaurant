$ErrorActionPreference = 'Stop'

$docPath = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'

$word = New-Object -ComObject Word.Application
$word.Visible = $false

try {
    $doc = $word.Documents.Open($docPath)

    # Move to end and create a dedicated section for real diagrams
    $sel = $word.Selection
    $sel.EndKey(6) | Out-Null # wdStory
    $sel.InsertBreak(7) | Out-Null # wdPageBreak

    $sel.TypeText('PHẦN B - BIỂU ĐỒ KIẾN TRÚC (VẼ TRỰC QUAN DẠNG HÌNH KHỐI)')
    $sel.TypeParagraph()
    $sel.TypeText('Biểu đồ 1: Kiến trúc tổng quan hệ thống')
    $sel.TypeParagraph()

    $anchor1 = $sel.Range

    function Add-Box {
        param($docRef, [string]$text, [float]$l, [float]$t, [float]$w, [float]$h, [int]$r=230,[int]$g=240,[int]$b=250, $anchor)
        $shape = $docRef.Shapes.AddShape(5, $l, $t, $w, $h, $anchor) # Rounded Rectangle
        $shape.Fill.Visible = -1
        $shape.Fill.ForeColor.RGB = ($b -shl 16) -bor ($g -shl 8) -bor $r
        $shape.Line.Visible = -1
        $shape.Line.ForeColor.RGB = 0
        $shape.TextFrame.TextRange.Text = $text
        $shape.TextFrame.TextRange.Font.Name = 'Times New Roman'
        $shape.TextFrame.TextRange.Font.Size = 11
        $shape.TextFrame.TextRange.ParagraphFormat.Alignment = 1
        return $shape
    }

    function Add-Arrow {
        param($docRef,[float]$x1,[float]$y1,[float]$x2,[float]$y2,$anchor)
        $ln = $docRef.Shapes.AddLine($x1,$y1,$x2,$y2,$anchor)
        $ln.Line.EndArrowheadStyle = 2
        $ln.Line.Weight = 1.5
        return $ln
    }

    # Diagram 1 boxes
    $y1 = 120
    $h1 = 58
    $bUser = Add-Box -docRef $doc -text "Người dùng`n(Web/Mobile/POS)" -l 55 -t $y1 -w 110 -h $h1 -r 220 -g 240 -b 255 -anchor $anchor1
    $bGw   = Add-Box -docRef $doc -text "API Gateway`nAuth + Routing" -l 190 -t $y1 -w 110 -h $h1 -r 220 -g 255 -b 220 -anchor $anchor1
    $bMs   = Add-Box -docRef $doc -text "Cụm Microservices`nOrder/Menu/Table/Payment/Customer" -l 325 -t $y1 -w 170 -h $h1 -r 255 -g 245 -b 220 -anchor $anchor1
    $bDb   = Add-Box -docRef $doc -text "Database per Service" -l 520 -t $y1 -w 120 -h $h1 -r 245 -g 230 -b 255 -anchor $anchor1

    # support components under microservices
    $bMq   = Add-Box -docRef $doc -text "Message Broker" -l 355 -t 205 -w 130 -h 44 -r 235 -g 235 -b 235 -anchor $anchor1
    $bObs  = Add-Box -docRef $doc -text "Logging + Monitoring" -l 505 -t 205 -w 135 -h 44 -r 235 -g 235 -b 235 -anchor $anchor1

    Add-Arrow -docRef $doc -x1 165 -y1 149 -x2 190 -y2 149 -anchor $anchor1 | Out-Null
    Add-Arrow -docRef $doc -x1 300 -y1 149 -x2 325 -y2 149 -anchor $anchor1 | Out-Null
    Add-Arrow -docRef $doc -x1 495 -y1 149 -x2 520 -y2 149 -anchor $anchor1 | Out-Null
    Add-Arrow -docRef $doc -x1 410 -y1 178 -x2 420 -y2 205 -anchor $anchor1 | Out-Null
    Add-Arrow -docRef $doc -x1 520 -y1 178 -x2 565 -y2 205 -anchor $anchor1 | Out-Null

    # Leave space then diagram 2 title
    for ($i=0; $i -lt 16; $i++) { $sel.TypeParagraph() }
    $sel.TypeText('Biểu đồ 2: Kiến trúc bên trong một microservice (Clean Architecture)')
    $sel.TypeParagraph()

    $anchor2 = $sel.Range

    $y2 = 460
    $h2 = 52
    Add-Box -docRef $doc -text "API Layer`nControllers" -l 60 -t $y2 -w 115 -h $h2 -r 220 -g 240 -b 255 -anchor $anchor2 | Out-Null
    Add-Box -docRef $doc -text "Application Layer`nUse Cases" -l 195 -t $y2 -w 130 -h $h2 -r 220 -g 255 -b 220 -anchor $anchor2 | Out-Null
    Add-Box -docRef $doc -text "Domain Layer`nEntities + Rules" -l 345 -t $y2 -w 130 -h $h2 -r 255 -g 245 -b 220 -anchor $anchor2 | Out-Null
    Add-Box -docRef $doc -text "Infrastructure`nDB/Cache/Broker/Repo" -l 495 -t $y2 -w 145 -h $h2 -r 245 -g 230 -b 255 -anchor $anchor2 | Out-Null

    Add-Arrow -docRef $doc -x1 175 -y1 486 -x2 195 -y2 486 -anchor $anchor2 | Out-Null
    Add-Arrow -docRef $doc -x1 325 -y1 486 -x2 345 -y2 486 -anchor $anchor2 | Out-Null
    Add-Arrow -docRef $doc -x1 495 -y1 486 -x2 475 -y2 486 -anchor $anchor2 | Out-Null

    # ensure text font consistency for normal paragraphs
    $doc.Content.Font.Name = 'Times New Roman'

    $wdFormatDocumentDefault = 16
    $doc.SaveAs([ref]$docPath, [ref]$wdFormatDocumentDefault)

    $pdfPath = [System.IO.Path]::ChangeExtension($docPath, 'pdf')
    $wdExportFormatPDF = 17
    $doc.ExportAsFixedFormat($pdfPath, $wdExportFormatPDF)

    $doc.Close()

    Write-Output "Updated diagrams in: $docPath"
    Write-Output "Updated PDF: $pdfPath"
}
finally {
    try { $word.Quit() } catch {}
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
