'Проект "GTF_450" v001 от 18.03.2021
'
'ОПИСАНИЕ: Извлекает данные из отчетов 1C и АТС для заполнения формы 450 в формате Excel

Option Explicit

Dim gXMLConfigPath, gXMLFileFolderLock, gConfigXML, gTransferData
Dim gExcel, gFSO, gWSO, gRExp
Dim gTraderID, gScriptFileName, gScriptPath, gDefaultLogFileName, gLogFilePath, gLogString
Dim gBaseA, gBaseB, gBaseC, gFinReport, gTemplate, gBaseXML, gBaseXMLLogFileName
Dim uD2S(255)
Dim gFinRepArray()
Dim gFinRepArraySize
Dim gCodeArray()
Dim gRowArray()
Dim gCodeArraySize, gCodeScanColumn, gLogYear, gLogMonth

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
		If Not gFSO.FileExists(inFile) Then
			fLogLine tLogTag, "Файл не существует! Отчет будет пропущен. FILEPATH=[" & inFile.Path & "]"
			Set outWorkBook = Nothing
			Exit Function
		End If

		Set outWorkBook = gExcel.Workbooks.Open (inFile.Path, False, inReadOnly)		
		If Err.Number <> 0 Then
			'WScript.Echo "Произошла ошибка открытия файла." & vbCrLf & "Данный отчет будет пропущен!" & vbCrLf & vbCrLf & "FilePath: " & vbTab & inFile.Path & vbCrLf & vbCrLf & "FileName: " & vbTab & inFile.Name & vbCrLf & vbCrLf & "Reason: " & vbTab & Err.Description
			fLogLine tLogTag, "Не удалось окрыть книгу! Отчет будет пропущен. FILEPATH=[" & inFile.Path & "]"
			Set outWorkBook = Nothing
			Exit Function
		ElseIf outWorkBook.WorkSheets.Count = 0 Then 'Вроде это невозможно
			fLogLine tLogTag, "В книге нет листов! Отчет будет пропущен."
			Set outWorkBook = Nothing
			Exit Function
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
	gLogFilePath = gScriptPath & "\" & gDefaultLogFileName
	gLogString = vbNullString
	fLogLine "LOG", "Начало сессии."
End Sub

'fLogClose - close logfile
Private Sub fLogClose(inClearPreviousSession)    
	Dim tTextFile, tOldLogString	
    fLogLine "LOG", "Конец сессии."

	If gLogYear <> 0 And gLogMonth <> 0 Then
		gLogFilePath = gScriptPath & "\" & "Log_" & gLogYear & fNZeroAdd(gLogMonth, 2) & ".txt"
	End If

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

'SAVE TEMP XML as logging issue
Private Sub fSaveBaseXMLLog(inBaseXML)
	Dim tNode, tTextFile, tXMLText, tXMLBufText, tIntro
    Dim tEncodingFormat
	Dim tFilePath
	Dim tLogTag

	tLogTag = "fSaveBaseXMLLog"
	tFilePath = gScriptPath & "/" & gBaseXMLLogFileName

	If gFSO.FileExists(tFilePath) Then
		On Error Resume Next
			gFSO.DeleteFile tFilePath
		On Error GoTo 0
    End If

	If gFSO.FileExists(tFilePath) Then
		fLogLine tLogTag, "Не удалось удалить файл: " & tFilePath
		Exit Sub
	End If

    ' 00 // Defaults
    tEncodingFormat = -1 ' 0 - ASCII (win base) \\ -1 - unicode \\ -2 - system default 

    ' 01 // Saving inBaseXML to file tFilePath
	Set tIntro = inBaseXML.CreateProcessingInstruction("xml", "version='1.0' encoding='UTF-16LE' standalone='yes'")
	inBaseXML.InsertBefore tIntro, inBaseXML.ChildNodes(0)
	inBaseXML.Save(tFilePath) 'RESAVE-SAVE

    ' 02 // Reopening XML file as TEXT file
	Set tTextFile = gFSO.OpenTextFile(tFilePath, 1,, tEncodingFormat)
	tXMLText = tTextFile.ReadAll	
	tTextFile.Close

	' 03 // Rebuilding TEXT with SPACEs adding (used for notepad++ view issue fix)
	Set tTextFile = gFSO.OpenTextFile(tFilePath, 2, True, tEncodingFormat)	
	tXMLText = Replace(tXMLText,"><","> <")
	tTextFile.Write tXMLText
	tTextFile.Close
	
    ' 04 // Resaving XML to apply changes from step 3
	inBaseXML.Load(tFilePath) 'RESAVE-READ
	inBaseXML.Save(tFilePath) 'RESAVE-SAVE

	' 05 // Logging
	fLogLine tLogTag, "Данные сохранены: " & tFilePath
End Sub

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
	gBaseC = vbNullString
	gTransferData = vbNullString
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
					'fLogLine tLogTag, "Поиск файла (путь): " & tFolder
					'fLogLine tLogTag, "Поиск файла (маска): " & gRExp.Pattern
				
					For Each tFile in tFolder.Files
						tFileName = fGetFileName(tFile)
						tFileExt = fCheckExtInList(fGetFileExtension(tFile), fAutoCorrectString(tNode.getAttribute("ext"), True))
						'fLogLine tLogTag, "Поиск файла (EXT): " & tFileExt & " // " & tFileName
					
						If gRExp.Test(tFileName) And tFileExt <> vbNullString Then
							Select Case tValue
								Case "basea": Set gBaseA = tFile
								Case "baseb": Set gBaseB = tFile
								Case "basec": Set gBaseC = tFile
								Case "transferdata": Set gTransferData = tFile
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

Private Function fIsContractNameValue(inValue, outContractID, outContractName, outErrorText)
	Dim tPos, tValue

	fIsContractNameValue = False
	outErrorText = vbNullString
	outContractID = vbNullString
	outContractName = vbNullString	
	
	'<Д000000000000 ТИП_ДОГОВОРА>

	If inValue = vbNullString Then
		outErrorText = "Строка имени договора пуста"
		Exit Function
	End If

	tValue = Replace(inValue, "_", " ") ' <- autocorr

	tPos = InStr(tValue, " ")
	If tPos <= 0 Then
		outErrorText = "Ожидался формат имени договора <Д000000000000 ТИП_ДОГОВОРА>, а получен <" & tValue & ">"
		Exit Function
	End If

	outContractID = UCase(Left(tValue, tPos - 1))
	outContractName = Trim(Right(tValue, Len(tValue) - tPos))

	If Left(outContractID, 1) <> "Д" Then
		outErrorText = "Ожидался формат имени договора <Д000000000000 ТИП_ДОГОВОРА>, а получен <" & tValue & ">"
		Exit Function
	End If

	fIsContractNameValue = True
End Function

