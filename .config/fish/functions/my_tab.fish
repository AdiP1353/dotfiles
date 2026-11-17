function my_tab
    if commandline --showing-suggestion
        commandline --function accept-autosuggestion
    else
        commandline --function complete
    end
end
