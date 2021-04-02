'Проект "GTF_450" v001 от 18.03.2021
'
'ОПИСАНИЕ: Извлекает данные из отчетов и заполняет форму 450

Option Explicit

Dim gXMLConfigPath, gXMLFileFolderLock, gConfigXML
Dim gExcel, gFSO, gWSO, gRExp
Dim gTraderID, gScriptFileName, gScriptPath, gLogFileName, gLogFilePath, gLogString
Dim gBaseA, gBaseB, gFinReport, gTemplate
Dim uD2S(255)
Dim gFinRepArray()
Dim gFinRepArraySize
Dim gCodeArray()
Dim gRowArray()
Dim gCodeArraySize, gCodeScanColumn

' fMonthD2C - converts month from INT to STRING value
Private Function fMonthD2C(inMonth)
    fMonthD2C = vbNullString
    Select Case inMonth
        Case 1:     fMonthD2C = "январь"
        Case 2:     fMonthD2C = "февраль"
        Case 3:     fMonthD2C = "март"
        Case 4:     fMonthD2C = "апрель"
        Case 5:     fMonthD2C = "май"
        Case 6:     fMonthD2C = "июнь"
        Case 7:     fMonthD2C = "июль"
        Case 8:     fMonthD2C = "август"
        Case 9:     fMonthD2C = "сентябрь"
        Case 10:    fMonthD2C = "октябрь"
        Case 11:    fMonthD2C = "ноябрь"
        Case 12:    fMonthD2C = "декабрь"
    End Select
End Function

' fMonthC2D - converts month from STRING to INT value
Private Function fMonthC2D(inMonth)
    fMonthC2D = 0
    Select Case Trim(LCase(inMonth))
        Case "январь", "января", "янв":		fMonthC2D = 1
        Case "февраль", "февраля", "фев":		fMonthC2D = 2
        Case "март", "марта", "мар":			fMonthC2D = 3
        Case "апрель", "апреля", "апр":		fMonthC2D = 4
        Case "май", "мая":				fMonthC2D = 5
        Case "июнь", "июня", "июн":        	fMonthC2D = 6
        Case "июль", "июля", "июл":			fMonthC2D = 7
        Case "август", "августа", "авг":		fMonthC2D = 8
        Case "сентябрь", "сентября", "сен":	fMonthC2D = 9
        Case "октябрь", "октября", "окт":		fMonthC2D = 10
        Case "ноябрь", "ноября", "ноя":		fMonthC2D = 11
        Case "декабрь", "декабря", "дек":		fMonthC2D = 12
    End Select
End Function

'fD2SInit - makes map-array for EXCEL CELLS in global map-array uD2S
Private Sub fD2SInit()
	Dim tTotalSize, tCounterSize
	Dim tCounter()
	Dim i, j
    If uD2S(1) = "A" Then: Exit Sub
    tTotalSize = UBound(uD2S)
    tCounterSize = 0
    ReDim tCounter(tCounterSize)
    tCounter(0) = 65
    'n = 65
    For i = 1 To tTotalSize
        uD2S(i) = vbNullString
        For j = tCounterSize To 0 Step -1
            uD2S(i) = uD2S(i) & Chr(tCounter(j))
        Next
        '=INC
        tCounter(0) = tCounter(0) + 1
        For j = 0 To tCounterSize
            If tCounter(j) = 91 Then
                tCounter(j) = 65
                If j < tCounterSize Then
                    tCounter(j + 1) = tCounter(j + 1) + 1
                Else
                    tCounterSize = tCounterSize + 1
                    ReDim Preserve tCounter(tCounterSize)
                    tCounter(tCounterSize) = 65
                    Exit For
                End If
            End If
        Next
    Next
End Sub

'fGetFileExtension - returns file extension from full filename
Private Function fGetFileExtension(inFileName)
	Dim tPos
	fGetFileExtension = vbNullString
	tPos = InStrRev(inFileName, ".")
	If tPos > 0 Then
		fGetFileExtension = UCase(Right(inFileName, Len(inFileName) - tPos))
	End If
End Function

'fGetFileName - returns filename without extension from full filename
Private Function fGetFileName(inFile)
	Dim tPos
	fGetFileName = vbNullString
	tPos = InStrRev(inFile.Name, ".")
	If tPos > 1 Then
		fGetFileName = Left(inFile.Name, tPos - 1)
	End If
End Function

'fGetPeriod - Extract period from STRING value
Private Function fGetPeriod(inText, outYear, outMonth, outDay, inMode)
	Dim tYear, tMonth, tDay, tTextLen
	'prep
	fGetPeriod = False
	outYear = vbNullString
	outMonth = vbNullString
	outDay = vbNullString
	'chk 1	
	tTextLen = Len(inText)
	If Not(tTextLen = 6 or tTextLen = 8) Then: Exit Function
	If Not IsNumeric(inText) Then: Exit Function	
	tYear = CInt(Left(inText, 4))
	tMonth = CInt(Mid(inText, 5, 2))
	If Len(inText) = 8 Then 
		tDay = CInt(Right(inText, 2))
	Else
		tDay = 1
	End If

	'overload check
	If tYear < 2000 Or tYear > 2100 Then: Exit Function
	If tMonth < 1 Or tMonth > 12 Then: Exit Function
	If fDaysPerMonth(tMonth, tYear) < tDay Then: Exit Function	
	
	'succes return
	If inMode = "short" Then: tDay = vbNullString
	fGetPeriod = True
	outYear = tYear
	outMonth = tMonth
	outDay = tDay	
End Function

'fGetTraderID - returns TraderID from STRING
Private Function fGetTraderID(inText)
	'prep
	fGetTraderID = vbNullString
	If Len(inText) <> 8 Then: Exit Function
	'fin
	fGetTraderID = UCase(inText)	
End Function

'fGetGTPCode - returns GTP Code from STRING
Private Function fGetGTPCode(inText)
	Dim tMatches
	'prep
	fGetGTPCode = vbNullString
	gRExp.IgnoreCase = True
	gRExp.Global = True
	gRExp.Pattern = "(?:P|G)[A-Z]{3}(?:[A-Z]|\d){4}"
	Set tMatches = gRExp.Execute(inText)
	If tMatches.Count = 1 Then
		fGetGTPCode = tMatches.Item(0).Value
	End If	
	'fin	
End Function

'fDaysPerMonth - returns days in month value
Private Function fDaysPerMonth(inMonth, inYear)
    fDaysPerMonth = 0
    Select Case LCase(inMonth)
        Case "январь", 1:       fDaysPerMonth = 31
        Case "февраль", 2:
            If (inYear Mod 4) = 0 Then
                                fDaysPerMonth = 29
            Else
                                fDaysPerMonth = 28
            End If
        Case "март", 3:         fDaysPerMonth = 31
        Case "апрель", 4:       fDaysPerMonth = 30
        Case "май", 5:          fDaysPerMonth = 31
        Case "июнь", 6:         fDaysPerMonth = 30
        Case "июль", 7:         fDaysPerMonth = 31
        Case "август", 8:       fDaysPerMonth = 31
        Case "сентябрь", 9:     fDaysPerMonth = 30
        Case "октябрь", 10:     fDaysPerMonth = 31
        Case "ноябрь", 11:      fDaysPerMonth = 30
        Case "декабрь", 12:     fDaysPerMonth = 31
    End Select
    If inYear <= 0 Then: fDaysPerMonth = 0
End Function

'fGetTimeStamp - returns TimeStamp string of current time (YYYYMMDDHHmmSS)
Private Function fGetTimeStamp()
	Dim tNow, tResult, tTemp
	tNow = Now() '20171017000000
	'year
	tResult = Year(tNow)
	'month
	tTemp = Month(tNow)
	If tTemp < 10 Then: tTemp = "0" & tTemp
	tResult = tResult & tTemp
	'day
	tTemp = Day(tNow)
	If tTemp < 10 Then: tTemp = "0" & tTemp
	tResult = tResult & tTemp
	'hour
	tTemp = Hour(tNow)
	If tTemp < 10 Then: tTemp = "0" & tTemp
	tResult = tResult & tTemp
	'min
	tTemp = Minute(tNow)
	If tTemp < 10 Then: tTemp = "0" & tTemp
	tResult = tResult & tTemp
	'sec
	tTemp = Second(tNow)
	If tTemp < 10 Then: tTemp = "0" & tTemp
	tResult = tResult & tTemp
	'fin
	fGetTimeStamp = tResult
End Function

'fOpenBook - opens workbook of excel
Private Function fOpenBook(outWorkBook, inFile, inReadOnly)
	Dim tLogTag
		
	fOpenBook = False
	tLogTag = "OPENBOOK"
	
	On Error Resume Next
		Set outWorkBook = gExcel.Workbooks.Open (inFile.Path, False, inReadOnly)		
		If Err.Number > 0 Then
			'WScript.Echo "Произошла ошибка открытия файла." & vbCrLf & "Данный отчет будет пропущен!" & vbCrLf & vbCrLf & "FilePath: " & vbTab & inFile.Path & vbCrLf & vbCrLf & "FileName: " & vbTab & inFile.Name & vbCrLf & vbCrLf & "Reason: " & vbTab & Err.Description
			fLogLine tLogTag, "Не удалось окрыть книгу! Отчет будет пропущен."
			Set outWorkBook = Nothing
		ElseIf outWorkBook.WorkSheets.Count = 0 Then 'Вроде это невозможно
			fLogLine tLogTag, "В книге нет листов! Отчет будет пропущен."
			Set outWorkBook = Nothing
		End If
	On Error GoTo 0
	
	fOpenBook = True
End Function

'fExcelControl - triggering excel settings (to speedup work with opened books)
Private Sub fExcelControl(inExcelApp, inScreen, inAlerts, inCalculation, inEvents)
	'Preventinve
	If IsEmpty(inExcelApp) Then: Exit Sub
	If inExcelApp Is Nothing Then: Exit Sub
    '=Screen
    If inScreen = 1 Then
        inExcelApp.Application.ScreenUpdating = True
    ElseIf inScreen = -1 Then
        inExcelApp.Application.ScreenUpdating = False
    End If
    '=Alerts
    If inAlerts = 1 Then
        inExcelApp.Application.DisplayAlerts = True
    ElseIf inAlerts = -1 Then
        inExcelApp.Application.DisplayAlerts = False
    End If
    '=Calculation
    If inCalculation = 1 Then
        inExcelApp.Application.Calculation = -4105	'automatic calc
    ElseIf inCalculation = -1 Then
        inExcelApp.Application.Calculation = -4135 'manual calc
    End If
    '=Events
    If inEvents = 1 Then
        inExcelApp.Application.EnableEvents = True
    ElseIf inEvents = -1 Then
        inExcelApp.Application.EnableEvents = False
    End If