' // read EXCEL to XML [BaseB -> BaseXML]
Private Function fReadBaseB(inBaseBFile, inBaseXML, inYear, inMonth)
	Dim tWorkBook, tLogTag, tWorkSheetIndex, tIndexCol
	Dim tLastRow, tCurrentRow, tStartRow, tValue, tTempValue, tLevel
	Dim tRootNode, tOrgNode, tContractNode, tActNode
	Dim tDropScan, tErrorText, tConractName, tContractID, tDateRow, tDateCol
	Dim tIndex, tMaxIndex, tValueCheck, tValueCheckString, tReads
	'baseA unique values	
	Dim tDataRead(2, 1) '3x2

	tLogTag = "fReadBaseB"
	fReadBaseB = False
	tWorkSheetIndex = 1
	tIndexCol = 1	
	tDateRow = 2
	tDateCol = 1
	tTempValue = "продажи за " & fMonthD2C(inMonth) & " " & inYear

	'minidb \\ 0 - name; 1 - column index; 2 - readed value
	tMaxIndex = UBound(tDataRead, 2) 
	tDataRead(0, 0) = "value"
	tDataRead(1, 0) = 11
	tDataRead(0, 1) = "cost"	
	tDataRead(1, 1) = 13

	' 01 // Open EXCEL workbook
	If Not fOpenBook(tWorkBook, inBaseBFile, True) Then
		fLogLine tLogTag, "Не удалось открыть файл по следующему пути > " & inBaseBFile
		Exit Function
	End If

	' 02 // Quickchecks
	On Error Resume Next

	'get last row index
	tLastRow = tWorkBook.WorkSheets(tWorkSheetIndex).Cells.SpecialCells(11).Row

	'err?
	If Err.Number <> 0 Then
		fLogLine tLogTag, "При чтении данных произошла ошибка #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
		On Error GoTo 0
		Exit Function
	End If

	'date check	
	tValue = LCase(tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tDateRow, tDateCol).Value)	
	If InStr(tValue, tTempValue) <= 0 Then
		fLogLine tLogTag, "Не удалось подтвердить период отчета в ячейке " & uD2S(tDateCol) & tDateRow & "; ожидалось наличие [" & tTempValue & "], а найдено [" & tValue & "]"
		On Error GoTo 0
		Exit Function
	End If
	
	'get start row index
	tStartRow = 0
	For tCurrentRow = 1 To tLastRow - 1
		tValue = tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tIndexCol).Value
		Select Case tValue
			Case "Контрагент": 
				tStartRow = -1
			Case "Договор":	
				If tStartRow = -1 Then:  tStartRow = -2
			Case "Документ": 
				If tStartRow = -2 Then
					tStartRow = tCurrentRow + 1
					Exit For
				End If
			Case Else:
				If tStartRow < 0 Then: tStartRow = 0
		End Select		
	Next

	'if not locked
	If tStartRow <= 0 Then
		fLogLine tLogTag, "Не удалось найти стартовую конструкцию КОНТРАГЕНТ->ДОГОВОР->ДОКУМЕНТ"
		fCloseBook tWorkBook, False
		Exit Function
	End If

	'reading (to virtual XML node)
	'ROOT
	Set tRootNode = inBaseXML.CreateElement("file")
	inBaseXML.DocumentElement.AppendChild tRootNode ' <- make it not virtual node
	tRootNode.SetAttribute "type", "baseb"
	tRootNode.SetAttribute "year", inYear
	tRootNode.SetAttribute "month", inMonth
	tRootNode.SetAttribute "indexcol", tIndexCol
	For tIndex = 0 To tMaxIndex
		tRootNode.SetAttribute tDataRead(0, tIndex), tDataRead(1, tIndex)		
	Next
	tRootNode.SetAttribute "startrow", tStartRow
	tRootNode.SetAttribute "lastrow", tLastRow

	'prepare values
	Set tOrgNode = Nothing
	Set tContractNode = Nothing
	Set tActNode = Nothing
	tDropScan = False

	'main scan
	For tCurrentRow = tStartRow To tLastRow

		'read values
		tValue = fAutoCorrectString(tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tIndexCol).Value, True)
		tLevel = tWorkBook.WorkSheets(tWorkSheetIndex).Rows(tCurrentRow).OutlineLevel
		For tIndex = 0 To tMaxIndex
			tDataRead(2, tIndex) = tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tDataRead(1, tIndex)).Value
		Next	

		'err control
		If Err.Number <> 0 Then
			fLogLine tLogTag, "При чтении данных произошла ошибка #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
			On Error GoTo 0
			Exit Function
		End If

		'drop scan check
		tValueCheck = True
		tValueCheckString = "CHECK: "
		For tIndex = 0 To tMaxIndex
			If Not IsEmpty(tDataRead(2, tIndex)) Then
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(TRUE)"
				tValueCheck = tValueCheck And True
			Else
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(FALSE)"
				tValueCheck = tValueCheck And False
			End If

			If tIndex <> tMaxIndex Then: tValueCheckString = tValueCheckString & "; "
		Next

		If Not tValueCheck Or tValue = "Итого" Then
			fLogLine tLogTag, "Окочание сканирования в строке " & tCurrentRow & " (уровень вложенности <" & tLevel & ">) ФЛАГИ [" & tValueCheckString &"; FIN tValue=" & tValue & "]"
			tDropScan = True
			Exit For
		End If

		'value tests
		tValueCheck = True
		tValueCheckString = "CHECK: "
		For tIndex = 0 To tMaxIndex
			If IsNumeric(tDataRead(2, tIndex)) Then
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(TRUE)"
				tValueCheck = tValueCheck And True
			Else
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(FALSE)"
				tValueCheck = tValueCheck And False
			End If

			If tIndex <> tMaxIndex Then: tValueCheckString = tValueCheckString & "; "
		Next

		If Not tValueCheck Then
			On Error GoTo 0
			fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружены неожиданные данные [" & tValueCheckString & "]"
			fCloseBook tWorkBook, False				
			Exit Function
		End If

		'logic
		Select Case tLevel

			'ORG
			Case 1:				
				Set tOrgNode = tRootNode.AppendChild(inBaseXML.CreateElement("organization"))
				tOrgNode.SetAttribute "row", tCurrentRow
				tOrgNode.SetAttribute "name1c", tValue
				For tIndex = 0 To tMaxIndex
					tOrgNode.SetAttribute tDataRead(0, tIndex), tDataRead(2, tIndex)
				Next
				tReads = tReads + 1

			'CONTRACT
			Case 2:
				If tOrgNode Is Nothing Then
					On Error GoTo 0
					fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружен неожиданный уровень вложенности <" & tLevel & "> // не было создано родительской ноды"
					fCloseBook tWorkBook, False				
					Exit Function
				End If

				Set tContractNode = tOrgNode.AppendChild(inBaseXML.CreateElement("contract"))

				If Not fIsContractNameValue(tValue, tContractID, tConractName, tErrorText) Then
					On Error GoTo 0
					fLogLine tLogTag, "В строке " & tCurrentRow & " имя договора оказалось неожиданным <" & tValue & "> // " & tErrorText
					fCloseBook tWorkBook, False
					Exit Function
				End If

				tContractNode.SetAttribute "row", tCurrentRow
				tContractNode.SetAttribute "id", tContractID
				tContractNode.SetAttribute "type", tConractName
				For tIndex = 0 To tMaxIndex
					tContractNode.SetAttribute tDataRead(0, tIndex), tDataRead(2, tIndex)
				Next
				tReads = tReads + 1

			'ACT
			Case 3:
				If tContractNode Is Nothing Then
					On Error GoTo 0
					fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружен неожиданный уровень вложенности <" & tLevel & "> // не было создано родительской ноды"
					fCloseBook tWorkBook, False				
					Exit Function
				End If

				Set tActNode = tContractNode.AppendChild(inBaseXML.CreateElement("act"))

				tActNode.SetAttribute "row", tCurrentRow
				tActNode.SetAttribute "name", tValue
				For tIndex = 0 To tMaxIndex
					tActNode.SetAttribute tDataRead(0, tIndex), tDataRead(2, tIndex)
				Next
				tReads = tReads + 1

			'UNKNOWN LEVEL
			Case Else:
				On Error GoTo 0
				fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружен неожиданный уровень вложенности <" & tLevel & "> (допустимые уровни: 1-3)"
				fCloseBook tWorkBook, False
				Exit Function
		End Select
	Next

	'err control restore
	On Error GoTo 0

	'logging issue
	If Not tDropScan Then
		fLogLine tLogTag, "Окочание сканирования в строке " & tCurrentRow & " по превышению лимита строк [tLastRow=" & tLastRow & "]"
	End If

	If tReads = 0 Then
		fLogLine tLogTag, "Количество успешно прочитанных строк [tReads] равно нулю. Произошла какая-то ошибка."
		Exit Function
	End If

	fLogLine tLogTag, "Количество успешно прочитанных строк [tReads=" & tReads & "]"

	'finalize	
	fCloseBook tWorkBook, False
	fLogLine tLogTag, "Чтение успешно."
	fReadBaseB = True
End Function

' // read EXCEL to XML [BaseA -> BaseXML]
Private Function fReadBaseA(inBaseBFile, inBaseXML, inYear, inMonth)
	Dim tWorkBook, tLogTag, tWorkSheetIndex, tIndexCol
	Dim tLastRow, tCurrentRow, tStartRow, tValue, tTempValue, tLevel
	Dim tRootNode, tOrgNode, tContractNode
	Dim tDropScan, tErrorText, tConractName, tContractID, tDateRow, tDateCol
	Dim tIndex, tMaxIndex, tValueCheck, tValueCheckString, tReads
	'baseA unique values	
	Dim tDataRead(2, 7) '3x8

	tLogTag = "fReadBaseA"
	fReadBaseA = False
	tWorkSheetIndex = 1
	tIndexCol = 1	
	tDateRow = 2
	tDateCol = 1
	tTempValue = "задолженность покупателей за " & fMonthD2C(inMonth) & " " & inYear

	'minidb \\ 0 - name; 1 - column index; 2 - readed value
	tMaxIndex = UBound(tDataRead, 2) 
	tDataRead(0, 0) = "periodstartdebt"
	tDataRead(1, 0) = 3
	tDataRead(0, 1) = "periodstartadvance"	
	tDataRead(1, 1) = 4
	tDataRead(0, 2) = "sellsold"
	tDataRead(1, 2) = 5
	tDataRead(0, 3) = "sellpaid"
	tDataRead(1, 3) = 6
	tDataRead(0, 4) = "prepaidincome"
	tDataRead(1, 4) = 8
	tDataRead(0, 5) = "prepaiduse"
	tDataRead(1, 5) = 9
	tDataRead(0, 6) = "periodenddebt"
	tDataRead(1, 6) = 10
	tDataRead(0, 7) = "periodendadvance"
	tDataRead(1, 7) = 11
	
	' 01 // Open EXCEL workbook
	If Not fOpenBook(tWorkBook, inBaseBFile, True) Then
		fLogLine tLogTag, "Не удалось открыть файл по следующему пути > " & inBaseBFile
		Exit Function
	End If

	' 02 // Quickchecks
	On Error Resume Next

	'get last row index
	tLastRow = tWorkBook.WorkSheets(tWorkSheetIndex).Cells.SpecialCells(11).Row

	'err?
	If Err.Number <> 0 Then
		fLogLine tLogTag, "При чтении данных произошла ошибка #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
		On Error GoTo 0
		Exit Function
	End If

	'date check	
	tValue = LCase(tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tDateRow, tDateCol).Value)	
	If InStr(tValue, tTempValue) <= 0 Then
		fLogLine tLogTag, "Не удалось подтвердить период отчета в ячейке " & uD2S(tDateCol) & tDateRow & "; ожидалось наличие [" & tTempValue & "], а найдено [" & tValue & "]"
		On Error GoTo 0
		Exit Function
	End If
	
	'get start row index
	tStartRow = 0
	For tCurrentRow = 1 To tLastRow - 1
		tValue = tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tIndexCol).Value
		Select Case tValue
			Case "Покупатель": 
				tStartRow = -1
			Case "Договор":	
				If tStartRow = -1 Then
					tStartRow = tCurrentRow + 1
					Exit For
				End If			
			Case Else:
				If tStartRow < 0 Then: tStartRow = 0
		End Select		
	Next

	'if not locked
	If tStartRow <= 0 Then
		fLogLine tLogTag, "Не удалось найти стартовую конструкцию ПОКУПАТЕЛЬ->ДОГОВОР"
		fCloseBook tWorkBook, False
		Exit Function
	End If

	'reading (to virtual XML node)
	'ROOT
	Set tRootNode = inBaseXML.CreateElement("file")
	inBaseXML.DocumentElement.AppendChild tRootNode ' <- make it not virtual node
	tRootNode.SetAttribute "type", "basea"
	tRootNode.SetAttribute "year", inYear
	tRootNode.SetAttribute "month", inMonth
	tRootNode.SetAttribute "indexcol", tIndexCol
	For tIndex = 0 To tMaxIndex
		tRootNode.SetAttribute tDataRead(0, tIndex), tDataRead(1, tIndex)		
	Next
	tRootNode.SetAttribute "startrow", tStartRow
	tRootNode.SetAttribute "lastrow", tLastRow

	'prepare values
	Set tOrgNode = Nothing
	Set tContractNode = Nothing	
	tDropScan = False
	tReads = 0

	'main scan
	For tCurrentRow = tStartRow To tLastRow

		'read values
		tValue = fAutoCorrectString(tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tIndexCol).Value, True)
		tLevel = tWorkBook.WorkSheets(tWorkSheetIndex).Rows(tCurrentRow).OutlineLevel
		For tIndex = 0 To tMaxIndex
			tDataRead(2, tIndex) = tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tDataRead(1, tIndex)).Value
			If IsEmpty(tDataRead(2, tIndex)) Then: tDataRead(2, tIndex) = 0
		Next		

		'err control
		If Err.Number <> 0 Then
			fLogLine tLogTag, "При чтении данных произошла ошибка #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
			On Error GoTo 0
			Exit Function
		End If

		'drop scan check
		If tValue = "Итого" Or tValue = vbNullString Then
			fLogLine tLogTag, "Окочание сканирования в строке " & tCurrentRow & " (уровень вложенности <" & tLevel & ">) ФЛАГИ [FIN tValue=" & tValue & "; EMPTY tValue?]"
			tDropScan = True
			Exit For
		End If

		'value tests
		tValueCheck = True
		tValueCheckString = "CHECK: "
		For tIndex = 0 To tMaxIndex
			If IsNumeric(tDataRead(2, tIndex)) Then
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(TRUE)"
				tValueCheck = tValueCheck And True
			Else
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(FALSE)"
				tValueCheck = tValueCheck And False
			End If

			If tIndex <> tMaxIndex Then: tValueCheckString = tValueCheckString & "; "
		Next

		If Not tValueCheck Then
			On Error GoTo 0
			fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружены неожиданные данные [" & tValueCheckString & "]"
			fCloseBook tWorkBook, False				
			Exit Function
		End If

		'logic
		Select Case tLevel

			'ORG
			Case 1:				
				Set tOrgNode = tRootNode.AppendChild(inBaseXML.CreateElement("organization"))
				tOrgNode.SetAttribute "row", tCurrentRow
				tOrgNode.SetAttribute "name1c", tValue
				For tIndex = 0 To tMaxIndex
					tOrgNode.SetAttribute tDataRead(0, tIndex), tDataRead(2, tIndex)
				Next
				tReads = tReads + 1

			'CONTRACT
			Case 2:
				If tOrgNode Is Nothing Then
					On Error GoTo 0
					fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружен неожиданный уровень вложенности <" & tLevel & "> // не было создано родительской ноды"
					fCloseBook tWorkBook, False				
					Exit Function
				End If

				Set tContractNode = tOrgNode.AppendChild(inBaseXML.CreateElement("contract"))

				If Not fIsContractNameValue(tValue, tContractID, tConractName, tErrorText) Then
					On Error GoTo 0
					fLogLine tLogTag, "В строке " & tCurrentRow & " имя договора оказалось неожиданным <" & tValue & "> // " & tErrorText
					fCloseBook tWorkBook, False
					Exit Function
				End If

				tContractNode.SetAttribute "row", tCurrentRow
				tContractNode.SetAttribute "id", tContractID
				tContractNode.SetAttribute "type", tConractName
				For tIndex = 0 To tMaxIndex
					tContractNode.SetAttribute tDataRead(0, tIndex), tDataRead(2, tIndex)
				Next
				tReads = tReads + 1

			'UNKNOWN LEVEL
			Case Else:
				On Error GoTo 0
				fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружен неожиданный уровень вложенности <" & tLevel & "> (допустимые уровни: 1-3)"
				fCloseBook tWorkBook, False
				Exit Function
		End Select
	Next

	'err control restore
	On Error GoTo 0

	'logging issue
	If Not tDropScan Then
		fLogLine tLogTag, "Окочание сканирования в строке " & tCurrentRow & " по превышению лимита строк [tLastRow=" & tLastRow & "]"
	End If

	If tReads = 0 Then
		fLogLine tLogTag, "Количество успешно прочитанных строк [tReads] равно нулю. Произошла какая-то ошибка."
		Exit Function
	End If

	fLogLine tLogTag, "Количество успешно прочитанных строк [tReads=" & tReads & "]"

	'finalize		
	fCloseBook tWorkBook, False
	fLogLine tLogTag, "Чтение успешно."
	fReadBaseA = True
