Attribute VB_Name = "modBenchmark"
Option Explicit

Private Type BenchmarkTimeVal
    seconds As LongPtr
    microseconds As Long
End Type
Private Declare PtrSafe Function BenchmarkGetTime Lib "/usr/lib/libSystem.B.dylib" Alias "gettimeofday" (ByRef value As BenchmarkTimeVal, ByVal zone As LongPtr) As Long

Private Function BenchmarkClock() As Double
    Dim tv As BenchmarkTimeVal
    If BenchmarkGetTime(tv, 0) <> 0 Then Err.Raise vbObjectError + 900, , "Clock failed"
    BenchmarkClock = CDbl(tv.seconds) + CDbl(tv.microseconds) / 1000000#
End Function

Public Sub BenchmarkExcelOWSA50()
    BenchmarkExcelRun "OWSA", 50
End Sub

Public Sub BenchmarkExcelPSA50()
    BenchmarkExcelRun "PSA", 50
End Sub

Public Sub BenchmarkExcelPilot()
    BenchmarkExcelRun "OWSA", 1
    BenchmarkExcelRun "PSA", 1
End Sub

Private Sub BenchmarkExcelRun(ByVal task As String, ByVal repetitions As Long)
    Dim trial As Long, seconds As Double, handle As Integer
    Dim outputPath As String, originalIterations As Variant
    Dim errNumber As Long, errText As String, outputOpen As Boolean
    On Error GoTo Failed
    If InStr(1, ThisWorkbook.Name, "benchmark", vbTextCompare) = 0 Then
        Err.Raise vbObjectError + 901, , "Open US_benchmark.xlsm to run the timing macros."
    End If
    If Application.Workbooks.Count <> 1 Then
        Err.Raise vbObjectError + 902, , "Close other workbooks before timing: the existing macros use Application.Calculate."
    End If
    originalIterations = ThisWorkbook.Worksheets(PSARawSheetName()).Range(PSA_ITERATION_CELL).Value2
    ThisWorkbook.Worksheets(PSARawSheetName()).Range(PSA_ITERATION_CELL).Value2 = 1000
    outputPath = ThisWorkbook.Path & Application.PathSeparator & "excel_" & LCase$(task) & "_times.csv"
    handle = FreeFile
    Open outputPath For Output As #handle
    outputOpen = True
    Print #handle, "engine,task,trial,seconds,psa_draws,scope"
    Application.CalculateFull
    For trial = 1 To repetitions
        If task = "OWSA" Then
            seconds = BenchmarkOWSAOnce()
        Else
            seconds = BenchmarkPSAOnce()
        End If
        Print #handle, "Excel," & task & "," & trial & "," & Trim$(Str$(seconds)) & ",1000,native_macro_including_worksheet_IO"
    Next trial
    Close #handle
    outputOpen = False
    ThisWorkbook.Worksheets(PSARawSheetName()).Range(PSA_ITERATION_CELL).Value2 = originalIterations
    MsgBox "Timing saved: " & outputPath, vbInformation
    Exit Sub
Failed:
    errNumber = Err.Number
    errText = Err.Description
    If outputOpen Then Close #handle
    If Not IsEmpty(originalIterations) Then ThisWorkbook.Worksheets(PSARawSheetName()).Range(PSA_ITERATION_CELL).Value2 = originalIterations
    MsgBox "Benchmark failed: " & errNumber & " " & errText, vbExclamation
End Sub