End Sub

'fLogInit - init logfile
Private Sub fLogInit()	
	gLogFilePath = gScriptPath & "\" & gLogFileName
	gLogString = vbNullString
	fLogLine "LOG", "Начало сессии."
End Sub

'fLogClose - close logfile
Private Sub fLogClose(inClearPreviousSession)    
	Dim tTextFile, tOldLogString	
    fLogLine "LOG", "Конец сессии."
	tOldLogString = vbNullString
    If gFSO.FileExists(gLogFilePath) Then
		On Error Resume Next
			Set tTextFile = gFSO.OpenTextFile(gLogFilePath, 1)
			tOldLogString = tTextFile.ReadAll
			tTextFile.Close
			If Err.Number > 0 Then: tOldLogString = vbNullString
		On Error GoTo 0
    End If
    Set tTextFile = gFSO.OpenTextFile(gLogFilePath, 2, True)
	If inClearPreviousSession Then: tOldLogString = vbNullString
    If tOldLogString <> vbNullString Then
        tTextFile.WriteLine gLogString
        tTextFile.Write tOldLogString
    Else
        tTextFile.Write gLogString
    End If
    tTextFile.Close
End Sub

'fLogLine - writing log string into the tempstring
Private Sub fLogLine(inBlockLabel, inText)
	Dim tTimeStamp	
	tTimeStamp = Now()
	tTimeStamp = fNZeroAdd(Month(tTimeStamp), 2) & "." & fNZeroAdd(Day(tTimeStamp), 2) & " " & fNZeroAdd(Hour(tTimeStamp), 2) & ":" & fNZeroAdd(Minute(tTimeStamp), 2) & ":" & fNZeroAdd(Second(tTimeStamp), 2) & " >"
	If gLogString <> vbNullString Then
		gLogString = gLogString & vbCrLf & tTimeStamp & vbTab & "[" & inBlockLabel & "] " & inText
	Else
		gLogString = tTimeStamp & vbTab & "[" & inBlockLabel & "] " & inText
	End If
End Sub

'fGetSheetIndex - Checks if worksheet index or name exists
Private Function fGetSheetIndex(inWorkBook, inSheetIndex, inSheetName)
	Dim tIndex, tNameExists, tIndexExists
	
	' 01 // Default Index
	fGetSheetIndex = 0
	tNameExists = False
	tIndexExists = False
	
	' 02 // Sheet scan by NAME
	If Not IsNull(inSheetName) Then
		If inSheetName <> vbNullString Then
			tNameExists = True
			For tIndex = 1 To inWorkBook.Worksheets.Count
				If LCase(inWorkBook.Worksheets(tIndex).Name) = LCase(inSheetName) Then
					fGetSheetIndex = tIndex
					Exit Function
				End If
			Next
		End If
	End If
	
	' 03 // Sheet scan by INDEX
	If Not IsNull(inSheetIndex) Then		
		If IsNumeric(inSheetIndex) Then
			tIndexExists = True
			tIndex = Fix(inSheetIndex)			
			If tIndex => 1 And tIndex <= inWorkBook.Worksheets.Count Then
				fGetSheetIndex = tIndex
				Exit Function
			End If
		End If
	End If
	
	' 04 // Something wrong
	If Not (tNameExists And tIndexExists) Then
		WScript.Echo "fGetSheetIndex can't get sheet INDEX; <inSheetIndex> and <inSheetName> is NULL!"	
	End If
End Function

'fNZeroAdd - INT to STRING formating to 0000 type ()
Private Function fNZeroAdd(inValue, inDigiCount)
	Dim tHighStack, tIndex
	fNZeroAdd = inValue	
	tHighStack = inDigiCount - Len(inValue)
	If tHighStack > 0 Then
		For tIndex = 1 To tHighStack
			fNZeroAdd = "0" & fNZeroAdd
		Next
	End If
End Function

Private Function fAutoCorrectString(inString, inTrim)
	fAutoCorrectString = vbNullString
	If IsNull(inString) Then: Exit Function
	fAutoCorrectString = inString
	If inTrim = 1 Then: fAutoCorrectString = Trim(inString)
End Function

Private Function fAutoCorrectNumeric(inValue, inDefaultValue, inMinValue, inMaxValue)
	Dim tCorrectLimits

	fAutoCorrectNumeric = inDefaultValue
	
	If IsNull(inValue) Then		
		Exit Function
	ElseIf Not IsNumeric(inValue) Then		
		Exit Function
	End If
	
	fAutoCorrectNumeric = Fix(inValue)
	
	tCorrectLimits = True
	If inMinValue <> "ANY" Then: tCorrectLimits = (tCorrectLimits And fAutoCorrectNumeric >= inMinValue)
	If inMaxValue <> "ANY" Then: tCorrectLimits = (tCorrectLimits And fAutoCorrectNumeric <= inMaxValue)	
	If Not tCorrectLimits Then: fAutoCorrectNumeric = inDefaultValue
End Function

Private Function fGetXMLConfig(inPathList, outSelectedPath, outXMLObject)
	Dim tPathList, tLock, tIndex, tFileName, tFilePath, tTempXML, tNode, tValue, tReportID, tVersion, tLogTag
	
	fGetXMLConfig = False
	tLogTag = "CONFIG"
	fLogLine tLogTag, "Searching for CONFIG XML > " & inPathList
	tPathList = Split(inPathList, ";")
	Set outXMLObject = Nothing
	outSelectedPath = vbNullString
	
	Set tTempXML = CreateObject("Msxml2.DOMDocument.6.0")
	tTempXML.ASync = False
	tFileName = "GTF_450_Config.xml"
	tReportID = "450"
	tVersion = "1"
	
	tIndex = 0
	tLock = False
	
	'scan
	Do While Not tLock
		If UBound(tPathList) < tIndex Then: Exit Do
		'file path forming
		tFilePath = tPathList(tIndex)
		If Right(tFilePath, 1) <> "\" Then: tFilePath = tFilePath & "\"
		tFilePath = tFilePath & tFileName
		'check if file exist		
		If gFSO.FileExists(tFilePath) Then
			tTempXML.Load tFilePath
			If tTempXML.parseError.ErrorCode = 0 Then 'Parsed?
				Set tNode = tTempXML.DocumentElement 'root
                tValue = tNode.NodeName
                If tValue = "message" Then 'message?
					tValue = UCase(tNode.getAttribute("class"))
                    If tValue = "CONFIG" Then 'message class is CALENDAR?
						tValue = tNode.getAttribute("id")
                        If tValue = tReportID Then 'report ID
							tValue = tNode.getAttribute("version")
							If tValue = tVersion Then 'version
								tLock = True
								fLogLine tLogTag, "CONFIG XML path locked > " & tFilePath
							End If
                        End If
					End If				
				End If
			Else
				fLogLine tLogTag, "XML parsing error: " & tTempXML.parseError.ErrorCode & " [LINE:" & tTempXML.parseError.Line & "/POS:" & tTempXML.parseError.LinePos & "]: " & tTempXML.parseError.Reason
			End If
		End If
		tIndex = tIndex + 1
	Loop
	
	'fin
	If Not (tTempXML Is Nothing) Then: Set tTempXML = Nothing 'release object
	If tLock Then		
		Set outXMLObject = CreateObject("Msxml2.DOMDocument.6.0")
		outXMLObject.ASync = False
		outXMLObject.Load tFilePath
		outSelectedPath = tFilePath
		fGetXMLConfig = True
	Else
		fLogLine tLogTag, "CONFIG XML not found!"
	End If	
End Function

Private Function fReportPeriodAsk(outYear, outMonth, inDefaultYear, inDefaultMonth)
	fReportPeriodAsk = False

	outYear = InputBox("Введите ГОД:", "Запрос ГОДА", inDefaultYear)
	If IsNumeric(outYear) Then
		outYear = Fix(outYear)
		If outYear => 2015 And outYear <= inDefaultYear Then	
			'FINE		
		Else
			WScript.Echo "Год неверный! #1"
			Exit Function
		End If
	Else
		WScript.Echo "Год неверный! #2"
		Exit Function
	End If

	outMonth = InputBox("Введите МЕСЯЦ:", "Запрос МЕСЯЦА", inDefaultMonth)
	If IsNumeric(outMonth) Then
		outMonth = Fix(outMonth)
		If outMonth => 1 And outMonth <= 12 Then	
			'FINE
		Else
			WScript.Echo "Месяц неверный! #1"
			Exit Function
		End If
	Else
		WScript.Echo "Месяц неверный! #2"
		Exit Function
	End If
	
	fReportPeriodAsk = True
End Function

Private Function fReprocessMask(inMask, inYear, inMonth, inRootPath)	
	fReprocessMask = Replace(inMask, "#YEAR_4#", inYear)	
	fReprocessMask = Replace(fReprocessMask, "#MONTH#", inMonth)
	fReprocessMask = Replace(fReprocessMask, "#MONTH_2#", fNZeroAdd(inMonth, 2))
	fReprocessMask = Replace(fReprocessMask, "#MONTH_CYR#", fMonthD2C(inMonth))
	fReprocessMask = Replace(fReprocessMask, "#ROOT#", inRootPath)
End Function

Private Function fCheckExtInList(inExt, inExtList)
	Dim tExtListElements, tExtElement, tTempExt
	fCheckExtInList = vbNullString
	If inExt = vbNullString Or inExtList = vbNullString Then: Exit Function
	tExtListElements = Split(LCase(inExtList), ";")
	tTempExt = LCase(inExt)
	For Each tExtElement In tExtListElements
		If tTempExt = tExtElement Then
			fCheckExtInList = tTempExt
			Exit Function
		End If
	Next
End Function