End Function

' // read EXCEL to XML [BaseC -> BaseXML]
Private Function fReadBaseC(inBaseBFile, inBaseXML, inYear, inMonth)
	Dim tWorkBook, tLogTag, tWorkSheetIndex, tIndexCol
	Dim tLastRow, tCurrentRow, tStartRow, tValue, tTempValue, tLevel
	Dim tRootNode, tOrgNode, tContractNode
	Dim tDropScan, tErrorText, tConractName, tContractID, tDateRow, tDateCol
	Dim tIndex, tMaxIndex, tValueCheck, tValueCheckString, tReads
	'baseA unique values	
	Dim tDataRead(2, 7) '3x8

	tLogTag = "fReadBaseC"
	fReadBaseC = False
	tWorkSheetIndex = 1
	tIndexCol = 1	
	tDateRow = 2
	tDateCol = 1
	tTempValue = "задолженность поставщикам за " & fMonthD2C(inMonth) & " " & inYear

	'minidb \\ 0 - name; 1 - column index; 2 - readed value
	tMaxIndex = UBound(tDataRead, 2) 
	tDataRead(0, 0) = "periodstartdebt"
	tDataRead(1, 0) = 3
	tDataRead(0, 1) = "periodstartadvance"	
	tDataRead(1, 1) = 4
	tDataRead(0, 2) = "sellsold"
	tDataRead(1, 2) = 5
	tDataRead(0, 3) = "sellpaid"
	tDataRead(1, 3) = 6
	tDataRead(0, 4) = "prepaidincome"
	tDataRead(1, 4) = 8
	tDataRead(0, 5) = "prepaiduse"
	tDataRead(1, 5) = 9
	tDataRead(0, 6) = "periodenddebt"
	tDataRead(1, 6) = 10
	tDataRead(0, 7) = "periodendadvance"
	tDataRead(1, 7) = 11
	
	' 01 // Open EXCEL workbook
	If Not fOpenBook(tWorkBook, inBaseBFile, True) Then
		fLogLine tLogTag, "Не удалось открыть файл по следующему пути > " & inBaseBFile
		Exit Function
	End If

	' 02 // Quickchecks
	On Error Resume Next

	'get last row index
	tLastRow = tWorkBook.WorkSheets(tWorkSheetIndex).Cells.SpecialCells(11).Row

	'err?
	If Err.Number <> 0 Then
		fLogLine tLogTag, "При чтении данных произошла ошибка #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
		On Error GoTo 0
		Exit Function
	End If

	'date check	
	tValue = LCase(tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tDateRow, tDateCol).Value)	
	If InStr(tValue, tTempValue) <= 0 Then
		fLogLine tLogTag, "Не удалось подтвердить период отчета в ячейке " & uD2S(tDateCol) & tDateRow & "; ожидалось наличие [" & tTempValue & "], а найдено [" & tValue & "]"
		On Error GoTo 0
		Exit Function
	End If
	
	'get start row index
	tStartRow = 0
	For tCurrentRow = 1 To tLastRow - 1
		tValue = tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tIndexCol).Value
		Select Case tValue
			Case "Поставщик": 
				tStartRow = -1
			Case "Договор":	
				If tStartRow = -1 Then
					tStartRow = tCurrentRow + 1
					Exit For
				End If
			Case Else:
				If tStartRow < 0 Then: tStartRow = 0
		End Select		
	Next

	'if not locked
	If tStartRow <= 0 Then
		fLogLine tLogTag, "Не удалось найти стартовую конструкцию ПОСТАВЩИК->ДОГОВОР"
		fCloseBook tWorkBook, False
		Exit Function
	End If

	'reading (to virtual XML node)
	'ROOT
	Set tRootNode = inBaseXML.CreateElement("file")
	inBaseXML.DocumentElement.AppendChild tRootNode ' <- make it not virtual node
	tRootNode.SetAttribute "type", "basec"
	tRootNode.SetAttribute "year", inYear
	tRootNode.SetAttribute "month", inMonth
	tRootNode.SetAttribute "indexcol", tIndexCol
	For tIndex = 0 To tMaxIndex
		tRootNode.SetAttribute tDataRead(0, tIndex), tDataRead(1, tIndex)		
	Next
	tRootNode.SetAttribute "startrow", tStartRow
	tRootNode.SetAttribute "lastrow", tLastRow

	'prepare values
	Set tOrgNode = Nothing
	Set tContractNode = Nothing	
	tDropScan = False
	tReads = 0

	'main scan
	For tCurrentRow = tStartRow To tLastRow

		'read values
		tValue = fAutoCorrectString(tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tIndexCol).Value, True)
		tLevel = tWorkBook.WorkSheets(tWorkSheetIndex).Rows(tCurrentRow).OutlineLevel
		For tIndex = 0 To tMaxIndex
			tDataRead(2, tIndex) = tWorkBook.WorkSheets(tWorkSheetIndex).Cells(tCurrentRow, tDataRead(1, tIndex)).Value
			If IsEmpty(tDataRead(2, tIndex)) Then: tDataRead(2, tIndex) = 0
		Next		

		'err control
		If Err.Number <> 0 Then
			fLogLine tLogTag, "При чтении данных произошла ошибка #" & Err.Number & " в <" & Err.Source & ">: " & Err.Description
			On Error GoTo 0
			Exit Function
		End If

		'drop scan check
		If tValue = "Итого" Or tValue = vbNullString Then
			fLogLine tLogTag, "Окочание сканирования в строке " & tCurrentRow & " (уровень вложенности <" & tLevel & ">) ФЛАГИ [FIN tValue=" & tValue & "; EMPTY tValue?]"
			tDropScan = True
			Exit For
		End If

		'value tests
		tValueCheck = True
		tValueCheckString = "CHECK: "
		For tIndex = 0 To tMaxIndex
			If IsNumeric(tDataRead(2, tIndex)) Then
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(TRUE)"
				tValueCheck = tValueCheck And True
			Else
				tValueCheckString = tValueCheckString & tDataRead(0, tIndex) & "=" & tDataRead(2, tIndex) & "(FALSE)"
				tValueCheck = tValueCheck And False
			End If

			If tIndex <> tMaxIndex Then: tValueCheckString = tValueCheckString & "; "
		Next

		If Not tValueCheck Then
			On Error GoTo 0
			fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружены неожиданные данные [" & tValueCheckString & "]"
			fCloseBook tWorkBook, False				
			Exit Function
		End If

		'logic		
		Select Case tLevel

			'ORG
			Case 1:				
				Set tOrgNode = tRootNode.AppendChild(inBaseXML.CreateElement("organization"))
				tOrgNode.SetAttribute "row", tCurrentRow
				tOrgNode.SetAttribute "name1c", tValue
				For tIndex = 0 To tMaxIndex
					tOrgNode.SetAttribute tDataRead(0, tIndex), tDataRead(2, tIndex)
				Next				
				tReads = tReads + 1

			'CONTRACT
			Case 2:
				If tOrgNode Is Nothing Then
					On Error GoTo 0
					fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружен неожиданный уровень вложенности <" & tLevel & "> // не было создано родительской ноды"
					fCloseBook tWorkBook, False				
					Exit Function
				End If

				Set tContractNode = tOrgNode.AppendChild(inBaseXML.CreateElement("contract"))

				If Not fIsContractNameValue(tValue, tContractID, tConractName, tErrorText) Then
					'On Error GoTo 0
					fLogLine tLogTag, "В строке " & tCurrentRow & " имя договора оказалось неожиданным <" & tValue & "> // " & tErrorText
					'fCloseBook tWorkBook, False
					'Exit Function
					tContractID = "UNKNOWN"
					tConractName = tValue
				End If

				tContractNode.SetAttribute "row", tCurrentRow
				tContractNode.SetAttribute "id", tContractID
				tContractNode.SetAttribute "type", tConractName
				For tIndex = 0 To tMaxIndex
					tContractNode.SetAttribute tDataRead(0, tIndex), tDataRead(2, tIndex)
				Next
				tReads = tReads + 1

			'UNKNOWN LEVEL
			Case Else:
				On Error GoTo 0
				fLogLine tLogTag, "В строке " & tCurrentRow & " обнаружен неожиданный уровень вложенности <" & tLevel & "> (допустимые уровни: 1-3)"
				fCloseBook tWorkBook, False
				Exit Function
		End Select
	Next

	'err control restore
	On Error GoTo 0

	'logging issue
	If Not tDropScan Then
		fLogLine tLogTag, "Окочание сканирования в строке " & tCurrentRow & " по превышению лимита строк [tLastRow=" & tLastRow & "]"
	End If

	If tReads = 0 Then
		fLogLine tLogTag, "Количество успешно прочитанных строк [tReads] равно нулю. Произошла какая-то ошибка."
		Exit Function
	End If

	fLogLine tLogTag, "Количество успешно прочитанных строк [tReads=" & tReads & "]"

	'finalize		
	fCloseBook tWorkBook, False
	fLogLine tLogTag, "Чтение успешно."
	fReadBaseC = True