Private Function BenchmarkOWSAOnce() As Double
    Dim benchmarkStarted As Double
    benchmarkStarted = BenchmarkClock()

    Dim oldCalculation As XlCalculation
    Dim oldScreenUpdating As Boolean
    Dim oldEnableEvents As Boolean

    Dim fastModeStarted As Boolean
    Dim stateSaved As Boolean

    Dim wsParameter As Worksheet
    Dim wsOutput As Worksheet

    Dim arms() As ArmDef
    Dim nArms As Long

    Dim lowCosts() As Double
    Dim lowQalys() As Double
    Dim highCosts() As Double
    Dim highQalys() As Double

    Dim firstParameterRow As Long
    Dim lastParameterRowValue As Long

    Dim parameterRow As Long
    Dim armIndex As Long

    Dim outputRow As Long
    Dim outputCol As Long

    Dim baseValue As Variant
    Dim lowValue As Variant
    Dim highValue As Variant

    Dim savedInputFormulas As Variant
    Dim baselineValues As Variant

    Dim parameterCount As Long

    Dim errorNumber As Long
    Dim errorMessage As String

    On Error GoTo CleanFail

    ValidateModelCore
    RequireWorksheet OWSARawSheetName()

    BeginFastMode oldCalculation, oldScreenUpdating, oldEnableEvents
    fastModeStarted = True

    Set wsParameter = ThisWorkbook.Worksheets(ParameterSheetName())
    Set wsOutput = ThisWorkbook.Worksheets(OWSARawSheetName())

    firstParameterRow = PARAM_HEADER_ROW + 1
    lastParameterRowValue = LastParameterRow()

    nArms = LoadArms(arms)

    savedInputFormulas = wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Formula
    stateSaved = True

    baselineValues = wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_BASE_COL), wsParameter.Cells(lastParameterRowValue, PARAM_BASE_COL)).Value2

    wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Value2 = baselineValues

    Application.Calculate

    wsOutput.Range(wsOutput.Cells(SA_OUTPUT_ROW, 1), wsOutput.Cells(wsOutput.Rows.count, wsOutput.Columns.count)).ClearContents

    wsOutput.Cells(SA_OUTPUT_ROW, 1).Value2 = "ParameterRow"
    wsOutput.Cells(SA_OUTPUT_ROW, 2).Value2 = "Category"
    wsOutput.Cells(SA_OUTPUT_ROW, 3).Value2 = "Parameter"
    wsOutput.Cells(SA_OUTPUT_ROW, 4).Value2 = "BaseValue"
    wsOutput.Cells(SA_OUTPUT_ROW, 5).Value2 = "LowValue"
    wsOutput.Cells(SA_OUTPUT_ROW, 6).Value2 = "HighValue"

    outputCol = 7

    For armIndex = 1 To nArms

        wsOutput.Cells(SA_OUTPUT_ROW, outputCol).Value2 = arms(armIndex).ArmName & "_Cost_Low"
        wsOutput.Cells(SA_OUTPUT_ROW, outputCol + 1).Value2 = arms(armIndex).ArmName & "_QALY_Low"
        wsOutput.Cells(SA_OUTPUT_ROW, outputCol + 2).Value2 = arms(armIndex).ArmName & "_Cost_High"
        wsOutput.Cells(SA_OUTPUT_ROW, outputCol + 3).Value2 = arms(armIndex).ArmName & "_QALY_High"

        outputCol = outputCol + 4

    Next armIndex

    outputRow = SA_OUTPUT_ROW + 1

    For parameterRow = firstParameterRow To lastParameterRowValue

        Application.StatusBar = "OWSA: parameter row " & parameterRow & " / " & lastParameterRowValue

        If Len(Trim$(CStr(wsParameter.Cells(parameterRow, PARAM_NAME_COL).Value2))) > 0 Then

            baseValue = wsParameter.Cells(parameterRow, PARAM_BASE_COL).Value2
            lowValue = wsParameter.Cells(parameterRow, PARAM_LOW_COL).Value2
            highValue = wsParameter.Cells(parameterRow, PARAM_HIGH_COL).Value2

            If Not IsError(baseValue) And Not IsError(lowValue) And Not IsError(highValue) Then

                If IsNumeric(baseValue) And IsNumeric(lowValue) And IsNumeric(highValue) Then

                    If CDbl(lowValue) <> CDbl(highValue) Then

                        wsParameter.Cells(parameterRow, PARAM_INPUT_COL).Value2 = CDbl(lowValue)

                        Application.Calculate

                        ReadArmOutcomes arms, nArms, lowCosts, lowQalys

                        wsParameter.Cells(parameterRow, PARAM_INPUT_COL).Value2 = CDbl(highValue)

                        Application.Calculate

                        ReadArmOutcomes arms, nArms, highCosts, highQalys

                        wsOutput.Cells(outputRow, 1).Value2 = parameterRow
                        wsOutput.Cells(outputRow, 2).Value2 = wsParameter.Cells(parameterRow, PARAM_CATEGORY_COL).Value2
                        wsOutput.Cells(outputRow, 3).Value2 = wsParameter.Cells(parameterRow, PARAM_NAME_COL).Value2
                        wsOutput.Cells(outputRow, 4).Value2 = baseValue
                        wsOutput.Cells(outputRow, 5).Value2 = lowValue
                        wsOutput.Cells(outputRow, 6).Value2 = highValue

                        outputCol = 7

                        For armIndex = 1 To nArms

                            wsOutput.Cells(outputRow, outputCol).Value2 = lowCosts(armIndex)
                            wsOutput.Cells(outputRow, outputCol + 1).Value2 = lowQalys(armIndex)
                            wsOutput.Cells(outputRow, outputCol + 2).Value2 = highCosts(armIndex)
                            wsOutput.Cells(outputRow, outputCol + 3).Value2 = highQalys(armIndex)

                            outputCol = outputCol + 4

                        Next armIndex

                        parameterCount = parameterCount + 1
                        outputRow = outputRow + 1

                        wsParameter.Cells(parameterRow, PARAM_INPUT_COL).Value2 = baseValue

                    End If

                End If

            End If

        End If

        If parameterRow Mod 10 = 0 Then DoEvents

    Next parameterRow

    wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Formula = savedInputFormulas

    Application.Calculate

    wsOutput.Rows(SA_OUTPUT_ROW).Font.Bold = True
    wsOutput.Columns.AutoFit

    EndFastMode oldCalculation, oldScreenUpdating, oldEnableEvents

    BenchmarkOWSAOnce = BenchmarkClock() - benchmarkStarted

    Exit Function