'MAIN \\ STEP 0 \\ Scan for files
Private Function fFileScanner(inFolder, inTraderCode, inYear, inMonth)
	Dim tSubFolder, tFile, Attrs, tLogTag
	Dim tFileNodes, tNode, tPathNodes, tPathNode, tFolder, tFileLock, tFileExt, tFileName, tValue, tResult
	Dim tFileNode, tTempValue
	
	tLogTag = "SCAN"
	fFileScanner = False
	
	' // проверим есть ли КОНФИГ
	If gConfigXML Is Nothing Then
		fLogLine tLogTag, "Инициализация неудачна! CONFIG XML не доступен"
		Exit Function
	End If
	
	' // defaults
	gBaseA = vbNullString
	gBaseB = vbNullString
	gFinReport = vbNullString
	gTemplate = vbNullString
	
	fLogLine tLogTag, "Дата периода формируемого отчета: [ " & fMonthD2C(inMonth) & " " & inYear & " ]"
	
	Set tFileNodes = gConfigXML.SelectNodes("//workfiles/file")	
	tResult = True
	
	' FILE SCAN
	For Each tFileNode In tFileNodes
		
		Set tPathNodes = tFileNode.SelectNodes("descendant::path")
		tValue = tFileNode.getAttribute("id")
		tFileLock = False
		
		'fLogLine tLogTag, "COUNT=" & tPathNodes.Length
			
		' PATH SCAN
		For Each tPathNode In tPathNodes		
			tFolder = fReprocessMask(tPathNode.Text, inYear, inMonth, inFolder)
						
			' IF FOLDER EXISTS
			If gFSO.FolderExists(tFolder) Then	
				Set tFolder = gFSO.GetFolder(tFolder)				
				Set tNode = tFileNode.SelectSingleNode("descendant::mask")
				
				If Not (tNode Is Nothing) Then
					gRExp.Pattern = fReprocessMask(tNode.Text, inYear, inMonth, inFolder)
					'fLogLine tLogTag, "Поиск файла: " & gRExp.Pattern
				
					For Each tFile in tFolder.Files
						tFileName = fGetFileName(tFile)
						tFileExt = fCheckExtInList(fGetFileExtension(tFile), fAutoCorrectString(tNode.getAttribute("ext"), True))
					
						If gRExp.Test(tFileName) And tFileExt <> vbNullString Then
							Select Case tValue
								Case "basea": Set gBaseA = tFile
								Case "baseb": Set gBaseB = tFile
								Case "finreport_cz": Set gFinReport = tFile
								Case "template": Set gTemplate = tFile								
							End Select
							tFileLock = True
							fLogLine tLogTag, "Файл типа [" & tValue &"] обнаружен: " & tFile
							Exit For
						End If
					Next
				End If
				
			End If
			
			If tFileLock Then: Exit For
		Next
		
		'finalyzer

		tResult = tResult And tFileLock
		If Not tFileLock Then: fLogLine tLogTag, "Файл типа [" & tValue &"] не обнаружен по прописанным путям."
	Next
	
	' // success return
	fFileScanner = tResult
End Function

' // work with finreport
Private Function fFinReportRead(outArray, outArraySize)
	Dim tLogTag, tWorkBook, tLastRow, tCurrentRow, tBlockIndex, tBlockName, tCurrentCol, tLockedBlock, tRowIndex, tValue, tGTPCode, tValTotal, tSumTotal
	
	tLogTag = "fFinReportRead"
	fFinReportRead = False
	outArraySize = -1
	tBlockIndex = "16."
	tBlockName = "Данные акта оборота электроэнергии"
	tLockedBlock = False
	
	On Error Resume Next
		
	If Not fOpenBook(tWorkBook, gFinReport, True) Then
		fLogLine tLogTag, "Не удалось открыть файл > " & gFinReport
		Exit Function
	End If
	
	'search for datablock
	tLastRow = tWorkBook.WorkSheets(1).Cells.SpecialCells(11).Row
	tCurrentCol = 1
	For tCurrentRow = tLastRow To 1 Step -1
		tValue = tWorkBook.WorkSheets(1).Cells(tCurrentRow, tCurrentCol).Value
		If InStr(tValue, tBlockIndex) > 0 And InStr(tValue, tBlockName) > 0 Then
			tLockedBlock = True
			Exit For
		End If
	Next
	
	'block locked?
	If Not tLockedBlock Then	
		fLogLine tLogTag, "Не удалось обнаружить БЛОК ИНДЕКС[" & tBlockIndex & "] с именем [" & tBlockName & "]. Что-то пошло не так..." 
		tWorkBook.Close
		On Error GoTo 0
		Exit Function
	End If
	
	fLogLine tLogTag, "Блок найден на строке [" & tCurrentRow & "]"
	
	'lock data index?
	tCurrentRow = tCurrentRow + 5
	tValue = tWorkBook.WorkSheets(1).Cells(tCurrentRow, tCurrentCol).Value
	If Not (tValue = "3" Or tValue = 3) Then
		fLogLine tLogTag, "Не удалось обнаружить БЛОК ИНДЕКС[" & tBlockIndex & "] с именем [" & tBlockName & "]. Что-то пошло не так..." 
		tWorkBook.Close
		On Error GoTo 0
		Exit Function
	End If
	
	'reading
	tSumTotal = 0
	For tRowIndex = tCurrentRow To tLastRow
		tValue = tWorkBook.WorkSheets(1).Cells(tRowIndex, tCurrentCol).Value
		
		If Not (IsNumeric(tValue) And Not IsEmpty(tValue)) Then: Exit For		
		
		tGTPCode = tWorkBook.WorkSheets(1).Cells(tRowIndex, tCurrentCol + 1).Value
		tValTotal = tWorkBook.WorkSheets(1).Cells(tRowIndex, tCurrentCol + 2).Value
		
		'fLogLine tLogTag, "G=" & tGTPCode & "(" & fGetGTPCode(tGTPCode) & "); V=" & tValTotal & "(" & IsNumeric(tValTotal) & ")"
		
		If Not (fGetGTPCode(tGTPCode) <> vbNullString And IsNumeric(tValTotal)) Then: Exit For		
		
		outArraySize = outArraySize + 1
		ReDim Preserve outArray(1, outArraySize)
		outArray(0, outArraySize) = tGTPCode
		outArray(1, outArraySize) = Fix(tValTotal)
		tSumTotal = tSumTotal + outArray(1, outArraySize)
		fLogLine tLogTag, "ГТП: " & tGTPCode & " -> " & outArray(1, outArraySize)
	Next
	
	'scan done // return
	tWorkBook.Close
	On Error GoTo 0
	
	fLogLine tLogTag, "Файл прочитан [ВсегоГТП = " & outArraySize + 1 & "] [ОбщийОбъем = " & tSumTotal & "] // StopRowIndex = " & tRowIndex
	fFinReportRead = True
End Function

' // reading files
Private Function fFileReader(inYear, inMonth, outBaseAWorkBook, outBaseBWorkBook)
	Dim tLogTag, tWorkBookA, tWorkBookB, tCurrentRow, tCurrentCol, tValue, tTempValue, tSheetIndex, tWorkBookTemplate, tNode, tXPathString

	fFileReader = False
	tLogTag = "fFileReader"
	Set outBaseAWorkBook = Nothing
	Set outBaseBWorkBook = Nothing
	
	'finreport read
	If Not fFinReportRead(gFinRepArray, gFinRepArraySize) Then: Exit Function
	
	'baseA ->
	If Not fOpenBook(tWorkBookA, gBaseA, True) Then
		fLogLine tLogTag, "Не удалось открыть файл типа [BaseA] > " & gBaseA
		Exit Function
	End If
	
	'baseB ->
	If Not fOpenBook(tWorkBookB, gBaseB, True) Then
		fLogLine tLogTag, "Не удалось открыть файл типа [BaseB] > " & gBaseB		
		Exit Function
	End If
	
	' periodcheck & quickcheck
	tCurrentRow = 2
	tCurrentCol = 1
	tSheetIndex = 1	
	
	'baseA ->
	tTempValue = "задолженность покупателей за " & fMonthD2C(inMonth) & " " & inYear
	tValue = LCase(tWorkBookA.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value)
	If InStr(tValue, tTempValue) <= 0 Then
		fLogLine tLogTag, "Не удалось подтвердить период отчета типа [BaseA] в ячейке " & uD2S(tCurrentCol) & tCurrentRow & "; ожидалось наличие [" & tTempValue & "], а найдено [" & tValue & "]"
		On Error GoTo 0
		Exit Function
	End If
	
	'baseB ->
	tTempValue = "продажи за " & fMonthD2C(inMonth) & " " & inYear
	tValue = LCase(tWorkBookB.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value)	
	If InStr(tValue, tTempValue) <= 0 Then
		fLogLine tLogTag, "Не удалось подтвердить период отчета типа [BaseB] в ячейке " & uD2S(tCurrentCol) & tCurrentRow & "; ожидалось наличие [" & tTempValue & "], а найдено [" & tValue & "]"
		On Error GoTo 0
		Exit Function
	End If
	
	'template ->
	If Not fOpenBook(tWorkBookTemplate, gTemplate, True) Then
		fLogLine tLogTag, "Не удалось открыть файл типа [Template] > " & gTemplate		
		Exit Function
	End If
	
	tXPathString = "//workfiles/file[@id='template']/codecolumn"
	Set tNode = gConfigXML.SelectSingleNode(tXPathString)
	If tNode Is Nothing Then
		fLogLine tLogTag, "Не удалось прочитать ноду XPath <" & tXPathString & ">!"
		Exit Function
	End If
	gCodeScanColumn = fAutoCorrectNumeric(tNode.Text, 0, 0, "ANY")
	If gCodeScanColumn = 0 Then
		fLogLine tLogTag, "Не удалось прочитать содержимое ноды [" & tNode.Text & "] XPath <" & tXPathString & "> (ожидалось значние > 0)!"
		Exit Function
	End If
	
	If Not fGetIndexTableTemplate(tWorkBookTemplate, gCodeScanColumn, gCodeArray, gRowArray, gCodeArraySize) Then	
		fCloseBook tWorkBookTemplate, False
		Exit Function
	End If
	
	fCloseBook tWorkBookTemplate, False
	
	'success return	
	Set outBaseAWorkBook = tWorkBookA
	Set outBaseBWorkBook = tWorkBookB
	
	fFileReader = True
End Function

Private Function fGetFinreportValueByGTPCode(inGTPCode, inFinReportArray)
	Dim tIndex
	
	fGetFinreportValueByGTPCode = -1
	If fGetGTPCode(inGTPCode) = vbNullString Then: Exit Function
	
	'fLogLine "GETbyGTP", "GTP to search -> " & inGTPCode & " // GTPList = " & UBound(inFinReportArray, 2) ' UBOUNC (Array, RANK-OF-DIMENSION)  \\ RANK-OF-DIMENSION starts from 1 \\ #2 Dimension is VAR
	
	For tIndex = 0 To UBound(inFinReportArray, 2)
		If inFinReportArray(0, tIndex) = inGTPCode Then
			fGetFinreportValueByGTPCode = inFinReportArray(1, tIndex)
			Exit Function
		End If
	Next
End Function