End Function

Private Function fReadTransferData(inXMLFile, inYear, inMonth, outTransferXMLNode)
	Dim tLogTag, tTempXML, tNode, tValue, tReportID, tXMLClass, tXMLVersion, tLock, tXPathString

	fReadTransferData = False
	tLogTag = "fReadTransferData"
	Set outTransferXMLNode = Nothing

	If Not gFSO.FileExists(inXMLFile) Then
		fLogLine tLogTag, "Файл не найден: " & inXMLFile
		Exit Function
	End If

	Set tTempXML = CreateObject("Msxml2.DOMDocument.6.0")
	tTempXML.ASync = False
	tTempXML.Load inXMLFile.Path

	tReportID = "450"
	tXMLClass = "TRANSFERDATA"
	tXMLVersion = "1"

	tLock = False

	'parsing quick check
	If tTempXML.parseError.ErrorCode = 0 Then 'Parsed?
		Set tNode = tTempXML.DocumentElement 'root        
        If tNode.NodeName = "message" Then 'message?
			tValue = UCase(tNode.getAttribute("class"))
            If tValue = tXMLClass Then 'message class is tXMLClass?
				tValue = tNode.getAttribute("id")
            	If tValue = tReportID Then 'report ID
					tValue = tNode.getAttribute("version")
					If tValue = tXMLVersion Then 'version
						tLock = True
						fLogLine tLogTag, "XML file locked!"
					Else
						fLogLine tLogTag, "XML Version Error: Found <" & tValue & "> when looking for <" & tXMLVersion & ">"
					End If
				Else
					fLogLine tLogTag, "XML REPORT ID Error: Found <" & tValue & "> when looking for <" & tReportID & ">"
                End If
			Else
				fLogLine tLogTag, "XML CLASS Error: Found <" & tValue & "> when looking for <" & tXMLClass & ">"
			End If				
		Else
			fLogLine tLogTag, "XML ROOT node name Error: Found <" & tNode.NodeName & "> when looking for <message>"
		End If
	Else
		fLogLine tLogTag, "XML parsing error: " & tTempXML.parseError.ErrorCode & " [LINE:" & tTempXML.parseError.Line & "/POS:" & tTempXML.parseError.LinePos & "]: " & tTempXML.parseError.Reason		
	End If	
	
	'quit on err
	If Not tLock Then: Exit Function

	'locking nodes
	tXPathString = "//period[(@year='" & inYear &  "' and @month='" & fNZeroAdd(inMonth, 2) & "')]"
	Set tNode = tTempXML.SelectNodes(tXPathString)
	If tNode.Length = 0 Then
		fLogLine tLogTag, "Не удалось найти подходящих данному периоду нод! > tXPathString=[" & tXPathString & "]"
		Exit Function
	End If

	'success return
	fLogLine tLogTag, "Найдено нод подходящих периоду - " & tNode.Length & "."
	Set outTransferXMLNode = tNode
	Set tNode = Nothing
	Set tTempXML = Nothing
		
	fReadTransferData = True
End Function

' // reading files
Private Function fFileReader(inYear, inMonth, inBaseXML, inTransferXMLNode)
	Dim tLogTag, tWorkBookA, tWorkBookB, tCurrentRow, tCurrentCol, tValue, tTempValue, tSheetIndex, tWorkBookTemplate, tNode, tXPathString

	fFileReader = False
	tLogTag = "fFileReader"	
	
	'finreport read
	If Not fReadTransferData(gTransferData, inYear, inMonth, inTransferXMLNode) Then: Exit Function
	If Not fFinReportRead(gFinRepArray, gFinRepArraySize) Then: Exit Function 'TODO DATECHECK 
	If Not fReadBaseB(gBaseB, inBaseXML, inYear, inMonth) Then: Exit Function
	If Not fReadBaseA(gBaseA, inBaseXML, inYear, inMonth) Then: Exit Function
	If Not fReadBaseC(gBaseC, inBaseXML, inYear, inMonth) Then: Exit Function	

	fSaveBaseXMLLog(inBaseXML)
	
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

' Add CONTRACT ITEM DATA to list
Private Sub fAddContractData(ioContractList, ioContractSize, inContractName, inStringCode, inAddVal, inAddCost, inTotalVal, inTotalCost, inContactParentOrg)
	Dim tContractName, tLogTag, tContractElements
	
	tLogTag = "fAddContractData"
	tContractElements = Split(Trim(inContractName), " ")	
	tContractName = UCase(tContractElements(0))
	
	'NEW
	ioContractSize = ioContractSize + 1
	ReDim Preserve ioContractList(6, ioContractSize)
	ioContractList(0, ioContractSize) = tContractName
	ioContractList(1, ioContractSize) = inStringCode
	ioContractList(2, ioContractSize) = inAddVal
	ioContractList(3, ioContractSize) = inAddCost
	ioContractList(4, ioContractSize) = inTotalVal
	ioContractList(5, ioContractSize) = inTotalCost
	ioContractList(6, ioContractSize) = inContactParentOrg
	
	'LOG
	fLogLine tLogTag, "Движение по договору [" & ioContractSize & ":" & inStringCode & ":" & tContractName & "] VAL=" & inAddVal & " COST=" & inAddCost & " // TOTALVAL=" & inTotalVal & " TOTALCOST=" & inTotalCost & " // Родитель - " & inContactParentOrg
End Sub

'fScanMethod_FinReport(tExtractNode, tOrgNode, tStringCode, ioDataArray(tTempValIndex, tCodeIndex), ioDataArray(tTempCostIndex, tCodeIndex), inContractList, inContractSize)
Private Function fScanMethod_FinReport(inExtractNode, inBaseBOrgNode, inStringCode, inScanWord, ioValStore, ioCostStore, ioContractList, ioContractSize, outValue)
	Dim tGTPCode, tMethod, tEtalonVal, tLockedRow
	Dim tLogTag, tValue
	Dim tTempVal, tTempCost, tReads
	Dim tContractVal, tContractCost, tContractName
	Dim tActNodes, tActNode, tXPathString, tContractNode
	
	'defaults
	fScanMethod_FinReport = False
	tLogTag = "fScanMethod_FinReport"
	outValue = 0
	
	'quick check #1
	If inExtractNode Is Nothing Then
		fLogLine tLogTag, "Входная нода inExtractNode оказалась не инициализированной!"
		Exit Function
	End If

	'quick check #2
	If inBaseBOrgNode Is Nothing Then
		fLogLine tLogTag, "Входная нода inBaseBOrgNode оказалась не инициализированной!"
		Exit Function
	End If

	'params
	tGTPCode = UCase(fAutoCorrectString(inExtractNode.GetAttribute("gtpcode"), False))
	tMethod = UCase(fAutoCorrectString(inExtractNode.GetAttribute("method"), True))
	tEtalonVal = fGetFinreportValueByGTPCode(tGTPCode, gFinRepArray)
				
	If tEtalonVal = -1 Then
		fLogLine tLogTag, "Ошибка синтаксиса ноды [" & inExtractNode.NodeName & "]: @gtpcode=[" & tGTPCode & "] не была найдена в файле типа [FinReport]"		
		Exit Function
	End If
	
	'fix
	tEtalonVal = tEtalonVal / 1000 'to correct kvt->mvt

	tXPathString = "descendant::act"
	Set tActNodes = inBaseBOrgNode.SelectNodes(tXPathString)

	If tActNodes.Length = 0 Then
		fLogLine tLogTag, "Не обнаружено дочерних нод [" & inBaseBOrgNode.NodeName & "] при tXPathString = <" & tXPathString & ">"
		Exit Function
	End If

	'scan
	tReads = 0
	tLockedRow = -1
	For Each tActNode In tActNodes
		
		'name check
		tValue = LCase(tActNode.GetAttribute("name"))
		If InStr(tValue, inScanWord) > 0 Then

			'values
			tTempVal = fXMLAttributeNumericRead(tActNode.GetAttribute("value"))
			tTempCost = fXMLAttributeNumericRead(tActNode.GetAttribute("cost"))
			tReads = tReads + 1

			If fGetMethodResult(tTempVal, tEtalonVal, tMethod) Then
				ioValStore = ioValStore + tTempVal
				ioCostStore = ioCostStore + tTempCost
				
				tXPathString = "parent::contract"
				Set tContractNode = tActNode.SelectSingleNode(tXPathString)
				If tContractNode Is Nothing Then
					fLogLine tLogTag, "Не обнаружено родительской ноды [" & tActNode.NodeName & "/ROW=" & tActNode.GetAttribute("row") & "] при tXPathString = <" & tXPathString & ">"
					Exit Function
				End If

				fAddContractData ioContractList, ioContractSize, tContractNode.GetAttribute("id"), inStringCode, tTempVal, tTempCost, fXMLAttributeNumericRead(tContractNode.GetAttribute("value")), fXMLAttributeNumericRead(tContractNode.GetAttribute("cost")), inBaseBOrgNode.GetAttribute("name1c")

				tLockedRow = tActNode.GetAttribute("row")
				outValue = tTempVal
				fLogLine tLogTag, "Нода [" & inExtractNode.NodeName & "]: [code=" & inStringCode & "] @gtpcode=[" & tGTPCode & "][" & tEtalonVal & "] по методу [" & tMethod & "] нашла подходящий элемент: ROW=" & tLockedRow & "; VAL=" & tTempVal & "; COST=" & tTempCost
				Exit For
			End If
		End If
	Next

	'check scan result
	If tLockedRow = -1 Or tReads = 0 Then
		fLogLine tLogTag, "Ошибка расчёта ноды [" & inExtractNode.NodeName & "]: @gtpcode=[" & tGTPCode & "][" & tEtalonVal & "] по методу [" & tMethod & "] не было найдено подходящих значений!"
		fLogLine tLogTag, "В файле типа [BaseB] обнаружено субэлементов (всего: " & tReads & ") [" & inScanWord & "] для организации [строка:" & inBaseBOrgNode.GetAttribute("row") & "]"		
		Exit Function
	End If
		
	fScanMethod_FinReport = True
