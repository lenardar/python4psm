on run argv
    set workbookPath to item 1 of argv
    tell application "Microsoft Excel"
        set book to open workbook workbook file name workbookPath
        try
            set controls to worksheet "控制界面" of book
            set results to worksheet "基础分析" of book
            calculate
            set baseCosts to value of range "B4:C4" of results
            set value of range "D107" of controls to 0
            calculate
            set removed to value of range "B4:C4" of results
            set formula r1c1 of range "D107" of controls to "=RC[1]"
            set value of range "D76:D79" of controls to 1
            calculate
            set unitQaly to value of range "B18:C18" of results
            set formula r1c1 of range "D76:D79" of controls to "=RC[1]"
            set value of range "D4:D5" of controls to 0
            calculate
            set rawCosts to value of range "B4:C4" of results
            set rawQaly to value of range "B18:C18" of results
            set formula r1c1 of range "D4:D5" of controls to "=RC[1]"

            repeat with pair in {{"D37:D38", "=R[-26]C[1]"}, {"D53:D55", "=R[-25]C[1]"}, {"D56:D65", "=R[10]C[1]"}, {"D76", "=R[1]C[1]"}, {"D78", "=R[1]C[1]"}, {"D100", "=R[1]C[1]"}, {"D105", "=R[1]C[1]"}}
                set formula r1c1 of range (item 1 of pair) of controls to (item 2 of pair)
            end repeat
            set value of range "D103" of controls to 0
            calculate
            set deltaCost to value of range "C22" of results
            set deltaQaly to value of range "C23" of results
            set formula r1c1 of range "D4:D131" of controls to "=RC[1]"
            set value of range "D100:D131" of controls to 0
            calculate
            set zeroCosts to value of range "B4:C4" of results
            set formula r1c1 of range "D100:D131" of controls to "=RC[1]"

            repeat with shName in {"ICC计算", "Dato 计算"}
                set sh to worksheet (contents of shName) of book
                set value of range "F6" of sh to "Exponential"
                set value of range "S6" of sh to "Exponential"
            end repeat
            repeat with addr in {"D6", "D19", "D32", "D44", "D5"}
                set value of range (contents of addr) of controls to 0
            end repeat
            set value of range "D76:D79" of controls to 1
            calculate
            set horizonValues to value of range "B18:C18" of results
            set csvText to "arm,qaly,terminal,no_dr_cost,no_dr_qaly,zero,years,delta_cost,delta_qaly"
            repeat with i from 1 to 2
                set arm to item i of {"ICC", "Dato"}
                set terminal to (item i of item 1 of baseCosts) - (item i of item 1 of removed)
                set csvText to csvText & linefeed & arm & "," & (item i of item 1 of unitQaly) & "," & terminal & "," & (item i of item 1 of rawCosts) & "," & (item i of item 1 of rawQaly) & "," & (item i of item 1 of zeroCosts) & "," & (item i of item 1 of horizonValues) & "," & deltaCost & "," & deltaQaly
            end repeat
        on error errText number errNum
            close book saving no
            error errText number errNum
        end try
        close book saving no
    end tell
    return csvText
end run
