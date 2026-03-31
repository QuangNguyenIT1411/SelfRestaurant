$ErrorActionPreference='Stop'
$docPath='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\Kien_truc_he_thong_BaiTapSo2_Nhom1.docx'
$w=New-Object -ComObject Word.Application
$w.Visible=$false
try {
  $d=$w.Documents.Open($docPath,$false,$false)
  $s=$w.Selection
  $s.EndKey(6) | Out-Null
  $s.InsertBreak(7) | Out-Null
  $s.TypeText('PART B - DRAWN BLOCK DIAGRAMS')
  $s.TypeParagraph()
  $s.TypeText('Diagram 1: System overview')
  $s.TypeParagraph()
  $a=$s.Range

  function Box($doc,[string]$txt,[single]$l,[single]$t,[single]$w,[single]$h,$anc){
    $x=$doc.Shapes.AddShape(1,$l,$t,$w,$h,$anc)
    $x.TextFrame.TextRange.Text=$txt
    $x.TextFrame.TextRange.Font.Name='Times New Roman'
    $x.TextFrame.TextRange.Font.Size=10
    $x.TextFrame.TextRange.ParagraphFormat.Alignment=1
    $x.Fill.ForeColor.RGB=14811135
    $x.Line.ForeColor.RGB=0
    return $x
  }
  function Arr($doc,[single]$x1,[single]$y1,[single]$x2,[single]$y2,$anc){
    $l=$doc.Shapes.AddLine($x1,$y1,$x2,$y2,$anc)
    $l.Line.EndArrowheadStyle=2
    return $l
  }

  Box $d "Users" 55 120 95 50 $a | Out-Null
  Box $d "API Gateway" 180 120 110 50 $a | Out-Null
  Box $d "Microservices" 320 120 130 50 $a | Out-Null
  Box $d "Databases" 480 120 110 50 $a | Out-Null
  Box $d "Message Broker" 350 200 120 40 $a | Out-Null
  Arr $d 150 145 180 145 $a | Out-Null
  Arr $d 290 145 320 145 $a | Out-Null
  Arr $d 450 145 480 145 $a | Out-Null
  Arr $d 385 170 405 200 $a | Out-Null

  1..14 | ForEach-Object { $s.TypeParagraph() }
  $s.TypeText('Diagram 2: Clean architecture layers')
  $s.TypeParagraph()
  $a2=$s.Range
  Box $d "API" 60 450 80 45 $a2 | Out-Null
  Box $d "Application" 170 450 110 45 $a2 | Out-Null
  Box $d "Domain" 310 450 90 45 $a2 | Out-Null
  Box $d "Infrastructure" 430 450 120 45 $a2 | Out-Null
  Arr $d 140 472 170 472 $a2 | Out-Null
  Arr $d 280 472 310 472 $a2 | Out-Null
  Arr $d 430 472 400 472 $a2 | Out-Null

  $d.Save()
  $d.Close()
  Write-Output 'saved'
}
finally {
  try { $w.Quit() } catch {}
}