End Function

Private Function fXMLAttributeNumericRead(inValue)
	Dim tLogTag

	tLogTag = "fXMLAttributeNumericRead"
	fXMLAttributeNumericRead = 0

	If IsNull(inValue) Then
		fLogLine tLogTag, "Аттрибут не прочитан!"
		Exit Function
	End If

	fXMLAttributeNumericRead = Replace(inValue, ".", ",")

	If Not IsNumeric(fXMLAttributeNumericRead) Then
		fXMLAttributeNumericRead = 0
		fLogLine tLogTag, "Аттрибут не является числом: " & inValue
		Exit Function
	End If

	fXMLAttributeNumericRead = fXMLAttributeNumericRead + 0
End Function

Private Function fScanMethod_Default(inExtractNode, inBaseBOrgNode, inStringCode, inScanWord, ioValStore, ioCostStore, ioContractList, ioContractSize, outValue)
	Dim tLogTag, tMethod, tMinValue, tMaxValue, tMinValCost, tMaxValCost, tMinValRow, tMaxValRow, tMinValContractRow, tMaxValContractRow
	Dim tLockedRow, tCurrentRow, tValue, tTempVal, tTempCost, tReads
	Dim tContractVal, tContractCost, tContractName, tContractRow
	Dim tActNode, tActNodes, tXPathString, tMinActNode, tMaxActNode, tContractNode
	
	'defaults
	fScanMethod_Default = False
	tLogTag = "fScanMethod_Default"
	outValue = 0
	
	'quick check #1
	If inExtractNode Is Nothing Then
		fLogLine tLogTag, "Входная нода inExtractNode оказалась не инициализированной!"
		Exit Function
	End If
	
	'quick check #2
	If inBaseBOrgNode Is Nothing Then
		fLogLine tLogTag, "Входная нода inBaseBOrgNode оказалась не инициализированной!"
		Exit Function
	End If
	
	'get method
	tMethod = UCase(fAutoCorrectString(inExtractNode.GetAttribute("method"), True))
	Select Case tMethod
		Case "MINVAL": 
		Case "MAXVAL": 
		Case Else:
			fLogLine tLogTag, "Ошибка синтаксиса ноды [" & inExtractNode.NodeName & "]: аттрибут @method не может иметь значния [" & tMethod & "]!"			
			Exit Function
	End Select

	'get act nodes
	tXPathString = "descendant::act"
	Set tActNodes = inBaseBOrgNode.SelectNodes(tXPathString)

	If tActNodes.Length = 0 Then
		fLogLine tLogTag, "Не обнаружено дочерних нод [" & inBaseBOrgNode.NodeName & "] при tXPathString = <" & tXPathString & ">"
		Exit Function
	End If
				
	'defaults
	Set tMinActNode = Nothing
	Set tMaxActNode = Nothing

	'scan	
	tReads = 0
	For Each tActNode In tActNodes
		'name check
		tValue = LCase(tActNode.GetAttribute("name"))
		If InStr(tValue, inScanWord) > 0 Then
			tTempVal = fXMLAttributeNumericRead(tActNode.GetAttribute("value"))
			tTempCost = fXMLAttributeNumericRead(tActNode.GetAttribute("cost"))
			tReads = tReads + 1
				
			'min by val
			If tMinActNode Is Nothing Then
				tMinValue = tTempVal
				tMinValCost = tTempCost
				Set tMinActNode = tActNode				
			ElseIf tTempVal < tMinValue Then
				tMinValue = tTempVal
				tMinValCost = tTempCost
				Set tMinActNode = tActNode
			End If
							
			'max by val
			If tMaxActNode Is Nothing Then
				tMaxValue = tTempVal
				tMaxValCost = tTempCost
				Set tMaxActNode = tActNode
			ElseIf tTempVal > tMaxValue Then
				tMaxValue = tTempVal
				tMaxValCost = tTempCost
				Set tMaxActNode = tActNode
			End If
		End If
	Next
	
	'check results
	If tReads = 0 Then
		fLogLine tLogTag, "Ошибка вычисления ноды [" & inExtractNode.NodeName & "] по методу [" & tMethod & "]: в файле типа [BaseB] не обнаружено субэлементов [" & inScanWord & "] для организации [строка:" & inBaseBOrgNode.GetAttribute("row") & "]"		
		Exit Function
	End If
				
	'form results
	Select Case tMethod
		Case "MINVAL":
			tTempVal = tMinValue
			tTempCost = tMinValCost
			Set tActNode = tMinActNode
		Case "MAXVAL": 						
			tTempVal = tMaxValue
			tTempCost = tMaxValCost
			Set tActNode = tMaxActNode
	End Select
	
	'contract extract
	tXPathString = "parent::contract"
	Set tContractNode = tActNode.SelectSingleNode(tXPathString)
	If tContractNode Is Nothing Then
		fLogLine tLogTag, "Не обнаружено родительской ноды [" & tActNode.NodeName & "/ROW=" & tActNode.GetAttribute("row") & "] при tXPathString = <" & tXPathString & ">"
		Exit Function
	End If

	fAddContractData ioContractList, ioContractSize, tContractNode.GetAttribute("id"), inStringCode, tTempVal, tTempCost, fXMLAttributeNumericRead(tContractNode.GetAttribute("value")), fXMLAttributeNumericRead(tContractNode.GetAttribute("cost")), inBaseBOrgNode.GetAttribute("name1c")
				
	'drop results
	tLockedRow = tActNode.GetAttribute("row")
	ioValStore = ioValStore + tTempVal
	ioCostStore = ioCostStore + tTempCost
	outValue = tTempVal
	fLogLine tLogTag, "Нода [" & inExtractNode.NodeName & "]: [code=" & inStringCode & "] по методу [" & tMethod & "] нашла подходящий элемент: ROW=" & tLockedRow & "; VAL=" & tTempVal & "; COST=" & tTempCost
	fScanMethod_Default = True
End Function

'Extract CONTRACT ALL contracts data from ORG NODE
Private Function fCollectInternalContracts(inBaseBOrgNode, inStringCode, ioContractList, ioContractSize)
	Dim tLogTag, tValue, tContractName, tContractVal, tContractCost, tReads
	Dim tXPathString, tContractNode, tContractNodes
	
	tLogTag = "fCollectInternalContracts"
	fCollectInternalContracts = False
	
	'get contract nodes
	tXPathString = "descendant::contract"
	Set tContractNodes = inBaseBOrgNode.SelectNodes(tXPathString)

	If tContractNodes.Length = 0 Then
		fLogLine tLogTag, "Не обнаружено дочерних нод [" & inBaseBOrgNode.NodeName & "] при tXPathString = <" & tXPathString & ">"
		Exit Function
	End If
	
	'scan
	tReads = 0
	For Each tContractNode In tContractNodes
		tContractName = tContractNode.GetAttribute("id")
		tContractVal = fXMLAttributeNumericRead(tContractNode.GetAttribute("value"))
		tContractCost = fXMLAttributeNumericRead(tContractNode.GetAttribute("cost"))
				
		fAddContractData ioContractList, ioContractSize, tContractName, inStringCode, tContractVal, tContractCost, tContractVal, tContractCost, inBaseBOrgNode.GetAttribute("name1c")
				
		tReads = tReads + 1
	Next
	
	If tReads = 0 Then
		fLogLine tLogTag, "Не удалось обнаружить записей договоров // tReads=0"		
		Exit Function
	End If
		
	fCollectInternalContracts = True
End Function