Private Function fGetMethodResult(inTestValue, inEtalonValue, inMethod)
	Dim tLogTag, tMethodElements, tValue
	
	tLogTag = "fGetMethodResult"
	fGetMethodResult = False
	
	tMethodElements = Split(Trim(inMethod), " ") 'space as splitter
	
	Select Case tMethodElements(0)
		Case "EQUAL":
			'fLogLine tLogTag, "EQ TEST=" & inTestValue & "; ETALON=" & inEtalonValue			
			fGetMethodResult = (inTestValue - inEtalonValue) = 0
		Case "NEAR":
			If UBound(tMethodElements) = 1 Then
				If Len(tMethodElements(1)) > 0 And InStr(tMethodElements(1), "%") Then
					If Right(tMethodElements(1), 1) = "%" Then
						tValue = Left(tMethodElements(1), Len(tMethodElements(1)) - 1)
						If IsNumeric(tValue) Then
							tValue = Abs(tValue)
							If tValue > 100 Then: tValue = 100 'autofix
							fGetMethodResult = inTestValue >= inEtalonValue * (1 - tValue/100) And inTestValue <= inEtalonValue * (1 + tValue/100)
						Else
							fLogLine tLogTag, "Синтаксис метода [NEAR] извлечения ноды [exctact] @method указан неверно: [" & inMethod & "]; Синатксис [NEAR d%] где d - число процента допустимого отклонения"							
						End If
					Else
						fLogLine tLogTag, "Синтаксис метода [NEAR] извлечения ноды [exctact] @method указан неверно: [" & inMethod & "]; Синатксис [NEAR d%] где d - число процента допустимого отклонения"						
					End If					
				Else
					fLogLine tLogTag, "Синтаксис метода [NEAR] извлечения ноды [exctact] @method указан неверно: [" & inMethod & "]; Синатксис [NEAR d%] где d - число процента допустимого отклонения"					
				End If
			Else
				fLogLine tLogTag, "Синтаксис метода [NEAR] извлечения ноды [exctact] @method указан неверно: [" & inMethod & "]; Синатксис [NEAR d%] где d - число процента допустимого отклонения"								
			End If
		Case Else:
			fLogLine tLogTag, "Метод извлечения ноды [exctact] @method указан неверно: [" & inMethod & "]"
	End Select
	
	'fGetMethodResult = True	
End Function

Private Sub fAddContractData(ioContractList, ioContractSize, inContractName, inStringCode, inAddVal, inAddCost, inTotalVal, inTotalCost)
	Dim tContractName, tLogTag, tContractElements
	
	tLogTag = "fAddContractData"
	tContractElements = Split(Trim(inContractName), " ")	
	tContractName = UCase(tContractElements(0))
	
	'NEW
	ioContractSize = ioContractSize + 1
	ReDim Preserve ioContractList(5, ioContractSize)
	ioContractList(0, ioContractSize) = tContractName
	ioContractList(1, ioContractSize) = inStringCode
	ioContractList(2, ioContractSize) = inAddVal
	ioContractList(3, ioContractSize) = inAddCost
	ioContractList(4, ioContractSize) = inTotalVal
	ioContractList(5, ioContractSize) = inTotalCost
	
	'LOG
	fLogLine tLogTag, "Движение по договору [" & ioContractSize & ":" & inStringCode & ":" & tContractName & "] VAL=" & inAddVal & " COST=" & inAddCost & " // TOTALVAL=" & inTotalVal & " TOTALCOST=" & inTotalCost
End Sub

Private Function fScanMethod_FinReport(inExtractNode, inWorkSheet, inStartRowIndex, inLastRowIndex, inScanCol, inValCol, inCostCol, inStringCode, inScanWord, ioValStore, ioCostStore, ioContractList, ioContractSize, inSafeRead)
	Dim tGTPCode, tMethod, tEtalonVal
	Dim tLogTag, tLockedRow, tCurrentRow, tValue
	Dim tTempVal, tTempCost, tReads
	Dim tContractVal, tContractCost, tContractName
	
	'defaults
	fScanMethod_FinReport = False
	tLogTag = "fScanMethod_FinReport"
	
	'quick check #1
	If inExtractNode Is Nothing Then
		fLogLine tLogTag, "Входная нода inExtractNode оказалась не инициализированной!"
		Exit Function
	End If
	
	'quick check #2
	If Not (IsNumeric(inStartRowIndex) And IsNumeric(inLastRowIndex)) Then
		fLogLine tLogTag, "Ошибка! Входные параметры имеют нечисловые значния: inStartRowIndex[" & inStartRowIndex & "] // inLastRowIndex[" & inLastRowIndex & "]"
		Exit Function
	ElseIf inStartRowIndex <=0 Or inLastRowIndex <= 0 Then
		fLogLine tLogTag, "Ошибка! Входные параметры имеют значния меньше или равные нулю: inStartRowIndex[" & inStartRowIndex & "] // inLastRowIndex[" & inLastRowIndex & "]"
		Exit Function
	End If
	
	'saferead trigger
	If inSafeRead Then: On Error Resume Next

	'params
	tGTPCode = UCase(fAutoCorrectString(inExtractNode.GetAttribute("gtpcode"), False))
	tMethod = UCase(fAutoCorrectString(inExtractNode.GetAttribute("method"), True))
	tEtalonVal = fGetFinreportValueByGTPCode(tGTPCode, gFinRepArray)
				
	If tEtalonVal = -1 Then
		fLogLine tLogTag, "Ошибка синтаксиса ноды [" & inExtractNode.NodeName & "]: @gtpcode=[" & tGTPCode & "] не была найдена в файле типа [FinReport]"
		If inSafeRead Then: On Error GoTo 0
		Exit Function
	End If
	
	'fix
	tEtalonVal = tEtalonVal / 1000 'to correct kvt->mvt
				
	'scan
	tLockedRow = -1
	tReads = 0
	For tCurrentRow = inStartRowIndex + 1 To inLastRowIndex		
		
		Select Case inWorkSheet.Rows(tCurrentRow).OutlineLevel
			Case 2: 
				tContractName = LCase(inWorkSheet.Cells(tCurrentRow, inScanCol).Value)
				
				tContractVal = inWorkSheet.Cells(tCurrentRow, inValCol).Value 'need check TODO
				tContractCost = inWorkSheet.Cells(tCurrentRow, inCostCol).Value 'need check TODO
			Case 3:			
				tValue = LCase(inWorkSheet.Cells(tCurrentRow, inScanCol).Value)
				If InStr(tValue, inScanWord) <= 0 Then: Exit For
				
				tReads = tReads + 1				
				tTempVal = inWorkSheet.Cells(tCurrentRow, inValCol).Value 'need check TODO
				tTempCost = inWorkSheet.Cells(tCurrentRow, inCostCol).Value 'need check TODO
				
				If fGetMethodResult(tTempVal, tEtalonVal, tMethod) Then
					ioValStore = ioValStore + tTempVal
					ioCostStore = ioCostStore + tTempCost
					
					fAddContractData ioContractList, ioContractSize, tContractName, inStringCode, tTempVal, tTempCost, tContractVal, tContractCost
				
					tLockedRow = tCurrentRow
					fLogLine tLogTag, "Нода [" & inExtractNode.NodeName & "]: [code=" & inStringCode & "] @gtpcode=[" & tGTPCode & "][" & tEtalonVal & "] по методу [" & tMethod & "] нашла подходящий элемент в строке [" & tCurrentRow & "]: VAL=" & tTempVal & "; COST=" & tTempCost
					Exit For
				End If				
			Case Else: Exit For 'dropscan (out)
		End Select		
	Next
	
	'check scan result
	If tLockedRow = -1 Or tReads = 0 Then
		fLogLine tLogTag, "Ошибка расчёта ноды [" & inExtractNode.NodeName & "]: @gtpcode=[" & tGTPCode & "][" & tEtalonVal & "] по методу [" & tMethod & "] не было найдено подходящих значений!"
		fLogLine tLogTag, "В файле типа [BaseB] обнаружено субэлементов (всего: " & tReads & ") [" & inScanWord & "] для организации [строка:" & inStartRowIndex & "]"
		If inSafeRead Then: On Error GoTo 0
		Exit Function
	End If
	
	If inSafeRead Then: On Error GoTo 0
	fScanMethod_FinReport = True
End Function