CleanFail:

    errorNumber = Err.Number
    errorMessage = Err.Description

    On Error Resume Next

    If stateSaved Then
        wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Formula = savedInputFormulas
        Application.Calculate
    End If

    If fastModeStarted Then
        EndFastMode oldCalculation, oldScreenUpdating, oldEnableEvents
    End If

    On Error GoTo 0

    Err.Raise errorNumber, "BenchmarkOWSAOnce", errorMessage

End Function

Private Function BenchmarkPSAOnce() As Double
    Dim benchmarkStarted As Double
    benchmarkStarted = BenchmarkClock()

    Dim oldCalculation As XlCalculation
    Dim oldScreenUpdating As Boolean
    Dim oldEnableEvents As Boolean

    Dim fastModeStarted As Boolean
    Dim stateSaved As Boolean

    Dim wsParameter As Worksheet
    Dim wsOutput As Worksheet

    Dim arms() As ArmDef
    Dim nArms As Long

    Dim costs() As Double
    Dim qalys() As Double

    Dim firstParameterRow As Long
    Dim lastParameterRowValue As Long

    Dim iterationSetting As Variant
    Dim nIterations As Long

    Dim iterationIndex As Long
    Dim parameterRow As Long
    Dim armIndex As Long

    Dim outputCol As Long
    Dim totalOutputCols As Long

    Dim distributionName As String
    Dim drawValue As Variant

    Dim savedInputFormulas As Variant
    Dim baselineValues As Variant
    Dim psaValues As Variant
    Dim workingInputValues As Variant

    Dim results() As Variant

    Dim errorNumber As Long
    Dim errorMessage As String

    On Error GoTo CleanFail

    ValidateModelCore
    RequireWorksheet PSARawSheetName()

    BeginFastMode oldCalculation, oldScreenUpdating, oldEnableEvents
    fastModeStarted = True

    Set wsParameter = ThisWorkbook.Worksheets(ParameterSheetName())
    Set wsOutput = ThisWorkbook.Worksheets(PSARawSheetName())

    firstParameterRow = PARAM_HEADER_ROW + 1
    lastParameterRowValue = LastParameterRow()

    nArms = LoadArms(arms)

    iterationSetting = wsOutput.Range(PSA_ITERATION_CELL).Value2

    If IsError(iterationSetting) Or Not IsNumeric(iterationSetting) Then
        Err.Raise vbObjectError + 200, "RunPSA", "PSA iterations must be numeric."
    End If

    If CDbl(iterationSetting) <= 0 Then
        Err.Raise vbObjectError + 201, "RunPSA", "PSA iterations must be greater than zero."
    End If

    If CDbl(iterationSetting) <> Fix(CDbl(iterationSetting)) Then
        Err.Raise vbObjectError + 202, "RunPSA", "PSA iterations must be a whole number."
    End If

    nIterations = CLng(iterationSetting)

    savedInputFormulas = wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Formula
    stateSaved = True

    baselineValues = wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_BASE_COL), wsParameter.Cells(lastParameterRowValue, PARAM_BASE_COL)).Value2

    totalOutputCols = 1 + nArms * 2

    ReDim results(1 To nIterations, 1 To totalOutputCols)

    For iterationIndex = 1 To nIterations

        If iterationIndex = 1 Or iterationIndex Mod 10 = 0 Or iterationIndex = nIterations Then
            Application.StatusBar = "PSA: iteration " & iterationIndex & " / " & nIterations
        End If

        wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_PSA_COL), wsParameter.Cells(lastParameterRowValue, PARAM_PSA_COL)).Calculate

        psaValues = wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_PSA_COL), wsParameter.Cells(lastParameterRowValue, PARAM_PSA_COL)).Value2

        workingInputValues = baselineValues

        For parameterRow = firstParameterRow To lastParameterRowValue

            If Len(Trim$(CStr(wsParameter.Cells(parameterRow, PARAM_NAME_COL).Value2))) > 0 Then

                distributionName = UCase$(Trim$(CStr(wsParameter.Cells(parameterRow, PARAM_DIST_COL).Value2)))

                If distributionName <> "" And distributionName <> "NA" Then

                    drawValue = psaValues(parameterRow - firstParameterRow + 1, 1)

                    If Not IsError(drawValue) Then

                        If IsNumeric(drawValue) Then
                            workingInputValues(parameterRow - firstParameterRow + 1, 1) = CDbl(drawValue)
                        End If

                    End If

                End If

            End If

        Next parameterRow

        wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Value2 = workingInputValues

        Application.Calculate

        ReadArmOutcomes arms, nArms, costs, qalys

        results(iterationIndex, 1) = iterationIndex

        outputCol = 2

        For armIndex = 1 To nArms

            results(iterationIndex, outputCol) = costs(armIndex)
            results(iterationIndex, outputCol + 1) = qalys(armIndex)

            outputCol = outputCol + 2

        Next armIndex

        If iterationIndex Mod 50 = 0 Then DoEvents

    Next iterationIndex

    wsOutput.Range(wsOutput.Cells(SA_OUTPUT_ROW, 1), wsOutput.Cells(wsOutput.Rows.count, wsOutput.Columns.count)).ClearContents

    wsOutput.Cells(SA_OUTPUT_ROW, 1).Value2 = "Iteration"

    outputCol = 2

    For armIndex = 1 To nArms

        wsOutput.Cells(SA_OUTPUT_ROW, outputCol).Value2 = arms(armIndex).ArmName & "_Cost"
        wsOutput.Cells(SA_OUTPUT_ROW, outputCol + 1).Value2 = arms(armIndex).ArmName & "_QALY"

        outputCol = outputCol + 2

    Next armIndex

    wsOutput.Range(wsOutput.Cells(SA_OUTPUT_ROW + 1, 1), wsOutput.Cells(SA_OUTPUT_ROW + nIterations, totalOutputCols)).Value = results

    wsOutput.Rows(SA_OUTPUT_ROW).Font.Bold = True
    wsOutput.Columns.AutoFit

    wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Formula = savedInputFormulas

    Application.Calculate

    EndFastMode oldCalculation, oldScreenUpdating, oldEnableEvents

    BenchmarkPSAOnce = BenchmarkClock() - benchmarkStarted

    Exit Function


CleanFail:

    errorNumber = Err.Number
    errorMessage = Err.Description

    On Error Resume Next

    If stateSaved Then
        wsParameter.Range(wsParameter.Cells(firstParameterRow, PARAM_INPUT_COL), wsParameter.Cells(lastParameterRowValue, PARAM_INPUT_COL)).Formula = savedInputFormulas
        Application.Calculate
    End If

    If fastModeStarted Then
        EndFastMode oldCalculation, oldScreenUpdating, oldEnableEvents
    End If

    On Error GoTo 0

    Err.Raise errorNumber, "BenchmarkPSAOnce", errorMessage

End Function