'tOrgContNode, inWorkBookB, tDataArray, tDataArraySize, tDataArrayLength, tPartVal, tPartCost
Private Function fGetBaseBValues(inContentNode, inBaseXML, ioDataArray, ioDataArraySize, inDataArrayLength, inDefaultCode, inContractList, inContractSize)
	Dim tLogTag, tOrgID, tOrgNode, tOrgName1C, tXPathString, tValue, tGTPCode, tFinReportUse, tMethod, tTempValue
	Dim tExtractNodes, tExtractNode, tTotalVal, tVal, tCost, tTempVal, tTempCost, tEtalonVal, tTotalCost, tCodeIndex
	Dim tValueIndex, tCostIndex, tStringCode, tMinValue, tMaxValue, tMinValCost, tMaxValCost, tTempValIndex, tTempCostIndex
	Dim tOrgNodeLocked, tDefaultTransferCode, tTransferCode, tTransferValue
	
	'defaults
	fGetBaseBValues = False
	tLogTag = "fGetBaseBValues"
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

	'lock ORG node BaseB (TODO PreINDEXing??? to lock by ID not name)
	tXPathString = "//file[@type='baseb']/organization[@name1c='" & tOrgName1C & "']"
	Set tOrgNode = inBaseXML.SelectSingleNode(tXPathString)
	If tOrgNode Is Nothing Then
		fLogLine tLogTag, "Искомую организацию не удалось найти в отчете типа [BaseB]"
		Exit Function
	End If

	'transfer value	
	tDefaultTransferCode = fAutoCorrectString(inContentNode.GetAttribute("transfercode"), True)	
	If tDefaultTransferCode <> vbNullString Then
		fAddNewCodeString ioDataArray, ioDataArraySize, inDataArrayLength, tDefaultTransferCode
	End If
	
	'default reads (non-ruled)
	tTotalVal = fXMLAttributeNumericRead(tOrgNode.GetAttribute("value")) 'value	
	tTotalCost = fXMLAttributeNumericRead(tOrgNode.GetAttribute("cost")) 'cost
	
	'reset val\cost
	For tCodeIndex = 0 To ioDataArraySize
		ioDataArray(tTempValIndex, tCodeIndex) = 0
		ioDataArray(tTempCostIndex, tCodeIndex) = 0
	Next
	
	'extract nodes work
	tXPathString = "child::extract"
	Set tExtractNodes = inContentNode.SelectNodes(tXPathString)
	
	If tExtractNodes.Length > 0 Then
		
		'collecting
		For Each tExtractNode In tExtractNodes
			
			'code extraction OR drop to default (if no mention)
			tStringCode = fAutoCorrectString(tExtractNode.GetAttribute("code"), True)			
			fAddNewCodeString ioDataArray, ioDataArraySize, inDataArrayLength, tStringCode
			If tStringCode = vbNullString Then: tStringCode = inDefaultCode			
			
			tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, tStringCode)

			If tCodeIndex = -1 Then
				fLogLine tLogTag, "Не удалось определить индекс строки по умолчанию [аттрибут @code]: искомый код <" & tStringCode & ">"			
				Exit Function
			End If
			
			'using finreport groups?
			'tFinReportUse = fAutoCorrectNumeric(tExtractNode.GetAttribute("finreportuse"), 0, 0, 1) = 1			

			If fAutoCorrectNumeric(tExtractNode.GetAttribute("finreportuse"), 0, 0, 1) = 1 Then
					 'fScanMethod_FinReport(inExtractNode, inWorkSheet, 					inSheetIndex, inStartRowIndex, inLastRowIndex, inScanCol, inValCol, inCostCol, inStringCode, inScanWord, ioValStore, ioCostStore, inSafeRead)
				If Not fScanMethod_FinReport(tExtractNode, tOrgNode, tStringCode, "реализация", ioDataArray(tTempValIndex, tCodeIndex), ioDataArray(tTempCostIndex, tCodeIndex), inContractList, inContractSize, tTransferValue) Then
					Exit Function
				End If
			Else
				If Not fScanMethod_Default(tExtractNode, tOrgNode, tStringCode, "реализация", ioDataArray(tTempValIndex, tCodeIndex), ioDataArray(tTempCostIndex, tCodeIndex), inContractList, inContractSize, tTransferValue) Then
					Exit Function
				End If				
			End If

			'get transfer code string
			tTransferCode = fAutoCorrectString(tExtractNode.GetAttribute("transfercode"), True)			
			fAddNewCodeString ioDataArray, ioDataArraySize, inDataArrayLength, tTransferCode
			If tTransferCode = vbNullString Then: tTransferCode = tDefaultTransferCode			
			tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, tTransferCode)

			If tCodeIndex = -1 Then
				fLogLine tLogTag, "Внимание! Не удалось определить индекс строки [аттрибут @transfercode]: искомый код <" & tTransferCode & ">! Объем пропущен!"
			Else
				ioDataArray(tTempValIndex, tCodeIndex) = ioDataArray(tTempValIndex, tCodeIndex) + tTransferValue
			End If
			
		Next
		
	'non-ruled	1 TO 1
	Else
		'BASEA
		tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, inDefaultCode)
		If tCodeIndex = -1 Then
			fLogLine tLogTag, "Не удалось определить индекс строки по умолчанию [аттрибут @code]: искомый код <" & inDefaultCode & ">"			
			Exit Function
		End If
		
		ioDataArray(tTempValIndex, tCodeIndex) = tTotalVal
		ioDataArray(tTempCostIndex, tCodeIndex) = tTotalCost

		'TRANSFER LOCK
		tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, tDefaultTransferCode)
		If tCodeIndex = -1 Then
			fLogLine tLogTag, "Не удалось определить индекс строки по умолчанию [аттрибут @trasfercode]: искомый код <" & tDefaultTransferCode & ">"			
			Exit Function
		End If
		
		ioDataArray(tTempValIndex, tCodeIndex) = tTotalVal 'only value		
		
		If Not fCollectInternalContracts(tOrgNode, inDefaultCode, inContractList, inContractSize) Then
			Exit Function
		End If
	End If
	
	'finalyze
	For tCodeIndex = 0 To ioDataArraySize
		If ioDataArray(0, tCodeIndex) <> "0" And (ioDataArray(tTempValIndex, tCodeIndex) <> 0 Or ioDataArray(tTempCostIndex, tCodeIndex) <> 0) Then
			fLogLine tLogTag, "Распределение данных по строкам [Использовано договоров: " & inContractSize + 1 & "][Строка: " & ioDataArray(0, tCodeIndex) & "]: VAL=" & ioDataArray(tTempValIndex, tCodeIndex) & "; COST=" & ioDataArray(tTempCostIndex, tCodeIndex) & " // TotalVal=" & tTotalVal & "; TotalCost=" & tTotalCost
		End If
	Next
		
	fGetBaseBValues = True	
End Function

Private Function fGetBaseAValues(inContentNode, inBaseXML, ioDataArray, ioDataArraySize, inDataArrayLength, inDefaultCode, inContractList, inContractSize)
	Dim tLogTag, tOrgID, tXPathString, tOrgNode, tOrgName1C, tContractRow
	Dim tValueA, tValueB, tValueC, tContractIndex, tNameElements, tContractName, tStringCode, tNameString, tCodeIndex, tPartIndex, tContractParentOrg
	Dim tDebtCost, tIncomeCost, tFactIncomeCost, tEndCredCost, tEndDebtCost, tContractNode
	
	'defaults
	tLogTag = "fGetBaseAValues"
	fGetBaseAValues = False	

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

	' lock ORG row in BaseB
	'lock ORG node BaseA (TODO PreINDEXing??? to lock by ID not name)
	tXPathString = "//file[@type='basea']/organization[@name1c='" & tOrgName1C & "']"
	Set tOrgNode = inBaseXML.SelectSingleNode(tXPathString)
	If tOrgNode Is Nothing Then
		fLogLine tLogTag, "Искомую организацию не удалось найти в отчете типа [BaseA]"
		Exit Function
	End If	

	'tCurrentCol = tScanCol
	'tIndexRow = 0	

	'scan for contract records
	For tContractIndex = 0 To inContractSize
	
		tContractName = inContractList(0, tContractIndex)
		tContractParentOrg = inContractList(6, tContractIndex)
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
		
		'GET CONTRACT
		tContractRow = 0

		'GET contract TRY #1 (with parent)
		tXPathString = "child::contract[@id='" & tContractName & "']"
		Set tContractNode = tOrgNode.SelectSingleNode(tXPathString)
		'GET contract TRY #2 (non-parent)
		If tContractNode Is Nothing Then
			tXPathString = "child::contract[@id='" & tContractName & "']"
			Set tContractNode = tOrgNode.SelectSingleNode(tXPathString)
		End If
		
		'Work with contract
		If Not tContractNode Is Nothing Then
			tContractRow = tContractNode.GetAttribute("row")
						
			'BEGIN // DEBT COST
			tValueA = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodstartdebt")) 'долг на начало
			tValueB = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodstartadvance")) 'аванс на начало
			tDebtCost = tValueA - tValueB
			tDebtCost = tDebtCost * tPartIndex
			ioDataArray(2, tCodeIndex) = ioDataArray(2, tCodeIndex) + tDebtCost
						
			'INCOME COST
			tIncomeCost = fXMLAttributeNumericRead(tContractNode.GetAttribute("sellsold"))
			tIncomeCost = tIncomeCost * tPartIndex
			ioDataArray(3, tCodeIndex) = ioDataArray(3, tCodeIndex) + tIncomeCost 'продано
								
			'INCOME FACT COST
			'tValueA = fXMLAttributeNumericRead(tContractNode.GetAttribute("sellpaid")) 'оплачено
			'tValueB = fXMLAttributeNumericRead(tContractNode.GetAttribute("prepaidincome")) 'поступило
			'tFactIncomeCost = tValueA + tValueB
			tValueA = fXMLAttributeNumericRead(tContractNode.GetAttribute("sellpaid")) 'оплачено
			tValueB = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodstartadvance")) 'аванс на начало
			tValueC = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodendadvance")) 'аванс на конец
			tFactIncomeCost = tValueA - tValueB + tValueC 'fix 2021-04-19
			tFactIncomeCost = tFactIncomeCost * tPartIndex
			ioDataArray(4, tCodeIndex) = ioDataArray(4, tCodeIndex) + tFactIncomeCost
						
			'END // CRED COST
			tEndCredCost = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodendadvance"))
			tEndCredCost = tEndCredCost * tPartIndex
			ioDataArray(10, tCodeIndex) = ioDataArray(10, tCodeIndex) + tEndCredCost 'аванс на конец
						
			'END // DEBT COST
			tEndDebtCost = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodenddebt"))
			tEndDebtCost = tEndDebtCost * tPartIndex
			ioDataArray(12, tCodeIndex) = ioDataArray(12, tCodeIndex) + tEndDebtCost 'долг на конец
						
			'LOGGING
			fLogLine tLogTag, "Данные договора [" & tStringCode & ":" & tContractName & "] успешно извлечены [К=" & Round(tPartIndex, 5) & "]: " & tDebtCost & " / " & tIncomeCost & " / " & tFactIncomeCost & " / " & tEndCredCost & " / " & tEndDebtCost
		End If		
		
		'lock check
		If tContractRow = 0 Then
			fLogLine tLogTag, "Договор [" & tContractName & "] не удалось найти в файле отчета типа [BaseA]."			
			Exit Function
		End If
	Next
	
	'success return	
	fGetBaseAValues = True