Private Function fScanMethod_Default(inExtractNode, inWorkSheet, inStartRowIndex, inLastRowIndex, inScanCol, inValCol, inCostCol, inStringCode, inScanWord, ioValStore, ioCostStore, ioContractList, ioContractSize, inSafeRead)
	Dim tLogTag, tMethod, tMinValue, tMaxValue, tMinValCost, tMaxValCost, tMinValRow, tMaxValRow, tMinValContractRow, tMaxValContractRow
	Dim tLockedRow, tCurrentRow, tValue, tTempVal, tTempCost, tReads
	Dim tContractVal, tContractCost, tContractName, tContractRow
	
	'defaults
	fScanMethod_Default = False
	tLogTag = "fScanMethod_Default"
	
	'quick check #1
	If inExtractNode Is Nothing Then
		fLogLine tLogTag, "Входная нода inExtractNode оказалась не инициализированной!"
		Exit Function
	End If
	
	'quick check #2
	If Not (IsNumeric(inStartRowIndex) And IsNumeric(inLastRowIndex)) Then
		fLogLine tLogTag, "Ошибка! Входные параметры имеют нечисловые значния: inStartRowIndex[" & inStartRowIndex & "] // inLastRowIndex[" & inLastRowIndex & "]"
		Exit Function
	ElseIf inStartRowIndex <=0 Or inLastRowIndex <= 0 Then
		fLogLine tLogTag, "Ошибка! Входные параметры имеют значния меньше или равные нулю: inStartRowIndex[" & inStartRowIndex & "] // inLastRowIndex[" & inLastRowIndex & "]"
		Exit Function
	End If
	
	'saferead trigger
	If inSafeRead Then: On Error Resume Next
	
	'get method
	tMethod = UCase(fAutoCorrectString(inExtractNode.GetAttribute("method"), True))
	Select Case tMethod
		Case "MINVAL": 
		Case "MAXVAL": 
		Case Else:
			fLogLine tLogTag, "Ошибка синтаксиса ноды [" & inExtractNode.NodeName & "]: аттрибут @method не может иметь значния [" & tMethod & "]!"
			If inSafeRead Then: On Error GoTo 0
			Exit Function
	End Select
				
	'defaults
	tMinValRow = 0
	tMaxValRow = 0
				
	'scan
	tLockedRow = -1
	tReads = 0
	For tCurrentRow = inStartRowIndex + 1 To inLastRowIndex
	
		Select Case inWorkSheet.Rows(tCurrentRow).OutlineLevel
			Case 2: 
				tContractRow = tCurrentRow
			Case 3: 
				tValue = LCase(inWorkSheet.Cells(tCurrentRow, inScanCol).Value)
				If InStr(tValue, inScanWord) <= 0 Then: Exit For
				
				tTempVal = inWorkSheet.Cells(tCurrentRow, inValCol).Value 'need check TODO
				tTempCost = inWorkSheet.Cells(tCurrentRow, inCostCol).Value 'need check TODO
				
				'min by val
				If tMinValRow = 0 Then
					tMinValue = tTempVal
					tMinValCost = tTempCost
					tMinValRow = tCurrentRow
					tMinValContractRow = tContractRow
				ElseIf tTempVal < tMinValue Then
					tMinValue = tTempVal
					tMinValCost = tTempCost
					tMinValRow = tCurrentRow
					tMinValContractRow = tContractRow
				End If
							
				'max by val
				If tMaxValRow = 0 Then
					tMaxValue = tTempVal
					tMaxValCost = tTempCost
					tMaxValRow = tCurrentRow
					tMaxValContractRow = tContractRow
				ElseIf tTempVal > tMaxValue Then
					tMaxValue = tTempVal
					tMaxValCost = tTempCost
					tMaxValRow = tCurrentRow
					tMaxValContractRow = tContractRow
				End If
				
				tReads = tReads + 1
			Case Else: Exit For
		End Select
		
	Next
	
	'check results
	If tReads = 0 Then
		fLogLine tLogTag, "Ошибка вычисления ноды [" & inExtractNode.NodeName & "] по методу [" & tMethod & "]: в файле типа [BaseB] не обнаружено субэлементов [" & inScanWord & "] для организации [строка:" & inStartRowIndex & "]"
		If inSafeRead Then: On Error GoTo 0
		Exit Function
	End If
				
	'form results
	Select Case tMethod
		Case "MINVAL":
			tTempVal = tMinValue
			tTempCost = tMinValCost
			tCurrentRow = tMinValRow
			tContractRow = tMinValContractRow
		Case "MAXVAL": 						
			tTempVal = tMaxValue
			tTempCost = tMaxValCost
			tCurrentRow = tMaxValRow
			tContractRow = tMaxValContractRow
	End Select
	
	'contract extract
	tContractName = LCase(inWorkSheet.Cells(tContractRow, inScanCol).Value)
				
	tContractVal = inWorkSheet.Cells(tContractRow, inValCol).Value 'need check TODO
	tContractCost = inWorkSheet.Cells(tContractRow, inCostCol).Value 'need check TODO
				
	fAddContractData ioContractList, ioContractSize, tContractName, inStringCode, tTempVal, tTempCost, tContractVal, tContractCost
				
	'drop results
	ioValStore = ioValStore + tTempVal
	ioCostStore = ioCostStore + tTempCost
	fLogLine tLogTag, "Нода [" & inExtractNode.NodeName & "]: [code=" & inStringCode & "] по методу [" & tMethod & "] нашла подходящий элемент в строке [" & tCurrentRow & "]: VAL=" & tTempVal & "; COST=" & tTempCost
	fScanMethod_Default = True
End Function

Private Function fCollectInternalConracts(inWorkSheet, inStartRowIndex, inLastRowIndex, inScanCol, inValCol, inCostCol, inStringCode, ioContractList, ioContractSize, inSafeRead)
	Dim tLogTag, tValue, tContractName, tContractVal, tContractCost, tReads, tCurrentRow
	
	tLogTag = "fCollectInternalConracts"
	fCollectInternalConracts = False
	
	'saferead trigger
	If inSafeRead Then: On Error Resume Next
	
	'scan
	tReads = 0
	For tCurrentRow = inStartRowIndex + 1 To inLastRowIndex
	
		Select Case inWorkSheet.Rows(tCurrentRow).OutlineLevel
			Case 2:
				tValue = LCase(inWorkSheet.Cells(tCurrentRow, inScanCol).Value)
				tContractName = Left(tValue, InStr(tValue, " ") - 1)
				
				tContractVal = inWorkSheet.Cells(tCurrentRow, inValCol).Value 'need check TODO
				tContractCost = inWorkSheet.Cells(tCurrentRow, inCostCol).Value 'need check TODO
				
				fAddContractData ioContractList, ioContractSize, tContractName, inStringCode, tContractVal, tContractCost, tContractVal, tContractCost
				
				tReads = tReads + 1
			Case 3:				
			Case Else: Exit For
		End Select
		
	Next
	
	If tReads = 0 Then
		fLogLine tLogTag, "Не удалось обнаружить записей договоров // tReads=0"
		If inSafeRead Then: On Error GoTo 0
		Exit Function
	End If
	
	If inSafeRead Then: On Error GoTo 0
	fCollectInternalConracts = True
End Function

'tOrgContNode, inWorkBookB, tDataArray, tDataArraySize, tDataArrayLength, tPartVal, tPartCost
Private Function fGetBaseBValues(inContentNode, inBaseB, ioDataArray, ioDataArraySize, inDataArrayLength, inDefaultCode, inContractList, inContractSize, inSafeRead)
	Dim tLogTag, tOrgID, tOrgNode, tOrgName1C, tXPathString, tSheetIndex, tLastRow, tCurrentRow, tCurrentCol, tValue, tIndexRow, tGTPCode, tFinReportUse, tMethod, tTempValue
	Dim tExtractNodes, tExtractNode, tTotalVal, tVal, tCost, tValueCol, tCostCol, tNameCol, tTempVal, tTempCost, tLockedRow, tEtalonVal, tTotalCost, tCodeIndex
	Dim tValueIndex, tCostIndex, tStringCode, tMinValue, tMaxValue, tMinValCost, tMaxValCost, tTempValIndex, tTempCostIndex
	
	'defaults
	fGetBaseBValues = False
	tLogTag = "fGetBaseBValues"	
	tSheetIndex = 1
	tNameCol = 1
	tValueCol = 11
	tCostCol = 13
	
	tValueIndex = 1
	tCostIndex = 5
	tTempValIndex = 20
	tTempCostIndex = 21
	inContractSize = -1
	
	'lock org node by id
	tOrgID = fAutoCorrectNumeric(inContentNode.getAttribute("id"), 0, 0, "ANY")
	tXPathString = "ancestor::message/organizations/organization[@id=" & tOrgID & "]/name1c"
	Set tOrgNode = inContentNode.SelectSingleNode(tXPathString)
	
	If tOrgNode Is Nothing Then
		fLogLine tLogTag, "Не удалось найти <имя 1С> в списке оргарнизаций ИНДЕКС [" & tOrgID & "]; XPath = <" & tXPathString & ">"
		Exit Function
	End If
		
	'locking BaseB org by OrgName1C
	tOrgName1C = tOrgNode.Text
	fLogLine tLogTag, "Чтение отчета типа [BaseB] Наименование 1С (ID=" & tOrgID & "): " & tOrgName1C & " [" & fAutoCorrectString(tOrgNode.SelectSingleNode("ancestor::organization/namedefault").Text, False) & "]"	
	
	If inSafeRead Then: On Error Resume Next
		
	' quick check	
	tLastRow = inBaseB.WorkSheets(tSheetIndex).Cells.SpecialCells(11).Row
	If Err.Number <> 0 Then
		fLogLine tLogTag, "Лист с ИНДЕКСОМ=" & tSheetIndex & " отчета BaseB не удалось прочитать!"
		On Error GoTo 0
		Exit Function
	End If
	
	' lock ORG row in BaseB
	tCurrentCol = tNameCol
	tCurrentRow = 3 'start from ROW=3
	tIndexRow = 0
	tOrgName1C = LCase(tOrgName1C)
	
	Do
		tValue = LCase(inBaseB.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value)		
		If tValue = tOrgName1C Then
			tIndexRow = tCurrentRow
			Exit Do
		End If		
		tCurrentRow = tCurrentRow + 1
	Loop While tCurrentRow <= tLastRow
	
	' not locked?
	If tIndexRow = 0 Then
		fLogLine tLogTag, "Искомую организацию не удалось найти в отчете типа [BaseB]"
		On Error GoTo 0
		Exit Function
	End If
	
	'fLogLine tLogTag, "Row=" & 1 & " L=" & inBaseB.WorkSheets(tSheetIndex).Rows(1).OutlineLevel 
	
	'default reads (non-ruled)
	tTotalVal = inBaseB.WorkSheets(tSheetIndex).Cells(tIndexRow, tValueCol).Value 'value	
	tTotalCost = inBaseB.WorkSheets(tSheetIndex).Cells(tIndexRow, tCostCol).Value 'cost
	'fLogLine tLogTag, "VAL=" & tTotalVal & " COST=" & tTotalCost
	
	'reset val\cost
	For tCodeIndex = 0 To ioDataArraySize
		ioDataArray(tTempValIndex, tCodeIndex) = 0
		ioDataArray(tTempCostIndex, tCodeIndex) = 0
	Next
	
	If inSafeRead Then: On Error GoTo 0	
	
	' extract nodes work
	tXPathString = "child::extract"
	Set tExtractNodes = inContentNode.SelectNodes(tXPathString)
	
	If tExtractNodes.Length > 0 Then
		
		'collecting
		For Each tExtractNode In tExtractNodes
			
			'code extraction OR drop to default (if no mention)
			tStringCode = fAutoCorrectString(tExtractNode.GetAttribute("code"), True)
			'fLogLine tLogTag, "CODE_R=" & tStringCode
			fAddNewCodeString ioDataArray, ioDataArraySize, inDataArrayLength, tStringCode
			If tStringCode = vbNullString Then: tStringCode = inDefaultCode
			'fLogLine tLogTag, "CODE_F=" & tStringCode
			
			tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, tStringCode)

			If tCodeIndex = -1 Then
				fLogLine tLogTag, "Не удалось определить индекс строки по умолчанию [аттрибут @code]: искомый код <" & tStringCode & ">"			
				Exit Function
			End If
			
			'using finreport groups?
			'tFinReportUse = fAutoCorrectNumeric(tExtractNode.GetAttribute("finreportuse"), 0, 0, 1) = 1

			If fAutoCorrectNumeric(tExtractNode.GetAttribute("finreportuse"), 0, 0, 1) = 1 Then
					 'fScanMethod_FinReport(inExtractNode, inWorkSheet, 					inSheetIndex, inStartRowIndex, inLastRowIndex, inScanCol, inValCol, inCostCol, inStringCode, inScanWord, ioValStore, ioCostStore, inSafeRead)
				If Not fScanMethod_FinReport(tExtractNode, inBaseB.WorkSheets(tSheetIndex), tIndexRow, tLastRow, tCurrentCol, tValueCol, tCostCol, tStringCode, "реализация", ioDataArray(tTempValIndex, tCodeIndex), ioDataArray(tTempCostIndex, tCodeIndex), inContractList, inContractSize, inSafeRead) Then
					Exit Function
				End If
			Else
				If Not fScanMethod_Default(tExtractNode, inBaseB.WorkSheets(tSheetIndex), tIndexRow, tLastRow, tCurrentCol, tValueCol, tCostCol, tStringCode, "реализация", ioDataArray(tTempValIndex, tCodeIndex), ioDataArray(tTempCostIndex, tCodeIndex), inContractList, inContractSize, inSafeRead) Then
					Exit Function
				End If				
			End If
		Next
		
	'non-ruled	1 TO 1
	Else
		tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, inDefaultCode)
		If tCodeIndex = -1 Then
			fLogLine tLogTag, "Не удалось определить индекс строки по умолчанию [аттрибут @code]: искомый код <" & inDefaultCode & ">"			
			Exit Function
		End If
		
		ioDataArray(tTempValIndex, tCodeIndex) = tTotalVal
		ioDataArray(tTempCostIndex, tCodeIndex) = tTotalCost
		
		If Not fCollectInternalConracts(inBaseB.WorkSheets(tSheetIndex), tIndexRow, tLastRow, tCurrentCol, tValueCol, tCostCol, inDefaultCode, inContractList, inContractSize, inSafeRead) Then
			Exit Function
		End If
	End If
	
	'finalyze koef
	For tCodeIndex = 0 To ioDataArraySize
		fLogLine tLogTag, "Извлечение данных успешно [Договоров: " & inContractSize + 1 & "][Code: " & ioDataArray(0, tCodeIndex) & "]: TOTAL=" & tTotalVal & "; VAL=" & ioDataArray(tTempValIndex, tCodeIndex) & "; TOTALCOST=" & tTotalCost & "; COST=" & ioDataArray(tTempCostIndex, tCodeIndex)
	Next
		
	fGetBaseBValues = True	
End Function

Private Function fGetBaseAValues(inContentNode, inBaseA, ioDataArray, ioDataArraySize, inDataArrayLength, inDefaultCode, inContractList, inContractSize, inSafeRead)
	Dim tLogTag, tOrgID, tXPathString, tOrgNode, tOrgName1C, tCurrentCol, tCurrentRow, tSheetIndex, tLastRow, tIndexRow, tValue, tContractRow, tScanCol, tCostPart, tValPart
	Dim tValueA, tValueB, tContractIndex, tNameElements, tContractName, tStringCode, tNameString, tCodeIndex, tPartIndex
	Dim tDebtCost, tIncomeCost, tFactIncomeCost, tEndCredCost, tEndDebtCost
	
	'defaults
	tLogTag = "fGetBaseAValues"
	fGetBaseAValues = False
	tSheetIndex = 1
	tScanCol = 1

	'lock org node by id
	tOrgID = fAutoCorrectNumeric(inContentNode.getAttribute("id"), 0, 0, "ANY")
	tXPathString = "ancestor::message/organizations/organization[@id=" & tOrgID & "]/name1c"
	Set tOrgNode = inContentNode.SelectSingleNode(tXPathString)
	
	If tOrgNode Is Nothing Then
		fLogLine tLogTag, "Не удалось найти <имя 1С> в списке оргарнизаций ИНДЕКС [" & tOrgID & "]; XPath = <" & tXPathString & ">"
		Exit Function
	End If
		
	'locking BaseB org by OrgName1C
	tOrgName1C = tOrgNode.Text
	fLogLine tLogTag, "Чтение отчета типа [BaseA] Наименование 1С (ID=" & tOrgID & "): " & tOrgName1C & " [" & fAutoCorrectString(tOrgNode.SelectSingleNode("ancestor::organization/namedefault").Text, False) & "]"
	
	If inSafeRead Then: On Error Resume Next
		
	' quick check	
	tLastRow = inBaseA.WorkSheets(tSheetIndex).Cells.SpecialCells(11).Row
	If Err.Number <> 0 Then
		fLogLine tLogTag, "Лист с ИНДЕКСОМ=" & tSheetIndex & " отчета типа [BaseA] не удалось прочитать!"
		If inSafeRead Then: On Error GoTo 0
		Exit Function
	End If
	
	' lock ORG row in BaseB
	tCurrentCol = tScanCol
	tIndexRow = 0
	tOrgName1C = LCase(tOrgName1C)
	
	For tCurrentRow = 3 To tLastRow
		If inBaseA.WorkSheets(tSheetIndex).Rows(tCurrentRow).OutlineLevel = 1 Then 'to short checks
			tValue = LCase(inBaseA.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value)
			If tValue = tOrgName1C Then
				tIndexRow = tCurrentRow
				Exit For
			End If
		End If
	Next
	
	' not locked?
	If tIndexRow = 0 Then
		fLogLine tLogTag, "Искомую организацию не удалось найти в отчете типа [BaseA]"
		If inSafeRead Then: On Error GoTo 0
		Exit Function
	End If
	
	'scan for contract records
	For tContractIndex = 0 To inContractSize
	
		tContractName = inContractList(0, tContractIndex)
		tStringCode = inContractList(1, tContractIndex)
		tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, tStringCode)
		
		'part index (koef)
		If inContractList(5, tContractIndex) <> 0 Then
			tPartIndex = inContractList(3, tContractIndex) / inContractList(5, tContractIndex)
		Else
			tPartIndex = 0
		End If
		
		'check
		If tCodeIndex = -1 Then
			fLogLine tLogTag, "Не удалось определить индекс строки // искомый код <" & inDefaultCode & ">"
			If inSafeRead Then: On Error GoTo 0
			Exit Function
		End If
		
		'scan
		tContractRow = 0
		For tCurrentRow = tIndexRow + 1 To tLastRow
			Select Case inBaseA.WorkSheets(tSheetIndex).Rows(tCurrentRow).OutlineLevel
				Case 2:	
					tNameElements = Split(Trim(inBaseA.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value), " ")
					tNameString = UCase(tNameElements(0))
					
					'locked contract
					If tNameString = tContractName Then
						tContractRow = tCurrentRow
						
						'BEGIN // DEBT COST
						tValueA = inBaseA.WorkSheets(tSheetIndex).Cells(tContractRow, 3).Value 'долг на начало
						tValueB = inBaseA.WorkSheets(tSheetIndex).Cells(tContractRow, 4).Value 'аванс на начало
						tDebtCost = tValueA - tValueB
						tDebtCost = tDebtCost * tPartIndex
						ioDataArray(2, tCodeIndex) = ioDataArray(2, tCodeIndex) + tDebtCost
						
						'INCOME COST
						tIncomeCost = inBaseA.WorkSheets(tSheetIndex).Cells(tContractRow, 5).Value
						tIncomeCost = tIncomeCost * tPartIndex
						ioDataArray(3, tCodeIndex) = ioDataArray(3, tCodeIndex) + tIncomeCost 'продано
								
						'INCOME FACT COST
						tValueA = inBaseA.WorkSheets(tSheetIndex).Cells(tContractRow, 6).Value 'оплачено
						tValueB = inBaseA.WorkSheets(tSheetIndex).Cells(tContractRow, 8).Value 'поступило
						tFactIncomeCost = tValueA + tValueB
						tFactIncomeCost = tFactIncomeCost * tPartIndex
						ioDataArray(4, tCodeIndex) = ioDataArray(4, tCodeIndex) + tFactIncomeCost
						
						'END // CRED COST
						tEndCredCost = inBaseA.WorkSheets(tSheetIndex).Cells(tContractRow, 11).Value
						tEndCredCost = tEndCredCost * tPartIndex
						ioDataArray(10, tCodeIndex) = ioDataArray(10, tCodeIndex) + tEndCredCost 'аванс на конец
						
						'END // DEBT COST
						tEndDebtCost = inBaseA.WorkSheets(tSheetIndex).Cells(tContractRow, 10).Value
						tEndDebtCost = tEndDebtCost * tPartIndex
						ioDataArray(12, tCodeIndex) = ioDataArray(12, tCodeIndex) + tEndDebtCost 'долг на конец
						
						'LOGGING
						fLogLine tLogTag, "Данные договора [" & tStringCode & ":" & tContractName & "] успешно извлечены [К=" & tPartIndex & "]: " & tDebtCost & " / " & tIncomeCost & " / " & tFactIncomeCost & " / " & tEndCredCost & " / " & tEndDebtCost
					End If
				Case Else: Exit For
			End Select
		Next
		
		'lock check
		If tContractRow = 0 Then
			fLogLine tLogTag, "Договор [" & tContractName & "] не удалось найти в файле отчета типа [BaseA]."
			If inSafeRead Then: On Error GoTo 0
			Exit Function
		End If
	Next
	
	'check errors
	If Err.Number <> 0 Then
		fLogLine tLogTag, "При чтении данных произошла ошибка #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
		If inSafeRead Then: On Error GoTo 0
		Exit Function
	End If

	'success return
	If inSafeRead Then: On Error GoTo 0	
	fGetBaseAValues = True
End Function