End Function

Private Function fGetExtractionPartIndexTransferDataNodes(inExtractionString, inContractID, inXMLNodes)
	Dim tLogTag, tNode, tLocked, tElements, tElement, tSumValue, tTempNode, tXPathString, tValue
	
	tLogTag = "fGetExtractionPartIndexTransferDataNodes"
	fGetExtractionPartIndexTransferDataNodes = 1

	If inExtractionString = vbNullString Then: Exit Function 'throttle
	
	If inXMLNodes Is Nothing Then
		fLogLine tLogTag, "inXMLNodes не определено. Ошибка логики."
		Exit Function
	End If

	If inXMLNodes.Length = 0 Then
		fLogLine tLogTag, "inXMLNodes (Length=0) не определено. Ошибка логики."
		Exit Function
	End If

	tLocked = False
	For Each tNode In inXMLNodes
		'WScript.Ec tNode.ParentNode.NodeName
		If tNode.ParentNode.GetAttribute("contractid") = inContractID Then
			tLocked = True
			Exit For
		End If
	Next

	If Not tLocked Then
		fLogLine tLogTag, "Не удалось найти договор [" & inContractID & "] в файле типа [transferdata]. Ошибка логики."
		Exit Function
	End If

	tSumValue = 0
	tElements = Split(UCase(inExtractionString), ";")
	For Each tElement In tElements	
		tXPathString = "child::element[@id='" & tElement & "']"
		Set tTempNode = tNode.SelectSingleNode(tXPathString)
		If tTempNode Is Nothing Then
			fLogLine tLogTag, "Не удалось найти ноду для ГТП [" & tElement & "] в файле типа [transferdata] для договора [" & inContractID & "] tXPathString=[" & tXPathString & "]"
			Exit Function
		End If
		tValue = tTempNode.Text
		If Not IsNumeric(tValue) Then
			fLogLine tLogTag, "Нода для ГТП [" & tElement & "] в файле типа [transferdata] для договора [" & inContractID & "] содержит нечисловое значение [" & tValue & "]"
			Exit Function
		End If
		tSumValue = tSumValue + tValue
	Next

	tXPathString = "child::total"
	Set tTempNode = tNode.SelectSingleNode(tXPathString)
	If tTempNode Is Nothing Then
		fLogLine tLogTag, "Не удалось найти ноду TOTAL в файле типа [transferdata] для договора [" & inContractID & "] tXPathString=[" & tXPathString & "]"
		Exit Function
	End If
	tValue = tTempNode.Text
	If Not IsNumeric(tValue) Then
		fLogLine tLogTag, "Нода для ГТП [" & tElement & "] в файле типа [transferdata] для договора [" & inContractID & "] содержит нечисловое значение [" & tValue & "]"
		Exit Function
	End If

	fGetExtractionPartIndexTransferDataNodes = tSumValue / tValue
	If fGetExtractionPartIndexTransferDataNodes > 1 Then
		fGetExtractionPartIndexTransferDataNodes = 1
		fLogLine tLogTag, "В файле типа [transferdata] для договора [" & inContractID & "] ошибка.. сумма элементов больше, чем общий объём!"
	End If

End Function

Private Function fGetBaseCValues(inTransferNode, inBaseXML, ioDataArray, ioDataArraySize, inDataArrayLength, inTransferXMLNode)
	Dim tLogTag, tContractID, tStringCode, tContractNode, tXPathString, tCodeIndex
	Dim tValueA, tValueB, tValueC, tPartIndex, tDebtCost, tIncomeCost, tFactIncomeCost, tEndCredCost, tEndDebtCost
	Dim tExtractString

	fGetBaseCValues = False
	tLogTag = "fGetBaseCValues"

	'get contract
	tContractID = UCase(fAutoCorrectString(inTransferNode.getAttribute("contractid"), True))
	tXPathString = "//file[@type='basec']/descendant::contract[@id='" & tContractID & "']"
	Set tContractNode = inBaseXML.SelectSingleNode(tXPathString)
	If tContractNode Is Nothing Then
		fLogLine tLogTag, "Искомый договор не удалось найти в отчете типа [BaseC]: " & tContractID
		Exit Function
	End If

	fLogLine tLogTag, "Договор [" & tContractID & "][ROW=" & tContractNode.GetAttribute("row") & "] найден. Контрагент [" & tContractNode.ParentNode.GetAttribute("name1c") & "]"

	'get code string
	tStringCode = fAutoCorrectString(inTransferNode.getAttribute("code"), True)
	fAddNewCodeString ioDataArray, ioDataArraySize, inDataArrayLength, tStringCode
	If tStringCode = vbNullString Then
		fLogLine tLogTag, "Не удалось установить код строки. Проверьте заполнение аттрибута @code"
		Exit Function
	End If

	'get code index by code string
	tCodeIndex = fGetCodeIndex(ioDataArray, ioDataArraySize, tStringCode)

	'get extrtaction part
	tPartIndex = 1
	tExtractString = fAutoCorrectString(inTransferNode.getAttribute("extract"), True)
	tPartIndex = fGetExtractionPartIndexTransferDataNodes(tExtractString, tContractID, inTransferXMLNode)

	'read values
	tValueA = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodstartdebt")) 'долг на начало
	tValueB = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodstartadvance")) 'аванс на начало
	tDebtCost = tValueA - tValueB
	tDebtCost = tDebtCost * tPartIndex
	ioDataArray(2, tCodeIndex) = ioDataArray(2, tCodeIndex) + tDebtCost

	'INCOME COST
	tIncomeCost = fXMLAttributeNumericRead(tContractNode.GetAttribute("sellsold"))
	tIncomeCost = tIncomeCost * tPartIndex
	ioDataArray(3, tCodeIndex) = ioDataArray(3, tCodeIndex) + tIncomeCost 'продано
								
	'INCOME FACT COST
	'tValueA = fXMLAttributeNumericRead(tContractNode.GetAttribute("sellpaid")) 'оплачено
	'tValueB = fXMLAttributeNumericRead(tContractNode.GetAttribute("prepaidincome")) 'поступило
	'tFactIncomeCost = tValueA' + tValueB 'fix 2021-04-19
	'tFactIncomeCost = tFactIncomeCost * tPartIndex

	tValueA = fXMLAttributeNumericRead(tContractNode.GetAttribute("sellpaid")) 'оплачено
	tValueB = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodstartadvance")) 'аванс на начало
	tValueC = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodendadvance")) 'аванс на конец
	tFactIncomeCost = tValueA - tValueB + tValueC 'fix 2021-04-19
	tFactIncomeCost = tFactIncomeCost * tPartIndex
	ioDataArray(4, tCodeIndex) = ioDataArray(4, tCodeIndex) + tFactIncomeCost
						
	'END // CRED COST
	tEndCredCost = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodendadvance"))
	tEndCredCost = tEndCredCost * tPartIndex
	ioDataArray(10, tCodeIndex) = ioDataArray(10, tCodeIndex) + tEndCredCost 'аванс на конец
						
	'END // DEBT COST
	tEndDebtCost = fXMLAttributeNumericRead(tContractNode.GetAttribute("periodenddebt"))
	tEndDebtCost = tEndDebtCost * tPartIndex
	ioDataArray(12, tCodeIndex) = ioDataArray(12, tCodeIndex) + tEndDebtCost 'долг на конец

	fLogLine tLogTag, "Данные договора [" & tStringCode & ":" & tContractID & "] успешно извлечены [К=" & Round(tPartIndex, 5) & "]: " & tDebtCost & " / " & tIncomeCost & " / " & tFactIncomeCost & " / " & tEndCredCost & " / " & tEndDebtCost

	fGetBaseCValues = True
End Function

Private Function fMakeBlankTemplate(inContentNode, inTemplateFile, inYear, inMonth, inRootFolder, inSubjectID, inSubjectName, outResultFile, inCheckFail)
	Dim tLogTag, tTemplateNode, tXPathString, tDropFolder, tNode, tCanCreate, tFileName, tExtension, tFullPath, tFileNameSuffix
	
	tLogTag = "fMakeBlankTemplate"
	fMakeBlankTemplate = False
	Set outResultFile = Nothing

	tFileNameSuffix = vbNullString 
	If inCheckFail Then: tFileNameSuffix = "!CHK_FAIL!"
	
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
	tFileName = fReprocessMask(tNode.Text, inYear, inMonth, inRootFolder) & tFileNameSuffix & tExtension
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

			'tCode = 0 -- ignore fill group
			If tCode <> 0 Then
				'lock
				For tIndex = 0 To gCodeArraySize
					If tCode = gCodeArray(tIndex) Then
						tDataRow = gRowArray(tIndex)
						Exit For
					End If
				Next

				'fill
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