Private Function fMakeBlankTemplate(inContentNode, inTemplateFile, inYear, inMonth, inRootFolder, inSubjectID, inSubjectName, outResultFile)
	Dim tLogTag, tTemplateNode, tXPathString, tDropFolder, tNode, tCanCreate, tFileName, tExtension, tFullPath
	
	tLogTag = "fMakeBlankTemplate"
	fMakeBlankTemplate = False
	Set outResultFile = Nothing
	
	'file node
	tXPathString = "ancestor::message/workfiles/file[@id='template']"
	Set tTemplateNode = inContentNode.SelectSingleNode(tXPathString)
	If tTemplateNode Is Nothing Then
		fLogLine tLogTag, "Не удалось извлечь ноду файла типа [template] XPath <" & tXPathString & ">"
		Exit Function
	End If
	
	'dropfolder resolver
	tXPathString = "child::outpath"
	Set tNode = tTemplateNode.SelectSingleNode(tXPathString)
	If tNode Is Nothing Then
		fLogLine tLogTag, "Не удалось извлечь ноду файла типа [template] XPath <" & tXPathString & ">"
		Exit Function
	End If
	
	tCanCreate = fAutoCorrectNumeric(tNode.GetAttribute("autocreate"), 0, 0, 1) = 1
	tDropFolder = fReprocessMask(tNode.Text, inYear, inMonth, inRootFolder)
	If Not gFSO.FolderExists(tDropFolder) Then
		If Not tCanCreate Then
			fLogLine tLogTag, "Не удалось ОБНАРУЖИТЬ папку для формирования итогов работы [" & tNode.Text & "]: " & tDropFolder
			Exit Function
		End If
		'create new?
		On Error Resume Next
			gFSO.CreateFolder tDropFolder
			If Err.Number <> 0 Or Not gFSO.FolderExists(tDropFolder) Then
				fLogLine tLogTag, "Ошибка при создании новой папки #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
				fLogLine tLogTag, "Не удалось ОБНАРУЖИТЬ и СОЗДАТЬ папку для формирования итогов работы [" & tNode.Text & "]: " & tDropFolder
				On Error GoTo 0
				Exit Function
			End If
		On Error GoTo 0
	End If
	
	'now we have a dropfolder -> copy template file to dropfolder
	tXPathString = "child::mask"
	Set tNode = tTemplateNode.SelectSingleNode(tXPathString)
	If tNode Is Nothing Then
		fLogLine tLogTag, "Не удалось извлечь ноду файла типа [template] XPath <" & tXPathString & ">"
		Exit Function
	End If
	tExtension = "." & fAutoCorrectString(tNode.GetAttribute("ext"), True)
	If tExtension = "." Then
		fLogLine tLogTag, "Не удалось извлечь обязательный аттрибут @ext ноды файла типа [template] XPath <" & tXPathString & ">"
		Exit Function
	End If
	
	tXPathString = "child::outname"
	Set tNode = tTemplateNode.SelectSingleNode(tXPathString)
	If tNode Is Nothing Then
		fLogLine tLogTag, "Не удалось извлечь ноду файла типа [template] XPath <" & tXPathString & ">"
		Exit Function
	End If	
	tFileName = fReprocessMask(tNode.Text, inYear, inMonth, inRootFolder) & tExtension
	tFileName = Replace(tFileName, "#R#", fNZeroAdd(inSubjectID, 2))
	tFileName = Replace(tFileName, "#RNAME#", inSubjectName)
	
	'copy
	tFullPath = tDropFolder & "\" & tFileName
	On Error Resume Next
		gFSO.CopyFile inTemplateFile, tFullPath, True 'overwrite
		If Err.Number <> 0 Or Not gFSO.FileExists(tFullPath) Then
			fLogLine tLogTag, "Ошибка при копировании файла типа [template] #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
			fLogLine tLogTag, "Не удалось создать копию файла типа [template] [" & tNode.Text & "]: " & tFileName
			fLogLine tLogTag, "Возможно файл кем-то открыт."
			On Error GoTo 0
			Exit Function
		End If
	On Error GoTo 0
	
	Set outResultFile = gFSO.GetFile(tFullPath)
	fMakeBlankTemplate = True
End Function

Private Function fFillBlankTemplate(inContentNode, inWorkBook, inYear, inMonth, inSubjectID, inSubjectName)
	Dim tLogTag, tLastRow, tSheetIndex, tScanIndexCol, tXPathString, tNode
	Dim tInfoNode, tConstFieldsNodes, tOrgName, tOrgID, tCurrentRow, tCurrentCol, tMonthCyr, tValue, tIndex
	Dim tCode, tShift
	Dim tIndexCode()
	Dim tIndexRow()
	Dim tIndexSize
	
	'defaults
	tLogTag = "fFillBlankTemplate"
	fFillBlankTemplate = False
	tSheetIndex = 1
	tScanIndexCol = gCodeScanColumn
	
	'lock info nodes
	tXPathString = "ancestor::message/constfields/field"
	Set tConstFieldsNodes = inContentNode.SelectNodes(tXPathString)
	
	'INFO
	tXPathString = "ancestor::message/info"
	Set tInfoNode = inContentNode.SelectSingleNode(tXPathString)
	If tInfoNode Is Nothing Then
		fLogLine tLogTag, "Не удалось извлечь ноду [info] XPath <" & tXPathString & ">"
		Exit Function
	End If
	
	'INFO/NAME
	tXPathString = "child::name"
	Set tNode = tInfoNode.SelectSingleNode(tXPathString)
	If tNode Is Nothing Then
		fLogLine tLogTag, "Не удалось извлечь ноду родителя [" & tInfoNode.NodeName & "] XPath <" & tXPathString & ">"
		Exit Function
	End If
	tOrgName = tNode.Text
	
	'INFO/REGID
	tXPathString = "child::regid"
	Set tNode = tInfoNode.SelectSingleNode(tXPathString)
	If tNode Is Nothing Then
		fLogLine tLogTag, "Не удалось извлечь ноду родителя [" & tInfoNode.NodeName & "] XPath <" & tXPathString & ">"
		Exit Function
	End If
	tOrgID = tNode.Text
	
	On Error Resume Next
	'fLogLine tLogTag, "#1"
	
	' quick check
	tLastRow = inWorkBook.WorkSheets(tSheetIndex).Cells.SpecialCells(11).Row
	If Err.Number <> 0 Then
		fLogLine tLogTag, "Лист с ИНДЕКСОМ=" & tSheetIndex & " отчета типа [template] результата не удалось прочитать!"
		On Error GoTo 0
		Exit Function
	End If
	
	'fLogLine tLogTag, "#2"
	'INFO
	tCurrentRow = 3
	tCurrentCol = 5
	tMonthCyr = fMonthD2C(inMonth)
	tMonthCyr = UCase(Left(tMonthCyr, 1)) & Right(tMonthCyr, Len(tMonthCyr) - 1)
	inWorkBook.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value = tMonthCyr & " " & inYear
	
	tCurrentRow = 4
	tCurrentCol = 5	
	inWorkBook.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value = tOrgID
	
	tCurrentRow = 4
	tCurrentCol = 6
	inWorkBook.WorkSheets(tSheetIndex).Cells(tCurrentRow, tCurrentCol).Value = tOrgName & " (" & inSubjectName & ")"
	'fLogLine tLogTag, "#3"
	'CONSTFIELDS	
	For Each tNode In tConstFieldsNodes
		tCode = fAutoCorrectNumeric(tNode.GetAttribute("code"), 0, 0, "ANY")
		tShift = fAutoCorrectNumeric(tNode.GetAttribute("shift"), 0, 0, "ANY")
		For tIndex = 0 To gCodeArraySize			
			If gCodeArray(tIndex) = tCode Then
				inWorkBook.WorkSheets(tSheetIndex).Cells(gRowArray(tIndex), tScanIndexCol + tShift).Value = tNode.Text
				Exit For
			End If			
		Next
	Next
	'fLogLine tLogTag, "#4"
	' success return
	
	fFillBlankTemplate = True
End Function

Private Function fGetIndexTableTemplate(inWorkBook, inCodeCol, outCodeArray, outRowArray, outArraySize)
	Dim tLogTag, tSheetIndex, tCurrentRow, tLastRow, tValue
	
	tLogTag = "fGetIndexTableTemplate"
	fGetIndexTableTemplate = False
	tSheetIndex = 1
	
	fLogLine tLogTag, "Начата индексация файла типа [template][лист: " & tSheetIndex & "] столбец кодов [" & inCodeCol & "]."
	
	On Error Resume Next
	
	' quick check
	tLastRow = inWorkBook.WorkSheets(tSheetIndex).Cells.SpecialCells(11).Row
	If Err.Number <> 0 Then
		fLogLine tLogTag, "Лист с ИНДЕКСОМ=" & tSheetIndex & " отчета типа [template] результата не удалось прочитать!"
		On Error GoTo 0
		Exit Function
	End If
	
	outArraySize = -1
	For tCurrentRow = 1 To tLastRow
		tValue = inWorkBook.WorkSheets(tSheetIndex).Cells(tCurrentRow, inCodeCol).Value
		If IsNumeric(tValue) Then
			If Fix(tValue) > 0 Then
				outArraySize = outArraySize + 1
				ReDim Preserve outCodeArray(outArraySize)
				ReDim Preserve outRowArray(outArraySize)
				
				outCodeArray(outArraySize) = Fix(tValue)
				outRowArray(outArraySize) = tCurrentRow
			End If
		End If
	Next
	
	If Err.Number <> 0 Then
		fLogLine tLogTag, "При чтении данных произошла в [" & Err.Source & "] ошибка #" & Err.Number & ": " & Err.Description
		On Error GoTo 0
		Exit Function
	End If
		
	On Error GoTo 0
	
	fLogLine tLogTag, "Индексация файла типа [template] успешна. Прочитано: " & outArraySize
	fGetIndexTableTemplate = True
End Function

Private Function fFillDataTemplate(inWorkBook, inDataArray, inDataArraySize, inDataArrayLength)
	Dim tLogTag, tCodeString, tCode, tCodeScanCol, tIndex
	Dim tDataRow, tSheetIndex, tCodeIndex
	
	tLogTag = "fFillDataTemplate"
	fFillDataTemplate = False
	tCodeScanCol = gCodeScanColumn
	tSheetIndex = 1
	'tCodeElements = Split(inCodeStrings, ":")
	
	On Error Resume Next
	
	For tCodeIndex = 0 To inDataArraySize
		tCodeString = inDataArray(0, tCodeIndex)
		If IsNumeric(tCodeString) Then
			tDataRow = 0
			tCode = Fix(tCodeString)
			For tIndex = 0 To gCodeArraySize
				If tCode = gCodeArray(tIndex) Then
					tDataRow = gRowArray(tIndex)
					Exit For
				End If
			Next
			
			If tDataRow > 0 Then
				For tIndex = 1 To inDataArrayLength
					If Not IsEmpty(inDataArray(tIndex, tCodeIndex)) Then
						inWorkBook.WorkSheets(tSheetIndex).Cells(tDataRow, tCodeScanCol + tIndex).Value = inDataArray(tIndex, tCodeIndex)
					End If
				Next
			Else
				fLogLine tLogTag, "Внимание! Неизвестный код на входе: " & tCodeString
				On Error GoTo 0
				Exit Function
			End If
		End If
	Next
	
	'errcheck
	If Err.Number <> 0 Then
		fLogLine tLogTag, "При чтении данных произошла в [" & Err.Source & "] ошибка #" & Err.Number & ": " & Err.Description
		On Error GoTo 0
		Exit Function
	End If
	
	On Error GoTo 0	
	fFillDataTemplate = True
End Function

Private Sub fAddNewCodeString(ioArray, ioSize, inLength, inCode)
	Dim tIndex
	
	If inCode = vbNullString Then: Exit Sub
	
	'lock
	For tIndex = 0 To ioSize
		If ioArray(0, tIndex) = inCode Then: Exit Sub
	Next
	
	'create new
	ioSize = ioSize + 1
	ReDim Preserve ioArray(inLength, ioSize)
	ioArray(0, ioSize) = inCode
	'fLogLine "ARR_ADD", inCode
End Sub

Private Function fGetCodeIndex(ioArray, ioSize, inCode)
	Dim tIndex
	
	fGetCodeIndex = -1
	
	For tIndex = 0 To ioSize
		If ioArray(0, tIndex) = inCode Then
			fGetCodeIndex = tIndex
			Exit Function
		End If
	Next
	
End Function

Private Function fCreateReportByContentNode(inContentNode, inTemplateFile, inWorkBookA, inWorkBookB, inYear, inMonth, inRootFolder, inSubjectID, inSubjectName)
	Dim tLogTag, tOrgContNodes, tOrgContNode ', tTotalVal, tTargetVal, tTotalCost, tTargetCost
	'Dim tDebtCost, tIncomeCost, tFactIncomeCost, tEndCredCost, tEndDebtCost, , tResultWorkBook, tDefaultCode
	Dim tDataArray()
	Dim tDataArraySize, tDataArrayLength, tCodeIndex, tDataArrayActLength
	Dim tResultWorkBook, tDefaultCode, tResultFile
	Dim tContractList()
	Dim tContractSize, tOrgIndex
	
	tLogTag = "fCreateReportByContentNode"
	fCreateReportByContentNode = False
	tDataArraySize = -1
	tOrgIndex = 1
	'inContractListSize = -1
	tDataArrayActLength = 19
	tDataArrayLength = tDataArrayActLength + 2 '19 + 2 internal vals '20=TempVAL 21=TempCOST
	
	fLogLine tLogTag, "###### Сборка контента начата..."
	
	'scan
	Set tOrgContNodes = inContentNode.SelectNodes("descendant::organization")
	For Each tOrgContNode In tOrgContNodes
	
		fLogLine tLogTag, " >> Сборка: Элемента #" & tOrgIndex & " из " & tOrgContNodes.Length
		
		tDefaultCode = fAutoCorrectString(tOrgContNode.GetAttribute("code"), True)
		fAddNewCodeString tDataArray, tDataArraySize, tDataArrayLength, tDefaultCode		
				
		If Not fGetBaseBValues(tOrgContNode, inWorkBookB, tDataArray, tDataArraySize, tDataArrayLength, tDefaultCode, tContractList, tContractSize, False) Then: Exit Function
		If Not fGetBaseAValues(tOrgContNode, inWorkBookA, tDataArray, tDataArraySize, tDataArrayLength, tDefaultCode, tContractList, tContractSize, False) Then: Exit Function	

		'sum it
		For tCodeIndex = 0 To tDataArraySize
			tDataArray(1, tCodeIndex) = tDataArray(1, tCodeIndex) + tDataArray(20, tCodeIndex)
			tDataArray(5, tCodeIndex) = tDataArray(5, tCodeIndex) + tDataArray(21, tCodeIndex)			
		Next
		
		tOrgIndex = tOrgIndex + 1
	Next
	
	fLogLine tLogTag, "###### Сборка закончена!"
	
	'correction
	For tCodeIndex = 0 To tDataArraySize
		tDataArray(1, tCodeIndex) = tDataArray(1, tCodeIndex) 'nothing to do
		tDataArray(5, tCodeIndex) = Round(tDataArray(5, tCodeIndex) / 1000, 3)
		tDataArray(2, tCodeIndex) = Round(tDataArray(2, tCodeIndex) / 1000, 3)
		tDataArray(3, tCodeIndex) = Round(tDataArray(3, tCodeIndex) / 1000, 3)
		tDataArray(4, tCodeIndex) = Round(tDataArray(4, tCodeIndex) / 1000, 3)
		tDataArray(10, tCodeIndex) = Round(tDataArray(10, tCodeIndex) / 1000, 3)
		tDataArray(12, tCodeIndex) = Round(tDataArray(12, tCodeIndex) / 1000, 3)
	Next
	
	'prepare report file from template filled with constfields and ect
	If Not fMakeBlankTemplate(inContentNode, inTemplateFile, inYear, inMonth, inRootFolder, inSubjectID, inSubjectName, tResultFile) Then
		fLogLine tLogTag, "Файл для вывода результата не получилось создать!"
		Exit Function
	End If
	
	'opening file
	If Not fOpenBook(tResultWorkBook, tResultFile, False) Then
		fLogLine tLogTag, "Не удалось открыть файл типа [template] результата > " & tResultFile		
		Exit Function
	End If	
	
	'fill with constfields and ect
	If Not fFillBlankTemplate(inContentNode, tResultWorkBook, inYear, inMonth, inSubjectID, inSubjectName) Then
		fLogLine tLogTag, "Файл для вывода результата не получилось заполнить (CONST)!"
		fCloseBook tResultWorkBook, True
		Exit Function
	End If
	
	'fill with collected data
	'tCodeString = "102:113:116"
	If Not fFillDataTemplate(tResultWorkBook, tDataArray, tDataArraySize, tDataArrayActLength) Then
		fLogLine tLogTag, "Файл для вывода результата не получилось заполнить (DATA)!"
		fCloseBook tResultWorkBook, True
		Exit Function
	End If
	
	tResultWorkBook.Save
	fCloseBook tResultWorkBook, False
	fLogLine tLogTag, "Файл результата: " & tResultFile	
	fCreateReportByContentNode = True
	
End Function

'safeclose workbook
Private Function fCloseBook(inWorkBook, inTryKillFile)
	Dim tPath
	On Error Resume Next
		tPath = inWorkBook.Path
		inWorkBook.Close
		If inTryKillFile Then
			gFSO.DeleteFile tPath, True 'overkill
		End If
	On Error GoTo 0
End Function

'fInit - init object and ect as global variables
Private Sub fInit()
	Dim tXMLFilePathA, tXMLFilePathB, tXMLFileFolderLock

	Set gFSO = CreateObject("Scripting.FileSystemObject")
	Set gWSO = CreateObject("WScript.Shell")
	Set gRExp = WScript.CreateObject("VBScript.RegExp")
	gRExp.IgnoreCase = True
	
	gTraderID = "BELKAMKO"
	gLogFileName = "Log.txt"
	
	gScriptFileName = Wscript.ScriptName
	gScriptPath = gFSO.GetParentFolderName(WScript.ScriptFullName)

	fD2SInit
	fLogInit
	
	tXMLFilePathA = gWSO.ExpandEnvironmentStrings("%HOMEPATH%") & "\GTPCFG"
	tXMLFilePathB = gScriptPath
	tXMLFileFolderLock = tXMLFilePathA & ";" & tXMLFilePathB
	
	If Not fGetXMLConfig(tXMLFileFolderLock, gXMLConfigPath, gConfigXML) Then: fQuitScript
	
	Set gExcel = CreateObject("Excel.Application")
	gExcel.Application.Visible = False
	If gExcel Is Nothing Then: WScript.Quit
	fExcelControl gExcel, -1, -1, 0, -1	
End Sub

'fQuitScript - soft quiting this script
Private Sub fQuitScript()
	'close log session
	fLogClose True
	If Not IsEmpty(gExcel) Then
		If Not (gExcel Is Nothing) Then
			fExcelControl gExcel, 1, 1, 0, 1
			gExcel.Quit
		End If
	End If
	'destroy objects	
	Set gFSO = Nothing	
	Set gRExp = Nothing
	Set gExcel = Nothing
	Set gWSO = Nothing
	Set gConfigXML = Nothing
	'quit
	WScript.Echo "Done"
	WScript.Quit
End Sub

Private Sub fMain()
	Dim tYear, tMonth, tLogTag
	Dim tWorkBookA, tWorkBookB
	Dim tSubjectNode, tSubjectNodes, tSubjectID, tSubjectName, tXPathStringA, tXPathStringB, tContentNode
	Dim tRootFolder
	
	tLogTag = "MAIN"
	gCodeArraySize = -1
	gCodeScanColumn = 0

	' // запрос ДАТЫ периода у пользователя Year(Date()), Month(Date())
	If Not fReportPeriodAsk(tYear, tMonth, 2020, 1) Then
		fLogLine tLogTag, "Не удалось получить дату периода от пользователя!"
		Exit Sub
	End If
	
	' // Поиск файлов
	tRootFolder = gFSO.GetFolder(gScriptPath)
	If Not fFileScanner(tRootFolder, gTraderID, tYear, tMonth) Then: Exit Sub
	
	' // Чтение файлов
	If Not fFileReader(tYear, tMonth, tWorkBookA, tWorkBookB) Then: Exit Sub
	
	' // Основная работа
	tXPathStringA = "//subjects/subject"
	Set tSubjectNodes = gConfigXML.SelectNodes(tXPathStringA)
	For Each tSubjectNode In tSubjectNodes
		
		'ID
		tSubjectID = fAutoCorrectNumeric(tSubjectNode.GetAttribute("id"), 0, 0, "ANY")
		
		'NAME
		tXPathStringB = "descendant::name"
		Set tSubjectName = tSubjectNode.SelectSingleNode(tXPathStringB)
		
		If tSubjectName Is Nothing Then
			fLogLine tLogTag, "Неверно заполнен блок [" & tXPathString & " -> " & tXPathStringB & "]"
			Exit For
		End If
		
		tSubjectName = tSubjectName.Text		
		fLogLine tLogTag, "Субъект в работе: [" & tSubjectID & "] [" & tSubjectName & "]"
		
		'CONTENT
		tXPathStringB = "descendant::content"
		Set tContentNode = tSubjectNode.SelectSingleNode(tXPathStringB)
		
		If tContentNode Is Nothing Then
			fLogLine tLogTag, "Неверно заполнен блок [" & tXPathString & " -> " & tXPathStringB & "]"
			Exit For		
		End If
		
		If Not fCreateReportByContentNode(tContentNode, gTemplate, tWorkBookA, tWorkBookB, tYear, tMonth, tRootFolder, tSubjectID, tSubjectName) Then
			fLogLine tLogTag, "Субъект не обработан."
		End If
	Next
	
	' // Фиширеры
	fCloseBook tWorkBookA, False
	fCloseBook tWorkBookB, False
End Sub

'======= // MAIN
fInit
fMain
fQuitScript