Private Function fCreateReportByContentNode(inContentNode, inTemplateFile, inBaseXML, inYear, inMonth, inRootFolder, inSubjectID, inSubjectName, inTransferXMLNode, inTempValue, outCheckFail)
	Dim tLogTag, tOrgContNodes, tOrgContNode, tTransferNodes, tTransferNode ', tTotalVal, tTargetVal, tTotalCost, tTargetCost
	'Dim tDebtCost, tIncomeCost, tFactIncomeCost, tEndCredCost, tEndDebtCost, , tResultWorkBook, tDefaultCode
	Dim tDataArray()
	Dim tDataArraySize, tDataArrayLength, tCodeIndex, tDataArrayActLength
	Dim tResultWorkBook, tDefaultCode, tResultFile
	Dim tContractList()
	Dim tContractSize, tIndex
	Dim tValGr9, tValGr11, tElementsCount, tExtractsCount, tCorrectionLimit, tTempValue
	
	tLogTag = "fCreateReportByContentNode"
	fCreateReportByContentNode = False
	tDataArraySize = -1
	tIndex = 1
	outCheckFail = False
	tTempValue = 0 'for logging
	'inContractListSize = -1
	tDataArrayActLength = 19
	tDataArrayLength = tDataArrayActLength + 2 '19 + 2 internal vals '20=TempVAL 21=TempCOST
	
	fLogLine tLogTag, "###### Сборка контента начата..."	
	
	'main scan
	Set tOrgContNodes = inContentNode.SelectNodes("descendant::organization")
	tElementsCount = tOrgContNodes.Length
	For Each tOrgContNode In tOrgContNodes

		'correction resolution multiplier
		tExtractsCount = tOrgContNode.SelectNodes("child::extract").Length
		If tExtractsCount > 1 Then: tElementsCount = tElementsCount + (tExtractsCount - 1)

		fLogLine tLogTag, " >> Сборка: Элемента A #" & tIndex & " из " & tOrgContNodes.Length		
		
		tDefaultCode = fAutoCorrectString(tOrgContNode.GetAttribute("code"), True)
		fAddNewCodeString tDataArray, tDataArraySize, tDataArrayLength, tDefaultCode		
				
		If Not fGetBaseBValues(tOrgContNode, inBaseXML, tDataArray, tDataArraySize, tDataArrayLength, tDefaultCode, tContractList, tContractSize) Then: Exit Function
		If Not fGetBaseAValues(tOrgContNode, inBaseXML, tDataArray, tDataArraySize, tDataArrayLength, tDefaultCode, tContractList, tContractSize) Then: Exit Function	

		'sum it
		For tCodeIndex = 0 To tDataArraySize
			tDataArray(1, tCodeIndex) = tDataArray(1, tCodeIndex) + tDataArray(20, tCodeIndex)
			tDataArray(5, tCodeIndex) = tDataArray(5, tCodeIndex) + tDataArray(21, tCodeIndex)
			tDataArray(3, tCodeIndex) = tDataArray(5, tCodeIndex) 'fix 2021-04-19
			tTempValue = tTempValue + tDataArray(20, tCodeIndex) 'fix 2021-04-20 <- to control value by OPERATOR (only for logging)
		Next
		
		tIndex = tIndex + 1
	Next

	'transfer scan
	tIndex = 1
	Set tTransferNodes = inContentNode.SelectNodes("descendant::transfer")
	For Each tTransferNode In tTransferNodes

		fLogLine tLogTag, " >> Сборка: Элемента B #" & tIndex & " из " & tTransferNodes.Length

		'tDefaultCode = 102 will be transfered as VALUE to 2.1.GR1
		If Not fGetBaseCValues(tTransferNode, inBaseXML, tDataArray, tDataArraySize, tDataArrayLength, inTransferXMLNode) Then: Exit Function

		tIndex = tIndex + 1
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

	'internal logic check \\ fix 2021-04-19
	tCorrectionLimit = 0.001 * tElementsCount
	For tCodeIndex = 0 To tDataArraySize
		If tDataArray(0, tCodeIndex) <> "0" Then
			tValGr9 = Round(tDataArray(2, tCodeIndex) + tDataArray(3, tCodeIndex) - tDataArray(4, tCodeIndex) - tDataArray(6, tCodeIndex), 3)
			tValGr11 = Round(tDataArray(12, tCodeIndex) + tDataArray(13, tCodeIndex) + tDataArray(14, tCodeIndex) + tDataArray(17, tCodeIndex) + tDataArray(18, tCodeIndex) - tDataArray(10, tCodeIndex), 3)
			fLogLine tLogTag, "Строка " & tDataArray(0, tCodeIndex) & ":: Проверка (Гр9=Гр11-Гр10) Результат (" & tValGr9 & " =? " & tValGr11 & ") >> " & (tValGr9 = tValGr11) & ""
			
			'correction
			If Abs(Round(tValGr9 - tValGr11, 3)) <= tCorrectionLimit And Abs(Round(tValGr9 - tValGr11, 3)) > 0 Then
				fLogLine tLogTag, "Строка " & tDataArray(0, tCodeIndex) & ":: Проверка (Гр9=Гр11-Гр10) Расхождение в пределах " & tCorrectionLimit & "! Коррекция Гр4 на " & Round(tValGr9 - tValGr11, 3)
				tDataArray(4, tCodeIndex) = Round(tDataArray(4, tCodeIndex) + Round(tValGr9 - tValGr11, 3), 3)
				
				'final check
				tValGr9 = Round(tDataArray(2, tCodeIndex) + tDataArray(3, tCodeIndex) - tDataArray(4, tCodeIndex) - tDataArray(6, tCodeIndex), 3)
				tValGr11 = Round(tDataArray(12, tCodeIndex) + tDataArray(13, tCodeIndex) + tDataArray(14, tCodeIndex) + tDataArray(17, tCodeIndex) + tDataArray(18, tCodeIndex) - tDataArray(10, tCodeIndex), 3)
				fLogLine tLogTag, "Строка " & tDataArray(0, tCodeIndex) & ":: Проверка (Гр9=Гр11-Гр10) Результат (" & tValGr9 & " =? " & tValGr11 & ") >> " & (tValGr9 = tValGr11) & ""
			ElseIf Abs(Round(tValGr9 - tValGr11, 3)) > tCorrectionLimit Then
				fLogLine tLogTag, "Строка " & tDataArray(0, tCodeIndex) & ":: Проверка (Гр9=Гр11-Гр10) Внимание расхождение больше " & tCorrectionLimit & "! Вероятна ошибка."
				outCheckFail = True
			End If
		End If
	Next
	
	'prepare report file from template filled with constfields and ect
	If Not fMakeBlankTemplate(inContentNode, inTemplateFile, inYear, inMonth, inRootFolder, inSubjectID, inSubjectName, tResultFile, outCheckFail) Then
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
	inTempValue = inTempValue + tTempValue 'back changes

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
	Dim tXMLFilePathA, tXMLFilePathB, tXMLFileFolderLock, tRoot

	Set gBaseXML = CreateObject("Msxml2.DOMDocument.6.0")
	Set tRoot = gBaseXML.CreateElement("message")
    gBaseXML.AppendChild tRoot
	Set tRoot = Nothing

	Set gFSO = CreateObject("Scripting.FileSystemObject")
	Set gWSO = CreateObject("WScript.Shell")
	Set gRExp = WScript.CreateObject("VBScript.RegExp")
	gRExp.IgnoreCase = True
	
	gTraderID = "BELKAMKO"
	gDefaultLogFileName = "Log.txt"
	gBaseXMLLogFileName = "Log.xml"

	gLogYear = 0
	gLogMonth = 0
	
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
	Set gBaseXML = Nothing
	'quit
	'WScript.Echo "Done"
	WScript.Quit
End Sub

Private Sub fMain()
	Dim tYear, tMonth, tLogTag	
	Dim tSubjectNode, tSubjectNodes, tSubjectID, tSubjectName, tXPathStringA, tXPathStringB, tContentNode
	Dim tRootFolder, tTransferXMLNode, tDateStamp, tCounter, tTempValue, tCheckFail
	
	tLogTag = "MAIN"
	gCodeArraySize = -1
	gCodeScanColumn = 0

	' // запрос ДАТЫ периода у пользователя Year(Date()), Month(Date())
	If Not fReportPeriodAsk(tYear, tMonth, 2020, 1) Then
		fLogLine tLogTag, "Не удалось получить дату периода от пользователя!"
		Exit Sub
	End If

	gLogYear = tYear
	gLogMonth = tMonth
	
	' // Поиск файлов
	tRootFolder = gFSO.GetFolder(gScriptPath)
	If Not fFileScanner(tRootFolder, gTraderID, tYear, tMonth) Then: Exit Sub
	
	' // Чтение файлов
	If Not fFileReader(tYear, tMonth, gBaseXML, tTransferXMLNode) Then: Exit Sub
	
	' // Основная работа
	tCounter = 0
	tTempValue = 0
	tXPathStringA = "//subjects/subject"
	Set tSubjectNodes = gConfigXML.SelectNodes(tXPathStringA)
	For Each tSubjectNode In tSubjectNodes
		
		'ID
		tSubjectID = fAutoCorrectNumeric(tSubjectNode.GetAttribute("id"), 0, 0, "ANY")
		
		'NAME
		tXPathStringB = "descendant::name"
		Set tSubjectName = tSubjectNode.SelectSingleNode(tXPathStringB)
		
		If tSubjectName Is Nothing Then
			fLogLine tLogTag, "Неверно заполнен блок [tSubjectID=" & tSubjectID & " -> " & tXPathStringB & "]"
			Exit For
		End If
		
		tSubjectName = tSubjectName.Text		
		fLogLine tLogTag, "Субъект в работе: [" & tSubjectID & "] [" & tSubjectName & "]"
		
		'CONTENT
		tDateStamp = Fix(tYear & fNZeroAdd(tMonth, 2))
		tXPathStringB = "descendant::content[(@start<=" & tDateStamp & " and @end>=" & tDateStamp & ")]"
		Set tContentNode = tSubjectNode.SelectNodes(tXPathStringB)
		
		If tContentNode.Length <> 1 Then
			fLogLine tLogTag, "Неверно заполнен блок [tSubjectName=" & tSubjectName & " -> " & tXPathStringB & "]"
			fLogLine tLogTag, "Ожидалось найти <1> ноду [content], а найдено <" & tContentNode.Length & ">"
			fLogLine tLogTag, "Субъект не обработан."			
		Else
			If Not fCreateReportByContentNode(tContentNode(0), gTemplate, gBaseXML, tYear, tMonth, tRootFolder, tSubjectID, tSubjectName, tTransferXMLNode, tTempValue, tCheckFail) Then
				fLogLine tLogTag, "Субъект не обработан."
			Else
				If Not tCheckFail Then: tCounter = tCounter + 1
			End If
		End If
	Next
	
	' // Фиширеры
	fLogLine tLogTag, "Проверка объёма регионов: " & tTempValue
	WScript.Echo "Успешно обработано субъектов " & tCounter & " из " & tSubjectNodes.Length & "..." & vbCrLf & "Подробности в файлах логов."
End Sub

Private Sub fTestingGround()
	Dim tTempXML, tTempRecord

	Set tTempXML = CreateObject("Msxml2.DOMDocument.6.0")
	Set tTempRecord = tTempXML.CreateElement("record")
	tTempRecord.SetAttribute "id", "cow"
	Set tTempXML = Nothing
	WScript.Echo "NodeName=" & tTempRecord.NodeName & "; NodeAttrID=" & tTempRecord.GetAttribute("id")
	Set tTempRecord = Nothing
	WScript.Echo "Test over"
	WScript.Quit
End Sub

'======= // MAIN

fInit
fMain
fQuitScript